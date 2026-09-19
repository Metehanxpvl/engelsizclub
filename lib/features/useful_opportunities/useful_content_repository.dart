import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_config.dart';
import '../../duyuru_store.dart';
import '../../utils/async_timeout.dart';
import '../global_news/global_news_model.dart';
import '../global_news/global_news_repository.dart';
import 'useful_content_model.dart';

UsefulContentItem usefulContentFromGlobalNews(GlobalNewsItem n) {
  return UsefulContentItem(
    id: '$kGlobalNewsUsefulPrefix${n.id}',
    title: n.title,
    summary: n.summary,
    body: n.titleOriginal,
    category: usefulCategoryFromGlobalNews(n.category),
    city: '',
    sourceName: n.sourceName,
    sourceUrl: n.sourceUrl,
    imageUrl: n.imageUrl,
    externalId: n.id,
    contentHash: n.id,
    status: n.status,
    createdAt: n.publishedAt,
    publishedAt: n.publishedAt,
    contentKind: 'global_news',
  );
}

class UsefulContentRepository {
  UsefulContentRepository({
    SupabaseClient? client,
    GlobalNewsRepository? news,
  })  : _db = client ?? Supabase.instance.client,
        _news = news ?? GlobalNewsRepository(client: client);

  final SupabaseClient _db;
  final GlobalNewsRepository _news;

  static const _colsCore =
      'id, title, summary, body, category, city, source_name, source_url, '
      'external_id, content_hash, status, deadline_at, expires_at, created_at';
  static const _cols = '$_colsCore, image_url';
  static const _colsDates = '$_cols, date_status, content_kind, published_at';

  Future<List<UsefulContentItem>> loadPublished({
    String category = '',
    String query = '',
  }) async {
    final cat = category.trim().toLowerCase();
    Future<List<dynamic>> run(String cols) {
      var q = _db.from('useful_content').select(cols).eq('status', 'published');
      if (cat.isNotEmpty && cat != 'tumu') {
        q = q.eq('category', cat);
      }
      return withNetworkTimeout<List<dynamic>>(
        q.order('created_at', ascending: false),
      );
    }

    final qn = query.trim().toLowerCase();
    List<UsefulContentItem> local = const [];
    try {
      final rows = await _withImageUrlColumn(run);
      local = rows
          .whereType<Map>()
          .map((e) => UsefulContentItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => isUserVisibleUsefulContent(e.status))
          .where((e) {
            if (qn.isEmpty) return true;
            return e.title.toLowerCase().contains(qn) ||
                e.summary.toLowerCase().contains(qn) ||
                e.city.toLowerCase().contains(qn);
          })
          .toList();
    } catch (_) {}
    final global = await _loadGlobalAsUseful(
      pending: false,
      category: cat,
      query: qn,
    );
    return _mergeByDate([...local, ...global]);
  }

  Future<List<UsefulContentItem>> loadPendingReview() async {
    _requireAdmin();
    List<UsefulContentItem> local = const [];
    try {
      final rows = await _withImageUrlColumn(
        (cols) => withNetworkTimeout<List<dynamic>>(
          _db
              .from('useful_content')
              .select(cols)
              .eq('status', 'pending_review')
              .order('created_at', ascending: false),
        ),
      );
      local = rows
          .whereType<Map>()
          .map((e) => UsefulContentItem.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => isPendingReviewStatus(e.status))
          .toList();
    } catch (_) {}
    return _mergeByDate([
      ...local,
      ...await _loadGlobalAsUseful(pending: true),
    ]);
  }

  Future<void> updateCopy({
    required String id,
    required String title,
    required String summary,
  }) async {
    _requireAdmin();
    if (id.startsWith(kGlobalNewsUsefulPrefix)) {
      await _news.updateCopy(
        id: globalNewsRawId(id),
        title: title,
        summary: summary,
      );
      return;
    }
    await withNetworkTimeout(
      _db.from('useful_content').update({
        'title': title.trim(),
        'summary': summary.trim(),
      }).eq('id', id),
    );
  }

  Future<void> updateImage({
    required String id,
    required String imageUrl,
  }) async {
    _requireAdmin();
    if (id.startsWith(kGlobalNewsUsefulPrefix)) {
      return;
    }
    final photo = imageUrl.trim();
    try {
      await withNetworkTimeout(
        _db.from('useful_content').update({
          'image_url': photo,
        }).eq('id', id),
      );
    } catch (e) {
      if (!_missingImageUrlColumn(e)) rethrow;
    }
  }

  Future<void> approve(
    String id, {
    String? adminEmail,
    String imageUrl = '',
    String? title,
    String? summary,
  }) async {
    _requireAdmin();
    if (id.startsWith(kGlobalNewsUsefulPrefix)) {
      await _news.approve(
        globalNewsRawId(id),
        adminEmail: adminEmail,
        title: title,
        summary: summary,
      );
      return;
    }
    final row = await _withImageUrlColumn(
      (cols) => withNetworkTimeout<Map<String, dynamic>?>(
        _db
            .from('useful_content')
            .select(cols)
            .eq('id', id)
            .eq('status', 'pending_review')
            .maybeSingle(),
      ),
    );
    if (row == null) {
      throw StateError('Kayıt bulunamadı veya zaten işlendi.');
    }
    final item = UsefulContentItem.fromJson(row);
    final draft = usefulContentToDuyuruDraft(
      item,
      imageUrl: imageUrl,
      title: title,
      summary: summary,
    );
    final email = (adminEmail ?? _db.auth.currentUser?.email ?? '').trim();
    await addDuyuru(
      title: draft.title,
      body: draft.body,
      imageUrl: draft.imageUrl,
      sourceUrl: draft.sourceUrl,
      adminEmail: email,
      isActive: true,
      isPopup: false,
      expiresAt: draft.expiresAt,
    );
    final photo = draft.imageUrl;
    final now = DateTime.now().toUtc().toIso8601String();
    final published = <String, dynamic>{
      'status': 'published',
      'published_at': now,
      'reviewed_at': now,
      'reviewed_by': _db.auth.currentUser?.id,
    };
    try {
      await withNetworkTimeout(
        _db.from('useful_content').update({
          ...published,
          'image_url': photo,
        }).eq('id', id).eq('status', 'pending_review'),
      );
    } catch (e) {
      if (!_missingImageUrlColumn(e)) rethrow;
      await withNetworkTimeout(
        _db
            .from('useful_content')
            .update(published)
            .eq('id', id)
            .eq('status', 'pending_review'),
      );
    }
  }

  Future<void> reject(String id) async {
    _requireAdmin();
    if (id.startsWith(kGlobalNewsUsefulPrefix)) {
      await _news.reject(globalNewsRawId(id));
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    await withNetworkTimeout(
      _db.from('useful_content').update({
        'status': 'rejected',
        'reviewed_at': now,
        'reviewed_by': _db.auth.currentUser?.id,
      }).eq('id', id).eq('status', 'pending_review'),
    );
  }

  Future<List<UsefulContentItem>> _loadGlobalAsUseful({
    required bool pending,
    String category = '',
    String query = '',
  }) async {
    try {
      final news = pending
          ? await _news.loadPendingReview()
          : await _news.loadPublished();
      final cat = category.trim().toLowerCase();
      final qn = query.trim().toLowerCase();
      return news.map(usefulContentFromGlobalNews).where((e) {
        if (cat.isNotEmpty && cat != 'tumu' && e.category != cat) return false;
        if (qn.isEmpty) return true;
        return e.title.toLowerCase().contains(qn) ||
            e.summary.toLowerCase().contains(qn) ||
            e.sourceName.toLowerCase().contains(qn);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<UsefulContentItem> _mergeByDate(List<UsefulContentItem> items) {
    final copy = [...items];
    copy.sort((a, b) {
      final da = a.createdAt ?? a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.createdAt ?? b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return copy;
  }

  Future<T> _withImageUrlColumn<T>(Future<T> Function(String cols) run) async {
    try {
      return await run(_colsDates);
    } catch (e) {
      if (_missingColumn(e, 'date_status') ||
          _missingColumn(e, 'content_kind') ||
          _missingColumn(e, 'published_at')) {
        try {
          return await run(_cols);
        } catch (e2) {
          if (!_missingColumn(e2, 'image_url')) rethrow;
          return await run(_colsCore);
        }
      }
      if (!_missingColumn(e, 'image_url')) rethrow;
      return await run(_colsCore);
    }
  }

  bool _missingImageUrlColumn(Object e) => _missingColumn(e, 'image_url');

  bool _missingColumn(Object e, String col) {
    final s = e.toString().toLowerCase();
    if (!s.contains(col.toLowerCase())) return false;
    return s.contains('does not exist') ||
        s.contains('schema cache') ||
        s.contains('pgrst204') ||
        s.contains('42703');
  }

  void _requireAdmin() {
    if (!isAppAdmin(_db.auth.currentUser?.email)) {
      throw StateError('Bu işlem yalnızca yöneticiler içindir.');
    }
  }
}
