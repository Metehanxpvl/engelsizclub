import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ilan_store.dart';

/// Misafir cihaz kimliği — unique görüntüleme için.
Future<String> guestViewerKey() async {
  final prefs = await SharedPreferences.getInstance();
  const k = 'engelsiz_viewer_key';
  var v = (prefs.getString(k) ?? '').trim();
  if (v.length >= 16) return v;
  const hex = '0123456789abcdef';
  final r = Random.secure();
  v = List.generate(32, (_) => hex[r.nextInt(16)]).join();
  await prefs.setString(k, v);
  return v;
}

Future<int> recordIlanView(int ilanId) async {
  if (ilanId <= 0) return 0;
  try {
    final guest = await guestViewerKey();
    final raw = await Supabase.instance.client.rpc(
      'record_ilan_view',
      params: {'p_id': ilanId, 'p_guest_key': guest},
    );
    final n = (raw as num?)?.toInt() ?? 0;
    if (n > 0) applyRuntimeIlanViews(ilanId, n);
    return n;
  } catch (_) {
    return 0;
  }
}

Future<int> recordForumView(int postId) async {
  if (postId <= 0) return 0;
  try {
    final guest = await guestViewerKey();
    final raw = await Supabase.instance.client.rpc(
      'record_forum_view',
      params: {'p_id': postId, 'p_guest_key': guest},
    );
    return (raw as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
}

String ilanViewLabel(int n) {
  if (n <= 0) return 'Henüz görüntüleme yok';
  if (n == 1) return '1 kişi görüntüledi';
  return '$n kişi görüntüledi';
}

String forumReadLabel(int n) {
  if (n <= 0) return '0 okuma';
  if (n == 1) return '1 kişi okudu';
  return '$n kişi okudu';
}
