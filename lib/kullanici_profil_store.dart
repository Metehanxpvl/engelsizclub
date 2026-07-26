import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class KullaniciProfil {
  const KullaniciProfil({
    this.adSoyad = '',
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
  final String sehir;
  final String ilce;
  final String meslek;
  final String egitim;
  final String deneyimYili;
  final String uzmanliklar;
  final String sertifikalar;
  final String calismaSekli;
  final String hakkimda;

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

  factory KullaniciProfil.fromJson(Map<String, dynamic> json) =>
      KullaniciProfil(
        adSoyad: json['adSoyad']?.toString() ?? '',
        sehir: json['sehir']?.toString() ?? '',
        ilce: json['ilce']?.toString() ?? '',
        meslek: json['meslek']?.toString() ?? '',
        egitim: json['egitim']?.toString() ?? '',
        deneyimYili: json['deneyimYili']?.toString() ?? '',
        uzmanliklar: json['uzmanliklar']?.toString() ?? '',
        sertifikalar: json['sertifikalar']?.toString() ?? '',
        calismaSekli: json['calismaSekli']?.toString() ?? '',
        hakkimda: json['hakkimda']?.toString() ?? '',
      );
}

String kullaniciProfilPrefsKey(String email, {String fallback = 'anon'}) {
  final normalized = email.trim().toLowerCase();
  return 'kullanici_profil_${normalized.isEmpty ? fallback : normalized}';
}

Future<KullaniciProfil> loadKullaniciProfil(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kullaniciProfilPrefsKey(email));
  if (raw == null || raw.isEmpty) return const KullaniciProfil();
  try {
    return KullaniciProfil.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
  } catch (_) {
    return const KullaniciProfil();
  }
}

Future<void> saveKullaniciProfil(
  String email,
  KullaniciProfil profil,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    kullaniciProfilPrefsKey(email),
    jsonEncode(profil.toJson()),
  );
}
