import 'package:supabase_flutter/supabase_flutter.dart';

import 'section_editors.dart';
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

/// Kampanya kapsamı: boş / 'Türkiye' / 'genel' = tüm ülkede geçerli.
bool isKampanyaNationwide(String? city) {
  final t = (city ?? '').trim();
  if (t.isEmpty) return true;
  final f = foldTurkish(t).replaceAll(RegExp(r'\s+'), ' ');
  return f == 'turkiye' ||
      f == 'genel' ||
      f == 'tum ulke' ||
      f == 'tumulkede gecerli' ||
      f == 'tum ulkede gecerli';
}

String kampanyaLocationLabel(String? city) {
  if (isKampanyaNationwide(city)) return 'Tüm ülke';
  return city!.trim();
}

const _trMonthNames = <String>[
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

final _trMonthRe = RegExp(
  r'ocak|şubat|subat|mart|nisan|may[ıi]s|haziran|temmuz|'
  r'a[gğ]ustos|eyl[uü]l|ekim|kas[ıi]m|aral[ıi]k',
  caseSensitive: false,
);

final _clockTimeRe = RegExp(
  r'\b((?:[01]?\d|2[0-3])[:.][0-5]\d'
  r'(?:\s*[-–]\s*(?:[01]?\d|2[0-3])[:.][0-5]\d)?)\b',
);

final _isoDateRe = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

bool _looksLikeEventWhen(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 90) return false;
  final lower = t.toLowerCase();
  if (_trMonthRe.hasMatch(lower)) return true;
  if (RegExp(r'\b20\d{2}\b').hasMatch(t)) return true;
  if (_clockTimeRe.hasMatch(t)) return true;
  if (_isoDateRe.hasMatch(t)) return true;
  if (RegExp(r'^\d{1,2}[./]\d{1,2}[./]\d{2,4}$').hasMatch(t)) return true;
  const phrases = [
    'devam ediyor',
    'her hafta',
    'her gün',
    'her gun',
    'bu hafta',
    'sürekli',
    'surekli',
    'vizyonda',
  ];
  for (final p in phrases) {
    if (lower.contains(p)) return true;
  }
  return false;
}

String _prettyEventWhen(String raw) {
  final t = raw.trim();
  if (t.isEmpty) return '';
  final iso = _isoDateRe.firstMatch(t);
  if (iso != null) {
    final y = int.tryParse(iso.group(1)!);
    final m = int.tryParse(iso.group(2)!);
    final d = int.tryParse(iso.group(3)!);
    if (y != null && m != null && d != null && m >= 1 && m <= 12) {
      return '$d ${_trMonthNames[m - 1]} $y';
    }
  }
  return t;
}

String _normalizeClockTime(String raw) {
  return raw.trim().replaceAll('.', ':');
}

({String when, String time, String body}) splitEtkinlikWhen({
  required String description,
  String eventDate = '',
}) {
  final desc = description.trim();
  var rawWhen = eventDate.trim();
  var body = desc;
  if (rawWhen.isEmpty && desc.isNotEmpty) {
    final nl = desc.indexOf('\n');
    final first = (nl < 0 ? desc : desc.substring(0, nl)).trim();
    if (_looksLikeEventWhen(first)) {
      rawWhen = first;
      body = nl < 0 ? '' : desc.substring(nl + 1).trim();
    }
  } else if (rawWhen.isNotEmpty && desc.isNotEmpty) {
    final nl = desc.indexOf('\n');
    final first = (nl < 0 ? desc : desc.substring(0, nl)).trim();
    if (first == rawWhen || first == _prettyEventWhen(rawWhen)) {
      body = nl < 0 ? '' : desc.substring(nl + 1).trim();
    }
  }
  if (rawWhen.isEmpty) {
    return (when: '', time: '', body: body);
  }
  final timeMatch = _clockTimeRe.firstMatch(rawWhen);
  var time = '';
  var when = rawWhen;
  if (timeMatch != null) {
    time = _normalizeClockTime(timeMatch.group(1)!);
    when = rawWhen.replaceFirst(timeMatch.group(0)!, '').trim();
    when = when.replaceAll(RegExp(r'[,;|/]+$'), '').trim();
    when = when.replaceAll(RegExp(r'^[,;|/]+'), '').trim();
    when = when.replaceAll(RegExp(r'\s{2,}'), ' ');
    when = when.replaceAll(RegExp(r'\s*,\s*$'), '').trim();
  }
  when = _prettyEventWhen(when);
  return (when: when, time: time, body: body);
}

enum GeziKampanyaKind { gezi, kampanya, etkinlik }

bool isCityFeedKind(GeziKampanyaKind kind) =>
    kind == GeziKampanyaKind.kampanya || kind == GeziKampanyaKind.etkinlik;

String cityFeedTable(GeziKampanyaKind kind) {
  switch (kind) {
    case GeziKampanyaKind.kampanya:
      return 'kampanyalar';
    case GeziKampanyaKind.etkinlik:
      return 'etkinlikler';
    case GeziKampanyaKind.gezi:
      throw StateError('Gezi ayrı tablo (gezi_rehberi).');
  }
}

const kEtkinlikStatusPending = 'pending';
const kEtkinlikStatusApproved = 'approved';
const kEtkinlikStatusRejected = 'rejected';
const kEtkinlikSourceScrape = 'avm_scrape';
const kEtkinlikSourceUser = 'user';

/// Onaylı / scrape (null status = onaylı). Reddedilen veya bekleyen değil.
bool isEtkinlikListed(KampanyaItem k) {
  if (!k.isActive) return false;
  if (k.source.trim() == kEtkinlikSourceScrape) return true;
  final s = k.status.trim().toLowerCase();
  return s.isEmpty || s == kEtkinlikStatusApproved;
}

bool isEtkinlikPending(KampanyaItem k) =>
    k.status.trim().toLowerCase() == kEtkinlikStatusPending;

bool isEtkinlikRejected(KampanyaItem k) =>
    k.status.trim().toLowerCase() == kEtkinlikStatusRejected;

String formatEtkinlikWhen(DateTime dt, {int? hour, int? minute}) {
  final when = '${dt.day} ${_trMonthNames[dt.month - 1]} ${dt.year}';
  if (hour == null) return when;
  final hh = hour.toString().padLeft(2, '0');
  final mm = (minute ?? 0).toString().padLeft(2, '0');
  return '$when, $hh:$mm';
}

/// Kampanya / etkinlik satırı (aynı kolonlar; etkinlikler.sort_index → sortOrder).
class KampanyaItem {
  const KampanyaItem({
    required this.id,
    this.title = '',
    required this.imageUrl,
    this.description = '',
    this.city = '',
    this.avmName = '',
    this.eventDate = '',
    this.sortOrder = 0,
    this.isActive = true,
    this.createdBy = '',
    this.status = '',
    this.source = '',
    this.rejectionReason = '',
    this.joinCount = 0,
    this.joinedByMe = false,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String imageUrl;
  final String description;
  /// Boş veya sentinel → tüm ülkede; aksi halde il adı (ör. Ankara).
  final String city;
  /// AVM adı (scraper); kampanyalarda boş.
  final String avmName;
  /// Scraper `event_date` kolonu (yoksa açıklamanın ilk satırından okunur).
  final String eventDate;
  final int sortOrder;
  final bool isActive;
  final String createdBy;
  /// `pending` | `approved` | `rejected` (boş = onaylı).
  final String status;
  final String source;
  final String rejectionReason;
  final int joinCount;
  final bool joinedByMe;
  final DateTime createdAt;

  bool get hasDescription => description.trim().isNotEmpty;

  bool get isNationwide => isKampanyaNationwide(city);

  KampanyaItem copyWith({
    int? joinCount,
    bool? joinedByMe,
    String? status,
    String? rejectionReason,
  }) {
    return KampanyaItem(
      id: id,
      title: title,
      imageUrl: imageUrl,
      description: description,
      city: city,
      avmName: avmName,
      eventDate: eventDate,
      sortOrder: sortOrder,
      isActive: isActive,
      createdBy: createdBy,
      status: status ?? this.status,
      source: source,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      joinCount: joinCount ?? this.joinCount,
      joinedByMe: joinedByMe ?? this.joinedByMe,
      createdAt: createdAt,
    );
  }

  ({String when, String time, String body}) get _whenParts => splitEtkinlikWhen(
        description: description,
        eventDate: eventDate,
      );

  /// Kartta gösterilecek tarih / dönem (saat ayrı).
  String get eventWhenLabel => _whenParts.when;

  /// Kaynakta varsa saat (ör. 14:00); yoksa boş — uydurulmaz.
  String get eventTimeLabel => _whenParts.time;

  /// Tarih satırı kart meta’sına alındıysa gövde metni.
  String get cardDescription => _whenParts.body;

  String get locationLabel {
    final loc = kampanyaLocationLabel(city);
    final avm = avmName.trim();
    if (avm.isEmpty) return loc;
    if (isNationwide) return avm;
    return '$avm · $loc';
  }

  factory KampanyaItem.fromJson(Map<String, dynamic> json) {
    final created =
        DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now();
    final sortOrder = (json['sort_order'] as num?)?.toInt() ?? 0;
    final sortIndex = (json['sort_index'] as num?)?.toInt() ?? 0;
    return KampanyaItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      avmName: json['avm_name']?.toString() ?? '',
      eventDate: json['event_date']?.toString() ?? '',
      sortOrder: sortOrder > 0 ? sortOrder : sortIndex,
      isActive: json['is_active'] != false,
      createdBy: json['created_by']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      createdAt: created,
    );
  }
}

const kGeziTileKey = 'gezi';
const kKampanyaTileKey = 'kampanya';
const kEtkinlikTileKey = 'etkinlik';
const kKampanyaTable = 'kampanyalar';
const kEtkinlikTable = 'etkinlikler';

const _kTileKeys = <String>{kGeziTileKey, kKampanyaTileKey, kEtkinlikTileKey};

Map<String, String> get _emptyTileCovers => {
      kGeziTileKey: '',
      kKampanyaTileKey: '',
      kEtkinlikTileKey: '',
    };

List<GeziItem>? _geziCache;
DateTime? _geziCacheAt;
List<KampanyaItem>? _kampanyaCache;
DateTime? _kampanyaCacheAt;
List<KampanyaItem>? _etkinlikCache;
DateTime? _etkinlikCacheAt;
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

void invalidateEtkinlikCache() {
  _etkinlikCache = null;
  _etkinlikCacheAt = null;
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

bool get hasFreshEtkinlikCache {
  final at = _etkinlikCacheAt;
  final list = _etkinlikCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<GeziItem>? get cachedGeziItems => _geziCache;

List<KampanyaItem>? get cachedKampanyaItems => _kampanyaCache;

List<KampanyaItem>? get cachedEtkinlikItems => _etkinlikCache;

bool get hasFreshTileCoverCache {
  final at = _tileCoverCacheAt;
  final map = _tileCoverCache;
  if (at == null || map == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

Map<String, String>? get cachedTileCovers => _tileCoverCache;

String _normalizeTileKey(String key) {
  final k = key.trim().toLowerCase();
  if (!_kTileKeys.contains(k)) {
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
    final map = _emptyTileCovers;
    for (final e in (rows as List).whereType<Map>()) {
      final key = e['tile_key']?.toString().trim().toLowerCase() ?? '';
      if (_kTileKeys.contains(key)) {
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
    return _emptyTileCovers;
  }
}

Future<void> upsertTileCover({
  required String tileKey,
  required String imageUrl,
  required String adminEmail,
}) async {
  final key = _normalizeTileKey(tileKey);
  final section = sectionKeyForTile(key);
  if (section == null) {
    throw StateError('Geçersiz kutucuk.');
  }
  await _requireSection(adminEmail, section);
  await Supabase.instance.client.from('gezi_kampanya_tiles').upsert({
    'tile_key': key,
    'image_url': imageUrl.trim(),
    'updated_by': adminEmail.trim().toLowerCase(),
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  });
  invalidateTileCoverCache();
}

Future<void> _requireSection(String? email, SectionKey key) async {
  await ensureSectionEditorsLoaded(email);
  if (!canEditSection(email, key)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }
}

Future<List<GeziItem>> loadGeziItems({
  String? cityName,
  String? citySlug,
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  await ensureSectionEditorsLoaded(viewerEmail);
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

  final admin = canEditSection(viewerEmail, SectionKey.gezi);
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
}) {
  return _loadScopedFeedItems(
    table: kKampanyaTable,
    forceRefresh: forceRefresh,
    viewerEmail: viewerEmail,
  );
}

Future<List<KampanyaItem>> loadEtkinlikItems({
  bool forceRefresh = false,
  String? viewerEmail,
}) {
  return _loadScopedFeedItems(
    table: kEtkinlikTable,
    forceRefresh: forceRefresh,
    viewerEmail: viewerEmail,
  );
}

bool _hasFreshScopedCache(String table) {
  return table == kEtkinlikTable ? hasFreshEtkinlikCache : hasFreshKampanyaCache;
}

List<KampanyaItem>? _scopedCacheList(String table) {
  return table == kEtkinlikTable ? _etkinlikCache : _kampanyaCache;
}

void _setScopedCache(String table, List<KampanyaItem> list) {
  final frozen = List<KampanyaItem>.unmodifiable(list);
  final now = DateTime.now();
  if (table == kEtkinlikTable) {
    _etkinlikCache = frozen;
    _etkinlikCacheAt = now;
  } else {
    _kampanyaCache = frozen;
    _kampanyaCacheAt = now;
  }
}

void _invalidateScopedCache(String table) {
  if (table == kEtkinlikTable) {
    invalidateEtkinlikCache();
  } else {
    invalidateKampanyaCache();
  }
}

List<KampanyaItem> _parseScopedRows(dynamic rows, {required String table}) {
  return [
    for (final e in (rows as List).whereType<Map>())
      KampanyaItem.fromJson(Map<String, dynamic>.from(e)),
  ].where((k) {
    if (k.id <= 0) return false;
    // Scrape etkinliklerinde görsel olmayabilir; kampanyada görsel zorunlu.
    if (table == kEtkinlikTable) return true;
    return k.imageUrl.trim().isNotEmpty;
  }).toList();
}

/// Son yükleme hatası (sessiz boş liste yerine UI’da gösterilir).
String? lastEtkinlikLoadError;
String? lastKampanyaLoadError;

void _clearFeedLoadError(String table) {
  if (table == kEtkinlikTable) {
    lastEtkinlikLoadError = null;
  } else {
    lastKampanyaLoadError = null;
  }
}

void _setFeedLoadError(String table, Object e) {
  final raw = e.toString();
  final missingTable = raw.contains('PGRST205') ||
      raw.contains('schema cache') ||
      raw.contains('does not exist') ||
      raw.contains('42P01') ||
      raw.contains('Could not find the table');
  final msg = table == kEtkinlikTable
      ? (missingTable
          ? 'Etkinlikler tablosu yok. Supabase SQL Editor’de etkinlikler.sql çalıştırın.'
          : 'Etkinlikler yüklenemedi.')
      : (missingTable
          ? 'Kampanyalar tablosu yok. Supabase’de gezi_kampanya.sql çalıştırın.'
          : 'Kampanyalar yüklenemedi.');
  if (table == kEtkinlikTable) {
    lastEtkinlikLoadError = msg;
  } else {
    lastKampanyaLoadError = msg;
  }
}

Future<dynamic> _selectScopedRows(String table) async {
  final sortCol = table == kEtkinlikTable ? 'sort_index' : 'sort_order';
  try {
    return await withNetworkTimeout(
      Supabase.instance.client
          .from(table)
          .select()
          .order(sortCol)
          .order('created_at', ascending: false),
    );
  } catch (_) {
    // sort_index / sort_order yoksa yine oku; boş liste sanılmasın.
    return await withNetworkTimeout(
      Supabase.instance.client
          .from(table)
          .select()
          .order('created_at', ascending: false),
    );
  }
}

Future<List<KampanyaItem>> _loadScopedFeedItems({
  required String table,
  bool forceRefresh = false,
  String? viewerEmail,
}) async {
  await ensureSectionEditorsLoaded(viewerEmail);
  final admin = canEditSection(
    viewerEmail,
    table == kEtkinlikTable ? SectionKey.etkinlik : SectionKey.kampanya,
  );
  if (!forceRefresh && _hasFreshScopedCache(table)) {
    return _filterScopedForViewer(
      List<KampanyaItem>.from(_scopedCacheList(table)!),
      table: table,
      admin: admin,
      viewerEmail: viewerEmail,
    );
  }
  try {
    final rows = await _selectScopedRows(table);
    final list = _parseScopedRows(rows, table: table);
    _setScopedCache(table, list);
    _clearFeedLoadError(table);
    return _filterScopedForViewer(
      list,
      table: table,
      admin: admin,
      viewerEmail: viewerEmail,
    );
  } catch (e) {
    final cachedRaw = _scopedCacheList(table);
    if (cachedRaw != null) {
      return _filterScopedForViewer(
        List<KampanyaItem>.from(cachedRaw),
        table: table,
        admin: admin,
        viewerEmail: viewerEmail,
      );
    }
    _setFeedLoadError(table, e);
    return const [];
  }
}

Future<List<KampanyaItem>> _filterScopedForViewer(
  List<KampanyaItem> all, {
  required String table,
  required bool admin,
  String? viewerEmail,
}) async {
  var list = all;
  if (table == kEtkinlikTable) {
    final email = (viewerEmail ?? '').trim().toLowerCase();
    if (!admin) {
      list = list
          .where(
            (k) =>
                isEtkinlikListed(k) ||
                (isEtkinlikPending(k) &&
                    k.createdBy.trim().toLowerCase() == email &&
                    email.isNotEmpty),
          )
          .toList();
    }
    list = await _withJoinState(list);
  } else if (!admin) {
    list = list.where((k) => k.isActive).toList();
  }
  return list;
}

Future<List<KampanyaItem>> _withJoinState(List<KampanyaItem> list) async {
  if (list.isEmpty) return list;
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.rpc(
        'etkinlik_katilim_ozet',
        params: {'p_ids': [for (final k in list) k.id]},
      ),
    );
    final map = <int, ({int count, bool mine})>{};
    for (final e in (rows as List).whereType<Map>()) {
      final id = (e['event_id'] as num?)?.toInt() ?? 0;
      if (id <= 0) continue;
      map[id] = (
        count: (e['join_count'] as num?)?.toInt() ?? 0,
        mine: e['joined_by_me'] == true,
      );
    }
    return [
      for (final k in list)
        k.copyWith(
          joinCount: map[k.id]?.count ?? 0,
          joinedByMe: map[k.id]?.mine ?? false,
        ),
    ];
  } catch (_) {
    return list;
  }
}

Future<int> _nextSort(String table) async {
  final col = table == kEtkinlikTable ? 'sort_index' : 'sort_order';
  try {
    final rows = await Supabase.instance.client
        .from(table)
        .select(col)
        .order(col, ascending: false)
        .limit(1);
    if (rows.isEmpty) return 1;
    return ((rows.first[col] as num?)?.toInt() ?? 0) + 1;
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
  await _requireSection(adminEmail, SectionKey.gezi);
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
  await _requireSection(adminEmail, SectionKey.gezi);
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
  await _requireSection(email, SectionKey.gezi);
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
  await _requireSection(email, SectionKey.gezi);
  await Supabase.instance.client.from('gezi_rehberi').delete().eq('id', id);
  invalidateGeziCache();
}

String _scopedCityDbValue(String? city) {
  if (isKampanyaNationwide(city)) return '';
  return city?.trim() ?? '';
}

StateError? _scopedCitySchemaError(Object e, {required String table}) {
  final raw = e.toString();
  if (raw.contains('city') ||
      raw.contains('sort_index') ||
      raw.contains('PGRST204') ||
      raw.contains('schema cache')) {
    if (table == kEtkinlikTable) {
      return StateError(
        'Etkinlikler tablosu yok. Supabase’de etkinlikler.sql çalıştırın.',
      );
    }
    return StateError(
      'İl kolonu yok. Supabase’de kampanyalar_city.sql çalıştırın.',
    );
  }
  return null;
}

Future<KampanyaItem> addKampanyaItem({
  String title = '',
  required String imageUrl,
  String description = '',
  String? city,
  required String adminEmail,
}) {
  return _addScopedFeedItem(
    table: kKampanyaTable,
    title: title,
    imageUrl: imageUrl,
    description: description,
    city: city,
    adminEmail: adminEmail,
  );
}

Future<KampanyaItem> addEtkinlikItem({
  String title = '',
  required String imageUrl,
  String description = '',
  String? city,
  required String adminEmail,
}) {
  return _addScopedFeedItem(
    table: kEtkinlikTable,
    title: title,
    imageUrl: imageUrl,
    description: description,
    city: city,
    adminEmail: adminEmail,
  );
}

Future<KampanyaItem> _addScopedFeedItem({
  required String table,
  String title = '',
  required String imageUrl,
  String description = '',
  String? city,
  required String adminEmail,
}) async {
  await _requireSection(
    adminEmail,
    table == kEtkinlikTable ? SectionKey.etkinlik : SectionKey.kampanya,
  );
  final url = imageUrl.trim();
  if (url.isEmpty) throw StateError('Görsel gerekli.');
  final next = await _nextSort(table);
  try {
    final payload = <String, dynamic>{
      'title': title.trim(),
      'image_url': url,
      'description': description.trim(),
      'city': _scopedCityDbValue(city),
      'sort_order': next,
      'is_active': true,
      'created_by': adminEmail.trim().toLowerCase(),
    };
    if (table == kEtkinlikTable) {
      payload['sort_index'] = next;
    }
    final row =
        await Supabase.instance.client.from(table).insert(payload).select().single();
    _invalidateScopedCache(table);
    return KampanyaItem.fromJson(Map<String, dynamic>.from(row));
  } catch (e) {
    final mapped = _scopedCitySchemaError(e, table: table);
    if (mapped != null) throw mapped;
    rethrow;
  }
}

Future<KampanyaItem> updateKampanyaItem({
  required int id,
  String title = '',
  String description = '',
  String? imageUrl,
  String? city,
  required String adminEmail,
}) {
  return _updateScopedFeedItem(
    table: kKampanyaTable,
    id: id,
    title: title,
    description: description,
    imageUrl: imageUrl,
    city: city,
    adminEmail: adminEmail,
  );
}

Future<KampanyaItem> updateEtkinlikItem({
  required int id,
  String title = '',
  String description = '',
  String? imageUrl,
  String? city,
  required String adminEmail,
}) {
  return _updateScopedFeedItem(
    table: kEtkinlikTable,
    id: id,
    title: title,
    description: description,
    imageUrl: imageUrl,
    city: city,
    adminEmail: adminEmail,
  );
}

Future<KampanyaItem> _updateScopedFeedItem({
  required String table,
  required int id,
  String title = '',
  String description = '',
  String? imageUrl,
  String? city,
  required String adminEmail,
}) async {
  await _requireSection(
    adminEmail,
    table == kEtkinlikTable ? SectionKey.etkinlik : SectionKey.kampanya,
  );
  final patch = <String, dynamic>{
    'title': title.trim(),
    'description': description.trim(),
    'city': _scopedCityDbValue(city),
  };
  final url = imageUrl?.trim() ?? '';
  if (url.isNotEmpty) patch['image_url'] = url;
  try {
    final row = await Supabase.instance.client
        .from(table)
        .update(patch)
        .eq('id', id)
        .select()
        .single();
    _invalidateScopedCache(table);
    return KampanyaItem.fromJson(Map<String, dynamic>.from(row));
  } catch (e) {
    final mapped = _scopedCitySchemaError(e, table: table);
    if (mapped != null) throw mapped;
    rethrow;
  }
}

Future<void> deleteKampanyaItem(int id) =>
    _deleteScopedFeedItem(table: kKampanyaTable, id: id);

Future<void> deleteEtkinlikItem(int id) =>
    _deleteScopedFeedItem(table: kEtkinlikTable, id: id);

Future<void> _deleteScopedFeedItem({
  required String table,
  required int id,
}) async {
  final email = Supabase.instance.client.auth.currentUser?.email;
  await _requireSection(
    email,
    table == kEtkinlikTable ? SectionKey.etkinlik : SectionKey.kampanya,
  );
  await Supabase.instance.client.from(table).delete().eq('id', id);
  _invalidateScopedCache(table);
}

/// Admin sıra (1, 2, 3…). Etkinlikler: sort_index. Kampanyalar: sort_order.
Future<void> persistCityFeedOrder({
  required GeziKampanyaKind kind,
  required List<KampanyaItem> ordered,
}) async {
  if (!isCityFeedKind(kind)) {
    throw StateError('Yalnız kampanya / etkinlik sırası.');
  }
  final email = Supabase.instance.client.auth.currentUser?.email;
  await _requireSection(
    email,
    kind == GeziKampanyaKind.etkinlik
        ? SectionKey.etkinlik
        : SectionKey.kampanya,
  );
  final table = cityFeedTable(kind);
  for (var i = 0; i < ordered.length; i++) {
    final n = i + 1;
    final patch = <String, dynamic>{'sort_order': n};
    if (table == kEtkinlikTable) {
      patch['sort_index'] = n;
    }
    await Supabase.instance.client.from(table).update(patch).eq('id', ordered[i].id);
  }
  _invalidateScopedCache(table);
}

StateError _etkinlikOneriSchemaError(Object e) {
  final raw = e.toString();
  if (raw.contains('status') ||
      raw.contains('etkinlik_katilim') ||
      raw.contains('PGRST') ||
      raw.contains('schema cache') ||
      raw.contains('42P01') ||
      raw.contains('Could not find')) {
    return StateError(
      'Etkinlik önerisi tablosu yok. Supabase SQL Editor’de etkinlik_oneri_katilim.sql çalıştırın.',
    );
  }
  return StateError('İşlem başarısız: $e');
}

/// Üye etkinlik önerir — `pending`, admin onayına kadar listede görünmez.
Future<KampanyaItem> proposeEtkinlik({
  required String title,
  required String description,
  required String city,
  required String eventDate,
  String avmName = '',
  String imageUrl = '',
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final email = (user?.email ?? '').trim().toLowerCase();
  if (user == null || email.isEmpty) {
    throw StateError('Etkinlik önermek için giriş yapın.');
  }
  final heading = title.trim();
  if (heading.isEmpty) throw StateError('Başlık girin.');
  final cityName = city.trim();
  if (cityName.isEmpty || isKampanyaNationwide(cityName)) {
    throw StateError('İl seçin.');
  }
  final when = eventDate.trim();
  if (when.isEmpty) throw StateError('Tarih seçin.');
  final next = await _nextSort(kEtkinlikTable);
  final payload = <String, dynamic>{
    'title': heading,
    'description': description.trim(),
    'city': cityName,
    'avm_name': avmName.trim(),
    'image_url': imageUrl.trim(),
    'event_date': when,
    'status': kEtkinlikStatusPending,
    'source': kEtkinlikSourceUser,
    'rejection_reason': '',
    'sort_order': next,
    'sort_index': next,
    'is_active': true,
    'created_by': email,
  };
  try {
    final row = await Supabase.instance.client
        .from(kEtkinlikTable)
        .insert(payload)
        .select()
        .single();
    invalidateEtkinlikCache();
    return KampanyaItem.fromJson(Map<String, dynamic>.from(row));
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('event_date') || raw.contains('rejection_reason')) {
      payload.remove('event_date');
      payload.remove('rejection_reason');
      payload['description'] = when.isEmpty
          ? description.trim()
          : '$when\n\n${description.trim()}'.trim();
      try {
        final row = await Supabase.instance.client
            .from(kEtkinlikTable)
            .insert(payload)
            .select()
            .single();
        invalidateEtkinlikCache();
        return KampanyaItem.fromJson(Map<String, dynamic>.from(row));
      } catch (e2) {
        throw _etkinlikOneriSchemaError(e2);
      }
    }
    throw _etkinlikOneriSchemaError(e);
  }
}

Future<void> approveEtkinlik({
  required int id,
  required String adminEmail,
}) async {
  await _requireSection(adminEmail, SectionKey.etkinlik);
  try {
    await Supabase.instance.client.from(kEtkinlikTable).update({
      'status': kEtkinlikStatusApproved,
      'rejection_reason': '',
      'is_active': true,
    }).eq('id', id);
    invalidateEtkinlikCache();
  } catch (e) {
    throw _etkinlikOneriSchemaError(e);
  }
}

Future<void> rejectEtkinlik({
  required int id,
  required String adminEmail,
  String reason = '',
}) async {
  await _requireSection(adminEmail, SectionKey.etkinlik);
  try {
    await Supabase.instance.client.from(kEtkinlikTable).update({
      'status': kEtkinlikStatusRejected,
      'rejection_reason': reason.trim(),
    }).eq('id', id);
    invalidateEtkinlikCache();
  } catch (e) {
    throw _etkinlikOneriSchemaError(e);
  }
}

Future<({bool joined, int joinCount})> toggleEtkinlikKatilim(int eventId) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Katılmak için giriş yapın.');
  }
  try {
    final rows = await Supabase.instance.client.rpc(
      'etkinlik_toggle_katilim',
      params: {'p_event_id': eventId},
    );
    if (rows is List && rows.isNotEmpty && rows.first is Map) {
      final m = Map<String, dynamic>.from(rows.first as Map);
      return (
        joined: m['joined'] == true,
        joinCount: (m['join_count'] as num?)?.toInt() ?? 0,
      );
    }
    if (rows is Map) {
      return (
        joined: rows['joined'] == true,
        joinCount: (rows['join_count'] as num?)?.toInt() ?? 0,
      );
    }
    throw StateError('Katılım güncellenemedi.');
  } catch (e) {
    if (e is StateError) rethrow;
    throw _etkinlikOneriSchemaError(e);
  }
}
