import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/more_menu_data.dart';
import 'utils/async_timeout.dart';

List<MoreMenuItem>? _allCache;
DateTime? _cacheAt;
const _cacheTtl = Duration(minutes: 5);

/// Tüm aktif satırlar (kök + çocuk). Grup sheet buradan okur.
List<MoreMenuItem>? get cachedMoreMenuAll => _allCache;

/// Kullanıcı üst listesi (kökler).
List<MoreMenuItem>? get cachedMoreMenu {
  final all = _allCache;
  if (all == null) return null;
  return prepareUserMoreMenu(all);
}

void invalidateMoreMenuCache() {
  _allCache = null;
  _cacheAt = null;
}

void _setCache(List<MoreMenuItem> items) {
  _allCache = List<MoreMenuItem>.unmodifiable(items);
  _cacheAt = DateTime.now();
}

const _menuColsWithParent =
    'id, title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, parent_id, updated_at';
const _menuColsLegacy =
    'id, title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, updated_at';

MoreMenuItem? _tryParseMenuRow(dynamic raw) {
  try {
    if (raw is! Map) return null;
    return MoreMenuItem.fromJson(Map<String, dynamic>.from(raw));
  } catch (_) {
    return null;
  }
}

Future<List<dynamic>> _fetchMenuRows({required bool includeInactive}) async {
  Future<List<dynamic>> run(String cols) async {
    var q = _db.from('daha_fazlasi_menu').select(cols);
    if (!includeInactive) {
      q = q.eq('is_active', true);
    }
    final rows = await withNetworkTimeout(
      q.order('sort_order').order('id'),
    );
    return rows is List ? rows : const [];
  }

  try {
    return await run(_menuColsWithParent);
  } catch (e) {
    if (isMissingParentIdColumn(e)) {
      try {
        return await run(_menuColsLegacy);
      } catch (_) {}
    }
    try {
      var q = _db.from('daha_fazlasi_menu').select();
      if (!includeInactive) q = q.eq('is_active', true);
      final rows = await withNetworkTimeout(
        q.order('sort_order').order('id'),
      );
      return rows is List ? rows : const [];
    } catch (_) {
      rethrow;
    }
  }
}

bool get _hasFreshCache {
  final at = _cacheAt;
  final list = _allCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _cacheTtl;
}

SupabaseClient get _db => Supabase.instance.client;

String? _authEmail() {
  final e = _db.auth.currentUser?.email?.trim().toLowerCase();
  return (e == null || e.isEmpty) ? null : e;
}

bool isMissingParentIdColumn(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('parent_id') &&
      (s.contains('column') ||
          s.contains('schema cache') ||
          s.contains('42703') ||
          s.contains('does not exist'));
}

bool _isMissingFolderType(Object e) {
  final s = e.toString().toLowerCase();
  return s.contains('link_type') &&
      (s.contains('folder') || s.contains('check') || s.contains('23514'));
}

/// Aktif menü (kullanıcı kökleri). Admin [includeInactive] ile pasifleri de alır.
Future<List<MoreMenuItem>> loadMoreMenu({
  bool includeInactive = false,
  bool forceRefresh = false,
}) async {
  final all = await loadMoreMenuAll(
    includeInactive: includeInactive,
    forceRefresh: forceRefresh,
  );
  return includeInactive
      ? prepareAdminMoreMenu(all)
      : prepareUserMoreMenu(all);
}

/// Ham liste (ağaç için). Kullanıcı cache’i yalnız aktif satırlardır.
Future<List<MoreMenuItem>> loadMoreMenuAll({
  bool includeInactive = false,
  bool forceRefresh = false,
}) async {
  if (!forceRefresh && !includeInactive && _hasFreshCache) {
    return _allCache!;
  }

  try {
    final rows = await _fetchMenuRows(includeInactive: includeInactive);
    final items = <MoreMenuItem>[];
    for (final r in rows) {
      final item = _tryParseMenuRow(r);
      if (item != null) items.add(item);
    }
    if (items.isEmpty) {
      final fallback = defaultMoreMenuItems()
          .where((e) => includeInactive || e.isActive)
          .toList();
      if (!includeInactive) _setCache(fallback);
      return fallback;
    }
    final cleaned = withoutMovedLibraryItems(items);
    if (!includeInactive) _setCache(cleaned);
    return cleaned;
  } catch (_) {
    final fallback = defaultMoreMenuItems()
        .where((e) => includeInactive || e.isActive)
        .toList();
    if (!includeInactive) _setCache(fallback);
    return fallback;
  }
}

Future<MoreMenuItem> upsertMoreMenuItem(MoreMenuItem item) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
  final payload = item.toWriteJson()..remove('id');
  try {
    return await _writeMenuRow(item.id, payload);
  } catch (e) {
    if (isMissingParentIdColumn(e)) {
      payload.remove('parent_id');
      return _writeMenuRow(item.id, payload);
    }
    if (_isMissingFolderType(e) && item.linkType == 'folder') {
      payload['link_type'] = 'route';
      payload['link'] = 'folder';
      return _writeMenuRow(item.id, payload);
    }
    rethrow;
  }
}

Future<MoreMenuItem> _writeMenuRow(
  int id,
  Map<String, dynamic> payload,
) async {
  if (id <= 0) {
    final row = await _db
        .from('daha_fazlasi_menu')
        .insert(payload)
        .select()
        .single();
    invalidateMoreMenuCache();
    return MoreMenuItem.fromJson(row);
  }
  final row = await _db
      .from('daha_fazlasi_menu')
      .update(payload)
      .eq('id', id)
      .select()
      .single();
  invalidateMoreMenuCache();
  return MoreMenuItem.fromJson(row);
}

Future<void> setMoreMenuActive({
  required int id,
  required bool isActive,
}) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
  if (id <= 0) {
    throw StateError('Önce Supabase tablosunu oluşturup seed edin.');
  }
  await _db.from('daha_fazlasi_menu').update({
    'is_active': isActive,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  }).eq('id', id);
  invalidateMoreMenuCache();
}

Future<void> deleteMoreMenuItem(int id) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin silebilir.');
  }
  if (id <= 0) {
    throw StateError('Geçersiz kayıt.');
  }
  await _db.from('daha_fazlasi_menu').delete().eq('id', id);
  invalidateMoreMenuCache();
}

Future<void> reorderMoreMenuItems(List<MoreMenuItem> ordered) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
  final now = DateTime.now().toUtc().toIso8601String();
  await Future.wait([
    for (var i = 0; i < ordered.length; i++)
      if (ordered[i].id > 0)
        _db.from('daha_fazlasi_menu').update({
          'sort_order': (i + 1) * 10,
          'updated_at': now,
        }).eq('id', ordered[i].id),
  ]);
  invalidateMoreMenuCache();
}

/// Öğeyi gruba taşı (parent_id) ve o grubun sonuna koy.
Future<void> moveMoreMenuItem({
  required int id,
  int? parentId,
  required List<MoreMenuItem> siblingsHint,
}) async {
  final email = _authEmail();
  if (!isAppAdmin(email)) {
    throw StateError('Yalnız admin düzenleyebilir.');
  }
  if (id <= 0) {
    throw StateError('Önce Supabase’de daha_fazlasi_menu_nest.sql çalıştırın.');
  }
  if (parentId != null && parentId <= 0) parentId = null;
  var maxSort = 0;
  for (final e in siblingsHint) {
    if (e.id == id) continue;
    if (e.sortOrder > maxSort) maxSort = e.sortOrder;
  }
  try {
    await _db.from('daha_fazlasi_menu').update({
      'parent_id': parentId,
      'sort_order': maxSort + 10,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    invalidateMoreMenuCache();
  } catch (e) {
    if (isMissingParentIdColumn(e)) {
      throw StateError(
        'Önce Supabase SQL Editor’de daha_fazlasi_menu_nest.sql çalıştırın.',
      );
    }
    rethrow;
  }
}

Future<MoreMenuItem> createMoreMenuGroup({
  required String title,
  String subtitle = '',
  String icon = 'folder',
  int sortOrder = 80,
}) async {
  return upsertMoreMenuItem(
    MoreMenuItem(
      id: 0,
      title: title,
      subtitle: subtitle,
      linkType: 'folder',
      link: 'folder',
      icon: icon.trim().isEmpty ? 'folder' : icon.trim(),
      sortOrder: sortOrder,
      isActive: true,
      isBuiltin: false,
    ),
  );
}
