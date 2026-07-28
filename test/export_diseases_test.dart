import 'dart:convert';
import 'dart:io';

import 'package:engelsizclub/data/diseases_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('export diseases.json', () {
    final list = <Map<String, dynamic>>[];
    for (var i = 0; i < kDiseases.length; i++) {
      final d = kDiseases[i];
      list.add({
        'id': d.id,
        'name': d.name,
        'icon': d.icon,
        'color': d.color.toARGB32(),
        'bg': d.bg.toARGB32(),
        'photo': d.photo ?? '',
        'description': d.desc,
        'symptoms': d.symptoms,
        'diagnosis': d.diagnosis,
        'support': d.support,
        'faq': [
          for (final f in d.faq) {'q': f.q, 'a': f.a},
        ],
        'sort_order': i,
        'active': true,
      });
    }
    final out = File('content/diseases.json');
    out.parent.createSync(recursive: true);
    out.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(list));
    // ignore: avoid_print
    print('Wrote ${out.path} (${list.length})');
    expect(list.length, greaterThan(0));
  });
}
