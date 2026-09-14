/// In-app screens MetoBot may suggest. Keep in sync with
/// `supabase/functions/metobot-chat` SITE_ROUTES.
const kMetoBotKnownRoutes = <String>{
  'haklar',
  'harita',
  'merkezler',
  'ilanlar',
  'kariyer',
  'kesfet',
  'forum',
  'kartlar',
  'cvi',
  'cvi2',
  'mchat',
  'gelisim',
  'barkod',
  'aile_kocu',
  'taramalar',
  'boyama',
  'puzzle',
  'destek_sorgu',
  'home',
};

class MetoBotSuggestedRoute {
  const MetoBotSuggestedRoute({required this.route, required this.title});

  final String route;
  final String title;
}

bool isAllowedMetoBotRoute(String route) {
  final r = route.trim();
  if (r.isEmpty) return false;
  if (kMetoBotKnownRoutes.contains(r)) return true;
  if (r.startsWith('/') && !r.startsWith('//') && !r.contains('://')) {
    return r.startsWith('/bilgi-kutuphanesi/') ||
        r == '/destek-sorgu' ||
        r == '/evde-egitim' ||
        r == '/fotografli-puzzle.html' ||
        r == '/boyama.html';
  }
  return false;
}

List<MetoBotSuggestedRoute> parseMetoBotSuggestedRoutes(Object? raw) {
  if (raw is! List) return const [];
  final out = <MetoBotSuggestedRoute>[];
  final seen = <String>{};
  for (final item in raw) {
    if (item is! Map) continue;
    final map = item.map((k, v) => MapEntry(k.toString(), v));
    final route = map['route']?.toString().trim() ?? '';
    final title = map['title']?.toString().trim() ?? '';
    if (!isAllowedMetoBotRoute(route) || !seen.add(route)) continue;
    out.add(MetoBotSuggestedRoute(
      route: route,
      title: title.isEmpty ? route : title,
    ));
    if (out.length >= 2) break;
  }
  return List<MetoBotSuggestedRoute>.unmodifiable(out);
}
