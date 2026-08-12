import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/gelisim_etkinlik_data.dart';

SupabaseClient get _db => Supabase.instance.client;

String? _authEmail() {
  final e = _db.auth.currentUser?.email?.trim().toLowerCase();
  return (e == null || e.isEmpty) ? null : e;
}

Future<List<GelisimEtkinlik>> loadGelisimEtkinlikleri({
  bool includeInactive = false,
}) async {
  try {
    var q = _db.from('gelisim_etkinlikleri').select();
    if (!includeInactive) {
      q = q.eq('is_active', true);
    }
    final rows = await q.order('sort_order').order('id');
    return [
      for (final r in rows)
        if (r is Map<String, dynamic>) GelisimEtkinlik.fromJson(r),
    ];
  } catch (_) {
    return const [];
  }
}

/// Admin: YouTube + kaynak (+ isteğe bağlı başlık/açıklama/aktif).
Future<GelisimEtkinlik> updateGelisimEtkinlik({
  required int id,
  required String youtubeUrl,
  required String kaynak,
  String? title,
  String? description,
  String? tip,
  bool? isActive,
}) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
  final payload = <String, dynamic>{
    'youtube_url': youtubeUrl.trim(),
    'kaynak': kaynak.trim(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (title != null) payload['title'] = title.trim();
  if (description != null) payload['description'] = description.trim();
  if (tip != null) payload['tip'] = tip.trim();
  if (isActive != null) payload['is_active'] = isActive;

  final row = await _db
      .from('gelisim_etkinlikleri')
      .update(payload)
      .eq('id', id)
      .select()
      .single();
  return GelisimEtkinlik.fromJson(row);
}
