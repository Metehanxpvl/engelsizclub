import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../firebase_options.dart';
import '../kredi_store.dart';
import '../user_cloud_store.dart';
import 'broadcast_push_service.dart';

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
class PushNotificationService with WidgetsBindingObserver {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  static const _androidChannelId = 'engelsizclub_default';
  static const _androidChannelName = 'Engelsiz Club';
  static const _pendingOpenPrefsKey = 'fcm_pending_open_v1';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _refreshing = false;
  String? fcmToken;
  RemoteMessage? _pendingOpen;
  BildirimAyarlari? _topicPrefs;
  String? _topicUserType;

  final StreamController<RemoteMessage> _opens =
      StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationOpened => _opens.stream;

  Map<String, String> _stringData(RemoteMessage message) =>
      message.data.map((k, v) => MapEntry(k, '$v'));

  Map<String, String> _normalizeData(Map<String, String> raw) {
    final out = <String, String>{};
    raw.forEach((k, v) {
      final key = k.trim();
      if (key.isEmpty) return;
      out[key] = v.trim();
      out[key.toLowerCase()] = v.trim();
    });
    return out;
  }

  Future<void> _persistOpenData(Map<String, String> data) async {
    if (data.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOpenPrefsKey, jsonEncode(data));
    } catch (e) {
      debugPrint('FCM pending kaydı: $e');
    }
  }

  Future<Map<String, String>?> _readPersistedOpenData({required bool clear}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingOpenPrefsKey);
      if (raw == null || raw.isEmpty) return null;
      if (clear) await prefs.remove(_pendingOpenPrefsKey);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return _normalizeData(
        decoded.map((k, v) => MapEntry('$k', '$v')),
      );
    } catch (e) {
      debugPrint('FCM pending okuma: $e');
      return null;
    }
  }

  /// Shell dinlemeden önce gelen tap (soğuk açılış).
  Map<String, String>? takePendingOpenData() {
    final m = _pendingOpen;
    _pendingOpen = null;
    if (m == null) return null;
    return _normalizeData(_stringData(m));
  }

  Future<Map<String, String>?> takePendingOpenDataAsync() async {
    final mem = takePendingOpenData();
    if (mem != null && mem.isNotEmpty) {
      unawaited(_readPersistedOpenData(clear: true));
      return mem;
    }
    return _readPersistedOpenData(clear: true);
  }

  Stream<Map<String, String>> get onOpenedData =>
      _opens.stream.map((m) => _normalizeData(_stringData(m)));

  void _emitOpen(RemoteMessage message) {
    debugPrint('FCM açıldı: data=${message.data}');
    _pendingOpen = message;
    final data = _normalizeData(_stringData(message));
    unawaited(_persistOpenData(data));
    _opens.add(message);
  }

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);

    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('FCM background handler: $e');
    }

    // iOS: izin + APNs 3 sn’lik init timeout’una takılmasın.
    unawaited(() async {
      await _requestPermission();
      await _refreshToken();
    }());

    try {
      await _initLocalNotifications().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('FCM local init: $e');
    }

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

    try {
      _messaging.onTokenRefresh.listen((token) {
        fcmToken = token;
        debugPrint('FCM token yenilendi: $token');
        unawaited(registerTokenWithServer(token));
        final prefs = _topicPrefs;
        if (prefs != null) unawaited(_applyTopics(prefs));
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
  }

  /// Soğuk açılış / bildirim tıklaması: FCM launch payload.
  Future<Map<String, String>?> recoverLaunchNotification() async {
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        _handleOpen(initial);
        return _normalizeData(_stringData(initial));
      }
    } catch (e) {
      debugPrint('FCM initial message: $e');
    }
    return takePendingOpenDataAsync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(ensureTokenRegistered());
    }
  }

  /// Giriş sonrası / token yenilenince Supabase’e kaydet (kişisel push).
  Future<void> registerTokenWithServer([String? token]) async {
    if (kIsWeb || !_initialized) return;
    final t = (token ?? fcmToken ?? '').trim();
    if (t.isEmpty) return;
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    var email = (user.email ?? '').trim().toLowerCase();
    // Apple Sign-In JWT e-postası boş kalabiliyor; profil / uid yedek.
    if (email.isEmpty) {
      try {
        final row = await client
            .from('user_profiles')
            .select('owner_email')
            .eq('owner_id', user.id)
            .maybeSingle();
        email = (row?['owner_email'] as String? ?? '').trim().toLowerCase();
      } catch (e) {
        debugPrint('FCM token e-posta profil: $e');
      }
    }
    if (email.isEmpty) email = user.id;
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
  Future<void> syncTopics(BildirimAyarlari prefs, {String? userType}) async {
    if (kIsWeb || !_initialized) return;
    _topicPrefs = prefs;
    if (userType != null) _topicUserType = userType;
    if ((fcmToken ?? '').trim().isEmpty) {
      await _refreshToken();
      return;
    }
    await _applyTopics(prefs);
  }

  Future<void> _applyTopics(BildirimAyarlari prefs) async {
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
    await set(kIlanlarTopic, prefs.ilanlar);
    final prof = isProfUserType(_topicUserType ?? currentAuthUserType());
    await set(kIlanlarProfTopic, prefs.ilanlar && prof);
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
        try {
          final launch = await _local.getNotificationAppLaunchDetails();
          final payload = launch?.notificationResponse?.payload;
          if (launch?.didNotificationLaunchApp == true &&
              payload != null &&
              payload.isNotEmpty) {
            final map = jsonDecode(payload) as Map<String, dynamic>;
            _emitOpen(
              RemoteMessage(data: map.map((k, v) => MapEntry(k, '$v'))),
            );
          }
        } catch (e) {
          debugPrint('FCM local launch: $e');
        }
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
            announcement: false,
            provisional: false,
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

    try {
      await _local
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('iOS yerel bildirim izni: $e');
    }
  }

  Future<String?> _waitForApnsToken() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return 'ok';
    }
    for (var i = 0; i < 24; i++) {
      try {
        final apns = await _messaging.getAPNSToken();
        if (apns != null && apns.isNotEmpty) return apns;
      } catch (e) {
        debugPrint('FCM APNs token: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    debugPrint('FCM: APNs token alınamadı (Push entitlement / izin).');
    return null;
  }

  Future<void> _refreshToken() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final apns = await _waitForApnsToken();
      if (apns == null) return;
      fcmToken = await _messaging.getToken().timeout(const Duration(seconds: 8));
      debugPrint('FCM token: $fcmToken');
      await registerTokenWithServer(fcmToken);
      final prefs = _topicPrefs;
      if (prefs != null && (fcmToken ?? '').trim().isNotEmpty) {
        await _applyTopics(prefs);
      }
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    } finally {
      _refreshing = false;
    }
  }

  /// Giriş sonrası: token yoksa yeniden dene, varsa sunucuya yaz.
  Future<void> ensureTokenRegistered() async {
    if (kIsWeb || !_initialized) return;
    if ((fcmToken ?? '').trim().isEmpty) {
      await _refreshToken();
      return;
    }
    await registerTokenWithServer(fcmToken);
  }

  Future<void> unregisterTokenFromServer() async {
    if (kIsWeb) return;
    final t = (fcmToken ?? '').trim();
    if (t.isEmpty) return;
    try {
      await Supabase.instance.client
          .from('user_push_tokens')
          .delete()
          .eq('token', t);
    } catch (e) {
      debugPrint('FCM token silme: $e');
    }
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    debugPrint(
      'FCM foreground: title=${message.notification?.title} data=${message.data}',
    );
    // iOS: sistem banner FCM presentation options ile gelir; yerel eklenti
    // UNUserNotificationCenter delegate'ini çalıp tıklamayı yutmasın.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;
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
