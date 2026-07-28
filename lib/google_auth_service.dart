import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'google_js_auth_stub.dart'
    if (dart.library.html) 'google_js_auth_web.dart' as google_js;

/// Google → Firebase Auth → Supabase oturumu.
///
/// Web: Firebase JS popup (engelsizclub.com) — supabase.co OAuth yok.
/// Mobil: Firebase Auth provider.
class GoogleAuthService {
  GoogleAuthService._();

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

  /// Başarılıysa Supabase [AuthResponse] döner.
  /// İptal / redirect → null.
  static Future<AuthResponse?> signIn() async {
    if (kIsWeb) {
      return _signInWeb();
    }
    return _signInMobile();
  }

  static Future<AuthResponse?> _signInWeb() async {
    // Firebase JS popup — hata yutulmaz, kullanıcıya gösterilir.
    final js = await google_js.firebaseGooglePopupJs();
    if (js == null) return null;
    if (js['cancelled'] == 'true') return null;
    if (js['redirecting'] == 'true') return null;
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
      if (m.contains('audience') || m.contains('provider')) {
        throw StateError(
          'Supabase Google Client ID eksik. Supabase → Authentication → '
          'Providers → Google → Client IDs alanına Firebase Web Client ID ekleyin.',
        );
      }
      rethrow;
    }
  }

  static Future<AuthResponse?> _signInMobile() async {
    late final firebase_auth.UserCredential firebaseCred;
    try {
      firebaseCred = await _firebaseAuth.signInWithProvider(_provider);
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (_isUserCancel(e)) return null;
      rethrow;
    }
    return _exchangeFirebaseForSupabase(firebaseCred);
  }

  static Future<AuthResponse?> completeRedirectIfAny() async {
    if (!kIsWeb) return null;
    if (Firebase.apps.isEmpty) return null;
    try {
      final result = await _firebaseAuth.getRedirectResult();
      if (result.user == null) return null;
      return _exchangeFirebaseForSupabase(result);
    } catch (_) {
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

  static bool _isUserCancel(firebase_auth.FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    return code.contains('popup-closed') ||
        code.contains('cancelled') ||
        code.contains('canceled') ||
        code == 'user-cancelled';
  }

  static Future<void> signOut() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await _firebaseAuth.signOut();
      }
    } catch (_) {}
  }
}
