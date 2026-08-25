import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/more_menu_data.dart';
import 'utils/async_timeout.dart';

List<MoreMenuItem>? _memoryCache;
DateTime? _cacheAt;
const _cacheTtl = Duration(minutes: 5);

List<MoreMenuItem>? get cachedMoreMenu => _memoryCache;

void invalidateMoreMenuCache() {
  _memoryCache = null;
  _cacheAt = null;
}

void _setCache(List<MoreMenuItem> items) {
  _memoryCache = List<MoreMenuItem>.unmodifiable(items);
  _cacheAt = DateTime.now();
}

bool get _hasFreshCache {
  final at = _cacheAt;
  final list = _memoryCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _cacheTtl;
}

SupabaseClient get _db => Supabase.instance.client;

String? _authEmail() {
  final e = _db.auth.currentUser?.email?.trim().toLowerCase();
  return (e == null || e.isEmpty) ? null : e;
}

/// Aktif menü (kullanıcı). Admin [includeInactive] ile pasifleri de alır.
Future<List<MoreMenuItem>> loadMoreMenu({
  bool includeInactive = false,
  bool forceRefresh = false,
}) async {
  if (!forceRefresh && !includeInactive && _hasFreshCache) {
    return _memoryCache!;
  }

  try {
    var q = _db.from('daha_fazlasi_menu').select();
    if (!includeInactive) {
      q = q.eq('is_active', true);
    }
    final rows = await withNetworkTimeout(
      q.order('sort_order').order('id'),
    );
    final items = <MoreMenuItem>[
      for (final r in rows)
        if (r is Map<String, dynamic>) MoreMenuItem.fromJson(r),
    ];
    if (items.isEmpty) {
      final fallback = withoutMainNavMapItems(defaultMoreMenuItems());
      if (!includeInactive) _setCache(fallback);
      return fallback;
    }
    final withoutMap = withoutMainNavMapItems(items);
    if (!includeInactive) _setCache(withoutMap);
    return withoutMap;
  } catch (_) {
    final fallback = withoutMainNavMapItems(defaultMoreMenuItems())
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
  if (item.id <= 0) {
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
      .eq('id', item.id)
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
