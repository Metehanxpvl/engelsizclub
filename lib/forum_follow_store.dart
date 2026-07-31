import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/ilanlar_data.dart' show publicContactLabel;

/// Forum konularından bildirim alma (kategori takip).
class ForumFollowStore {
  ForumFollowStore._();

  static String _key(String email) =>
      'forum_follow_cats_${email.trim().toLowerCase()}';

  static Future<Set<String>> loadFollowed(String email) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList(_key(email)) ?? const [];
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> saveFollowed(String email, Set<String> cats) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_key(email), cats.toList()..sort());
  }

  static Future<void> setFollowing(
    String email,
    String category, {
    required bool follow,
  }) async {
    final set = await loadFollowed(email);
    final cat = category.trim();
    if (cat.isEmpty) return;
    if (follow) {
      set.add(cat);
    } else {
      set.remove(cat);
    }
    await saveFollowed(email, set);
    await syncFollowToCloud(email, cat, follow);
  }

  static Future<void> syncFollowToCloud(
    String email,
    String category,
    bool follow,
  ) async {
    final owner = email.trim().toLowerCase();
    if (owner.isEmpty || category.trim().isEmpty) return;
    try {
      if (follow) {
        await Supabase.instance.client.from('forum_topic_follows').upsert({
          'owner_email': owner,
          'category': category.trim(),
        });
      } else {
        await Supabase.instance.client
            .from('forum_topic_follows')
            .delete()
            .eq('owner_email', owner)
            .eq('category', category.trim());
      }
    } catch (_) {}
  }

  static String _short(String t) {
    final s = t.trim();
    if (s.length <= 120) return s;
    return '${s.substring(0, 117)}...';
  }

  /// Yeni gönderi → bu kategoriyi takip edenlere bildirim.
  static Future<void> notifyFollowersOfPost({
    required String category,
    required String title,
    required String actorName,
    required String actorEmail,
  }) async {
    final cat = category.trim();
    final me = actorEmail.trim().toLowerCase();
    if (cat.isEmpty || me.isEmpty) return;
    try {
      final rows = await Supabase.instance.client
          .from('forum_topic_follows')
          .select('owner_email')
          .eq('category', cat);
      final name = publicContactLabel(me, preferredName: actorName);
      for (final row in (rows as List)) {
        final owner =
            (row['owner_email']?.toString() ?? '').trim().toLowerCase();
        if (owner.isEmpty || owner == me) continue;
        await Supabase.instance.client.from('bildirimler').insert({
          'owner_email': owner,
          'actor_email': me,
          'actor_name': name,
          'type': 'forum',
          'title': 'Takip ettiğin konuda yeni yazı',
          'body': _short('$cat · $title'),
          'read': false,
        });
      }
    } catch (_) {}
  }
}
