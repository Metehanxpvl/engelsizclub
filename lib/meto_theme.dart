import 'package:flutter/material.dart';

/// Tanı farkındalık rengi paleti.
class MetoPalette {
  const MetoPalette({
    required this.id,
    required this.name,
    required this.aciklama,
    required this.primary,
    required this.primaryDark,
    required this.muted,
    required this.mutedFg,
    required this.selectedBg,
    required this.background,
    required this.foreground,
  });

  final String id;
  final String name;
  final String aciklama;
  final Color primary;
  final Color primaryDark;
  final Color muted;
  final Color mutedFg;
  final Color selectedBg;
  final Color background;
  final Color foreground;
}

/// Uygulama renk temaları (farkındalık renkleri).
const List<MetoPalette> kMetoPalettes = <MetoPalette>[
  MetoPalette(
    id: 'yesil',
    name: 'Yeşil',
    aciklama: 'Serebral Palsi farkındalığı',
    primary: Color(0xFF1A6B4A),
    primaryDark: Color(0xFF124A34),
    muted: Color(0xFFDCEEE4),
    mutedFg: Color(0xFF4D7A62),
    selectedBg: Color(0xFFE8F5EE),
    background: Color(0xFFF2F7F4),
    foreground: Color(0xFF0D2B1F),
  ),
  MetoPalette(
    id: 'mavi',
    name: 'Mavi',
    aciklama: 'Otizm farkındalığı',
    primary: Color(0xFF1D5FA8),
    primaryDark: Color(0xFF134378),
    muted: Color(0xFFDCE8F5),
    mutedFg: Color(0xFF4A6788),
    selectedBg: Color(0xFFE8F0FA),
    background: Color(0xFFF2F6FB),
    foreground: Color(0xFF0D1F33),
  ),
  MetoPalette(
    id: 'down',
    name: 'Mavi-sarı',
    aciklama: 'Down Sendromu farkındalığı',
    primary: Color(0xFF1D5FA8),
    primaryDark: Color(0xFF134378),
    muted: Color(0xFFFBEFC8),
    mutedFg: Color(0xFF4A6788),
    selectedBg: Color(0xFFFDF5DC),
    background: Color(0xFFF7F8FA),
    foreground: Color(0xFF0D1F33),
  ),
  MetoPalette(
    id: 'mor',
    name: 'Mor',
    aciklama: 'Epilepsi ve Rett Sendromu farkındalığı',
    primary: Color(0xFF6A3FA0),
    primaryDark: Color(0xFF4B2C73),
    muted: Color(0xFFE9E0F5),
    mutedFg: Color(0xFF6E5A88),
    selectedBg: Color(0xFFF1EBFA),
    background: Color(0xFFF6F3FA),
    foreground: Color(0xFF231536),
  ),
  MetoPalette(
    id: 'turuncu',
    name: 'Turuncu',
    aciklama: 'DEHB farkındalığı',
    primary: Color(0xFFA3420A),
    primaryDark: Color(0xFF823508),
    muted: Color(0xFFFBE3D3),
    mutedFg: Color(0xFF8A5A3C),
    selectedBg: Color(0xFFFDEEE4),
    background: Color(0xFFFBF6F2),
    foreground: Color(0xFF3A1A06),
  ),
  MetoPalette(
    id: 'sari',
    name: 'Koyu sarı',
    aciklama: 'Spina Bifida farkındalığı',
    primary: Color(0xFF8A5A00),
    primaryDark: Color(0xFF634000),
    muted: Color(0xFFF8EBC4),
    mutedFg: Color(0xFF7A6236),
    selectedBg: Color(0xFFFCF3DA),
    background: Color(0xFFFAF7EE),
    foreground: Color(0xFF2E2000),
  ),
  MetoPalette(
    id: 'fistik',
    name: 'Fıstık yeşili',
    aciklama: 'Kas distrofisi farkındalığı',
    primary: Color(0xFF4A6B0F),
    primaryDark: Color(0xFF344C0A),
    muted: Color(0xFFE5F0CF),
    mutedFg: Color(0xFF5E7040),
    selectedBg: Color(0xFFEEF6DF),
    background: Color(0xFFF5F8EE),
    foreground: Color(0xFF1C2805),
  ),
];

/// Figma Make theme tokens — aktif [MetoPalette] üzerinden.
abstract final class MetoColors {
  static MetoPalette _aktif = kMetoPalettes.first;

  static MetoPalette get aktif => _aktif;

  static void uygula(MetoPalette palette) {
    _aktif = palette;
  }

  static Color get background => _aktif.background;
  static Color get foreground => _aktif.foreground;
  static const Color card = Color(0xFFFFFFFF);
  static Color get primary => _aktif.primary;
  static Color get primaryDark => _aktif.primaryDark;
  static const Color accentGold = Color(0xFFF4A832);
  static Color get muted => _aktif.muted;
  static Color get mutedFg => _aktif.mutedFg;
  static Color get border =>
      _aktif.primary.withValues(alpha: 0x2E / 255.0); // rgba(primary,0.18)
  static Color get selectedBg => _aktif.selectedBg;
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
