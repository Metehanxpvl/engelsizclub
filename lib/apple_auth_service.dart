import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Apple → Supabase oturumu (Sign in with Apple).
///
/// iOS/macOS: native Apple kimlik jetonu → `signInWithIdToken`.
/// Web/Android: görünürlük [isNativeAvailable] false; isteğe bağlı OAuth
/// Supabase panelinden açılabilir.
class AppleAuthService {
  AppleAuthService._();

  /// Native Sign in with Apple bu platformda sunuluyor mu?
  static Future<bool> get isNativeAvailable async {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        try {
          return await SignInWithApple.isAvailable();
        } catch (_) {
          return true; // simülatör / paket: yine de butonu göster
        }
      default:
        return false;
    }
  }

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  static String _sha256of(String input) =>
      sha256.convert(utf8.encode(input)).toString();

  /// Başarılıysa Supabase [AuthResponse] döner. Kullanıcı iptal ederse null.
  static Future<AuthResponse?> signIn() async {
    final rawNonce = _generateNonce();
    final hashedNonce = _sha256of(rawNonce);

    late final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw StateError('Apple girişi başarısız: ${e.message}');
    }

    final idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Apple kimlik jetonu alınamadı.');
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      // İlk girişte Apple yalnızca bir kez ad verir — metadata'ya yaz.
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final full = [given, family].where((e) => e.isNotEmpty).join(' ').trim();
      if (full.isNotEmpty) {
        try {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'full_name': full, 'name': full}),
          );
        } catch (_) {}
      }
      return res;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('signup') && m.contains('disabled')) {
        throw StateError(
          'Yeni üyelik kapalı. Supabase → Authentication → Providers → '
          'Apple / Settings’te “Allow new users to sign up” açık olmalı.',
        );
      }
      if (m.contains('provider') || m.contains('unsupported')) {
        throw StateError(
          'Supabase’de Apple sağlayıcısı kapalı. Authentication → Providers → '
          'Apple’ı etkinleştirin (Services ID / Key).',
        );
      }
      rethrow;
    }
  }
}
