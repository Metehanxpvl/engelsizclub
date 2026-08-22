import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/gelisim_etkinlik_data.dart';
import 'utils/async_timeout.dart';

SupabaseClient get _db => Supabase.instance.client;

String? _authEmail() {
  final e = _db.auth.currentUser?.email?.trim().toLowerCase();
  return (e == null || e.isEmpty) ? null : e;
}

void _requireAdmin() {
  if (!isAppAdmin(_authEmail())) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
}

Future<List<GelisimEtkinlik>> loadGelisimEtkinlikleri({
  bool includeInactive = false,
}) async {
  try {
    var q = _db.from('gelisim_etkinlikleri').select();
    if (!includeInactive) {
      q = q.eq('is_active', true);
    }
    final rows = await withNetworkTimeout(
      q.order('sort_order').order('id'),
    );
    return [
      for (final r in rows) GelisimEtkinlik.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<int> _nextId() async {
  final rows = await _db
      .from('gelisim_etkinlikleri')
      .select('id')
      .order('id', ascending: false)
      .limit(1);
  if (rows.isEmpty) return 1;
  final max = (rows.first['id'] as num?)?.toInt() ?? 0;
  return max + 1;
}

Future<int> _nextSort() async {
  final rows = await _db
      .from('gelisim_etkinlikleri')
      .select('sort_order')
      .order('sort_order', ascending: false)
      .limit(1);
  if (rows.isEmpty) return 1;
  return ((rows.first['sort_order'] as num?)?.toInt() ?? 0) + 1;
}

/// Yeni etkinlik (başlık → YouTube → kaynak → açıklama).
Future<GelisimEtkinlik> insertGelisimEtkinlik({
  required String title,
  required String description,
  required String youtubeUrl,
  required String kaynak,
  String tip = '',
  String grup = 'bilissel',
  String grupAd = 'Bilişsel',
  String yas = '2-3yas',
  String yasAd = '2–3 yaş',
  String zorluk = 'kolay',
  String zorlukAd = 'Kolay',
  bool isActive = true,
}) async {
  _requireAdmin();
  final id = await _nextId();
  final sort = await _nextSort();
  final row = await _db
      .from('gelisim_etkinlikleri')
      .insert({
        'id': id,
        'title': title.trim(),
        'description': description.trim(),
        'tip': tip.trim(),
        'grup': grup,
        'grup_ad': grupAd,
        'yas': yas,
        'yas_ad': yasAd,
        'zorluk': zorluk,
        'zorluk_ad': zorlukAd,
        'youtube_url': youtubeUrl.trim(),
        'kaynak': kaynak.trim(),
        'sort_order': sort,
        'is_active': isActive,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      })
      .select()
      .single();
  return GelisimEtkinlik.fromJson(row);
}

Future<GelisimEtkinlik> updateGelisimEtkinlik({
  required int id,
  required String title,
  required String description,
  required String youtubeUrl,
  required String kaynak,
  String? tip,
  String? grup,
  String? grupAd,
  String? yas,
  String? yasAd,
  String? zorluk,
  String? zorlukAd,
  bool? isActive,
}) async {
  _requireAdmin();
  final payload = <String, dynamic>{
    'title': title.trim(),
    'description': description.trim(),
    'youtube_url': youtubeUrl.trim(),
    'kaynak': kaynak.trim(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (tip != null) payload['tip'] = tip.trim();
  if (grup != null) payload['grup'] = grup;
  if (grupAd != null) payload['grup_ad'] = grupAd;
  if (yas != null) payload['yas'] = yas;
  if (yasAd != null) payload['yas_ad'] = yasAd;
  if (zorluk != null) payload['zorluk'] = zorluk;
  if (zorlukAd != null) payload['zorluk_ad'] = zorlukAd;
  if (isActive != null) payload['is_active'] = isActive;

  final row = await _db
      .from('gelisim_etkinlikleri')
      .update(payload)
      .eq('id', id)
      .select()
      .single();
  return GelisimEtkinlik.fromJson(row);
}

Future<void> deleteGelisimEtkinlik(int id) async {
  _requireAdmin();
  await _db.from('gelisim_etkinlikleri').delete().eq('id', id);
}

Future<void> setGelisimEtkinlikActive({
  required int id,
  required bool isActive,
}) async {
  _requireAdmin();
  await _db.from('gelisim_etkinlikleri').update({
    'is_active': isActive,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', id);
}
