import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import '../user_cloud_store.dart';

/// Arka planda (isolate) gelen FCM mesajları.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('FCM background Firebase init: $e');
  }
  debugPrint(
    'FCM background: id=${message.messageId} '
    'title=${message.notification?.title} data=${message.data}',
  );
}

/// FCM + yerel bildirim (ön planda BigPicture destekli).
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _androidChannelId = 'engelsizclub_default';
  static const _androidChannelName = 'Engelsiz Club';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? fcmToken;
  RemoteMessage? _pendingOpen;

  final StreamController<RemoteMessage> _opens =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationOpened => _opens.stream;

  Map<String, String> _stringData(RemoteMessage message) =>
      message.data.map((k, v) => MapEntry(k, '$v'));

  /// Shell dinlemeden önce gelen tap (soğuk açılış).
  Map<String, String>? takePendingOpenData() {
    final m = _pendingOpen;
    _pendingOpen = null;
    if (m == null) return null;
    return _stringData(m);
  }

  Stream<Map<String, String>> get onOpenedData =>
      _opens.stream.map(_stringData);

  void _emitOpen(RemoteMessage message) {
    debugPrint('FCM açıldı: data=${message.data}');
    _pendingOpen = message;
    _opens.add(message);
  }

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('FCM background handler: $e');
    }

    try {
      await _initLocalNotifications().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FCM local init: $e');
    }

    // iOS izin diyaloğu ilk kareyi bekletmesin / asılı kalmasın.
    unawaited(_requestPermission());

    try {
      await _messaging
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          )
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FCM presentation options: $e');
    }

    unawaited(_refreshToken());
    try {
      _messaging.onTokenRefresh.listen((token) {
        fcmToken = token;
        debugPrint('FCM token yenilendi: $token');
        unawaited(registerTokenWithServer(token));
      });
    } catch (e) {
      debugPrint('FCM token refresh listen: $e');
    }

    try {
      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);
    } catch (e) {
      debugPrint('FCM message listen: $e');
    }

    try {
      final initial = await _messaging
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initial != null) {
        _handleOpen(initial);
      }
    } catch (e) {
      debugPrint('FCM initial message: $e');
    }
  }

  /// Giriş sonrası / token yenilenince Supabase’e kaydet (kişisel push).
  Future<void> registerTokenWithServer([String? token]) async {
    if (kIsWeb || !_initialized) return;
    final t = (token ?? fcmToken ?? '').trim();
    if (t.isEmpty) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    final email = (user?.email ?? '').trim().toLowerCase();
    if (user == null || email.isEmpty) return;
    try {
      await client.from('user_push_tokens').upsert(
        {
          'token': t,
          'owner_email': email,
          'owner_id': user.id,
          'platform': defaultTargetPlatform.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (e) {
      debugPrint('FCM token kaydı: $e');
    }
  }

  /// Bildirim tercihlerine göre FCM topic abonelikleri.
  Future<void> syncTopics(BildirimAyarlari prefs) async {
    if (kIsWeb || !_initialized) return;
    Future<void> set(String topic, bool on) async {
      try {
        if (on) {
          await _messaging.subscribeToTopic(topic);
        } else {
          await _messaging.unsubscribeFromTopic(topic);
        }
      } catch (e) {
        debugPrint('FCM topic $topic: $e');
      }
    }

    await set('duyurular', prefs.duyurular);
    await set('ilanlar', prefs.ilanlar);
    await set('forum', prefs.forum);
    await set('mesajlar', prefs.mesajlar);
  }

  Future<void> _initLocalNotifications() async {
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    var ok = false;
    for (final icon in const ['ic_stat_notify', 'ic_launcher']) {
      try {
        await _local.initialize(
          settings: InitializationSettings(
            android: AndroidInitializationSettings(icon),
            iOS: iosInit,
          ),
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload == null || payload.isEmpty) return;
            try {
              final map = jsonDecode(payload) as Map<String, dynamic>;
              _emitOpen(
                RemoteMessage(data: map.map((k, v) => MapEntry(k, '$v'))),
              );
            } catch (_) {}
          },
        );
        ok = true;
        break;
      } catch (e) {
        debugPrint('FCM local notify init ($icon): $e');
      }
    }
    if (!ok) return;

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _androidChannelId,
        _androidChannelName,
        description: 'Genel uygulama bildirimleri',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _messaging
          .requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: true,
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('FCM izin durumu: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('FCM requestPermission: $e');
    }

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      // runApp öncesi mainActivity null olabilir — FCM init'i düşürmesin.
      await androidPlugin
          ?.requestNotificationsPermission()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('POST_NOTIFICATIONS isteği: $e');
    }
  }

  Future<void> _refreshToken() async {
    try {
      fcmToken = await _messaging.getToken().timeout(const Duration(seconds: 8));
      debugPrint('FCM token: $fcmToken');
      await registerTokenWithServer(fcmToken);
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'FCM foreground: title=${message.notification?.title} data=${message.data}',
    );
    final n = message.notification;
    final title = n?.title ?? message.data['title']?.toString() ?? '';
    final body = n?.body ?? message.data['body']?.toString() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    final imageUrl = (n?.android?.imageUrl ??
            message.data['image']?.toString() ??
            '')
        .trim();

    StyleInformation? style;
    AndroidBitmap<Object>? largeIcon;
    if (imageUrl.startsWith('https://')) {
      final bytes = await _downloadImage(imageUrl);
      if (bytes != null && bytes.isNotEmpty) {
        final bmp = ByteArrayAndroidBitmap(bytes);
        largeIcon = bmp;
        style = BigPictureStyleInformation(
          bmp,
          largeIcon: bmp,
          contentTitle: title,
          summaryText: body,
        );
      }
    }

    await _local.show(
      id: message.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: 'Genel uygulama bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notify',
          largeIcon: largeIcon,
          styleInformation: style,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data.isEmpty ? null : jsonEncode(message.data),
    );
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      final r = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 8),
          );
      if (r.statusCode == 200 && r.bodyBytes.isNotEmpty) {
        return r.bodyBytes;
      }
    } catch (e) {
      debugPrint('Bildirim görseli indirilemedi: $e');
    }
    return null;
  }

  void _handleOpen(RemoteMessage message) {
    _emitOpen(message);
  }
}
