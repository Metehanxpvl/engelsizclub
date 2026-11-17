import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/async_timeout.dart';

bool _ready() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

Future<String> _anonViewerKey() async {
  final prefs = await SharedPreferences.getInstance();
  var key = (prefs.getString('expert_profile_viewer_key') ?? '').trim();
  if (key.length >= 8) return key;
  key = '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(1 << 20)}';
  await prefs.setString('expert_profile_viewer_key', key);
  return key;
}

/// Ziyaretçiyi (sahip hariç) bir kez kaydeder. Aynı kişi tekrar sayılmaz.
Future<void> recordExpertProfileView(int profileId) async {
  if (!_ready() || profileId <= 0) return;
  try {
    final anon = await _anonViewerKey();
    await withNetworkTimeout(
      Supabase.instance.client.rpc(
        'record_expert_profile_view',
        params: {
          'p_profile_id': profileId,
          'p_anon_key': anon,
        },
      ),
    );
  } catch (_) {}
}

/// Yalnız profil sahibi / admin için benzersiz bakan kişi sayısı.
Future<int> loadExpertProfileViewCount(int profileId) async {
  if (!_ready() || profileId <= 0) return 0;
  try {
    final raw = await withNetworkTimeout(
      Supabase.instance.client.rpc(
        'expert_profile_view_count',
        params: {'p_profile_id': profileId},
      ),
    );
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  } catch (_) {
    return 0;
  }
}
