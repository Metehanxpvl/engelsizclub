import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Madde durumu: yapıldı veya gerek yok. Kayıt yoksa "eksik" sayılır.
enum YolDurum { yapildi, gerekYok }

class YolKayit {
  YolKayit({
    this.taniId,
    Map<String, bool>? cevaplar,
    Map<String, YolDurum>? durumlar,
    Set<String>? otomatik,
  })  : cevaplar = cevaplar ?? {},
        durumlar = durumlar ?? {},
        otomatik = otomatik ?? {};

  String? taniId;
  final Map<String, bool> cevaplar;
  final Map<String, YolDurum> durumlar;

  /// Sihirbaz cevaplarına göre otomatik "Gerek yok" işaretlenen maddeler.
  final Set<String> otomatik;

  bool get haritaHazir => taniId != null && cevaplar.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'tani': taniId,
        'cevaplar': cevaplar,
        'durumlar': durumlar.map((k, v) => MapEntry(k, v.name)),
        'otomatik': otomatik.toList(),
      };

  factory YolKayit.fromJson(Map<String, dynamic> j) {
    final durumlar = <String, YolDurum>{};
    final ham = j['durumlar'];
    if (ham is Map) {
      ham.forEach((k, v) {
        for (final d in YolDurum.values) {
          if (d.name == v) durumlar['$k'] = d;
        }
      });
    }
    final cevaplar = <String, bool>{};
    final hamC = j['cevaplar'];
    if (hamC is Map) {
      hamC.forEach((k, v) {
        if (v is bool) cevaplar['$k'] = v;
      });
    }
    final hamO = j['otomatik'];
    return YolKayit(
      taniId: j['tani'] as String?,
      cevaplar: cevaplar,
      durumlar: durumlar,
      otomatik: hamO is List ? hamO.map((e) => '$e').toSet() : {},
    );
  }
}

/// Şimdilik cihazda (kullanıcı e-postasına göre) saklanır.
String _anahtar(String email) =>
    'yol_haritasi_v1_${email.trim().toLowerCase()}';

Future<YolKayit> yolKayitYukle(String email) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_anahtar(email));
  if (raw == null || raw.isEmpty) return YolKayit();
  try {
    final j = jsonDecode(raw);
    if (j is Map<String, dynamic>) return YolKayit.fromJson(j);
  } catch (_) {}
  return YolKayit();
}

Future<void> yolKayitKaydet(String email, YolKayit kayit) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_anahtar(email), jsonEncode(kayit.toJson()));
}
