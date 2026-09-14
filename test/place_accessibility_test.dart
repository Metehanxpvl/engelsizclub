import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/places/place_models.dart';

void main() {
  test('normalizeGooglePlaceId strips places/ prefix', () {
    expect(normalizeGooglePlaceId('places/ChIJ123'), 'ChIJ123');
    expect(normalizeGooglePlaceId('ChIJ123'), 'ChIJ123');
    expect(normalizeGooglePlaceId('  '), isNull);
    expect(normalizeGooglePlaceId(null), isNull);
  });

  test('search parse uses Places id, never name as display key', () {
    expect(
      googlePlaceIdFromPlacesJson({
        'id': 'ChIJabc',
        'name': 'places/ChIJabc',
      }),
      'ChIJabc',
    );
    expect(
      googlePlaceIdFromPlacesJson({'name': 'places/ChIJonlyName'}),
      'ChIJonlyName',
    );
  });

  test('catalog key is local:id when Places id is missing', () {
    expect(catalogPlaceKey(42), 'local:42');
    expect(normalizeGooglePlaceId(null) ?? catalogPlaceKey(42), 'local:42');
  });

  test('summary averages ramp / elevator / wc / entrance / parking', () {
    final reviews = [
      PlaceReview(
        id: '1',
        placeId: 'p',
        userId: 'u1',
        criteria: const {
          'ramp': 2,
          'elevator': 0,
          'accessible_wc': 1,
          'entrance': 2,
          'parking': 0,
        },
        note: '',
      ),
      PlaceReview(
        id: '2',
        placeId: 'p',
        userId: 'u2',
        criteria: const {
          'ramp': 2,
          'elevator': 2,
          'accessible_wc': 1,
          'entrance': 1,
          'parking': 1,
        },
        note: '',
      ),
    ];
    final s = PlaceAccessSummary(reviews: reviews);
    expect(s.count, 2);
    expect(s.labelFor('ramp'), 'Var');
    expect(s.labelFor('elevator'), 'Kısmi');
    expect(s.labelFor('accessible_wc'), 'Kısmi');
    expect(s.labelFor('parking'), 'Yok');
    expect(kAccessCriteria.map((c) => c.key).toList(), [
      'ramp',
      'elevator',
      'accessible_wc',
      'entrance',
      'parking',
    ]);
  });
}
