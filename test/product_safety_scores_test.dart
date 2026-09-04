import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/models/product_safety.dart';
import 'package:engelsizclub/services/e_number_explanations.dart';
import 'package:engelsizclub/services/nova_from_ingredients.dart';

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

    test('reads Gemini string, nested map, and hyphenated keys', () {
      expect(NovaGroup.tryParse('nova: 4'), NovaGroup.four);
      expect(NovaGroup.tryParse('NOVA 3'), NovaGroup.three);
      expect(NovaGroup.tryParse({'group': '2'}), NovaGroup.two);
      expect(NovaGroup.tryParse('ultra-processed'), isNull);
      expect(
        NovaGroup.fromLooseJson({
          'nova_groups_tags': ['en:4-ultra-processed-food'],
        }),
        NovaGroup.four,
      );
      expect(
        NovaGroup.fromLooseJson({
          'nutriments': {'nova-group': 1},
        }),
        NovaGroup.one,
      );
      expect(
        SafetyReport.fromJson({
          'nova-group': '4',
        }).novaGroup,
        NovaGroup.four,
      );
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

    test('named additives (lesitin, aroma) count even without E-numbers', () {
      const banada =
          'Şeker, bitkisel yağ (palm), fındık, kakao tozu, yağsız süt tozu, '
          'demineralize peyniraltı suyu tozu, emülgatör (ayçiçek lesitini), tuz, aroma';
      final additives = ENumberExplanations.forDisplay(
        additives: const [],
        ingredients: banada,
      );
      expect(additives.any((a) => a.code == 'e322'), isTrue);
      expect(additives.any((a) => a.code == 'named:aroma'), isTrue);
      expect(
        AdditiveRiskLevel.fromAdditives(additives, ingredientsKnown: true),
        AdditiveRiskLevel.cokAz,
      );
      expect(
        AdditiveRiskLevel.fromAdditives(additives, ingredientsKnown: true),
        isNot(AdditiveRiskLevel.yok),
      );
      expect(NovaFromIngredients.classify(ingredients: banada), NovaGroup.four);
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

  group('NovaFromIngredients', () {
    test('FAO markers → 4; simple lists stay 1–3; unknown stays null', () {
      expect(
        NovaFromIngredients.classify(
          ingredients: 'su, şeker, karamel, fosforik asit, doğal aroma',
        ),
        NovaGroup.four,
      );
      expect(
        NovaFromIngredients.classify(
          ingredients: 'un, su, tuz, maya, E471',
        ),
        NovaGroup.four,
      );
      expect(
        NovaFromIngredients.classify(ingredients: 'süt'),
        NovaGroup.one,
      );
      expect(
        NovaFromIngredients.classify(ingredients: 'zeytinyağı'),
        NovaGroup.two,
      );
      expect(
        NovaFromIngredients.classify(
          ingredients: 'patates, ayçiçek yağı, tuz',
        ),
        NovaGroup.three,
      );
      expect(
        NovaFromIngredients.classify(
          ingredients: 'domates, tuz, sitrik asit (E330)',
        ),
        NovaGroup.three,
      );
      expect(NovaFromIngredients.classify(ingredients: ''), isNull);
      expect(NovaFromIngredients.classify(ingredients: 'Bilinmiyor'), isNull);
      expect(
        NovaFromIngredients.classify(
          ingredients: 'ksilooligosakkarit karışımı, özel formül xyz',
        ),
        isNull,
      );
    });

    test('does not override an official OFF NOVA', () {
      const official = SafetyReport(
        novaGroup: NovaGroup.one,
        novaGroupSource: LabelScoreSource.openfoodfacts,
        ingredientsSummary: 'su, şeker, doğal aroma',
      );
      final kept = NovaFromIngredients.applyIfMissing(official);
      expect(kept.novaGroup, NovaGroup.one);
      expect(kept.novaGroupSource, LabelScoreSource.openfoodfacts);
    });

    test('fills missing NOVA from the ingredient list as estimate', () {
      const empty = SafetyReport(
        ingredientsSummary: 'patates, ayçiçek yağı, tuz',
      );
      final filled = NovaFromIngredients.applyIfMissing(empty);
      expect(filled.novaGroup, NovaGroup.three);
      expect(filled.novaGroupSource, LabelScoreSource.estimate);
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
