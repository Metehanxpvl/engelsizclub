import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/models/product_safety.dart';

void main() {
  group('NovaGroup.tryParse', () {
    test('reads OFF number, en: prefix, and tag slugs', () {
      expect(NovaGroup.tryParse(4), NovaGroup.four);
      expect(NovaGroup.tryParse('3'), NovaGroup.three);
      expect(NovaGroup.tryParse('en:2'), NovaGroup.two);
      expect(NovaGroup.tryParse('4-ultra-processed-food'), NovaGroup.four);
      expect(
        NovaGroup.tryParse(['en:4-ultra-processed-food']),
        NovaGroup.four,
      );
      expect(NovaGroup.tryParse(0), isNull);
      expect(NovaGroup.tryParse('unknown'), isNull);
      expect(NovaGroup.tryParse(''), isNull);
      expect(NovaGroup.tryParse(null), isNull);
    });
  });

  group('AdditiveRiskLevel.fromAdditives', () {
    test('Yok only when ingredients are known and there are no E-codes', () {
      expect(
        AdditiveRiskLevel.fromAdditives(const [], ingredientsKnown: true),
        AdditiveRiskLevel.yok,
      );
    });

    test('Bilinmiyor when ingredients unknown — empty additives is not Yok', () {
      expect(
        AdditiveRiskLevel.fromAdditives(const []),
        AdditiveRiskLevel.bilinmiyor,
      );
      expect(
        AdditiveRiskLevel.fromAdditives(const [], ingredientsKnown: false),
        AdditiveRiskLevel.bilinmiyor,
      );
    });

    test('E-codes set risk even if NOVA / ingredients text is missing', () {
      final risk = AdditiveRiskLevel.fromAdditives(
        const [AdditiveHit(code: 'e330', labelTr: 'sitrik asit')],
        ingredientsKnown: false,
      );
      expect(risk, AdditiveRiskLevel.cokAz);
      expect(risk.isUnknown, isFalse);
    });
  });

  group('ProductRecord.knowsIngredientList', () {
    test('placeholder text is not usable ingredients', () {
      expect(ProductRecord.isUsableIngredientText('Bilinmiyor'), isFalse);
      expect(ProductRecord.isUsableIngredientText('Bilgi yok'), isFalse);
      expect(ProductRecord.isUsableIngredientText('İçindekiler metni yok.'), isFalse);
      expect(
        ProductRecord.isUsableIngredientText('patates, ayçiçek yağı, tuz'),
        isTrue,
      );
    });
  });
}
