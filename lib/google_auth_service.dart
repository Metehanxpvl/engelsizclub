import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_js_auth_stub.dart'
    if (dart.library.html) 'google_js_auth_web.dart' as google_js;

/// Google → Supabase oturumu.
///
/// Web: Firebase JS popup (engelsizclub.com).
/// Android/iOS: Hosted Firebase Google page → deep link + idToken
/// (Play SHA-1 / Supabase→Google redirect_uri gerekmez).
class GoogleAuthService {
  GoogleAuthService._();

  /// Firebase / Google Cloud Web Client ID (Supabase Google provider’da da olmalı).
  static const webClientId =
      '59695056324-3dk4r1lsht7n5agn811vjj9777l0qdce.apps.googleusercontent.com';

  static const mobileRedirect = 'io.supabase.engelsizclub://login-callback';

  /// Web’de çalışan Firebase Google akışını mobil tarayıcıda açar.
  static const mobileAuthPage =
      'https://engelsizclub.com/mobile_google_auth.html';

  static StreamSubscription<Uri>? _linkSub;
  static Completer<AuthResponse?>? _mobileWait;
  static bool _listening = false;

  static firebase_auth.FirebaseAuth get _firebaseAuth {
    if (Firebase.apps.isEmpty) {
      throw StateError(
        'Firebase henüz başlatılmadı. Firebase.initializeApp() çağrılmalı.',
      );
    }
    return firebase_auth.FirebaseAuth.instance;
  }

  static firebase_auth.GoogleAuthProvider get _provider {
    return firebase_auth.GoogleAuthProvider()
      ..addScope('openid')
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
  }

  /// Deep link dinleyicisini başlat (main’de bir kez).
  static Future<void> startMobileDeepLinkListener() async {
    if (kIsWeb || _listening) return;
    _listening = true;
    final appLinks = AppLinks();
    try {
      final initial = await appLinks.getInitialLink();
      if (initial != null) {
        await handleMobileAuthDeepLink(initial);
      }
    } catch (_) {}
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      unawaited(handleMobileAuthDeepLink(uri));
    });
  }

  static Future<void> disposeDeepLinkListener() async {
    await _linkSub?.cancel();
    _linkSub = null;
    _listening = false;
  }

  /// Başarılıysa Supabase [AuthResponse] döner.
  static Future<AuthResponse?> signIn() async {
    if (kIsWeb) {
      return _signInWeb();
    }
    return _signInMobileBridge();
  }

  static Future<AuthResponse?> _signInWeb() async {
    final js = await google_js.firebaseGooglePopupJs();
    if (js == null) return null;
    if (js['cancelled'] == 'true') return null;
      if (js['redirecting'] == 'true') {
        // Sayfa Google’a gidiyor — oturum dönüşte completeRedirectIfAny ile kurulur.
        throw const GoogleAuthRedirecting();
      }
    final err = js['error'];
    if (err != null && err.isNotEmpty) {
      throw StateError(err);
    }
    final idToken = js['idToken'];
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google kimlik jetonu alınamadı.');
    }
    try {
      return await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: js['accessToken'],
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('signup') && m.contains('disabled')) {
        throw StateError(
          'Yeni üyelik kapalı. Supabase → Authentication → Providers → '
          'Google / Settings’te “Allow new users to sign up” açık olmalı.',
        );
      }
      if (m.contains('audience') || m.contains('provider')) {
        throw StateError(
          'Supabase Google Client ID eksik. Supabase → Authentication → '
          'Providers → Google → Client IDs alanına Firebase Web Client ID ekleyin.',
        );
      }
      rethrow;
    }
  }

  /// Web’deki çalışan Firebase Google girişini Custom Tab’da açar;
  /// dönüşte id_token ile Supabase oturumu kurar.
  static Future<AuthResponse?> _signInMobileBridge() async {
    await startMobileDeepLinkListener();

    if (_mobileWait != null && !_mobileWait!.isCompleted) {
      _mobileWait!.complete(null);
    }
    final wait = Completer<AuthResponse?>();
    _mobileWait = wait;

    final uri = Uri.parse(mobileAuthPage);
    var launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!launched) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    if (!launched) {
      _mobileWait = null;
      throw StateError(
        'Google giriş sayfası açılamadı. İnternet bağlantınızı kontrol edin.',
      );
    }

    try {
      return await wait.future.timeout(
        const Duration(minutes: 3),
        onTimeout: () => null,
      );
    } finally {
      if (identical(_mobileWait, wait)) {
        _mobileWait = null;
      }
    }
  }

  static Map<String, String> _paramsFromUri(Uri uri) {
    final out = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      out.addAll(Uri.splitQueryString(uri.fragment));
    }
    return out;
  }

  static Future<void> handleMobileAuthDeepLink(Uri uri) async {
    if (uri.scheme != 'io.supabase.engelsizclub') return;
    final host = uri.host;
    if (host.isNotEmpty && host != 'login-callback') return;
    if (host.isEmpty && uri.path != 'login-callback' && uri.path != '/login-callback') {
      // Bazı cihazlarda host boş, path login-callback olabilir
      if (!uri.toString().contains('login-callback')) return;
    }

    final params = _paramsFromUri(uri);
    if (params['cancelled'] == '1') {
      if (_mobileWait != null && !_mobileWait!.isCompleted) {
        _mobileWait!.complete(null);
      }
      return;
    }

    final idToken = params['id_token'];
    if (idToken == null || idToken.isEmpty) return;

    final accessToken = params['access_token'];
    try {
      try {
        await closeInAppWebView();
      } catch (_) {}
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: (accessToken != null && accessToken.isNotEmpty)
            ? accessToken
            : null,
      );
      if (_mobileWait != null && !_mobileWait!.isCompleted) {
        _mobileWait!.complete(res);
      }
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      final mapped = (m.contains('signup') &&
              (m.contains('disabled') || m.contains('not allowed')))
          ? StateError(
              'Yeni Google üyelikleri kapalı. Supabase → Authentication → '
              'Settings: “Allow new users to sign up” açın.',
            )
          : e;
      if (_mobileWait != null && !_mobileWait!.isCompleted) {
        _mobileWait!.completeError(mapped);
      }
    } catch (e) {
      if (_mobileWait != null && !_mobileWait!.isCompleted) {
        _mobileWait!.completeError(e);
      }
    }
  }

  static Future<AuthResponse?> completeRedirectIfAny() async {
    if (!kIsWeb) return null;

    // Web’de FlutterFire init edilmiyor — Firebase JS redirect sonucunu kullan.
    try {
      final js = await google_js.firebaseGoogleRedirectResultJs();
      if (js == null) return null;
      if (js['empty'] == 'true') return null;
      final err = js['error'];
      if (err != null && err.isNotEmpty) {
        throw StateError(err);
      }
      final idToken = js['idToken'];
      if (idToken == null || idToken.isEmpty) return null;
      return await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: js['accessToken'],
      );
    } catch (e) {
      // Redirect yoksa veya hata — çağıran normal oturuma düşer
      if (e is StateError) rethrow;
      return null;
    }
  }

  static Future<AuthResponse> _exchangeFirebaseForSupabase(
    firebase_auth.UserCredential firebaseCred,
  ) async {
    final oauth = firebaseCred.credential;
    String? googleIdToken;
    String? googleAccessToken;
    if (oauth is firebase_auth.OAuthCredential) {
      googleIdToken = oauth.idToken;
      googleAccessToken = oauth.accessToken;
    }

    if ((googleIdToken == null || googleIdToken.isEmpty) &&
        kIsWeb &&
        firebaseCred.user != null) {
      final again =
          await firebaseCred.user!.reauthenticateWithPopup(_provider);
      final againOauth = again.credential;
      if (againOauth is firebase_auth.OAuthCredential) {
        googleIdToken = againOauth.idToken;
        googleAccessToken = againOauth.accessToken ?? googleAccessToken;
      }
    }

    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw StateError(
        'Google kimlik jetonu alınamadı. Firebase Console → Authentication → '
        'Sign-in method → Google açık olmalı.',
      );
    }

    return Supabase.instance.client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: googleIdToken,
      accessToken: googleAccessToken,
    );
  }

  static Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await _firebaseAuth.signOut();
      }
    } catch (_) {}
  }
}

/// Web popup engelli → Firebase redirect sürüyor (sayfa yenilenecek).
class GoogleAuthRedirecting implements Exception {
  const GoogleAuthRedirecting();
}
