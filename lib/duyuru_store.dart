import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'data/duyuru_data.dart';

String _seenKey(String email) =>
    'duyuru_seen_ids_${email.trim().toLowerCase()}';

/// Bellek önbelleği — sekmeler arası geçişte yeniden indirmeyi önler.
List<DuyuruItem>? _duyuruMemoryCache;
DateTime? _duyuruCacheAt;
const _duyuruCacheTtl = Duration(minutes: 10);

List<DuyuruItem>? get cachedDuyurular => _duyuruMemoryCache;

bool get hasFreshDuyuruCache {
  final at = _duyuruCacheAt;
  final list = _duyuruMemoryCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _duyuruCacheTtl;
}

void invalidateDuyuruCache() {
  _duyuruMemoryCache = null;
  _duyuruCacheAt = null;
}

void _setDuyuruCache(List<DuyuruItem> items) {
  _duyuruMemoryCache = List<DuyuruItem>.unmodifiable(items);
  _duyuruCacheAt = DateTime.now();
}

Future<Set<int>> loadSeenDuyuruIds(String email) async {
  if (email.trim().isEmpty) return {};
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getStringList(_seenKey(email)) ?? const [];
  return {
    for (final s in raw)
      if (int.tryParse(s) != null) int.parse(s),
  };
}

Future<void> markDuyuruSeen({
  required String email,
  required int id,
}) async {
  if (email.trim().isEmpty || id <= 0) return;
  final prefs = await SharedPreferences.getInstance();
  final key = _seenKey(email);
  final current = prefs.getStringList(key) ?? <String>[];
  final sid = '$id';
  if (current.contains(sid)) return;
  await prefs.setStringList(key, [...current, sid]);
}

DuyuruItem duyuruFromRow(Map<String, dynamic> json) {
  final created =
      DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
  final source = json['source_url']?.toString().trim();
  return DuyuruItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    imageUrl: json['image_url']?.toString() ?? '',
    sourceUrl: (source == null || source.isEmpty) ? null : source,
    createdAt: created,
    isActive: json['is_active'] != false,
  );
}

/// Okunmamışlar başta (yeniden eskiye), sonra okunanlar.
List<DuyuruItem> sortDuyurular(
  List<DuyuruItem> items,
  Set<int> seenIds,
) {
  final unread = <DuyuruItem>[];
  final read = <DuyuruItem>[];
  for (final d in items) {
    if (seenIds.contains(d.id)) {
      read.add(d);
    } else {
      unread.add(d);
    }
  }
  int byNew(DuyuruItem a, DuyuruItem b) =>
      b.createdAt.compareTo(a.createdAt);
  unread.sort(byNew);
  read.sort(byNew);
  return [...unread, ...read];
}

/// [forceRefresh] true değilse ve taze önbellek varsa ağ çağrısı yapılmaz.
/// Admin tüm kayıtları (pasif dahil) görür; diğerleri yalnız aktifleri.
Future<List<DuyuruItem>> loadDuyurular({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  if (!forceRefresh && hasFreshDuyuruCache) {
    final cached = List<DuyuruItem>.from(_duyuruMemoryCache!);
    if (isAppAdmin(viewerEmail)) return cached;
    return cached.where((d) => d.isActive).toList();
  }
  try {
    final rows = await Supabase.instance.client
        .from('duyurular')
        .select()
        .order('created_at', ascending: false)
        .limit(50);
    final list = [
      for (final e in (rows as List).whereType<Map>())
        duyuruFromRow(Map<String, dynamic>.from(e)),
    ].where((d) => d.id > 0 && d.title.isNotEmpty).toList();
    _setDuyuruCache(list);
    if (isAppAdmin(viewerEmail)) return list;
    return list.where((d) => d.isActive).toList();
  } catch (_) {
    if (_duyuruMemoryCache != null) {
      final cached = List<DuyuruItem>.from(_duyuruMemoryCache!);
      if (isAppAdmin(viewerEmail)) return cached;
      return cached.where((d) => d.isActive).toList();
    }
    return const [];
  }
}

Future<DuyuruItem> addDuyuru({
  required String title,
  required String body,
  required String imageUrl,
  String? sourceUrl,
  required String adminEmail,
  bool isActive = true,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  final t = title.trim();
  final b = body.trim();
  final img = imageUrl.trim();
  if (t.isEmpty) throw StateError('Başlık gerekli.');
  if (img.isEmpty) throw StateError('Görsel URL veya yükleme gerekli.');

  final src = (sourceUrl ?? '').trim();
  final payload = <String, dynamic>{
    'title': t,
    'body': b,
    'image_url': img,
    'created_by': adminEmail.trim().toLowerCase(),
    'is_active': isActive,
    if (src.isNotEmpty) 'source_url': src,
  };

  Map<String, dynamic> row;
  try {
    row = Map<String, dynamic>.from(
      await client.from('duyurular').insert(payload).select().single(),
    );
  } catch (_) {
    // is_active sütunu yoksa eskiye düş
    payload.remove('is_active');
    row = Map<String, dynamic>.from(
      await client.from('duyurular').insert(payload).select().single(),
    );
  }
  final item = duyuruFromRow(row);
  final prev = _duyuruMemoryCache ?? const <DuyuruItem>[];
  _setDuyuruCache([item, ...prev.where((d) => d.id != item.id)]);
  return item;
}

Future<DuyuruItem> updateDuyuru({
  required int id,
  required String title,
  required String body,
  required String imageUrl,
  String? sourceUrl,
  bool isActive = true,
}) async {
  if (id <= 0) throw StateError('Geçersiz duyuru.');
  final t = title.trim();
  final b = body.trim();
  final img = imageUrl.trim();
  if (t.isEmpty) throw StateError('Başlık gerekli.');
  if (img.isEmpty) throw StateError('Görsel gerekli.');
  final src = (sourceUrl ?? '').trim();

  final payload = <String, dynamic>{
    'title': t,
    'body': b,
    'image_url': img,
    'source_url': src.isEmpty ? null : src,
    'is_active': isActive,
  };

  Map<String, dynamic> row;
  try {
    row = Map<String, dynamic>.from(
      await Supabase.instance.client
          .from('duyurular')
          .update(payload)
          .eq('id', id)
          .select()
          .single(),
    );
  } catch (_) {
    payload.remove('is_active');
    row = Map<String, dynamic>.from(
      await Supabase.instance.client
          .from('duyurular')
          .update(payload)
          .eq('id', id)
          .select()
          .single(),
    );
  }
  final item = duyuruFromRow(row);
  final prev = _duyuruMemoryCache ?? const <DuyuruItem>[];
  _setDuyuruCache([
    for (final d in prev)
      if (d.id == id) item else d,
  ]);
  if (!prev.any((d) => d.id == id)) {
    _setDuyuruCache([item, ...prev]);
  }
  return item;
}

Future<void> deleteDuyuru(int id) async {
  if (id <= 0) return;
  await Supabase.instance.client.from('duyurular').delete().eq('id', id);
  final prev = _duyuruMemoryCache;
  if (prev != null) {
    _setDuyuruCache(prev.where((d) => d.id != id).toList());
  }
}
