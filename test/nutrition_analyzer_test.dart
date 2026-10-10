import 'package:engelsizclub/nutrition/food_catalog.dart';
import 'package:engelsizclub/nutrition/nutrient_references.dart';
import 'package:engelsizclub/nutrition/nutrition_analyzer.dart';
import 'package:engelsizclub/nutrition/nutrition_parser.dart';
import 'package:engelsizclub/nutrition/nutrition_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 29);

  test('parses portions like 2 yumurta and 50 gram peynir', () {
    final parsed = parseNutritionInput(
      '2 yumurta, 50 gram peynir, 1 kase mercimek çorbası, 200 ml ayran, 1 avuç badem, 1 adet muz, 150 gram tavuk',
    );
    expect(parsed.foods.map((e) => e.foodId).toList(), [
      'egg',
      'white_cheese',
      'lentil_soup',
      'ayran',
      'almond',
      'banana',
      'chicken',
    ]);
    expect(parsed.foods[0].quantity, 2);
    expect(parsed.foods[0].unit, NutritionUnit.piece);
    expect(parsed.foods[1].quantity, 50);
    expect(parsed.foods[1].unit, NutritionUnit.g);
    expect(parsed.foods.every((e) => e.portionSpecified), isTrue);
  });

  test('meal prefixes still parse quantities', () {
    final parsed = parseNutritionInput(
      'Sabah 2 haşlanmış yumurta, 1 dilim peynir. Öğlen 1 kase mercimek çorbası.',
    );
    expect(parsed.foods.map((e) => e.foodId), [
      'egg',
      'white_cheese',
      'lentil_soup',
    ]);
    expect(parsed.foods[0].quantity, 2);
    expect(parsed.foods[0].portionSpecified, isTrue);
  });

  test('missing portions lower confidence', () {
    final low = analyzeNutrition('yumurta peynir tavuk', day);
    expect(low.confidence, NutritionConfidence.low);
    expect(low.analyzedFoods.every((e) => !e.portionSpecified), isTrue);

    final high = analyzeNutrition(
      '2 yumurta, 50 gram peynir, 150 gram tavuk',
      day,
    );
    expect(high.confidence, NutritionConfidence.high);
  });

  test('rejects empty input and future dates', () {
    expect(
      () => analyzeNutrition('abc', day),
      throwsA(isA<StateError>()),
    );
    expect(
      () => analyzeNutrition(
        '2 yumurta, 50 gram peynir',
        DateTime.now().add(const Duration(days: 2)),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('stats keep UL separate from RDA percentage', () {
    final result = analyzeNutrition('2 yumurta, 50 gram peynir', day);
    final iron = result.nutrients[NutrientKey.iron]!;
    expect(iron.percentage, isNonNegative);
    expect(iron.upperLimit, isNotNull);
    expect(result.summary['nutrientCount'], 18);
    expect(result.toJson()['summary'], isA<Map<String, dynamic>>());
  });

  test('percentage bands and food sources for a nutrient', () {
    expect(nutritionBand(28).labelTr, 'Hedefin altında');
    expect(nutritionBand(28).rangeTr, '%0–49');
    expect(nutritionBand(90).labelTr, 'Hedefe yakın');
    expect(nutritionBand(160).labelTr, 'Günlük hedefin üzerinde');
    final dFoods = catalogFoodsForNutrient(NutrientKey.vitaminD);
    expect(dFoods.map((e) => e.id), containsAll(['fish', 'egg']));
    final result = analyzeNutrition('2 yumurta, 150 gram tavuk', day);
    final today = todayFoodsForNutrient(
      result.analyzedFoods,
      NutrientKey.vitaminD,
    );
    expect(today.map((e) => e.food.foodId), contains('egg'));
    expect(today.every((e) => e.amount > 0), isTrue);
  });

  test('parses 4 tane fındık as hazelnut', () {
    final parsed = parseNutritionInput('4 tane fındık');
    expect(parsed.unknown, isEmpty);
    expect(parsed.foods, hasLength(1));
    expect(parsed.foods.single.foodId, 'hazelnut');
    expect(parsed.foods.single.quantity, 4);
    expect(parsed.foods.single.unit, NutritionUnit.piece);
    expect(parsed.foods.single.grams, closeTo(5.6, 0.01));
    final result = analyzeNutrition('4 tane fındık', day);
    expect(result.unknownTokens, isEmpty);
    expect(result.analyzedFoods.single.foodId, 'hazelnut');
  });

  test('parses brokoli', () {
    final parsed = parseNutritionInput('brokoli');
    expect(parsed.unknown, isEmpty);
    expect(parsed.foods.single.foodId, 'broccoli');
    final portion = parseNutritionInput('1 porsiyon brokoli');
    expect(portion.foods.single.foodId, 'broccoli');
    expect(portion.foods.single.quantity, 1);
    expect(analyzeNutrition('brokoli', day).unknownTokens, isEmpty);
  });

  test('parses sucuk, soda, coffee, tea, meat, salad, vegetables', () {
    final parsed = parseNutritionInput(
      'sucuk, maden suyu/soda, filtre kahve, çay, yumurta, peynir, et, salata, sebze',
    );
    expect(
      parsed.foods.map((e) => e.foodId).toSet(),
      containsAll([
        'sucuk',
        'mineral_water',
        'coffee',
        'tea',
        'egg',
        'white_cheese',
        'red_meat',
        'salad',
        'vegetables',
      ]),
    );
    expect(parsed.unknown, isEmpty);
  });

  test('female iron RDA is higher than male at 19–50', () {
    const input = '150 gram et, 2 yumurta, sucuk';
    final male = analyzeNutrition(
      input,
      day,
      profile: const NutritionUserProfile(
        ageBand: NutritionAgeBand.y19to50,
        sex: NutritionSex.male,
      ),
    );
    final female = analyzeNutrition(
      input,
      day,
      profile: const NutritionUserProfile(
        ageBand: NutritionAgeBand.y19to50,
        sex: NutritionSex.female,
      ),
    );
    expect(female.nutrients[NutrientKey.iron]!.target, 18);
    expect(male.nutrients[NutrientKey.iron]!.target, 8);
    expect(male.nutrients[NutrientKey.vitaminK]!.referenceType, NutrientReferenceType.ai);
    expect(male.nutrients[NutrientKey.vitaminC]!.referenceType, NutrientReferenceType.rda);
    expect(
      female.nutrients[NutrientKey.iron]!.percentage,
      lessThan(male.nutrients[NutrientKey.iron]!.percentage),
    );
    expect(male.overallFillPercent, inInclusiveRange(0, 100));
  });

  test('DRI age bands use official targets', () {
    final child = resolveDriReferences(
      const NutritionUserProfile(
        ageBand: NutritionAgeBand.y4to8,
        sex: NutritionSex.male,
      ),
    );
    expect(child[NutrientKey.vitaminA]!.sex, NutritionSex.all);
    expect(child[NutrientKey.vitaminA]!.target, 400);
    expect(child[NutrientKey.vitaminD]!.target, 15);

    final older = resolveDriReferences(
      const NutritionUserProfile(
        ageBand: NutritionAgeBand.y71plus,
        sex: NutritionSex.male,
      ),
    );
    expect(older[NutrientKey.vitaminD]!.target, 20);
    expect(older[NutrientKey.calcium]!.target, 1200);

    final midFemale = resolveDriReferences(
      const NutritionUserProfile(
        ageBand: NutritionAgeBand.y51to70,
        sex: NutritionSex.female,
      ),
    );
    expect(midFemale[NutrientKey.calcium]!.target, 1200);
    expect(midFemale[NutrientKey.vitaminB6]!.target, 1.5);
    expect(midFemale[NutrientKey.iron]!.target, 8);

    final teenK = resolveDriReferences(
      const NutritionUserProfile(
        ageBand: NutritionAgeBand.y9to13,
        sex: NutritionSex.male,
      ),
    );
    expect(teenK[NutrientKey.potassium]!.target, 2500);
    expect(teenK[NutrientKey.potassium]!.sex, NutritionSex.male);

    expect(
      () => resolveDriReferences(
        const NutritionUserProfile(
          lifeStage: NutritionLifeStage.pregnancy,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('single egg is not inflated and JSON matches engine shape', () {
    final egg = analyzeNutrition('1 yumurta', day);
    expect(egg.overallFillPercent, lessThan(40));
    expect(egg.nutrients[NutrientKey.vitaminC]!.percentage, 0);
    expect(egg.analysisSummary.toLowerCase(), isNot(contains('eksikliğin var')));
    expect(
      egg.recommendations.join(' ').toLowerCase(),
      isNot(contains('kesinlikle')),
    );
    final json = egg.toJson();
    expect(json['total_fulfillment_percentage'], egg.overallFillPercent.round());
    expect(json['analysis_summary'], isA<String>());
    expect(json['vitamins_breakdown'], isA<Map>());
    expect(json['minerals_breakdown'], isA<Map>());
    expect(json['recommendations'], isA<List>());
    expect(
      (json['vitamins_breakdown'] as Map)['vitamin_c']['percentage'],
      isA<int>(),
    );
  });

  test('high vitamin C does not lift overall score above 100', () {
    final result = analyzeNutrition('100 gram brokoli', day);
    final c = result.nutrients[NutrientKey.vitaminC]!.percentage;
    expect(c, closeTo(99, 2));
    expect(result.overallFillPercent, lessThan(c));
    expect(result.overallFillPercent, lessThanOrEqualTo(100));
  });

  test('3 almonds use piece weight not a handful', () {
    final counted = analyzeNutrition('3 badem', day);
    final handful = analyzeNutrition('bir avuç badem', day);
    expect(counted.analyzedFoods.single.grams, closeTo(3.6, 0.05));
    expect(handful.analyzedFoods.single.grams, closeTo(28, 0.1));
    expect(
      counted.nutrients[NutrientKey.vitaminE]!.intake,
      lessThan(handful.nutrients[NutrientKey.vitaminE]!.intake / 4),
    );
  });

  test('macros scale with grams and stay independent of vitamin DRI', () {
    final egg100 = analyzeNutrition('100 gram yumurta', day);
    final egg50 = analyzeNutrition('50 gram yumurta', day);
    expect(egg100.macros.caloriesKcal, closeTo(155, 0.2));
    expect(egg100.macros.proteinG, closeTo(13, 0.05));
    expect(egg50.macros.caloriesKcal, closeTo(77.5, 0.2));
    expect(egg50.macros.proteinG, closeTo(egg100.macros.proteinG / 2, 0.05));
    expect(egg100.summary['nutrientCount'], 18);
    expect(egg100.nutrients[NutrientKey.vitaminC]!.percentage, 0);
    final json = egg100.toJson();
    expect(json['macros'], isA<Map>());
    expect((json['macros'] as Map)['calories_kcal'], isA<num>());
    expect((json['macros'] as Map)['protein_g'], isA<num>());
    expect((json['macros'] as Map)['sodium_mg'], isA<num>());
    final foods = json['foods'] as List;
    expect((foods.first as Map)['macros']['fat_g'], isA<num>());
  });

  test('gram restitch keeps vitamin and macro totals consistent', () {
    final a = analyzeNutrition('55 g yumurta, 60 g ekmek', day);
    final raw = foodsToRawInput(a.analyzedFoods);
    final b = analyzeNutrition(raw, day);
    expect(b.macros.caloriesKcal, closeTo(a.macros.caloriesKcal, 0.5));
    expect(
      b.nutrients[NutrientKey.vitaminA]!.intake,
      closeTo(a.nutrients[NutrientKey.vitaminA]!.intake, 0.05),
    );
  });

  test('child profile uses child RDA not adult', () {
    const child = NutritionUserProfile(
      ageBand: NutritionAgeBand.y4to8,
      sex: NutritionSex.male,
    );
    final adult = analyzeNutrition('100 gram brokoli', day);
    final kid = analyzeNutrition('100 gram brokoli', day, profile: child);
    expect(kid.nutrients[NutrientKey.vitaminC]!.target, 25);
    expect(adult.nutrients[NutrientKey.vitaminC]!.target, 90);
    expect(
      kid.nutrients[NutrientKey.vitaminC]!.percentage,
      greaterThan(adult.nutrients[NutrientKey.vitaminC]!.percentage),
    );
  });
}
