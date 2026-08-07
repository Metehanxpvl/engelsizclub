import 'package:flutter/material.dart';

/// Figma Make theme tokens (`theme.css`).
abstract final class MetoColors {
  static const Color background = Color(0xFFF2F7F4);
  static const Color foreground = Color(0xFF0D2B1F);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1A6B4A);
  static const Color primaryDark = Color(0xFF124A34);
  static const Color accentGold = Color(0xFFF4A832);
  static const Color muted = Color(0xFFDCEEE4);
  static const Color mutedFg = Color(0xFF4D7A62);
  static const Color border = Color(0x2E1A6B4A); // rgba(26,107,74,0.18)
  static const Color selectedBg = Color(0xFFE8F5EE);
  static const Color googleBorder = Color(0xFFDADCE0);
  static const Color googleText = Color(0xFF3C4043);
}

class AuthUser {
  const AuthUser({
    required this.name,
    required this.email,
    required this.avatar,
    required this.avatarColor,
    this.userType,
  });

  /// Üye olmadan gezinme.
  static const guest = AuthUser(
    name: 'Misafir',
    email: '',
    avatar: 'M',
    avatarColor: Color(0xFF94A3B8),
    userType: 'guest',
  );

  final String name;
  final String email;
  final String avatar;
  final Color avatarColor;
  final String? userType;

  bool get isGuest => userType == 'guest';

  AuthUser copyWith({
    String? name,
    String? email,
    String? avatar,
    Color? avatarColor,
    String? userType,
  }) =>
      AuthUser(
        name: name ?? this.name,
        email: email ?? this.email,
        avatar: avatar ?? this.avatar,
        avatarColor: avatarColor ?? this.avatarColor,
        userType: userType ?? this.userType,
      );
}
