import 'package:engelsizclub/nutrition/nutrition_analyzer.dart';
import 'package:engelsizclub/nutrition/nutrition_meal_photo.dart';
import 'package:engelsizclub/nutrition/nutrition_meal_store.dart';
import 'package:engelsizclub/nutrition/nutrition_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final day = DateTime(2026, 10, 1);

  test('meal photo JSON maps into existing nutrition parser', () {
    final line = mealPhotoJsonToInput(
      '{"foods":[{"name":"yumurta","grams":100},{"name":"peynir","grams":50},{"name":"domates","grams":80},{"name":"ekmek","grams":40}]}',
    );
    expect(line, '100 g yumurta, 50 g peynir, 80 g domates, 40 g ekmek');
    final analysis = analyzeNutrition(line, day);
    expect(
      analysis.analyzedFoods.map((e) => e.foodId),
      containsAll(['egg', 'white_cheese', 'tomato', 'bread']),
    );
    expect(analysis.nutrients[NutrientKey.vitaminC]!.target, isPositive);
  });

  test('combining meals sums intake against the same DRI target', () {
    final breakfast = analyzeNutrition('2 yumurta, 50 gram peynir', day);
    final lunch = analyzeNutrition('1 portakal, 150 gram tavuk', day);
    final dayTotal = combineMealAnalyses(
      [breakfast, lunch],
      date: day,
      profile: const NutritionUserProfile(),
    );
    final key = NutrientKey.vitaminC;
    expect(
      dayTotal.nutrients[key]!.intake,
      closeTo(
        breakfast.nutrients[key]!.intake + lunch.nutrients[key]!.intake,
        0.01,
      ),
    );
    expect(
      dayTotal.nutrients[key]!.target,
      breakfast.nutrients[key]!.target,
    );
    expect(
      dayTotal.nutrients[key]!.percentage,
      closeTo(
        nutrientPercentage(
          intake: dayTotal.nutrients[key]!.intake,
          target: dayTotal.nutrients[key]!.target,
        ),
        0.01,
      ),
    );
  });

  test('local meal store keeps four slots and replacing breakfast does not duplicate', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NutritionMealStore.instance;
    await store.saveMeal(
      date: day,
      slot: NutritionMealSlot.breakfast,
      rawInput: '2 yumurta',
      fingerprint: 'a',
    );
    await store.saveMeal(
      date: day,
      slot: NutritionMealSlot.lunch,
      rawInput: '1 portakal',
    );
    await store.saveMeal(
      date: day,
      slot: NutritionMealSlot.breakfast,
      rawInput: '1 yumurta',
      fingerprint: 'b',
    );
    final meals = await store.mealsFor(day);
    expect(meals.length, 2);
    expect(meals[NutritionMealSlot.breakfast]!.rawInput, '1 yumurta');
    expect(meals[NutritionMealSlot.lunch]!.rawInput, '1 portakal');
  });

  test('photo JSON accepts food_name and estimated_weight_g', () {
    final line = mealPhotoJsonToInput(
      '{"foods":[{"food_name":"Yumurta","estimated_weight_g":55},{"name":"ekmek","grams":60}]}',
    );
    expect(line, '55 g Yumurta, 60 g ekmek');
    final analysis = analyzeNutrition(line, day);
    expect(analysis.analyzedFoods.map((e) => e.foodId), containsAll(['egg', 'bread']));
    expect(analysis.macros.caloriesKcal, greaterThan(0));
    expect(analysis.analyzedFoods.first.macros.caloriesKcal, closeTo(155 * 0.55, 0.2));
  });

  test('combining meals also sums macros without changing vitamin targets', () {
    final breakfast = analyzeNutrition('2 yumurta, 50 gram peynir', day);
    final lunch = analyzeNutrition('1 portakal, 150 gram tavuk', day);
    final dayTotal = combineMealAnalyses(
      [breakfast, lunch],
      date: day,
      profile: const NutritionUserProfile(),
    );
    expect(
      dayTotal.macros.caloriesKcal,
      closeTo(
        breakfast.macros.caloriesKcal + lunch.macros.caloriesKcal,
        0.2,
      ),
    );
    expect(
      dayTotal.macros.proteinG,
      closeTo(breakfast.macros.proteinG + lunch.macros.proteinG, 0.05),
    );
    expect(
      dayTotal.nutrients[NutrientKey.vitaminC]!.target,
      breakfast.nutrients[NutrientKey.vitaminC]!.target,
    );
  });

  test('same photo fingerprint is stable', () {
    final a = nutritionPhotoFingerprint([1, 2, 3, 4, 5]);
    final b = nutritionPhotoFingerprint([1, 2, 3, 4, 5]);
    final c = nutritionPhotoFingerprint([9, 2, 3, 4, 5]);
    expect(a, b);
    expect(a, isNot(c));
  });
}
