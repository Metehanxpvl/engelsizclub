import 'package:engelsizclub/services/centers_osm_service.dart';
import 'package:engelsizclub/utils/tr_norm.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mirrors Places free-text relevance for mall queries (ECG-15).
bool freeTextKeepsMall(String name, String keyword) {
  final n = normTrForSearch('$name ');
  final k = normTrForSearch(keyword);
  const freeTextNegatives = [
    'otel',
    'hotel',
    'restoran',
    'banka',
    'cami',
  ];
  final junkHit = freeTextNegatives.any(n.contains);
  final mallQuery = k.contains('avm') ||
      k.contains('alisveris') ||
      k.contains('mall') ||
      k.contains('shopping');
  final junkInQuery = freeTextNegatives.any(k.contains) || mallQuery;
  if (junkHit && !junkInQuery) return false;
  if (mallQuery &&
      (n.contains('avm') ||
          n.contains('mall') ||
          n.contains('forum') ||
          n.contains('outlet'))) {
    return true;
  }
  final tokens = searchTokens(keyword, minLen: 2);
  if (tokens.isEmpty) return true;
  return tokens.any(n.contains);
}

void main() {
  test('free-text "avm" keeps mall names (no longer treated as junk)', () {
    expect(freeTextKeepsMall('Cevahir AVM', 'avm'), isTrue);
    expect(freeTextKeepsMall('Forum İstanbul', 'avm'), isTrue);
    expect(freeTextKeepsMall('İstanbul AVM', 'AVM'), isTrue);
  });

  test('OSM searchByQuery returns AVM hits for Istanbul', () async {
    final list = await CentersOsmService.searchByQuery(
      query: 'avm',
      latitude: 41.0082,
      longitude: 28.9784,
      city: 'İstanbul',
      radiusKm: 50,
    );
    expect(list, isNotEmpty);
    expect(
      list.any((c) => normTrForSearch(c.name).contains('avm')),
      isTrue,
    );
  }, timeout: const Timeout(Duration(seconds: 60)));
}
