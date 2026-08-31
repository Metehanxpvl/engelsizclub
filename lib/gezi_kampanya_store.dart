import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'utils/async_timeout.dart';

/// Türkçe il adını URL/slug için ASCII'ye çevirir (Ankara → ankara, İstanbul → istanbul).
String turkishCitySlug(String name) {
  const tr = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final rune in name.trim().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(tr[ch] ?? ch.toLowerCase());
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

/// Arama için Türkçe katlaması (İstanbul / istanbul eşleşir).
String foldTurkish(String s) {
  const tr = <String, String>{
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'I': 'i',
    'İ': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final rune in s.trim().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(tr[ch] ?? ch.toLowerCase());
  }
  return buf.toString();
}

class GeziItem {
  const GeziItem({
    required this.id,
    required this.cityName,
    required this.citySlug,
    this.title = '',
    required this.imageUrl,
    this.description = '',
    this.sortOrder = 0,
    this.sortIndex = 0,
    this.isActive = true,
    this.createdBy = '',
    required this.createdAt,
  });

  final int id;
  final String cityName;
  final String citySlug;
  final String title;
  final String imageUrl;
  final String description;
  final int sortOrder;
  final int sortIndex;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  bool get hasDescription => description.trim().isNotEmpty;

  int get cityOrder {
    if (sortIndex > 0) return sortIndex;
    if (sortOrder > 0) return sortOrder;
    return 0;
  }

  factory GeziItem.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    final sortOrder = (json['sort_order'] as num?)?.toInt() ?? 0;
    final sortIndex = (json['sort_index'] as num?)?.toInt() ?? 0;
    return GeziItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      cityName: json['city_name']?.toString() ?? '',
      citySlug: json['city_slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sortOrder: sortOrder,
      sortIndex: sortIndex > 0 ? sortIndex : sortOrder,
      isActive: json['is_active'] != false,
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: created,
    );
  }
}

class KampanyaItem {
  const KampanyaItem({
    required this.id,
    this.title = '',
    required this.imageUrl,
    this.description = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.createdBy = '',
    required this.createdAt,
  });

  final int id;
  final String title;
  final String imageUrl;
  final String description;
  final int sortOrder;
  final bool isActive;
  final String createdBy;
  final DateTime createdAt;

  bool get hasDescription => description.trim().isNotEmpty;

  factory KampanyaItem.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    return KampanyaItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] != false,
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: created,
    );
  }
}

const kGeziTileKey = 'gezi';
const kKampanyaTileKey = 'kampanya';

List<GeziItem>? _geziCache;
DateTime? _geziCacheAt;
List<KampanyaItem>? _kampanyaCache;
DateTime? _kampanyaCacheAt;
Map<String, String>? _tileCoverCache;
DateTime? _tileCoverCacheAt;
const _ttl = Duration(minutes: 10);

void invalidateGeziCache() {
  _geziCache = null;
  _geziCacheAt = null;
}

void invalidateKampanyaCache() {
  _kampanyaCache = null;
  _kampanyaCacheAt = null;
}

void invalidateTileCoverCache() {
  _tileCoverCache = null;
  _tileCoverCacheAt = null;
}

bool get hasFreshGeziCache {
  final at = _geziCacheAt;
  final list = _geziCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

bool get hasFreshKampanyaCache {
  final at = _kampanyaCacheAt;
  final list = _kampanyaCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<GeziItem>? get cachedGeziItems => _geziCache;

List<KampanyaItem>? get cachedKampanyaItems => _kampanyaCache;

bool get hasFreshTileCoverCache {
  final at = _tileCoverCacheAt;
  final map = _tileCoverCache;
  if (at == null || map == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

Map<String, String>? get cachedTileCovers => _tileCoverCache;

String _normalizeTileKey(String key) {
  final k = key.trim().toLowerCase();
  if (k != kGeziTileKey && k != kKampanyaTileKey) {
    throw StateError('Geçersiz kutucuk: $key');
  }
  return k;
}

Future<Map<String, String>> loadTileCovers({
  bool forceRefresh = false,
}) async {
  if (!forceRefresh && hasFreshTileCoverCache) {
    return Map<String, String>.from(_tileCoverCache!);
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from('gezi_kampanya_tiles').select(),
    );
    final map = <String, String>{
      kGeziTileKey: '',
      kKampanyaTileKey: '',
    };
    for (final e in (rows as List).whereType<Map>()) {
      final key = e['tile_key']?.toString().trim().toLowerCase() ?? '';
      if (key == kGeziTileKey || key == kKampanyaTileKey) {
        map[key] = e['image_url']?.toString().trim() ?? '';
      }
    }
    _tileCoverCache = Map<String, String>.unmodifiable(map);
    _tileCoverCacheAt = DateTime.now();
    return Map<String, String>.from(map);
  } catch (_) {
    if (_tileCoverCache != null) {
      return Map<String, String>.from(_tileCoverCache!);
    }
    return {
      kGeziTileKey: '',
      kKampanyaTileKey: '',
    };
  }
}

Future<void> upsertTileCover({
  required String tileKey,
  required String imageUrl,
  required String adminEmail,
}) async {
  _requireAdmin(adminEmail);
  final key = _normalizeTileKey(tileKey);
  await Supabase.instance.client.from('gezi_kampanya_tiles').upsert({
    'tile_key': key,
    'image_url': imageUrl.trim(),
    'updated_by': adminEmail.trim().toLowerCase(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
  invalidateTileCoverCache();
}

void _requireAdmin(String? email) {
  if (!isAppAdmin(email)) {
    throw StateError('Yalnızca admin ekleyebilir / silebilir.');
  }
}

Future<List<GeziItem>> loadGeziItems({
  String? cityName,
  String? citySlug,
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  List<GeziItem> all;
  if (!forceRefresh && hasFreshGeziCache) {
    all = List<GeziItem>.from(_geziCache!);
  } else {
    try {
      final rows = await withNetworkTimeout(
        Supabase.instance.client
            .from('gezi_rehberi')
            .select()
            .order('sort_order')
            .order('created_at'),
      );
      all = [
        for (final e in (rows as List).whereType<Map>())
          GeziItem.fromJson(Map<String, dynamic>.from(e)),
      ].where((g) => g.id > 0 && g.imageUrl.trim().isNotEmpty).toList();
      _geziCache = List.unmodifiable(all);
      _geziCacheAt = DateTime.now();
    } catch (_) {
      if (_geziCache != null) {
        all = List<GeziItem>.from(_geziCache!);
      } else {
        return const [];
      }
    }
  }

  final admin = isAppAdmin(viewerEmail);
  var list = admin ? all : all.where((g) => g.isActive).toList();
  final name = cityName?.trim();
  final slug = (citySlug ?? (name != null ? turkishCitySlug(name) : '')).trim();
  if (name != null && name.isNotEmpty) {
    final folded = foldTurkish(name);
    list = list
        .where(
          (g) =>
              foldTurkish(g.cityName) == folded ||
              (slug.isNotEmpty && g.citySlug == slug),
        )
        .toList();
  } else if (slug.isNotEmpty) {
    list = list.where((g) => g.citySlug == slug).toList();
  }
  return list;
}

Future<List<KampanyaItem>> loadKampanyaItems({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  if (!forceRefresh && hasFreshKampanyaCache) {
    final cached = List<KampanyaItem>.from(_kampanyaCache!);
    if (isAppAdmin(viewerEmail)) return cached;
    return cached.where((k) => k.isActive).toList();
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('kampanyalar')
          .select()
          .order('sort_order')
          .order('created_at', ascending: false),
    );
    final list = [
      for (final e in (rows as List).whereType<Map>())
        KampanyaItem.fromJson(Map<String, dynamic>.from(e)),
    ].where((k) => k.id > 0 && k.imageUrl.trim().isNotEmpty).toList();
    _kampanyaCache = List.unmodifiable(list);
    _kampanyaCacheAt = DateTime.now();
    if (isAppAdmin(viewerEmail)) return list;
    return list.where((k) => k.isActive).toList();
  } catch (_) {
    if (_kampanyaCache != null) {
      final cached = List<KampanyaItem>.from(_kampanyaCache!);
      if (isAppAdmin(viewerEmail)) return cached;
      return cached.where((k) => k.isActive).toList();
    }
    return const [];
  }
}

Future<int> _nextSort(String table) async {
  try {
    final rows = await Supabase.instance.client
        .from(table)
        .select('sort_order')
        .order('sort_order', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 1;
    return ((rows.first['sort_order'] as num?)?.toInt() ?? 0) + 1;
  } catch (_) {
    return 1;
  }
}

/// İl içi sonraki numara (1, 2, 3…).
Future<int> _nextGeziSortIndex(String citySlug) async {
  final slug = citySlug.trim();
  try {
    final rows = await Supabase.instance.client
        .from('gezi_rehberi')
        .select('sort_index')
        .eq('city_slug', slug)
        .order('sort_index', ascending: false)
        .limit(1);
    if (rows.isEmpty) return 1;
    return ((rows.first['sort_index'] as num?)?.toInt() ?? 0) + 1;
  } catch (_) {
    try {
      final rows = await Supabase.instance.client
          .from('gezi_rehberi')
          .select('sort_order')
          .eq('city_slug', slug)
          .order('sort_order', ascending: false)
          .limit(1);
      if (rows.isEmpty) return 1;
      return ((rows.first['sort_order'] as num?)?.toInt() ?? 0) + 1;
    } catch (_) {
      return 1;
    }
  }
}

Future<GeziItem> addGeziItem({
  required String cityName,
  required String imageUrl,
  String title = '',
  String description = '',
  required String adminEmail,
}) async {
  _requireAdmin(adminEmail);
  final name = cityName.trim();
  if (name.isEmpty) throw StateError('İl seçin.');
  final heading = title.trim();
  if (heading.isEmpty) throw StateError('Başlık girin.');
  final url = imageUrl.trim();
  if (url.isEmpty) throw StateError('Görsel gerekli.');
  final slug = turkishCitySlug(name);
  final next = await _nextGeziSortIndex(slug);
  try {
    final row = await Supabase.instance.client.from('gezi_rehberi').insert({
      'city_name': name,
      'city_slug': slug,
      'title': heading,
      'image_url': url,
      'description': description.trim(),
      'sort_index': next,
      'sort_order': next,
      'is_active': true,
      'created_by': adminEmail.trim().toLowerCase(),
    }).select().single();
    invalidateGeziCache();
    return GeziItem.fromJson(Map<String, dynamic>.from(row));
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('title') ||
        raw.contains('sort_index') ||
        raw.contains('PGRST204') ||
        raw.contains('schema cache')) {
      throw StateError(
        'Başlık kolonu yok. Supabase’de gezi_rehberi_title.sql çalıştırın.',
      );
    }
    rethrow;
  }
}

Future<GeziItem> updateGeziItem({
  required int id,
  required String title,
  String description = '',
  String? imageUrl,
  required String adminEmail,
}) async {
  _requireAdmin(adminEmail);
  final heading = title.trim();
  if (heading.isEmpty) throw StateError('Başlık girin.');
  final patch = <String, dynamic>{
    'title': heading,
    'description': description.trim(),
  };
  final url = imageUrl?.trim() ?? '';
  if (url.isNotEmpty) patch['image_url'] = url;
  try {
    final row = await Supabase.instance.client
        .from('gezi_rehberi')
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    invalidateGeziCache();
    return GeziItem.fromJson(Map<String, dynamic>.from(row));
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('title') ||
        raw.contains('PGRST204') ||
        raw.contains('schema cache')) {
      throw StateError(
        'Başlık kolonu yok. Supabase’de gezi_rehberi_title.sql çalıştırın.',
      );
    }
    rethrow;
  }
}

/// İl listesindeki sırayı 1, 2, 3… olarak yazar.
Future<void> persistGeziCityOrder(List<GeziItem> ordered) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  _requireAdmin(email);
  try {
    for (var i = 0; i < ordered.length; i++) {
      final n = i + 1;
      await Supabase.instance.client.from('gezi_rehberi').update({
        'sort_index': n,
        'sort_order': n,
      }).eq('id', ordered[i].id);
    }
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('sort_index') ||
        raw.contains('PGRST204') ||
        raw.contains('schema cache')) {
      throw StateError(
        'Sıra kolonu yok. Supabase’de gezi_rehberi_title.sql çalıştırın.',
      );
    }
    rethrow;
  }
  invalidateGeziCache();
}

Future<void> deleteGeziItem(int id) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  _requireAdmin(email);
  await Supabase.instance.client.from('gezi_rehberi').delete().eq('id', id);
  invalidateGeziCache();
}

Future<KampanyaItem> addKampanyaItem({
  String title = '',
  required String imageUrl,
  String description = '',
  required String adminEmail,
}) async {
  _requireAdmin(adminEmail);
  final url = imageUrl.trim();
  if (url.isEmpty) throw StateError('Görsel gerekli.');
  final row = await Supabase.instance.client.from('kampanyalar').insert({
    'title': title.trim(),
    'image_url': url,
    'description': description.trim(),
    'sort_order': await _nextSort('kampanyalar'),
    'is_active': true,
    'created_by': adminEmail.trim().toLowerCase(),
  }).select().single();
  invalidateKampanyaCache();
  return KampanyaItem.fromJson(Map<String, dynamic>.from(row));
}

Future<void> deleteKampanyaItem(int id) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  _requireAdmin(email);
  await Supabase.instance.client.from('kampanyalar').delete().eq('id', id);
  invalidateKampanyaCache();
}
