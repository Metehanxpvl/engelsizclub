import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'section_editors.dart';
import 'utils/async_timeout.dart';

const kKariyerAssetPath = 'assets/engelsiz_kariyer/engelsiz-kariyer.json';
const kKariyerSourceUrl =
    'https://esube.iskur.gov.tr/istihdam/AcikIsIlanAra.aspx';

const _githubCatalog = <String>[
  'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/web/engelsiz-kariyer.json',
  'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/master/web/engelsiz-kariyer.json',
];
const _hostedCatalog = 'https://www.engelsizclub.com/engelsiz-kariyer.json';
const _githubOverrides = <String>[
  'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/web/engelsiz-kariyer-overrides.json',
  'https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/master/web/engelsiz-kariyer-overrides.json',
];
const _hostedOverrides =
    'https://www.engelsizclub.com/engelsiz-kariyer-overrides.json';

const kKariyerSektorKamu = 'kamu';
const kKariyerSektorOzel = 'ozel';
const kKariyerSektorAll = 'all';

/// İŞKUR `data-isverentur` / JSON `sektor` → `kamu` | `ozel` | '' (bilinmiyor).
String normalizeKariyerSektor([String? sektor, String? employerType]) {
  final raw = '${sektor ?? ''} ${employerType ?? ''}'
      .toLowerCase()
      .replaceAll('ö', 'o')
      .replaceAll('Ö', 'o');
  if (raw.contains('kamu')) return kKariyerSektorKamu;
  if (raw.contains('ozel')) return kKariyerSektorOzel;
  return '';
}

String kariyerSektorLabel(String sektor) {
  switch (sektor) {
    case kKariyerSektorKamu:
      return 'Kamu';
    case kKariyerSektorOzel:
      return 'Özel';
    default:
      return '';
  }
}

/// `all` herkes; boş sektör (elle eklenen) her sekmede kalır.
bool kariyerMatchesSektor(KariyerJob job, String filter) {
  if (filter.isEmpty || filter == kKariyerSektorAll) return true;
  final s = normalizeKariyerSektor(job.sektor, job.employerType);
  if (s.isEmpty) return true;
  return s == filter;
}

class KariyerJob {
  const KariyerJob({
    required this.id,
    required this.title,
    required this.city,
    required this.date,
    required this.applyUrl,
    this.positions = '',
    this.employerType = '',
    this.workType = '',
    this.sektor = '',
    this.hidden = false,
    this.custom = false,
  });

  final String id;
  final String title;
  final String city;
  final String date;
  final String applyUrl;
  final String positions;
  final String employerType;
  final String workType;
  final String sektor;
  final bool hidden;
  final bool custom;

  String get sektorKey => normalizeKariyerSektor(sektor, employerType);

  String get sektorDisplay {
    final label = kariyerSektorLabel(sektorKey);
    if (label.isNotEmpty) return label;
    return employerType.trim();
  }

  KariyerJob copyWith({
    String? title,
    String? city,
    String? date,
    String? applyUrl,
    bool? hidden,
  }) {
    return KariyerJob(
      id: id,
      title: title ?? this.title,
      city: city ?? this.city,
      date: date ?? this.date,
      applyUrl: applyUrl ?? this.applyUrl,
      positions: positions,
      employerType: employerType,
      workType: workType,
      sektor: sektor,
      hidden: hidden ?? this.hidden,
      custom: custom,
    );
  }

  factory KariyerJob.fromJson(Map<String, dynamic> json) {
    final employerType = (json['employerType'] ?? json['employer_type'] ?? '')
        .toString()
        .trim();
    final sektor = normalizeKariyerSektor(
      (json['sektor'] ?? json['sector'] ?? '').toString().trim(),
      employerType,
    );
    return KariyerJob(
      id: (json['id'] ?? '').toString().trim(),
      title: (json['title'] ?? '').toString().trim(),
      city: (json['city'] ?? '').toString().trim(),
      date: (json['date'] ?? json['date_text'] ?? '').toString().trim(),
      applyUrl: (json['applyUrl'] ?? json['apply_url'] ?? '').toString().trim(),
      positions: (json['positions'] ?? '').toString().trim(),
      employerType: employerType,
      workType: (json['workType'] ?? json['work_type'] ?? '').toString().trim(),
      sektor: sektor,
      hidden: json['hidden'] == true,
      custom: json['custom'] == true ||
          (json['id']?.toString() ?? '').startsWith('custom-'),
    );
  }
}

class KariyerOverride {
  const KariyerOverride({
    required this.jobId,
    this.hidden = false,
    this.title,
    this.city,
    this.date,
    this.applyUrl,
    this.custom = false,
  });

  final String jobId;
  final bool hidden;
  final String? title;
  final String? city;
  final String? date;
  final String? applyUrl;
  final bool custom;
}

List<KariyerJob>? _catalogCache;
DateTime? _catalogCacheAt;
String? lastKariyerLoadError;
const _ttl = Duration(minutes: 20);

bool get hasFreshKariyerCache {
  final at = _catalogCacheAt;
  final list = _catalogCache;
  if (at == null || list == null) return false;
  return DateTime.now().difference(at) < _ttl;
}

List<KariyerJob>? get cachedKariyerJobs => _catalogCache;

void invalidateKariyerCache() {
  _catalogCache = null;
  _catalogCacheAt = null;
}

String _bust(String url) {
  final sep = url.contains('?') ? '&' : '?';
  // 15 dk kova: GitHub Action güncellemesi hosting deploy’u beklemeden görünür.
  final bucket = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 900000;
  return '$url${sep}v=$bucket';
}

Future<Map<String, dynamic>?> _getJson(String url) async {
  try {
    final r = await http.get(Uri.parse(_bust(url))).timeout(
          const Duration(seconds: 12),
        );
    if (r.statusCode != 200 || r.body.trim().isEmpty) return null;
    final decoded = jsonDecode(r.body);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is List) return {'items': decoded};
    return null;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> _loadCatalogJson() async {
  // GitHub Action JSON’u main’e yazar; hosting kopyası deploy bekler.
  for (final url in _githubCatalog) {
    final json = await _getJson(url);
    if (json != null) return json;
  }
  final hosted = await _getJson(_hostedCatalog);
  if (hosted != null) return hosted;
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http')) {
      final local = await _getJson('$origin/engelsiz-kariyer.json');
      if (local != null) return local;
    }
  }
  try {
    final raw = await rootBundle.loadString(kKariyerAssetPath);
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
  } catch (_) {}
  return null;
}

Future<KariyerOverrideMap> _loadStaticOverrides() async {
  Map<String, dynamic>? json;
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('http')) {
      json = await _getJson('$origin/engelsiz-kariyer-overrides.json');
    }
  }
  json ??= await _getJson(_hostedOverrides);
  if (json == null) {
    for (final url in _githubOverrides) {
      json = await _getJson(url);
      if (json != null) break;
    }
  }
  return KariyerOverrideMap.fromJson(json ?? const {});
}

class KariyerOverrideMap {
  KariyerOverrideMap(this.byId);

  final Map<String, KariyerOverride> byId;

  factory KariyerOverrideMap.fromJson(Map<String, dynamic> json) {
    final map = <String, KariyerOverride>{};
    for (final id in (json['hidden'] as List? ?? const [])) {
      final jobId = id.toString().trim();
      if (jobId.isEmpty) continue;
      map[jobId] = KariyerOverride(jobId: jobId, hidden: true);
    }
    final edits = json['edits'];
    if (edits is Map) {
      for (final e in edits.entries) {
        final jobId = e.key.toString().trim();
        if (jobId.isEmpty || e.value is! Map) continue;
        final row = Map<String, dynamic>.from(e.value as Map);
        final prev = map[jobId];
        map[jobId] = KariyerOverride(
          jobId: jobId,
          hidden: prev?.hidden == true || row['hidden'] == true,
          title: row['title']?.toString(),
          city: row['city']?.toString(),
          date: (row['date'] ?? row['date_text'])?.toString(),
          applyUrl: (row['applyUrl'] ?? row['apply_url'])?.toString(),
          custom: row['custom'] == true || jobId.startsWith('custom-'),
        );
      }
    }
    return KariyerOverrideMap(map);
  }

  void mergeRow(KariyerOverride row) {
    final prev = byId[row.jobId];
    byId[row.jobId] = KariyerOverride(
      jobId: row.jobId,
      hidden: row.hidden || (prev?.hidden ?? false),
      title: _nz(row.title) ?? prev?.title,
      city: _nz(row.city) ?? prev?.city,
      date: _nz(row.date) ?? prev?.date,
      applyUrl: _nz(row.applyUrl) ?? prev?.applyUrl,
      custom: row.custom || (prev?.custom ?? false),
    );
  }
}

String? _nz(String? v) {
  final t = v?.trim();
  if (t == null || t.isEmpty) return null;
  return t;
}

List<KariyerJob> mergeKariyerJobs({
  required List<KariyerJob> catalog,
  required KariyerOverrideMap overrides,
}) {
  final out = <KariyerJob>[];
  final seen = <String>{};
  for (final job in catalog) {
    if (job.id.isEmpty) continue;
    seen.add(job.id);
    final o = overrides.byId[job.id];
    if (o == null) {
      out.add(job);
      continue;
    }
    out.add(
      job.copyWith(
        title: _nz(o.title) ?? job.title,
        city: _nz(o.city) ?? job.city,
        date: _nz(o.date) ?? job.date,
        applyUrl: _nz(o.applyUrl) ?? job.applyUrl,
        hidden: o.hidden,
      ),
    );
  }
  for (final o in overrides.byId.values) {
    if (seen.contains(o.jobId)) continue;
    if (!o.custom && !o.jobId.startsWith('custom-')) continue;
    if (o.hidden) continue;
    final title = _nz(o.title);
    if (title == null) continue;
    out.add(
      KariyerJob(
        id: o.jobId,
        title: title,
        city: _nz(o.city) ?? '',
        date: _nz(o.date) ?? '',
        applyUrl: _nz(o.applyUrl) ?? kKariyerSourceUrl,
        custom: true,
      ),
    );
  }
  return out;
}

Future<KariyerOverrideMap> _loadTableOverrides() async {
  try {
    final rows = await withNetworkTimeout(
      Supabase.instance.client.from('kariyer_overrides').select(),
    );
    final map = KariyerOverrideMap({});
    for (final r in (rows as List).whereType<Map>()) {
      final id = (r['job_id'] ?? '').toString().trim();
      if (id.isEmpty) continue;
      map.mergeRow(
        KariyerOverride(
          jobId: id,
          hidden: r['hidden'] == true,
          title: r['title']?.toString(),
          city: r['city']?.toString(),
          date: r['date_text']?.toString(),
          applyUrl: r['apply_url']?.toString(),
          custom: r['custom'] == true || id.startsWith('custom-'),
        ),
      );
    }
    return map;
  } catch (_) {
    return KariyerOverrideMap({});
  }
}

Future<List<KariyerJob>> loadKariyerJobs({
  bool forceRefresh = false,
  bool includeHidden = false,
}) async {
  if (!forceRefresh && hasFreshKariyerCache) {
    final cached = List<KariyerJob>.from(_catalogCache!);
    return includeHidden ? cached : cached.where((j) => !j.hidden).toList();
  }
  lastKariyerLoadError = null;
  try {
    final catalogJson = await _loadCatalogJson();
    if (catalogJson == null) {
      lastKariyerLoadError = 'Kariyer listesi yüklenemedi.';
      return _catalogCache ?? const [];
    }
    final catalog = [
      for (final e in (catalogJson['items'] as List? ?? const []))
        if (e is Map) KariyerJob.fromJson(Map<String, dynamic>.from(e)),
    ].where((j) => j.id.isNotEmpty && j.title.isNotEmpty).toList();
    final overrides = await _loadStaticOverrides();
    final table = await _loadTableOverrides();
    for (final row in table.byId.values) {
      overrides.mergeRow(row);
    }
    final merged = mergeKariyerJobs(catalog: catalog, overrides: overrides);
    _catalogCache = List<KariyerJob>.unmodifiable(merged);
    _catalogCacheAt = DateTime.now();
    return includeHidden
        ? List<KariyerJob>.from(merged)
        : merged.where((j) => !j.hidden).toList();
  } catch (e) {
    lastKariyerLoadError = '$e';
    if (_catalogCache != null) {
      final cached = List<KariyerJob>.from(_catalogCache!);
      return includeHidden ? cached : cached.where((j) => !j.hidden).toList();
    }
    return const [];
  }
}

Future<void> _requireKariyerAdmin(String? email) async {
  await ensureSectionEditorsLoaded(email);
  if (!canEditSection(email, SectionKey.kariyer)) {
    throw StateError('Bu bölümü yönetme yetkiniz yok.');
  }
}

Future<void> upsertKariyerOverride({
  required String adminEmail,
  required String jobId,
  bool? hidden,
  String? title,
  String? city,
  String? date,
  String? applyUrl,
  bool custom = false,
}) async {
  await _requireKariyerAdmin(adminEmail);
  final id = jobId.trim();
  if (id.isEmpty) throw StateError('İlan kimliği boş.');
  try {
    await Supabase.instance.client.from('kariyer_overrides').upsert({
      'job_id': id,
      'hidden': hidden ?? false,
      'title': title?.trim() ?? '',
      'city': city?.trim() ?? '',
      'date_text': date?.trim() ?? '',
      'apply_url': applyUrl?.trim() ?? '',
      'custom': custom || id.startsWith('custom-'),
      'updated_by': adminEmail.trim().toLowerCase(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (e) {
    final raw = e.toString();
    if (raw.contains('kariyer_overrides') ||
        raw.contains('PGRST') ||
        raw.contains('schema') ||
        raw.contains('42P01')) {
      throw StateError(
        'Override tablosu yok. Supabase’de engelsiz_kariyer.sql çalıştırın.',
      );
    }
    rethrow;
  }
  invalidateKariyerCache();
}

Future<void> hideKariyerJob({
  required String adminEmail,
  required KariyerJob job,
}) {
  return upsertKariyerOverride(
    adminEmail: adminEmail,
    jobId: job.id,
    hidden: true,
    title: job.title,
    city: job.city,
    date: job.date,
    applyUrl: job.applyUrl,
    custom: job.custom,
  );
}
