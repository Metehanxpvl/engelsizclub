import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_config.dart';
import '../../duyuru_store.dart';
import '../../utils/async_timeout.dart';
import 'scientific_research_model.dart';

class ScientificResearchRepository {
  ScientificResearchRepository({SupabaseClient? client})
      : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  static const _table = 'scientific_researches';
  static const _colsCore =
      'id, title, original_title, summary, why_important, limitations, '
      'conditions, categories, study_type, evidence_level, study_phase, '
      'human_or_animal, pediatric_relevance, relevance_score, '
      'scientific_importance_score, treatment_potential_score, '
      'clinical_readiness_score, treatment_potential, recruitment_status, '
      'publication_date, country, journal, doi, pmid, nct_id, source_name, '
      'source_url, external_id, content_hash, status, ai_notes, created_at';
  static const _cols = '$_colsCore, image_url';

  Future<List<ScientificResearch>> loadForAdmin({
    ScienceAdminFilter filter = ScienceAdminFilter.pending,
  }) async {
    _requireAdmin();
    try {
      final rows = await _withImageUrlColumn(
        (cols) {
          var q = _db.from(_table).select(cols);
          switch (filter) {
            case ScienceAdminFilter.pending:
              q = q.eq('status', 'pending_review');
            case ScienceAdminFilter.published:
              q = q.eq('status', 'published');
            case ScienceAdminFilter.rejected:
              q = q.eq('status', 'rejected');
            case ScienceAdminFilter.highValue:
            case ScienceAdminFilter.clinical:
            case ScienceAdminFilter.pediatric:
              break;
          }
          return withNetworkTimeout<List<dynamic>>(
            q.order('created_at', ascending: false).limit(300),
          );
        },
      );
      return rows
          .whereType<Map>()
          .map((e) => ScientificResearch.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => matchesScienceAdminFilter(e, filter))
          .toList();
    } catch (e) {
      throw StateError(scientificResearchLoadError(e));
    }
  }

  Future<void> updateCopy({
    required String id,
    required String title,
    required String summary,
  }) async {
    _requireAdmin();
    try {
      await withNetworkTimeout(
        _db.from(_table).update({
          'title': title.trim(),
          'summary': summary.trim(),
        }).eq('id', id),
      );
    } catch (e) {
      throw StateError(scientificResearchLoadError(e));
    }
  }

  Future<void> updateImage({
    required String id,
    required String imageUrl,
  }) async {
    _requireAdmin();
    final photo = imageUrl.trim();
    try {
      await withNetworkTimeout(
        _db.from(_table).update({
          'image_url': photo,
        }).eq('id', id),
      );
    } catch (e) {
      if (!isScientificResearchImageUrlColumnMissing(e)) {
        throw StateError(scientificResearchLoadError(e));
      }
    }
  }

  /// addDuyuru (notify) sonra status=published. Duyuru yazılmazsa yayınlanmaz.
  Future<void> approve(
    String id, {
    String? adminEmail,
    String imageUrl = '',
    String? title,
    String? summary,
  }) async {
    _requireAdmin();
    try {
      final row = await _withImageUrlColumn(
        (cols) => withNetworkTimeout<Map<String, dynamic>?>(
          _db
              .from(_table)
              .select(cols)
              .eq('id', id)
              .eq('status', 'pending_review')
              .maybeSingle(),
        ),
      );
      if (row == null) {
        throw StateError('Kayıt bulunamadı veya zaten işlendi.');
      }
      final item = ScientificResearch.fromJson(row);
      final draft = scientificResearchToDuyuruDraft(
        item,
        imageUrl: imageUrl,
        title: title,
        summary: summary,
      );
      ensureScientificResearchStoryImage(draft.imageUrl);
      final email = (adminEmail ?? _db.auth.currentUser?.email ?? '').trim();
      await addDuyuru(
        title: draft.title,
        body: draft.body,
        imageUrl: draft.imageUrl,
        sourceUrl: draft.sourceUrl,
        adminEmail: email,
        isActive: true,
        isPopup: false,
        requireImage: draft.requireImage,
        notify: draft.notify,
      );
      final photo = draft.imageUrl;
      final published = scientificResearchApprovePatch();
      try {
        await withNetworkTimeout(
          _db.from(_table).update({
            ...published,
            'image_url': photo,
          }).eq('id', id).eq('status', 'pending_review'),
        );
      } catch (e) {
        if (!isScientificResearchImageUrlColumnMissing(e)) rethrow;
        await withNetworkTimeout(
          _db
              .from(_table)
              .update(published)
              .eq('id', id)
              .eq('status', 'pending_review'),
        );
      }
    } catch (e) {
      throw StateError(scientificResearchLoadError(e));
    }
  }

  Future<void> reject(String id) async {
    _requireAdmin();
    try {
      await withNetworkTimeout(
        _db
            .from(_table)
            .update(scientificResearchRejectPatch())
            .eq('id', id)
            .eq('status', 'pending_review'),
      );
    } catch (e) {
      throw StateError(scientificResearchLoadError(e));
    }
  }

  /// Yayınlanan kaydı withdrawn yoksa rejected yapar.
  Future<void> unpublish(String id) async {
    _requireAdmin();
    try {
      await withNetworkTimeout(
        _db
            .from(_table)
            .update(scientificResearchUnpublishPatch())
            .eq('id', id)
            .eq('status', 'published'),
      );
    } catch (e) {
      throw StateError(scientificResearchLoadError(e));
    }
  }

  Future<T> _withImageUrlColumn<T>(Future<T> Function(String cols) run) async {
    try {
      return await run(_cols);
    } catch (e) {
      if (!isScientificResearchImageUrlColumnMissing(e)) rethrow;
      return await run(_colsCore);
    }
  }

  void _requireAdmin() {
    if (!isAppAdmin(_db.auth.currentUser?.email)) {
      throw StateError('Bu işlem yalnızca yöneticiler içindir.');
    }
  }
}
