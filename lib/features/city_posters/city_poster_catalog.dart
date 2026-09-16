import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/turkish_cities_data.dart';

const kCityPosterGithubRepo = 'Metehanxpvl/engelsizclub';
const kCityPosterWorkflowUrl =
    'https://github.com/$kCityPosterGithubRepo/actions/workflows/generate_city_poster.yml';
const kCityPosterContentsUrl =
    'https://api.github.com/repos/$kCityPosterGithubRepo/contents/output';
const kCityPosterRunsUrl =
    'https://api.github.com/repos/$kCityPosterGithubRepo/actions/workflows/generate_city_poster.yml/runs?per_page=1';

final _fileRe = RegExp(
  r'^([a-z0-9]+)_muze_gezisi_(\d{4}-\d{2}-\d{2})\.(jpg|jpeg|png)$',
  caseSensitive: false,
);

/// Python `slug_city` ile aynı: İstanbul → istanbul, Şanlıurfa → sanliurfa.
String cityPosterSlug(String city) {
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
  for (final rune in city.trim().runes) {
    final ch = String.fromCharCode(rune);
    buf.write(tr[ch] ?? ch.toLowerCase());
  }
  return buf.toString().replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

String cityPosterCdnUrl(String filename) {
  final safe = Uri.encodeComponent(filename);
  return 'https://cdn.jsdelivr.net/gh/$kCityPosterGithubRepo@main/output/$safe';
}

class CityPosterItem {
  const CityPosterItem({
    required this.city,
    required this.slug,
    this.filename,
    this.imageUrl,
    this.date,
  });

  final String city;
  final String slug;
  final String? filename;
  final String? imageUrl;
  final String? date;

  bool get hasImage => (imageUrl ?? '').trim().isNotEmpty;
}

class CityPosterRunStatus {
  const CityPosterRunStatus({
    required this.conclusion,
    required this.htmlUrl,
    this.headSha,
    this.updatedAt,
    this.runNumber,
  });

  final String conclusion;
  final String htmlUrl;
  final String? headSha;
  final DateTime? updatedAt;
  final int? runNumber;

  bool get succeeded => conclusion.toLowerCase() == 'success';
}

class CityPosterSnapshot {
  const CityPosterSnapshot({
    required this.items,
    this.run,
  });

  final List<CityPosterItem> items;
  final CityPosterRunStatus? run;

  int get readyCount => items.where((e) => e.hasImage).length;
}

typedef CityPosterHttpGet = Future<String> Function(Uri uri);

class CityPosterCatalog {
  CityPosterCatalog({CityPosterHttpGet? get}) : _get = get ?? _githubGet;

  final CityPosterHttpGet _get;

  static Future<String> _githubGet(Uri uri) async {
    final res = await http.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'engelsizclub-city-posters',
      },
    );
    if (res.statusCode >= 400) {
      throw StateError('GitHub HTTP ${res.statusCode}');
    }
    return res.body;
  }

  Future<CityPosterSnapshot> load() async {
    List<CityPosterItem> files = const [];
    try {
      files = parseGithubOutputListing(await _get(Uri.parse(kCityPosterContentsUrl)));
    } catch (_) {
      files = const [];
    }
    CityPosterRunStatus? run;
    try {
      run = parseLatestWorkflowRun(await _get(Uri.parse(kCityPosterRunsUrl)));
    } catch (_) {
      run = null;
    }
    return CityPosterSnapshot(
      items: mergeCityPosters(cities: kCityNames, files: files),
      run: run,
    );
  }
}

List<CityPosterItem> parseGithubOutputListing(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! List) return const [];
  final out = <CityPosterItem>[];
  for (final row in decoded) {
    if (row is! Map) continue;
    final name = row['name']?.toString() ?? '';
    final match = _fileRe.firstMatch(name.toLowerCase());
    if (match == null) continue;
    final slug = match.group(1)!;
    final date = match.group(2)!;
    final download = (row['download_url']?.toString() ?? '').trim();
    out.add(
      CityPosterItem(
        city: slug,
        slug: slug,
        filename: name,
        imageUrl: download.isNotEmpty ? download : cityPosterCdnUrl(name),
        date: date,
      ),
    );
  }
  return out;
}

CityPosterRunStatus? parseLatestWorkflowRun(String body) {
  final decoded = jsonDecode(body);
  if (decoded is! Map) return null;
  final runs = decoded['workflow_runs'];
  if (runs is! List || runs.isEmpty) return null;
  final first = runs.first;
  if (first is! Map) return null;
  final html = first['html_url']?.toString() ?? '';
  if (html.isEmpty) return null;
  return CityPosterRunStatus(
    conclusion: first['conclusion']?.toString() ?? first['status']?.toString() ?? '',
    htmlUrl: html,
    headSha: first['head_sha']?.toString(),
    runNumber: (first['run_number'] as num?)?.toInt(),
    updatedAt: DateTime.tryParse(first['updated_at']?.toString() ?? ''),
  );
}

List<CityPosterItem> mergeCityPosters({
  required List<String> cities,
  required List<CityPosterItem> files,
}) {
  final bySlug = <String, CityPosterItem>{};
  for (final file in files) {
    final prev = bySlug[file.slug];
    if (prev == null || (file.date ?? '').compareTo(prev.date ?? '') >= 0) {
      bySlug[file.slug] = file;
    }
  }
  return [
    for (final city in cities) _itemForCity(city, bySlug),
  ];
}

CityPosterItem _itemForCity(
  String city,
  Map<String, CityPosterItem> bySlug,
) {
  final slug = cityPosterSlug(city);
  final hit = bySlug[slug];
  if (hit == null) {
    return CityPosterItem(city: city, slug: slug);
  }
  return CityPosterItem(
    city: city,
    slug: slug,
    filename: hit.filename,
    imageUrl: hit.imageUrl,
    date: hit.date,
  );
}
