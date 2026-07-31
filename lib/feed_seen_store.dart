import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// İlan / forum “son görüldü” — alt menü yeni gönderi sayısı için.
class FeedSeenStore {
  FeedSeenStore._();

  static const _ilanKey = 'feed_seen_ilanlar_ms';
  static const _forumKey = 'feed_seen_forum_ms';

  static Future<DateTime?> _read(String key) async {
    final p = await SharedPreferences.getInstance();
    final ms = p.getInt(key);
    if (ms == null || ms <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  static Future<void> _write(String key, DateTime at) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(key, at.toUtc().millisecondsSinceEpoch);
  }

  static Future<DateTime?> lastSeenIlanlar() => _read(_ilanKey);
  static Future<DateTime?> lastSeenForum() => _read(_forumKey);

  static Future<void> markIlanlarSeen([DateTime? at]) =>
      _write(_ilanKey, at ?? DateTime.now().toUtc());

  static Future<void> markForumSeen([DateTime? at]) =>
      _write(_forumKey, at ?? DateTime.now().toUtc());

  static String _iso(DateTime at) => at.toUtc().toIso8601String();

  /// Buluttaki en yeni ilan / gönderi zamanı (UTC).
  static Future<DateTime?> latestIlanCreatedAt() async {
    try {
      final row = await Supabase.instance.client
          .from('ilanlar')
          .select('created_at')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final raw = row?['created_at']?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<DateTime?> latestForumCreatedAt() async {
    try {
      final row = await Supabase.instance.client
          .from('forum_posts')
          .select('created_at')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final raw = row?['created_at']?.toString();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw)?.toUtc();
    } catch (_) {
      return null;
    }
  }

  static Future<int> _countAfter({
    required String table,
    required DateTime seen,
  }) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select('id')
          .gt('created_at', _iso(seen))
          .limit(99);
      return (rows as List).length.clamp(0, 99);
    } catch (_) {
      return 0;
    }
  }

  /// Son görülenden sonra eklenen yeni ilan sayısı.
  static Future<int> countNewIlanlar() async {
    final latest = await latestIlanCreatedAt();
    if (latest == null) return 0;
    final seen = await lastSeenIlanlar();
    if (seen == null) {
      // İlk açılış: mevcut içeriği görüldü say, sayı gösterme
      await markIlanlarSeen(latest);
      return 0;
    }
    if (!latest.isAfter(seen)) return 0;
    return _countAfter(table: 'ilanlar', seen: seen);
  }

  /// Son görülenden sonra eklenen yeni forum gönderisi sayısı.
  static Future<int> countNewForum() async {
    final latest = await latestForumCreatedAt();
    if (latest == null) return 0;
    final seen = await lastSeenForum();
    if (seen == null) {
      await markForumSeen(latest);
      return 0;
    }
    if (!latest.isAfter(seen)) return 0;
    return _countAfter(table: 'forum_posts', seen: seen);
  }

  @Deprecated('Use countNewIlanlar')
  static Future<bool> hasNewIlanlar() async => (await countNewIlanlar()) > 0;

  @Deprecated('Use countNewForum')
  static Future<bool> hasNewForum() async => (await countNewForum()) > 0;
}
