import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/services/centers_osm_service.dart';

void main() {
  test('OSM free-text search returns Kadıköy fizik tedavi hits', () async {
    final results = await CentersOsmService.searchByQuery(
      query: 'kadıköy fizik tedavi',
      latitude: 40.99,
      longitude: 29.03,
      city: 'İstanbul',
      radiusKm: 40,
    );

    expect(results, isNotEmpty);
    final hay = results
        .map((c) => '${c.name} ${c.address}'.toLowerCase())
        .join(' | ');
    expect(
      hay.contains('fizik') || hay.contains('rehab'),
      isTrue,
      reason: 'expected rehab/fizik POI in OSM results, got: $hay',
    );
  }, timeout: const Timeout(Duration(seconds: 45)));
}
