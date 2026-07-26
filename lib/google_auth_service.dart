import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google → Firebase Auth → Supabase oturumu.
///
/// Web'de Supabase `signInWithOAuth` kullanılmaz (URL'de `*.supabase.co`
/// görünmesin diye). Google jetonu Firebase popup/redirect ile alınır.
class GoogleAuthService {
  GoogleAuthService._();

  static final _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  static firebase_auth.GoogleAuthProvider get _provider {
    return firebase_auth.GoogleAuthProvider()
      ..addScope('openid')
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});
  }

  /// Başarılıysa Supabase [AuthResponse] döner.
  /// Kullanıcı iptal ederse null. Redirect başlatıldıysa da null (sayfa yenilenir).
  static Future<AuthResponse?> signIn() async {
    late final firebase_auth.UserCredential firebaseCred;
    try {
      if (kIsWeb) {
        firebaseCred = await _firebaseAuth.signInWithPopup(_provider);
      } else {
        firebaseCred = await _firebaseAuth.signInWithProvider(_provider);
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      if (_isUserCancel(e)) return null;
      // Popup engellendiyse aynı marka alanında redirect dene (supabase yok).
      if (kIsWeb && e.code == 'popup-blocked') {
        await _firebaseAuth.signInWithRedirect(_provider);
        return null;
      }
      rethrow;
    }

    return _exchangeFirebaseForSupabase(firebaseCred);
  }

  /// `signInWithRedirect` dönüşünde çağrılır (web).
  static Future<AuthResponse?> completeRedirectIfAny() async {
    if (!kIsWeb) return null;
    final result = await _firebaseAuth.getRedirectResult();
    if (result.user == null) return null;
    return _exchangeFirebaseForSupabase(result);
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

    if (googleIdToken == null || googleIdToken.isEmpty) {
      // Bazı tarayıcılarda credential boş kalabiliyor; bir kez daha popup/reauth.
      if (kIsWeb && firebaseCred.user != null) {
        final again = await firebaseCred.user!.reauthenticateWithPopup(
          _provider,
        );
        final againOauth = again.credential;
        if (againOauth is firebase_auth.OAuthCredential) {
          googleIdToken = againOauth.idToken;
          googleAccessToken = againOauth.accessToken ?? googleAccessToken;
        }
      }
    }

    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw StateError(
        'Google kimlik jetonu alınamadı. Firebase Console → Authentication → '
        'Sign-in method → Google sağlayıcısının açık olduğundan ve '
        'Authorized domains içinde engelsizclub.com bulunduğundan emin olun.',
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
      await _firebaseAuth.signOut();
    } catch (_) {}
  }
}
