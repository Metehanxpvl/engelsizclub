import 'food_catalog.dart';
import 'nutrient_references.dart';
import 'nutrition_parser.dart';
import 'nutrition_types.dart';

NutritionConfidence nutritionConfidence({
  required int parsed,
  required int withPortion,
  required int unknown,
}) {
  if (parsed <= 0) return NutritionConfidence.low;
  final ratio = withPortion / parsed;
  if (ratio >= 0.75 && unknown <= 1 && parsed >= 2) {
    return NutritionConfidence.high;
  }
  if (ratio >= 0.4) return NutritionConfidence.medium;
  return NutritionConfidence.low;
}

double nutrientPercentage({required double intake, required double target}) {
  if (target <= 0) return 0;
  return (intake / target) * 100;
}

/// Kural tabanlı analiz. Hedefler IOM/NIH DRI tablosundan gelir.
NutritionAnalysis analyzeNutrition(
  String input,
  DateTime date, {
  NutritionUserProfile profile = const NutritionUserProfile(),
}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    throw StateError('Lütfen bugün tükettiğin yiyecek ve içecekleri yaz.');
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day.isAfter(today)) {
    throw StateError('Gelecek bir tarih seçilemez.');
  }
  final parsed = parseNutritionInput(trimmed);
  if (parsed.foods.isEmpty) {
    throw StateError('Bu girişte analiz edilebilecek bir gıda bulunamadı.');
  }

  var total = NutrientAmounts.zero();
  for (final item in parsed.foods) {
    final food = foodById(item.foodId);
    if (food == null) continue;
    total += food.per100g.scaledGrams(item.grams);
  }

  final refs = resolveDriReferences(profile);
  final nutrients = <NutrientKey, NutrientStat>{};
  for (final key in NutrientKey.values) {
    final ref = refs[key]!;
    final intake = total[key];
    nutrients[key] = NutrientStat(
      key: key,
      intake: intake,
      target: ref.target,
      percentage: nutrientPercentage(intake: intake, target: ref.target),
      unit: ref.unit,
      referenceType: ref.referenceType,
      upperLimit: ref.upperLimit,
    );
  }

  final withPortion =
      parsed.foods.where((e) => e.portionSpecified).length;

  return NutritionAnalysis(
    nutrients: nutrients,
    analyzedFoods: parsed.foods,
    confidence: nutritionConfidence(
      parsed: parsed.foods.length,
      withPortion: withPortion,
      unknown: parsed.unknown.length,
    ),
    unknownTokens: parsed.unknown,
    date: day,
    rawInput: trimmed,
    profile: profile,
  );
}
