import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_config.dart';
import 'utils/async_timeout.dart';

class DernekItem {
  const DernekItem({
    required this.id,
    required this.title,
    this.imageUrl = '',
    this.websiteUrl = '',
    this.sortOrder = 0,
    this.isActive = true,
  });

  final int id;
  final String title;
  final String imageUrl;
  final String websiteUrl;
  final int sortOrder;
  final bool isActive;

  bool get hasLink {
    final u = websiteUrl.trim();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  factory DernekItem.fromJson(Map<String, dynamic> json) => DernekItem(
        id: (json['id'] as num?)?.toInt() ?? 0,
        title: json['title']?.toString().trim() ?? '',
        imageUrl: json['image_url']?.toString().trim() ?? '',
        websiteUrl: json['website_url']?.toString().trim() ?? '',
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
        isActive: json['is_active'] != false,
      );
}

const kDefaultDernekler = <DernekItem>[
  DernekItem(
    id: -1,
    title: 'SERÇEV',
    websiteUrl: 'https://www.sercev.org.tr/',
    sortOrder: 10,
  ),
  DernekItem(
    id: -2,
    title: 'Down Sendromlular Derneği',
    websiteUrl: 'https://www.downturkiye.org/',
    sortOrder: 20,
  ),
];

List<DernekItem>? _cache;
DateTime? _cacheAt;
bool _tableUnavailable = false;
const _ttl = Duration(minutes: 10);
const _loadTimeout = Duration(seconds: 4);

bool _supabaseReady() {
  try {
    return Supabase.instance.isInitialized;
  } catch (_) {
    return false;
  }
}

void invalidateDerneklerCache() {
  _cache = null;
  _cacheAt = null;
}

bool get hasFreshDerneklerCache {
  final at = _cacheAt;
  final list = _cache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<DernekItem>? get cachedDernekler => _cache;

List<DernekItem> visibleDernekler(List<DernekItem> all, {required bool admin}) {
  final list = (admin ? all : all.where((d) => d.isActive)).toList();
  list.sort((a, b) {
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.id.compareTo(b.id);
  });
  return list;
}

List<DernekItem> _fallbackVisible({required bool admin}) {
  return visibleDernekler(
    List<DernekItem>.from(_cache ?? kDefaultDernekler),
    admin: admin,
  );
}

Future<List<DernekItem>> loadDernekler({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  final admin = isAppAdmin(viewerEmail);
  if (!forceRefresh && hasFreshDerneklerCache) {
    return visibleDernekler(
      List<DernekItem>.from(_cache!),
      admin: admin,
    );
  }
  if (_tableUnavailable || !_supabaseReady()) {
    return _fallbackVisible(admin: admin);
  }
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client
          .from('dernekler')
          .select()
          .order('sort_order')
          .order('id'),
      timeout: _loadTimeout,
    );
    final raw = rows is List ? rows : const [];
    final list = [
      for (final e in raw.whereType<Map>())
        DernekItem.fromJson(Map<String, dynamic>.from(e)),
    ];
    if (list.isEmpty) {
      _cache = List<DernekItem>.unmodifiable(kDefaultDernekler);
    } else {
      _cache = List<DernekItem>.unmodifiable(list);
    }
    _cacheAt = DateTime.now();
    return visibleDernekler(List<DernekItem>.from(_cache!), admin: admin);
  } catch (e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('pgrst') ||
        msg.contains('schema cache') ||
        msg.contains('does not exist') ||
        (msg.contains('relation') && msg.contains('dernekler'))) {
      _tableUnavailable = true;
    }
    return _fallbackVisible(admin: admin);
  }
}

Future<void> _requireAdmin(String? email) async {
  if (!isAppAdmin(email)) {
    throw StateError('Yalnızca admin dernek kutucuğu yönetebilir.');
  }
}

Future<DernekItem> upsertDernek({
  int? id,
  required String title,
  required String imageUrl,
  required String websiteUrl,
  required String adminEmail,
  int? sortOrder,
  bool isActive = true,
}) async {
  await _requireAdmin(adminEmail);
  final name = title.trim();
  if (name.isEmpty) {
    throw StateError('Kutucuk adı boş olamaz.');
  }
  final payload = <String, dynamic>{
    'title': name,
    'image_url': imageUrl.trim(),
    'website_url': websiteUrl.trim(),
    'is_active': isActive,
    'created_by': adminEmail.trim().toLowerCase(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (sortOrder != null) payload['sort_order'] = sortOrder;
  if (id != null && id > 0) {
    final row = await Supabase.instance.client
        .from('dernekler')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    invalidateDerneklerCache();
    return DernekItem.fromJson(Map<String, dynamic>.from(row));
  }
  final nextOrder = sortOrder ??
      ((_cache ?? kDefaultDernekler)
              .map((e) => e.sortOrder)
              .fold<int>(0, (a, b) => a > b ? a : b) +
          10);
  payload['sort_order'] = nextOrder;
  final row = await Supabase.instance.client
      .from('dernekler')
      .insert(payload)
      .select()
      .single();
  invalidateDerneklerCache();
  return DernekItem.fromJson(Map<String, dynamic>.from(row));
}

Future<void> deleteDernek({
  required int id,
  required String adminEmail,
}) async {
  await _requireAdmin(adminEmail);
  if (id <= 0) {
    throw StateError('Tablo yok. Supabase’de dernekler.sql çalıştırın.');
  }
  await Supabase.instance.client.from('dernekler').delete().eq('id', id);
  invalidateDerneklerCache();
}
