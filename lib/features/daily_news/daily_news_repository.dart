import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_config.dart';
import '../../duyuru_store.dart';
import '../../utils/async_timeout.dart';
import 'daily_news_model.dart';

class DailyNewsRepository {
  DailyNewsRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _table = 'news_candidates';
  static const _cols =
      'id, source_name, source_url, article_url, title, summary, '
      'published_at, image_url, category, categories, relevance_score, '
      'importance_level, ai_reason, affected_users, status';

  void _requireAdmin() {
    final email = _db.auth.currentUser?.email;
    if (!isAppAdmin(email)) {
      throw StateError('Bu işlem yalnızca yöneticiler içindir.');
    }
  }

  Future<List<DailyNewsCandidate>> loadPending() async {
    _requireAdmin();
    final rows = await withNetworkTimeout<List<dynamic>>(
      _db
          .from(_table)
          .select(_cols)
          .eq('status', 'pending')
          .order('relevance_score', ascending: false)
          .limit(80),
    );
    return rows
        .whereType<Map>()
        .map((e) => DailyNewsCandidate.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> reject(String id) async {
    _requireAdmin();
    await withNetworkTimeout(
      _db.from(_table).update({'status': 'rejected'}).eq('id', id).eq(
            'status',
            'pending',
          ),
    );
  }

  Future<void> approve(DailyNewsCandidate item, {String? adminEmail}) async {
    _requireAdmin();
    final email = (adminEmail ?? _db.auth.currentUser?.email ?? '').trim();
    await addDuyuru(
      title: item.title,
      body: item.summary,
      imageUrl: item.imageUrl,
      sourceUrl: item.articleUrl,
      adminEmail: email,
      isActive: true,
      isPopup: false,
    );
    await withNetworkTimeout(
      _db.from(_table).update({'status': 'approved'}).eq('id', item.id).eq(
            'status',
            'pending',
          ),
    );
  }
}
