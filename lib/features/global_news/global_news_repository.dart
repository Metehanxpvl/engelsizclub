import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_config.dart';
import '../../duyuru_store.dart';
import '../../utils/async_timeout.dart';
import 'global_news_catalog.dart';
import 'global_news_model.dart';

class GlobalNewsRepository {
  GlobalNewsRepository({
    SupabaseClient? client,
    GlobalNewsCatalog? catalog,
  })  : _db = client ?? Supabase.instance.client,
        _catalog = catalog ?? GlobalNewsCatalog();

  final SupabaseClient _db;
  final GlobalNewsCatalog _catalog;

  static const _table = 'global_news_overrides';

  Future<List<GlobalNewsItem>> loadMerged() async {
    final items = await _catalog.load();
    final overrides = await _loadOverrides();
    return [
      for (final e in items) e.applyOverride(overrides[e.id]),
    ];
  }

  Future<List<GlobalNewsItem>> loadPublished({
    String category = '',
    String query = '',
  }) async {
    final cat = category.trim().toLowerCase();
    final qn = query.trim().toLowerCase();
    return (await loadMerged()).where((e) {
      if (!isPublishedGlobalNews(e.status)) return false;
      if (cat.isNotEmpty && cat != 'tumu' && e.category != cat) return false;
      if (qn.isEmpty) return true;
      return e.title.toLowerCase().contains(qn) ||
          e.summary.toLowerCase().contains(qn) ||
          e.sourceName.toLowerCase().contains(qn);
    }).toList();
  }

  Future<List<GlobalNewsItem>> loadPendingReview() async {
    _requireAdmin();
    return (await loadMerged()).where((e) => isPendingGlobalNews(e.status)).toList();
  }

  Future<void> updateCopy({
    required String id,
    required String title,
    required String summary,
  }) async {
    _requireAdmin();
    await _upsertOverride(
      id: id,
      status: 'pending_review',
      title: title.trim(),
      summary: summary.trim(),
    );
  }

  Future<void> approve(
    String id, {
    String? adminEmail,
    String? title,
    String? summary,
    String imageUrl = '',
  }) async {
    _requireAdmin();
    final items = await loadMerged();
    GlobalNewsItem? item;
    for (final e in items) {
      if (e.id == id) {
        item = e;
        break;
      }
    }
    if (item == null) {
      throw StateError('Kayıt bulunamadı.');
    }
    final headline = (title ?? item.title).trim();
    final body = (summary ?? item.summary).trim();
    final email = (adminEmail ?? _db.auth.currentUser?.email ?? '').trim();
    final photo = imageUrl.trim().isNotEmpty ? imageUrl.trim() : item.imageUrl;
    await addDuyuru(
      title: headline.isEmpty ? 'Küresel haber' : headline,
      body: body.isEmpty ? item.sourceUrl : body,
      imageUrl: photo,
      sourceUrl: item.sourceUrl,
      adminEmail: email,
      isActive: true,
      isPopup: false,
    );
    await _upsertOverride(
      id: id,
      status: 'published',
      title: headline,
      summary: body,
      imageUrl: photo,
    );
  }

  Future<void> reject(String id) async {
    _requireAdmin();
    await _upsertOverride(id: id, status: 'rejected');
  }

  Future<Map<String, GlobalNewsOverride>> _loadOverrides() async {
    try {
      final rows = await withNetworkTimeout<List<dynamic>>(
        _db.from(_table).select('news_id, status, title, summary, image_url'),
      );
      final map = <String, GlobalNewsOverride>{};
      for (final raw in rows) {
        if (raw is! Map) continue;
        final o = GlobalNewsOverride.fromJson(Map<String, dynamic>.from(raw));
        if (o.newsId.isEmpty) continue;
        map[o.newsId] = o;
      }
      return map;
    } catch (e) {
      if (_missingTable(e)) return {};
      rethrow;
    }
  }

  Future<void> _upsertOverride({
    required String id,
    required String status,
    String? title,
    String? summary,
    String? imageUrl,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final row = <String, dynamic>{
      'news_id': id,
      'status': normalizeGlobalNewsStatus(status),
      'reviewed_at': now,
      'reviewed_by': _db.auth.currentUser?.id,
      'updated_at': now,
    };
    if (title != null) row['title'] = title;
    if (summary != null) row['summary'] = summary;
    if (imageUrl != null) row['image_url'] = imageUrl;
    try {
      await withNetworkTimeout(
        _db.from(_table).upsert(row, onConflict: 'news_id'),
      );
    } catch (e) {
      throw StateError(
        _missingTable(e)
            ? 'global_news_overrides tablosu yok. SQL Editor’de global_news_overrides.sql çalıştırın.'
            : e.toString(),
      );
    }
  }

  bool _missingTable(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('global_news_overrides') &&
        (s.contains('does not exist') ||
            s.contains('schema cache') ||
            s.contains('pgrst') ||
            s.contains('42p01'));
  }

  void _requireAdmin() {
    if (!isAppAdmin(_db.auth.currentUser?.email)) {
      throw StateError('Bu işlem yalnızca yöneticiler içindir.');
    }
  }
}
