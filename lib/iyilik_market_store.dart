import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'kredi_store.dart';
import 'utils/async_timeout.dart';

const kIyilikMarketTebrik = 'Tebrikler 1 iyilik market puanı kazandınız';

String iyilikMarketPrefsKeyFor(String email) {
  final e = email.trim().toLowerCase();
  return 'iyilik_market_puan_${e.isEmpty ? 'anon' : e}';
}

Future<int> loadIyilikMarketPuan({required String email}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = iyilikMarketPrefsKeyFor(email);
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user != null) {
    try {
      final row = await client
          .from('user_profiles')
          .select('iyilik_market_puan')
          .eq('owner_id', user.id)
          .maybeSingle();
      final n = (row?['iyilik_market_puan'] as num?)?.toInt();
      if (n != null) {
        await prefs.setInt(key, n);
        return n;
      }
    } catch (_) {}
  }
  return prefs.getInt(key) ?? 0;
}

Future<int?> awardIyilikMarketPuan({
  required String email,
  String? userType,
}) async {
  if (!isAileUserType(userType)) return null;
  final client = Supabase.instance.client;
  if (client.auth.currentUser == null) return null;
  try {
    final raw = await withNetworkTimeout(
      client.rpc('award_iyilik_market_puan'),
      message: 'İyilik market puanı yazılamadı.',
    );
    final n = raw is num ? raw.toInt() : int.tryParse('$raw');
    if (n == null) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(iyilikMarketPrefsKeyFor(email), n);
    return n;
  } catch (_) {
    return null;
  }
}

String forumShareSnack({
  required bool isEdit,
  required bool isExpert,
  required bool awardedMarket,
}) {
  if (isEdit) return 'Gönderi güncellendi ✅';
  final base = isExpert
      ? 'Köşe yazınız paylaşıldı — herkes görebilir ✅'
      : 'Gönderiniz paylaşıldı — herkes görebilir ✅';
  if (!awardedMarket) return base;
  return '$base +1 iyilik market puanı';
}

String ilanShareSnack({
  required bool isEdit,
  required bool awardedMarket,
}) {
  if (isEdit) return 'İlan güncellendi ✅';
  if (awardedMarket) return 'İlanınız yayınlandı. +1 iyilik market puanı';
  return 'İlanınız yayınlandı ✅';
}

String haritaShareSnack({required bool awardedMarket}) {
  if (awardedMarket) return 'Yer kaydedildi. +1 iyilik market puanı';
  return 'Yer kaydedildi.';
}
