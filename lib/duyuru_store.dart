import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/duyuru_data.dart';
import 'section_editors.dart';
import 'services/broadcast_push_service.dart';

String _seenKey(String email) {
  final e = email.trim().toLowerCase();
  // Misafir: cihaz lokal okundu takibi
  if (e.isEmpty) return 'duyuru_seen_ids_guest_v1';
  return 'duyuru_seen_ids_$e';
}

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
  if (id <= 0) return;
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
  final publishAt = DateTime.tryParse(json['publish_at']?.toString() ?? '');
  final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
  return DuyuruItem(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title']?.toString() ?? '',
    body: json['body']?.toString() ??
        json['content']?.toString() ??
        '',
    imageUrl: json['image_url']?.toString() ?? '',
    sourceUrl: (source == null || source.isEmpty) ? null : source,
    createdAt: created,
    isActive: json['is_active'] != false,
    isPopup: json['is_popup'] == true,
    publishAt: publishAt,
    expiresAt: expiresAt,
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
/// Bölüm editörü / super admin tüm kayıtları (pasif dahil) görür; diğerleri yalnız aktifleri.
Future<List<DuyuruItem>> loadDuyurular({
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  await ensureSectionEditorsLoaded(viewerEmail);
  final editor = canEditSection(viewerEmail, SectionKey.duyurular);
  if (!forceRefresh && hasFreshDuyuruCache) {
    final cached = List<DuyuruItem>.from(_duyuruMemoryCache!);
    if (editor) return cached;
    return cached.where((d) => d.isVisibleNow()).toList();
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
    ].where((d) {
      if (d.id <= 0) return false;
      if (d.isInstagramEmbed && d.hasSource) return true;
      return d.title.isNotEmpty || d.imageUrl.isNotEmpty;
    }).toList();
    _setDuyuruCache(list);
    if (editor) return list;
    return list.where((d) => d.isVisibleNow()).toList();
  } catch (_) {
    if (_duyuruMemoryCache != null) {
      final cached = List<DuyuruItem>.from(_duyuruMemoryCache!);
      if (editor) return cached;
      return cached.where((d) => d.isVisibleNow()).toList();
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
  bool isPopup = false,
  DateTime? publishAt,
  DateTime? expiresAt,
}) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) throw StateError('Giriş gerekli.');
  await ensureSectionEditorsLoaded(adminEmail);
  await ensureSectionEditorsLoaded(user.email);
  if (!canEditSection(adminEmail, SectionKey.duyurular) &&
      !canEditSection(user.email, SectionKey.duyurular)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }

  final payload = _buildDuyuruPayload(
    title: title,
    body: body,
    imageUrl: imageUrl,
    sourceUrl: sourceUrl,
    adminEmail: adminEmail,
    isActive: isActive,
    isPopup: isPopup,
    publishAt: publishAt,
    expiresAt: expiresAt,
    includeCreatedBy: true,
  );

  Map<String, dynamic> row;
  try {
    row = Map<String, dynamic>.from(
      await client.from('duyurular').insert(payload).select().single(),
    );
  } catch (_) {
    // Eski şema: schedule / is_popup / is_active yoksa sırayla düş
    payload.remove('publish_at');
    payload.remove('expires_at');
    try {
      row = Map<String, dynamic>.from(
        await client.from('duyurular').insert(payload).select().single(),
      );
    } catch (_) {
      payload.remove('is_popup');
      try {
        row = Map<String, dynamic>.from(
          await client.from('duyurular').insert(payload).select().single(),
        );
      } catch (_) {
        payload.remove('is_active');
        row = Map<String, dynamic>.from(
          await client.from('duyurular').insert(payload).select().single(),
        );
      }
    }
  }
  final item = duyuruFromRow(row).copyWith(isPopup: isPopup);
  final prev = _duyuruMemoryCache ?? const <DuyuruItem>[];
  _setDuyuruCache([item, ...prev.where((d) => d.id != item.id)]);

  // Görselli push (yalnız https görseller; data URL atlanır)
  if (item.isActive) {
    unawaited(
      BroadcastPushService.instance.duyuru(
        title: item.title.trim().isEmpty ? 'Yeni duyuru' : item.title.trim(),
        body: item.body.trim().isEmpty
            ? 'Güncel haber ve duyurulara göz atın'
            : item.body.trim(),
        imageUrl: item.imageUrl,
        duyuruId: '${item.id}',
      ),
    );
  }
  return item;
}

/// Instagram: DB'ye yalnızca permalink metni + kısa marker. Medya/CDN URL yazılmaz.
Future<DuyuruItem> addInstagramStoryLink({
  required String instagramUrl,
  String title = 'Instagram',
  required String adminEmail,
  bool isActive = true,
  DateTime? publishAt,
  DateTime? expiresAt,
}) async {
  await ensureSectionEditorsLoaded(adminEmail);
  if (!canEditSection(adminEmail, SectionKey.duyurular)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }
  final url = normalizeInstagramUrl(instagramUrl);
  if (url == null) {
    throw StateError('Geçerli bir Instagram linki gerekli.');
  }
  return addDuyuru(
    title: title.trim().isEmpty ? 'Instagram' : title.trim(),
    body: '',
    imageUrl: kInstagramEmbedMarker,
    sourceUrl: url,
    adminEmail: adminEmail,
    isActive: isActive,
    isPopup: false,
    publishAt: publishAt,
    expiresAt: expiresAt,
  );
}

String? _toIsoOrNull(DateTime? dt) => dt?.toUtc().toIso8601String();

Map<String, dynamic> _buildDuyuruPayload({
  required String title,
  required String body,
  required String imageUrl,
  String? sourceUrl,
  String? adminEmail,
  required bool isActive,
  required bool isPopup,
  DateTime? publishAt,
  DateTime? expiresAt,
  required bool includeCreatedBy,
}) {
  final t = title.trim();
  final b = body.trim();
  final srcRaw = (sourceUrl ?? '').trim();
  final igUrl = normalizeInstagramUrl(srcRaw);
  final imgRaw = imageUrl.trim();
  // Marker veya (görsel yok + IG link) → URL-only Instagram kaydı.
  // Normal haberde kaynak olarak IG linki kullanılabilir; medyayı düşürme.
  final wantsIg = imgRaw == kInstagramEmbedMarker ||
      imgRaw.startsWith(kInstagramVideoPrefix) ||
      (imgRaw.isEmpty && igUrl != null);

  String img;
  String? src;
  bool popup = isPopup;
  var bodyOut = b;

  if (wantsIg) {
    if (igUrl == null) {
      throw StateError('Instagram linki gerekli.');
    }
    if (looksLikeEmbeddedMediaPayload(imageUrl) ||
        looksLikeEmbeddedMediaPayload(srcRaw)) {
      throw StateError(
        'Instagram içeriklerinde medya yüklenemez; yalnızca link kaydedilir.',
      );
    }
    // DB'ye sadece marker — CDN video URL'si dahi yazılmaz.
    img = kInstagramEmbedMarker;
    src = igUrl;
    popup = false;
    bodyOut = '';
  } else {
    img = imageUrl.trim();
    if (img.isEmpty) throw StateError('Görsel URL veya yükleme gerekli.');
    src = srcRaw.isEmpty ? null : srcRaw;
  }

  return <String, dynamic>{
    'title': t.isEmpty && img == kInstagramEmbedMarker ? 'Instagram' : t,
    'body': bodyOut,
    'image_url': img,
    if (includeCreatedBy && adminEmail != null)
      'created_by': adminEmail.trim().toLowerCase(),
    'is_active': isActive,
    'is_popup': popup,
    'source_url': src,
    'publish_at': _toIsoOrNull(publishAt ?? DateTime.now()),
    'expires_at': _toIsoOrNull(expiresAt),
  };
}

Future<DuyuruItem> updateDuyuru({
  required int id,
  required String title,
  required String body,
  required String imageUrl,
  String? sourceUrl,
  bool isActive = true,
  bool isPopup = false,
  DateTime? publishAt,
  DateTime? expiresAt,
}) async {
  if (id <= 0) throw StateError('Geçersiz duyuru.');
  final email = Supabase.instance.client.auth.currentUser?.email;
  await ensureSectionEditorsLoaded(email);
  if (!canEditSection(email, SectionKey.duyurular)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }

  final payload = _buildDuyuruPayload(
    title: title,
    body: body,
    imageUrl: imageUrl,
    sourceUrl: sourceUrl,
    isActive: isActive,
    isPopup: isPopup,
    publishAt: publishAt,
    expiresAt: expiresAt,
    includeCreatedBy: false,
  );

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
    payload.remove('publish_at');
    payload.remove('expires_at');
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
      payload.remove('is_popup');
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
    }
  }
  final item = duyuruFromRow(row).copyWith(
    isPopup: payload['is_popup'] == true,
  );
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

/// Aktif (tarih aralığı dahil) pop-up haberlerden en yenisi.
DuyuruItem? latestActivePopup(List<DuyuruItem> items) {
  final pops = items.where((d) => d.isPopup && d.isVisibleNow()).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return pops.isEmpty ? null : pops.first;
}

Future<void> deleteDuyuru(int id) async {
  if (id <= 0) return;
  final email = Supabase.instance.client.auth.currentUser?.email;
  await ensureSectionEditorsLoaded(email);
  if (!canEditSection(email, SectionKey.duyurular)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }
  await Supabase.instance.client.from('duyurular').delete().eq('id', id);
  final prev = _duyuruMemoryCache;
  if (prev != null) {
    _setDuyuruCache(prev.where((d) => d.id != id).toList());
  }
}
