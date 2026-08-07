import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

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

  final StreamController<RemoteMessage> _opens =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationOpened => _opens.stream;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermission();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _refreshToken();
    _messaging.onTokenRefresh.listen((token) {
      fcmToken = token;
      debugPrint('FCM token yenilendi: $token');
    });

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpen);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleOpen(initial);
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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final map = jsonDecode(payload) as Map<String, dynamic>;
          _opens.add(
            RemoteMessage(data: map.map((k, v) => MapEntry(k, '$v'))),
          );
        } catch (_) {}
      },
    );

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
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('FCM izin durumu: ${settings.authorizationStatus}');

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _refreshToken() async {
    try {
      fcmToken = await _messaging.getToken();
      debugPrint('FCM token: $fcmToken');
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
          icon: '@mipmap/ic_launcher',
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
    debugPrint('FCM açıldı: data=${message.data}');
    _opens.add(message);
  }
}
