import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import 'models/info_content.dart';

/// Supabase `info_library_contents` okuma / admin yazma.
class InfoLibraryRepository {
  InfoLibraryRepository._();
  static final InfoLibraryRepository instance = InfoLibraryRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<InfoContent>> fetchByCategory(
    String category, {
    String? viewerEmail,
    bool includeInactive = false,
  }) async {
    final cat = category.trim().toLowerCase();
    if (cat.isEmpty) return const [];

    var q = _client.from('info_library_contents').select();
    q = q.eq('category', cat);
    if (!includeInactive || !isAppAdmin(viewerEmail)) {
      q = q.eq('is_active', true);
    }
    final rows = await q
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false)
        .limit(100);

    return [
      for (final e in (rows as List).whereType<Map>())
        InfoContent.fromRow(Map<String, dynamic>.from(e)),
    ].where((c) => c.id.isNotEmpty && c.title.isNotEmpty).toList();
  }

  Future<InfoContent> create({
    required String title,
    required String description,
    required String youtubeUrl,
    required String category,
    required String adminEmail,
    String source = '',
    int? sortOrder,
  }) async {
    final t = title.trim();
    if (t.isEmpty) throw StateError('Başlık gerekli.');
    final payload = <String, dynamic>{
      'title': t,
      'description': description.trim(),
      'youtube_url': youtubeUrl.trim(),
      'source': source.trim(),
      'category': category.trim().toLowerCase().isEmpty
          ? InfoLibraryCategories.genel
          : category.trim().toLowerCase(),
      'is_active': true,
      'sort_order': sortOrder ?? 0,
      'created_by': adminEmail.trim().toLowerCase(),
    };
    final row = Map<String, dynamic>.from(
      await _client
          .from('info_library_contents')
          .insert(payload)
          .select()
          .single(),
    );
    return InfoContent.fromRow(row);
  }

  Future<InfoContent> update({
    required String id,
    required String title,
    required String description,
    required String youtubeUrl,
    required String category,
    String source = '',
    bool isActive = true,
    int? sortOrder,
  }) async {
    if (id.trim().isEmpty) throw StateError('Geçersiz id.');
    final t = title.trim();
    if (t.isEmpty) throw StateError('Başlık gerekli.');
    final payload = <String, dynamic>{
      'title': t,
      'description': description.trim(),
      'youtube_url': youtubeUrl.trim(),
      'source': source.trim(),
      'category': category.trim().toLowerCase(),
      'is_active': isActive,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
    final row = Map<String, dynamic>.from(
      await _client
          .from('info_library_contents')
          .update(payload)
          .eq('id', id)
          .select()
          .single(),
    );
    return InfoContent.fromRow(row);
  }

  Future<void> delete(String id) async {
    if (id.trim().isEmpty) return;
    await _client.from('info_library_contents').delete().eq('id', id);
  }

  /// Admin sürükle-bırak: listedeki sırayı `sort_order` (0..n-1) olarak yazar.
  Future<void> reorder(List<InfoContent> ordered) async {
    if (ordered.isEmpty) return;
    await Future.wait([
      for (var i = 0; i < ordered.length; i++)
        _client
            .from('info_library_contents')
            .update({'sort_order': i})
            .eq('id', ordered[i].id),
    ]);
  }
}
