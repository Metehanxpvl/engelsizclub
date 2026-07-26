import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CocukProfil {
  const CocukProfil({
    this.ad = '',
    this.dogumTarihi = '',
    this.cinsiyet = '',
    this.tanilar = const [],
    this.gelisimNotu = '',
    this.terapiler = '',
  });

  final String ad;
  final String dogumTarihi;
  final String cinsiyet;
  final List<String> tanilar;
  final String gelisimNotu;
  final String terapiler;

  bool get isEmpty =>
      ad.trim().isEmpty &&
      dogumTarihi.trim().isEmpty &&
      cinsiyet.isEmpty &&
      tanilar.isEmpty &&
      gelisimNotu.trim().isEmpty &&
      terapiler.trim().isEmpty;

  bool get isFilled => ad.trim().isNotEmpty;

  String get menuSub {
    if (!isFilled) return 'Tanı ve gelişim bilgileri';
    final tani = tanilar.isEmpty ? 'Tanı eklenmedi' : tanilar.take(2).join(', ');
    return '$ad · $tani';
  }

  Map<String, dynamic> toJson() => {
        'ad': ad,
        'dogumTarihi': dogumTarihi,
        'cinsiyet': cinsiyet,
        'tanilar': tanilar,
        'gelisimNotu': gelisimNotu,
        'terapiler': terapiler,
      };

  factory CocukProfil.fromJson(Map<String, dynamic> json) => CocukProfil(
        ad: json['ad']?.toString() ?? '',
        dogumTarihi: json['dogumTarihi']?.toString() ?? '',
        cinsiyet: json['cinsiyet']?.toString() ?? '',
        tanilar: ((json['tanilar'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        gelisimNotu: json['gelisimNotu']?.toString() ?? '',
        terapiler: json['terapiler']?.toString() ?? '',
      );

  CocukProfil copyWith({
    String? ad,
    String? dogumTarihi,
    String? cinsiyet,
    List<String>? tanilar,
    String? gelisimNotu,
    String? terapiler,
  }) =>
      CocukProfil(
        ad: ad ?? this.ad,
        dogumTarihi: dogumTarihi ?? this.dogumTarihi,
        cinsiyet: cinsiyet ?? this.cinsiyet,
        tanilar: tanilar ?? this.tanilar,
        gelisimNotu: gelisimNotu ?? this.gelisimNotu,
        terapiler: terapiler ?? this.terapiler,
      );
}

String cocukProfilPrefsKey(String email, {String fallback = 'anon'}) {
  final e = email.trim().toLowerCase();
  return 'cocuk_profil_${e.isEmpty ? fallback : e}';
}

Future<CocukProfil> loadCocukProfil(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(cocukProfilPrefsKey(email));
  if (raw == null || raw.isEmpty) return const CocukProfil();
  try {
    return CocukProfil.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return const CocukProfil();
  }
}

Future<void> saveCocukProfil(String email, CocukProfil profil) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(cocukProfilPrefsKey(email), jsonEncode(profil.toJson()));
}

const kCocukTaniSecenekleri = <String>[
  'Otizm Spektrum Bozukluğu',
  'Serebral Palsi',
  'Down Sendromu',
  'SMA (Spinal Müsküler Atrofi)',
  'DEHB',
  'Gelişim Geriliği',
  'Duyu Bütünleme Sorunları',
  'İletişim Bozuklukları',
  'Nadir Hastalıklar',
  'Diğer',
];

const kCocukCinsiyetSecenekleri = <String>[
  'Kız',
  'Erkek',
  'Belirtmek istemiyorum',
];
