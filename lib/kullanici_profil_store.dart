import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'data/location_models.dart';

class KullaniciProfil {
  const KullaniciProfil({
    this.adSoyad = '',
    this.countryCode = 'TR',
    this.sehir = '',
    this.ilce = '',
    this.meslek = '',
    this.egitim = '',
    this.deneyimYili = '',
    this.uzmanliklar = '',
    this.sertifikalar = '',
    this.calismaSekli = '',
    this.hakkimda = '',
  });

  final String adSoyad;
  final String countryCode;
  final String sehir;
  final String ilce;
  final String meslek;
  final String egitim;
  final String deneyimYili;
  final String uzmanliklar;
  final String sertifikalar;
  final String calismaSekli;
  final String hakkimda;

  LocationData get location => LocationData.fromLegacy(
        city: sehir,
        district: ilce,
        countryCode: countryCode.isEmpty ? 'TR' : countryCode,
      );

  bool get isEmpty =>
      adSoyad.trim().isEmpty &&
      sehir.trim().isEmpty &&
      ilce.trim().isEmpty &&
      meslek.trim().isEmpty &&
      egitim.trim().isEmpty &&
      deneyimYili.trim().isEmpty &&
      uzmanliklar.trim().isEmpty &&
      sertifikalar.trim().isEmpty &&
      calismaSekli.trim().isEmpty &&
      hakkimda.trim().isEmpty;

  String get menuSub {
    if (isEmpty) return 'Özgeçmişinizi oluşturun';
    if (meslek.trim().isNotEmpty) return meslek.trim();
    if (adSoyad.trim().isNotEmpty) return adSoyad.trim();
    return 'Profili tamamlamaya devam edin';
  }

  Map<String, dynamic> toJson() => {
        'adSoyad': adSoyad,
        'countryCode': countryCode,
        'location_data': location.toJson(),
        'sehir': sehir,
        'ilce': ilce,
        'meslek': meslek,
        'egitim': egitim,
        'deneyimYili': deneyimYili,
        'uzmanliklar': uzmanliklar,
        'sertifikalar': sertifikalar,
        'calismaSekli': calismaSekli,
        'hakkimda': hakkimda,
      };

  factory KullaniciProfil.fromJson(Map<String, dynamic> json) {
    final locRaw = json['location_data'] ?? json['locationData'];
    LocationData? loc;
    if (locRaw is Map) {
      loc = LocationData.fromJson(locRaw);
    }
    final code = (json['countryCode'] ??
            json['country_code'] ??
            loc?.countryCode ??
            'TR')
        .toString()
        .toUpperCase();
    return KullaniciProfil(
      adSoyad: json['adSoyad']?.toString() ?? '',
      countryCode: code.isEmpty ? 'TR' : code,
      sehir: (loc != null && loc.state.isNotEmpty)
          ? loc.state
          : (json['sehir']?.toString() ?? ''),
      ilce: (loc != null && loc.city.isNotEmpty)
          ? loc.city
          : (json['ilce']?.toString() ?? ''),
      meslek: json['meslek']?.toString() ?? '',
      egitim: json['egitim']?.toString() ?? '',
      deneyimYili: json['deneyimYili']?.toString() ?? '',
      uzmanliklar: json['uzmanliklar']?.toString() ?? '',
      sertifikalar: json['sertifikalar']?.toString() ?? '',
      calismaSekli: json['calismaSekli']?.toString() ?? '',
      hakkimda: json['hakkimda']?.toString() ?? '',
    );
  }
}

String kullaniciProfilPrefsKey(String email, {String fallback = 'anon'}) {
  final normalized = email.trim().toLowerCase();
  return 'kullanici_profil_${normalized.isEmpty ? fallback : normalized}';
}

Future<KullaniciProfil> loadKullaniciProfil(
  String email, {
  String fallback = 'anon',
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kullaniciProfilPrefsKey(email, fallback: fallback));
  if (raw == null || raw.isEmpty) return const KullaniciProfil();
  try {
    final map = jsonDecode(raw);
    if (map is Map<String, dynamic>) return KullaniciProfil.fromJson(map);
    if (map is Map) {
      return KullaniciProfil.fromJson(Map<String, dynamic>.from(map));
    }
  } catch (_) {}
  return const KullaniciProfil();
}

Future<void> saveKullaniciProfil(
  String email,
  KullaniciProfil profil, {
  String fallback = 'anon',
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kullaniciProfilPrefsKey(email, fallback: fallback),
    jsonEncode(profil.toJson()),
  );
}
