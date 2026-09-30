import 'package:engelsizclub/nutrition/food_dictionary.dart';
import 'package:engelsizclub/nutrition/nutrition_analyzer.dart';
import 'package:engelsizclub/nutrition/nutrition_parser.dart';
import 'package:engelsizclub/nutrition/nutrition_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DateTime(2026, 9, 29);

  List<String> ids(String input) =>
      parseNutritionInput(input).foods.map((e) => e.foodId).toList();

  test('single foods resolve to canonical ids', () {
    expect(ids('brokoli'), ['broccoli']);
    expect(ids('fındık'), ['hazelnut']);
    expect(ids('badem'), ['almond']);
    expect(ids('brokolı'), ['broccoli']);
    expect(ids('findik'), ['hazelnut']);
    expect(ids('yogurt'), ['yogurt']);
    expect(parseNutritionInput('brokoli').unknown, isEmpty);
    expect(parseNutritionInput('brokoli').foods.single.labelTr, 'Brokoli');
  });

  test('portions and natural sentences', () {
    expect(ids('100 gram brokoli'), ['broccoli']);
    expect(parseNutritionInput('100 gram brokoli').foods.single.grams, 100);
    expect(ids('1 avuç fındık'), ['hazelnut']);
    expect(parseNutritionInput('1 avuç fındık').foods.single.grams, 20);
    expect(ids('1 kase mercimek çorbası'), ['lentil_soup']);
    expect(ids('2 yumurta ve peynir'), ['egg', 'white_cheese']);
    expect(ids('brokoli ve tavuk'), ['broccoli', 'chicken']);
    expect(ids('brokoli, fındık ve muz'), ['broccoli', 'hazelnut', 'banana']);
    expect(ids('bugün brokoli yedim'), ['broccoli']);
    expect(
      ids('sabah iki yumurta, peynir ve domates yedim'),
      ['egg', 'white_cheese', 'tomato'],
    );
    expect(
      ids('öğlen tavuk, brokoli ve ayran yedim'),
      ['chicken', 'broccoli', 'ayran'],
    );
    expect(
      ids('akşam bir kase mercimek çorbası ve bir avuç fındık yedim'),
      ['lentil_soup', 'hazelnut'],
    );
  });

  test('unknown tokens do not cancel recognized foods', () {
    final parsed = parseNutritionInput('Bugün brokoli, fındık ve xyzabc yedim');
    expect(parsed.foods.map((e) => e.foodId), ['broccoli', 'hazelnut']);
    expect(parsed.unknown, isNotEmpty);
    final result = analyzeNutrition(
      'Bugün brokoli, fındık ve xyzabc yedim',
      day,
    );
    expect(result.analyzedFoods.map((e) => e.foodId), ['broccoli', 'hazelnut']);
    expect(result.unknownTokens, isNotEmpty);
  });

  test('broccoli nutrients match 100 g database values', () {
    final result = analyzeNutrition('100 gram brokoli', day);
    expect(result.unknownTokens, isEmpty);
    expect(result.nutrients[NutrientKey.vitaminC]!.intake, closeTo(89, 0.01));
    expect(result.nutrients[NutrientKey.vitaminK]!.intake, closeTo(102, 0.01));
  });

  test('typos and turkish numbers', () {
    expect(ids('brocoli'), ['broccoli']);
    expect(ids('brokolii'), ['broccoli']);
    expect(ids('yogur'), ['yogurt']);
    expect(ids('iki yumurta'), ['egg']);
    expect(ids('üç dilim peynir'), ['white_cheese']);
    expect(ids('beş zeytin'), ['olive']);
  });

  test('dictionary ids are unique', () {
    final ids = kFoodDictionary.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
