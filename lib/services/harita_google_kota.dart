import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Engelsiz Haritalar → Google Places aylık kotası (Supabase sayaç).
///
/// Her Google Places isteğinden önce [izinAl] çağrılır. Admin Google'ı
/// kapattıysa veya aylık sınır dolduysa `false` döner; çağıran OpenStreetMap'e
/// düşer. Hata (ağ vb.) durumunda da güvenli tarafta kalıp `false` döner.
class HaritaGoogleKota {
  HaritaGoogleKota._();

  static DateTime? _redSonu;

  static Future<bool> izinAl() async {
    final simdi = DateTime.now();
    final red = _redSonu;
    if (red != null && simdi.isBefore(red)) return false;
    try {
      final r = await Supabase.instance.client
          .rpc('harita_google_izin_al')
          .timeout(const Duration(seconds: 8));
      final ok = r == true;
      if (!ok) _redSonu = simdi.add(const Duration(minutes: 10));
      return ok;
    } catch (e) {
      debugPrint('[HaritaGoogleKota] izin alınamadı: $e');
      return false;
    }
  }

  /// Admin ayarı değiştirince önbelleği temizle.
  static void onbellekTemizle() => _redSonu = null;

  static Future<HaritaGoogleDurum> durum() async {
    final r = await Supabase.instance.client.rpc('harita_google_durum');
    final row = (r is List && r.isNotEmpty) ? r.first : r;
    if (row is! Map) {
      throw StateError('Harita kota durumu okunamadı.');
    }
    return HaritaGoogleDurum(
      googleAcik: row['google_acik'] == true,
      aylikLimit: (row['aylik_limit'] as num?)?.toInt() ?? 0,
      buAy: (row['bu_ay'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<void> ayarKaydet({bool? googleAcik, int? aylikLimit}) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (googleAcik != null) 'google_acik': googleAcik,
      if (aylikLimit != null) 'aylik_limit': aylikLimit,
    };
    final rows = await Supabase.instance.client
        .from('harita_google_ayar')
        .update(patch)
        .eq('id', 1)
        .select();
    if (rows.isEmpty) {
      throw StateError('Ayar kaydedilemedi (yetki yok).');
    }
    onbellekTemizle();
  }
}

class HaritaGoogleDurum {
  const HaritaGoogleDurum({
    required this.googleAcik,
    required this.aylikLimit,
    required this.buAy,
  });

  final bool googleAcik;
  final int aylikLimit;
  final int buAy;
}
