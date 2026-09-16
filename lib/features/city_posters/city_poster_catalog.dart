import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../data/turkish_cities_data.dart';

const kCityPosterGithubRepo = 'Metehanxpvl/engelsizclub';
const kCityPosterWorkflowUrl =
    'https://github.com/$kCityPosterGithubRepo/actions/workflows/generate_city_poster.yml';
const kCityPosterIndexRawUrl =
    'https://raw.githubusercontent.com/$kCityPosterGithubRepo/main/output/index.json';
const kCityPosterIndexCdnUrl =
    'https://cdn.jsdelivr.net/gh/$kCityPosterGithubRepo@main/output/index.json';

/// CORS-friendly index URLs (no GitHub Contents API — browser preflight fails).
const kCityPosterIndexUrls = <String>[
  kCityPosterIndexRawUrl,
  kCityPosterIndexCdnUrl,
];

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

String cityPosterRawUrl(String filename) {
  final safe = Uri.encodeComponent(filename);
  return 'https://raw.githubusercontent.com/$kCityPosterGithubRepo/main/output/$safe';
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
    this.ok,
    this.fail,
  });

  final String conclusion;
  final String htmlUrl;
  final String? headSha;
  final DateTime? updatedAt;
  final int? runNumber;
  final int? ok;
  final int? fail;

  bool get succeeded => conclusion.toLowerCase() == 'success' ||
      conclusion.toLowerCase() == 'ok' ||
      conclusion.toLowerCase() == 'ready';
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

class CityPosterIndexParse {
  const CityPosterIndexParse({
    required this.posters,
    this.run,
  });

  final List<CityPosterItem> posters;
  final CityPosterRunStatus? run;
}

typedef CityPosterHttpGet = Future<String> Function(Uri uri);

class CityPosterCatalog {
  CityPosterCatalog({CityPosterHttpGet? get}) : _get = get ?? _plainGet;

  final CityPosterHttpGet _get;

  /// No GitHub-specific headers — those trigger a CORS preflight that
  /// api.github.com / raw.githubusercontent.com may reject from engelsizclub.com.
  static Future<String> _plainGet(Uri uri) async {
    final res = await http.get(uri);
    if (res.statusCode >= 400) {
      throw StateError('HTTP ${res.statusCode} ${uri.path}');
    }
    return res.body;
  }

  List<String> _indexUrls() {
    final out = [...kCityPosterIndexUrls];
    try {
      if (Uri.base.hasScheme &&
          (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
        out.add(Uri.base.resolve('output/index.json').toString());
      }
    } catch (_) {}
    return out;
  }

  Future<CityPosterSnapshot> load() async {
    final bust = DateTime.now().millisecondsSinceEpoch.toString();
    Object? lastErr;
    for (final raw in _indexUrls()) {
      try {
        final parsedBase = Uri.parse(raw);
        final uri = parsedBase.replace(
          queryParameters: {
            ...parsedBase.queryParameters,
            't': bust,
          },
        );
        final parsed = parseCityPosterIndex(await _get(uri));
        return CityPosterSnapshot(
          items: mergeCityPosters(cities: kCityNames, files: parsed.posters),
          run: parsed.run,
        );
      } catch (e) {
        lastErr = e;
      }
    }
    return CityPosterSnapshot(
      items: mergeCityPosters(cities: kCityNames, files: const []),
      run: CityPosterRunStatus(
        conclusion: 'index-error',
        htmlUrl: kCityPosterWorkflowUrl,
        headSha: lastErr?.toString(),
      ),
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
        imageUrl: download.isNotEmpty ? download : cityPosterRawUrl(name),
        date: date,
      ),
    );
  }
  return out;
}

CityPosterIndexParse parseCityPosterIndex(String body) {
  final decoded = jsonDecode(body);
  if (decoded is List) {
    return CityPosterIndexParse(posters: parseGithubOutputListing(body));
  }
  if (decoded is! Map) {
    return const CityPosterIndexParse(posters: []);
  }
  final postersRaw = decoded['posters'];
  final files = <CityPosterItem>[];
  if (postersRaw is List) {
    for (final row in postersRaw) {
      if (row is! Map) continue;
      final file =
          (row['file'] ?? row['filename'] ?? row['name'])?.toString() ?? '';
      final match = _fileRe.firstMatch(file.toLowerCase());
      var slug = (row['slug']?.toString() ?? '').trim().toLowerCase();
      if (slug.isEmpty && match != null) slug = match.group(1)!;
      if (slug.isEmpty || file.isEmpty) continue;
      final date = (row['date']?.toString() ?? match?.group(2) ?? '').trim();
      final url = (row['url']?.toString() ?? '').trim();
      files.add(
        CityPosterItem(
          city: row['city']?.toString() ?? slug,
          slug: slug,
          filename: file,
          imageUrl: url.isNotEmpty ? url : cityPosterRawUrl(file),
          date: date.isEmpty ? null : date,
        ),
      );
    }
  }
  final generatedAt = decoded['generated_at']?.toString() ?? '';
  final status = decoded['status']?.toString() ??
      decoded['conclusion']?.toString() ??
      (files.isEmpty ? 'empty' : 'ok');
  return CityPosterIndexParse(
    posters: files,
    run: CityPosterRunStatus(
      conclusion: status,
      htmlUrl: kCityPosterWorkflowUrl,
      updatedAt: DateTime.tryParse(generatedAt),
      ok: (decoded['ok'] as num?)?.toInt(),
      fail: (decoded['fail'] as num?)?.toInt(),
    ),
  );
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
