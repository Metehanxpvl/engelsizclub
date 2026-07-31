import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/nadir_data.dart';

List<NadirItem>? _nadirCache;
DateTime? _nadirCacheAt;
const _nadirTtl = Duration(minutes: 15);

List<NadirItem>? get cachedNadirItems => _nadirCache;

bool get hasFreshNadirCache {
  final at = _nadirCacheAt;
  final list = _nadirCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _nadirTtl;
}

void invalidateNadirCache() {
  _nadirCache = null;
  _nadirCacheAt = null;
}

void _setNadirCache(List<NadirItem> items) {
  _nadirCache = List<NadirItem>.unmodifiable(items);
  _nadirCacheAt = DateTime.now();
}

NadirItem _fromRow(Map<String, dynamic> json, NadirItem? fallback) {
  final id = json['id']?.toString() ?? fallback?.id ?? '';
  return NadirItem(
    id: id,
    name: json['name']?.toString() ?? fallback?.name ?? '',
    icon: json['icon']?.toString() ?? fallback?.icon ?? '🔬',
    shortDesc: json['short_desc']?.toString() ?? fallback?.shortDesc ?? '',
    definition: json['definition']?.toString() ?? fallback?.definition ?? '',
    effects: json['effects']?.toString() ?? fallback?.effects ?? '',
    sortOrder: (json['sort_order'] as num?)?.toInt() ?? fallback?.sortOrder ?? 0,
  );
}

/// Varsayılanları yükler; Supabase'te kayıt varsa üzerine yazar.
Future<List<NadirItem>> loadNadirItems({bool forceRefresh = false}) async {
  if (!forceRefresh && hasFreshNadirCache) {
    return List<NadirItem>.from(_nadirCache!);
  }

  final byId = {for (final d in kDefaultNadirItems) d.id: d};

  try {
    final rows = await Supabase.instance.client
        .from('nadir_hastaliklar')
        .select()
        .order('sort_order');
    for (final e in (rows as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(e);
      final id = map['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      byId[id] = _fromRow(map, byId[id]);
    }
  } catch (_) {
    // Tablo yoksa / ağ yoksa varsayılanlarla devam
  }

  final list = byId.values.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  _setNadirCache(list);
  return list;
}

Future<NadirItem> updateNadirItem(NadirItem item) async {
  final payload = <String, dynamic>{
    'id': item.id,
    'name': item.name.trim(),
    'icon': item.icon,
    'short_desc': item.shortDesc.trim(),
    'definition': item.definition.trim(),
    'effects': item.effects.trim(),
    'sort_order': item.sortOrder,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };

  Map<String, dynamic> row;
  try {
    row = Map<String, dynamic>.from(
      await Supabase.instance.client
          .from('nadir_hastaliklar')
          .upsert(payload)
          .select()
          .single(),
    );
  } catch (e) {
    // Tablo yoksa en azından lokal cache güncelle
    final prev = await loadNadirItems();
    final next = [
      for (final n in prev)
        if (n.id == item.id) item else n,
    ];
    if (!next.any((n) => n.id == item.id)) next.add(item);
    next.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    _setNadirCache(next);
    rethrow;
  }

  final updated = _fromRow(row, item);
  final prev = _nadirCache ?? kDefaultNadirItems;
  _setNadirCache([
    for (final n in prev)
      if (n.id == updated.id) updated else n,
  ]);
  return updated;
}
