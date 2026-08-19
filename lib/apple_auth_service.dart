import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// iOS Sign in with Apple → Supabase oturumu.
class AppleAuthService {
  AppleAuthService._();

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  static String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  static String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Başarılıysa Supabase [AuthResponse] döner; iptal edilirse null.
  static Future<AuthResponse?> signIn() async {
    if (!isAvailable) return null;

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

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

      // İlk girişte Apple ad-soyad yalnızca bir kez gelir.
      final given = credential.givenName?.trim() ?? '';
      final family = credential.familyName?.trim() ?? '';
      final fullName = [given, family].where((p) => p.isNotEmpty).join(' ');
      if (fullName.isNotEmpty) {
        final user = res.user ?? Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final meta = Map<String, dynamic>.from(
            user.userMetadata ?? const {},
          );
          final existingName = meta['name'] ?? meta['full_name'];
          if (existingName is! String || existingName.trim().isEmpty) {
            try {
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(
                  data: {
                    ...meta,
                    'name': fullName,
                    'full_name': fullName,
                  },
                ),
              );
            } catch (_) {}
          }
        }
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
      if (m.contains('provider') || m.contains('audience')) {
        throw StateError(
          'Supabase Apple sağlayıcısı yapılandırılmamış. Supabase → Authentication → '
          'Providers → Apple’ı açın ve Bundle ID’yi (com.sakircaykara.engelsizclub) ekleyin.',
        );
      }
      rethrow;
    }
  }
}
