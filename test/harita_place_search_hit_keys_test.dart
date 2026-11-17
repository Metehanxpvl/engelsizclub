import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/data/centers_data.dart';
import 'package:engelsizclub/utils/tr_norm.dart';

/// Mirrors Merkezler free-text merge: putIfAbsent must keep the stored id in
/// hitIds (PR #13 path), and geo keys survive overlay id remap.
void main() {
  String geoKey(MetoCenter c) =>
      '${c.lat.toStringAsFixed(4)}|${c.lng.toStringAsFixed(4)}';

  test('putIfAbsent hitIds use kept center id', () {
    final existing = MetoCenter(
      id: 100,
      city: 'İstanbul',
      ilce: 'Şişli',
      name: 'Cevahir',
      category: 'Özel Eğitim',
      address: 'Şişli / İstanbul',
      phone: '—',
      hours: '—',
      services: const ['Özel Eğitim'],
      rating: 0,
      reviews: 0,
      color: const Color(0xFFE07A5F),
      lat: 41.0620,
      lng: 28.9870,
    );
    final incoming = MetoCenter(
      id: 810001,
      city: 'İstanbul',
      ilce: 'Şişli',
      name: 'Cevahir',
      category: 'Özel Eğitim',
      address: 'Şişli / İstanbul',
      phone: '—',
      hours: '—',
      services: const ['Özel Eğitim'],
      rating: 0,
      reviews: 0,
      color: const Color(0xFFE07A5F),
      lat: 41.0620,
      lng: 28.9870,
    );

    final merged = <String, MetoCenter>{};
    final key =
        '${normTrForSearch(existing.name)}|${existing.lat.toStringAsFixed(4)}|${existing.lng.toStringAsFixed(4)}';
    merged[key] = existing;

    final hitIds = <int>{};
    final hitKeys = <String>{};
    final kept = merged.putIfAbsent(key, () => incoming);
    hitIds.add(kept.id);
    hitKeys.add(geoKey(kept));

    expect(hitIds, contains(100));
    expect(hitIds, isNot(contains(810001)));
    expect(hitKeys, contains(geoKey(existing)));
    expect(haystackMatchesQuery(kept.name, 'cevahir'), isTrue);
  });
}
