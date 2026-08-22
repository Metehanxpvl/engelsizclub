import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../admin_config.dart';
import '../utils/async_timeout.dart';
import 'models/info_content.dart';

/// Supabase `info_library_contents` okuma / admin yazma.
/// Metin + YouTube URL’leri cihaz önbelleğinde (TTL); blob yok.
class InfoLibraryRepository {
  InfoLibraryRepository._();
  static final InfoLibraryRepository instance = InfoLibraryRepository._();

  SupabaseClient get _client => Supabase.instance.client;

  static const _ttl = Duration(minutes: 45);
  static const _prefsPrefix = 'info_lib_cache_v1_';
  static const _prefsTsPrefix = 'info_lib_cache_ts_v1_';

  final Map<String, List<InfoContent>> _memory = {};
  final Map<String, DateTime> _memoryAt = {};

  String _catKey(String category) => category.trim().toLowerCase();

  bool _memoryFresh(String cat) {
    final at = _memoryAt[cat];
    final list = _memory[cat];
    if (at == null || list == null) return false;
    return DateTime.now().difference(at) < _ttl;
  }

  Map<String, dynamic> _toCacheJson(InfoContent c) => {
        'id': c.id,
        'title': c.title,
        'description': c.description,
        'youtube_url': c.youtubeUrl,
        'source': c.source,
        'category': c.category,
        'created_at': c.createdAt.toIso8601String(),
        'is_active': c.isActive,
        'sort_order': c.sortOrder,
      };

  Future<void> _persist(String cat, List<InfoContent> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode([for (final c in items) _toCacheJson(c)]);
      if (payload.length > 700000) return;
      await prefs.setString('$_prefsPrefix$cat', payload);
      await prefs.setInt(
        '$_prefsTsPrefix$cat',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  Future<({List<InfoContent> items, DateTime at})?> _loadDisk(String cat) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefsPrefix$cat');
      final ts = prefs.getInt('$_prefsTsPrefix$cat') ?? 0;
      if (raw == null || raw.isEmpty || ts <= 0) return null;
      final at = DateTime.fromMillisecondsSinceEpoch(ts);
      if (DateTime.now().difference(at) > const Duration(days: 7)) return null;
      final list = jsonDecode(raw);
      if (list is! List) return null;
      final items = [
        for (final e in list.whereType<Map>())
          InfoContent.fromRow(Map<String, dynamic>.from(e)),
      ].where((c) => c.id.isNotEmpty && c.title.isNotEmpty).toList();
      if (items.isEmpty) return null;
      return (items: items, at: at);
    } catch (_) {
      return null;
    }
  }

  void _setMemory(String cat, List<InfoContent> items) {
    _memory[cat] = List<InfoContent>.unmodifiable(items);
    _memoryAt[cat] = DateTime.now();
    // ignore: unawaited_futures
    _persist(cat, items);
  }

  Future<List<InfoContent>> fetchByCategory(
    String category, {
    String? viewerEmail,
    bool includeInactive = false,
    bool forceRefresh = false,
  }) async {
    final cat = _catKey(category);
    if (cat.isEmpty) return const [];

    List<InfoContent> filter(List<InfoContent> src) {
      if (includeInactive && isAppAdmin(viewerEmail)) return src;
      return src.where((c) => c.isActive).toList();
    }

    if (!forceRefresh && _memoryFresh(cat)) {
      return filter(_memory[cat]!);
    }

    if (!forceRefresh && !_memory.containsKey(cat)) {
      final disk = await _loadDisk(cat);
      if (disk != null && DateTime.now().difference(disk.at) < _ttl) {
        _memory[cat] = List<InfoContent>.unmodifiable(disk.items);
        _memoryAt[cat] = disk.at;
        return filter(disk.items);
      }
    }

    try {
      var q = _client.from('info_library_contents').select();
      q = q.eq('category', cat);
      if (!includeInactive || !isAppAdmin(viewerEmail)) {
        q = q.eq('is_active', true);
      }
      final rows = await withNetworkTimeout(
        q
            .order('sort_order', ascending: true)
            .order('created_at', ascending: false)
            .limit(100),
      );

      final list = [
        for (final e in (rows as List).whereType<Map>())
          InfoContent.fromRow(Map<String, dynamic>.from(e)),
      ].where((c) => c.id.isNotEmpty && c.title.isNotEmpty).toList();
      _setMemory(cat, list);
      return filter(list);
    } catch (e) {
      if (_memory.containsKey(cat)) return filter(_memory[cat]!);
      final disk = await _loadDisk(cat);
      if (disk != null) {
        _memory[cat] = List<InfoContent>.unmodifiable(disk.items);
        _memoryAt[cat] = disk.at;
        return filter(disk.items);
      }
      rethrow;
    }
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
    final cat = category.trim().toLowerCase().isEmpty
        ? InfoLibraryCategories.genel
        : category.trim().toLowerCase();
    final payload = <String, dynamic>{
      'title': t,
      'description': description.trim(),
      'youtube_url': youtubeUrl.trim(),
      'source': source.trim(),
      'category': cat,
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
    final item = InfoContent.fromRow(row);
    final prev = List<InfoContent>.from(_memory[cat] ?? const []);
    _setMemory(cat, [...prev.where((e) => e.id != item.id), item]
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        if (o != 0) return o;
        return b.createdAt.compareTo(a.createdAt);
      }));
    return item;
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
    final cat = category.trim().toLowerCase();
    final payload = <String, dynamic>{
      'title': t,
      'description': description.trim(),
      'youtube_url': youtubeUrl.trim(),
      'source': source.trim(),
      'category': cat,
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
    final item = InfoContent.fromRow(row);
    final prev = List<InfoContent>.from(_memory[cat] ?? const []);
    final next = [
      for (final e in prev)
        if (e.id == item.id) item else e,
    ];
    if (!next.any((e) => e.id == item.id)) next.add(item);
    _setMemory(cat, next
      ..sort((a, b) {
        final o = a.sortOrder.compareTo(b.sortOrder);
        if (o != 0) return o;
        return b.createdAt.compareTo(a.createdAt);
      }));
    return item;
  }

  Future<void> delete(String id) async {
    if (id.trim().isEmpty) return;
    await _client.from('info_library_contents').delete().eq('id', id);
    for (final cat in _memory.keys.toList()) {
      final next = _memory[cat]!.where((e) => e.id != id).toList();
      _setMemory(cat, next);
    }
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
    final cat = ordered.first.category.trim().toLowerCase();
    final withOrder = [
      for (var i = 0; i < ordered.length; i++)
        ordered[i].copyWith(sortOrder: i),
    ];
    _setMemory(cat, withOrder);
  }
}
