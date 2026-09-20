import 'dart:convert';

import 'package:http/http.dart' as http;

import 'scientific_research_model.dart';

const kSciencePapersGithubRepo = 'Metehanxpvl/engelsizclub';

const kSciencePapersRawUrl =
    'https://raw.githubusercontent.com/$kSciencePapersGithubRepo/main/output/papers.json';

const kSciencePapersCdnUrl =
    'https://cdn.jsdelivr.net/gh/$kSciencePapersGithubRepo@main/output/papers.json';

/// Profil / admin Bilimsel Araştırmalar — collector'ın GitHub'a yazdığı katalog.
/// CORS: GitHub Contents API yok; raw + jsDelivr (şehir afişleriyle aynı desen).
const kSciencePapersUrls = <String>[
  kSciencePapersRawUrl,
  kSciencePapersCdnUrl,
];

typedef SciencePapersHttpGet = Future<String> Function(Uri uri);

class ScientificPapersCatalog {
  ScientificPapersCatalog({SciencePapersHttpGet? get}) : _get = get ?? _plainGet;

  final SciencePapersHttpGet _get;

  static Future<String> _plainGet(Uri uri) async {
    final res = await http.get(
      uri,
      headers: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (res.statusCode >= 400) {
      throw StateError('HTTP ${res.statusCode} ${uri.path}');
    }
    return res.body;
  }

  List<String> _catalogUrls() {
    final out = [...kSciencePapersUrls];
    try {
      if (Uri.base.hasScheme &&
          (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
        out.add(Uri.base.resolve('output/papers.json').toString());
      }
    } catch (_) {}
    return out;
  }

  /// Her çağrıda `t=` ile önbellek kırılır. Boş/404 olursa [] döner.
  Future<List<ScientificResearch>> load() async {
    final bust = DateTime.now().millisecondsSinceEpoch.toString();
    Object? lastErr;
    for (final raw in _catalogUrls()) {
      try {
        final parsedBase = Uri.parse(raw);
        final uri = parsedBase.replace(
          queryParameters: {
            ...parsedBase.queryParameters,
            't': bust,
          },
        );
        final items = parseSciencePapersJson(await _get(uri));
        if (items.isNotEmpty) return items;
      } catch (e) {
        lastErr = e;
      }
    }
    if (lastErr != null) {
      throw StateError(scientificResearchLoadError(lastErr));
    }
    return const [];
  }
}

List<ScientificResearch> parseSciencePapersJson(String raw) {
  final decoded = jsonDecode(raw);
  List<dynamic> list;
  if (decoded is List) {
    list = decoded;
  } else if (decoded is Map) {
    final nested = decoded['papers'] ?? decoded['items'] ?? decoded['data'];
    list = nested is List ? nested : const [];
  } else {
    list = const [];
  }
  return list
      .whereType<Map>()
      .map((e) => ScientificResearch.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
