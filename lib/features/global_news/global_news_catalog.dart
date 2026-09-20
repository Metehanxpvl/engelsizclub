import 'package:http/http.dart' as http;

import 'global_news_model.dart';

const kGlobalNewsGithubRepo = 'Metehanxpvl/engelsizclub';

const kGlobalNewsRawUrl =
    'https://raw.githubusercontent.com/$kGlobalNewsGithubRepo/main/web/engelsiz-haberler.json';

const kGlobalNewsCdnUrl =
    'https://cdn.jsdelivr.net/gh/$kGlobalNewsGithubRepo@main/web/engelsiz-haberler.json';

const kGlobalNewsUrls = <String>[
  kGlobalNewsRawUrl,
  kGlobalNewsCdnUrl,
];

typedef GlobalNewsHttpGet = Future<String> Function(Uri uri);

class GlobalNewsCatalog {
  GlobalNewsCatalog({GlobalNewsHttpGet? get}) : _get = get ?? _plainGet;

  final GlobalNewsHttpGet _get;

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
    final out = [...kGlobalNewsUrls];
    try {
      if (Uri.base.hasScheme &&
          (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
        out.insert(0, Uri.base.resolve('engelsiz-haberler.json').toString());
      }
    } catch (_) {}
    return out;
  }

  Future<List<GlobalNewsItem>> load() async {
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
        return parseGlobalNewsJson(await _get(uri));
      } catch (e) {
        lastErr = e;
      }
    }
    if (lastErr != null) {
      throw StateError('Küresel haber kataloğu okunamadı: $lastErr');
    }
    return const [];
  }
}
