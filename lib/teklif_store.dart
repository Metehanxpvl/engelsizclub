import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

String _teklifKey(String email) =>
    'teklif_verilen_ilanlar_${email.trim().toLowerCase()}';

/// Buluttan (bildirimler.actor) + yerel cache birleşimi.
Future<Set<int>> loadTeklifVerilenIlanlar(String email) async {
  if (email.trim().isEmpty) return {};
  final me = email.trim().toLowerCase();
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_teklifKey(me)) ?? const [];
  final local = <int>{
    for (final s in raw)
      if (int.tryParse(s) != null) int.parse(s),
  };

  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return local;

  try {
    final rows = await client
        .from('bildirimler')
        .select('ilan_id')
        .eq('actor_email', me)
        .eq('type', 'teklif')
        .not('ilan_id', 'is', null)
        .limit(500);
    final cloud = <int>{
      for (final e in (rows as List).whereType<Map>())
        if ((e['ilan_id'] as num?) != null) (e['ilan_id'] as num).toInt(),
    };
    final merged = {...local, ...cloud};
    await prefs.setStringList(
      _teklifKey(me),
      merged.map((e) => '$e').toList(),
    );
    return merged;
  } catch (_) {
    return local;
  }
}

Future<void> markTeklifVerildi({
  required String email,
  required int ilanId,
}) async {
  if (email.trim().isEmpty || ilanId <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  final key = _teklifKey(email);
  final current = prefs.getStringList(key) ?? <String>[];
  final id = '$ilanId';
  if (current.contains(id)) return;
  await prefs.setStringList(key, [...current, id]);
  // Kalıcı kayıt notifyIlanSahibiTeklif → bildirimler satırında tutulur.
}
