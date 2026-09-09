import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/async_timeout.dart';

int minHaftalikSaat(String kademe) {
  if (kademe == 'ortaogretim') return 16;
  if (kademe == 'ilkogretim' || kademe == 'ortaogretim_ozel') return 10;
  return 0;
}

SupabaseClient get _db => Supabase.instance.client;

/// Ad, soyad ve T.C. yazılmaz. Yalnızca hizmet / kademe / model özeti.
Future<String> insertEvdeEgitimBasvuru({
  required String hizmetTuru,
  String? kademe,
  int? haftalikDersSaati,
  String? egitimTuru,
}) async {
  final user = _db.auth.currentUser;
  if (user == null) {
    throw StateError('Oturum yok');
  }
  final row = await withNetworkTimeout(
    _db.from('evde_egitim_basvurulari').insert({
      'user_id': user.id,
      'hizmet_turu': hizmetTuru,
      'egitim_turu': egitimTuru,
      'kademe': kademe,
      'haftalik_ders_saati': haftalikDersSaati,
      'durum': 'taslak',
      'ek1_veli_sozlesmesi_onaylandi': false,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single(),
  );
  return row['id'] as String;
}
