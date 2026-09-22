import 'package:supabase_flutter/supabase_flutter.dart';

import '../../admin_config.dart';
import '../../utils/async_timeout.dart';
import 'scientific_papers_catalog.dart';
import 'scientific_research_model.dart';

class ScientificResearchRepository {
  ScientificResearchRepository({
    SupabaseClient? client,
    ScientificPapersCatalog? catalog,
  })  : _db = client ?? Supabase.instance.client,
        _catalog = catalog ?? ScientificPapersCatalog();

  final SupabaseClient _db;
  final ScientificPapersCatalog _catalog;

  static const _table = 'scientific_researches';
  static const _cols =
      'id, title, original_title, summary, why_important, limitations, '
      'conditions, categories, study_type, evidence_level, study_phase, '
      'human_or_animal, pediatric_relevance, relevance_score, '
      'scientific_importance_score, treatment_potential_score, '
      'clinical_readiness_score, treatment_potential, recruitment_status, '
      'publication_date, country, journal, doi, pmid, nct_id, source_name, '
      'source_url, external_id, content_hash, status, ai_notes, created_at';

  Future<List<ScientificResearch>> loadForAdmin({
    ScienceAdminFilter filter = ScienceAdminFilter.pending,
  }) async {
    _requireAdmin();
    try {
      final github = await _loadGithubCatalog();
      if (github.isNotEmpty) {
        return github.where((e) => matchesScienceAdminFilter(e, filter)).toList();
      }
      return _loadSupabase(filter);
    } catch (e) {
      try {
        return await _loadSupabase(filter);
      } catch (_) {
        throw StateError(scientificResearchLoadError(e));
      }
    }
  }

  Future<List<ScientificResearch>> _loadGithubCatalog() async {
    try {
      return await _catalog.load();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ScientificResearch>> _loadSupabase(ScienceAdminFilter filter) async {
    var q = _db.from(_table).select(_cols);
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
    final rows = await withNetworkTimeout<List<dynamic>>(
      q.order('created_at', ascending: false).limit(kScientificResearchListLimit),
    );
    return rows
        .whereType<Map>()
        .map((e) => ScientificResearch.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => matchesScienceAdminFilter(e, filter))
        .toList();
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

  /// status=published. Duyuru veya FCM yok.
  Future<void> approve(String id) async {
    _requireAdmin();
    try {
      await withNetworkTimeout(
        _db
            .from(_table)
            .update(scientificResearchApprovePatch())
            .eq('id', id)
            .eq('status', 'pending_review'),
      );
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

  void _requireAdmin() {
    if (!isAppAdmin(_db.auth.currentUser?.email)) {
      throw StateError('Bu işlem yalnızca yöneticiler içindir.');
    }
  }
}
