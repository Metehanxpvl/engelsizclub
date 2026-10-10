import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engelsizclub/data/cards_data.dart';
import 'package:engelsizclub/services/app_catalog_service.dart';
import 'package:engelsizclub/services/catalog_adapters.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('catalogColor accepts hex strings without throwing', () {
    expect(catalogColor('#1A6B4A', 0xFF000000), const Color(0xFF1A6B4A));
    expect(catalogColor('0xFFE8F5EE', 0xFF000000), const Color(0xFFE8F5EE));
    expect(catalogColor('not-a-color', 0xFF1A6B4A), const Color(0xFF1A6B4A));
    expect(catalogInt('12'), 12);
    expect(catalogInt('#nope'), isNull);
    expect(colorFromHex('##'), const Color(0xFF1A6B4A));
  });

  test('diseases() survives string color and sort_order from catalog cache',
      () async {
    await AppCatalogService.instance.replaceDiseaseRow({
      'id': 'otizm-hex',
      'name': 'Otizm',
      'color': '#1A6B4A',
      'bg': '#E8F5EE',
      'sort_order': '3',
      'active': true,
    });
    expect(CatalogAdapters.diseases, returnsNormally);
    expect(
      CatalogAdapters.diseases().any((d) => d.id == 'otizm-hex'),
      isTrue,
    );
  });
}
