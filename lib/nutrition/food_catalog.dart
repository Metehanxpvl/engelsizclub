import 'food_dictionary.dart';
import 'nutrition_database.dart';
import 'nutrition_types.dart';

class FoodItem {
  const FoodItem({
    required this.id,
    required this.labelTr,
    required this.emoji,
    required this.aliases,
    required this.gramsPerPiece,
    required this.per100g,
    this.liquid = false,
  });

  final String id;
  final String labelTr;
  final String emoji;
  final List<String> aliases;
  final double gramsPerPiece;
  final NutrientAmounts per100g;
  final bool liquid;
}

FoodItem _toItem(FoodDictionaryEntry e) {
  return FoodItem(
    id: e.id,
    labelTr: e.canonicalName,
    emoji: e.emoji,
    aliases: e.aliases,
    gramsPerPiece: e.defaultServingGrams,
    per100g: nutritionAmountsFor(e),
    liquid: e.liquid,
  );
}

/// Sözlük + besin DB birleşimi. Bir kez üretilir.
final kNutritionFoodCatalog = List<FoodItem>.unmodifiable([
  for (final e in kFoodDictionary) _toItem(e),
]);

final _catalogById = <String, FoodItem>{
  for (final e in kNutritionFoodCatalog) e.id: e,
};

const _kNutrientPresent = 0.01;

List<FoodItem> catalogFoodsForNutrient(NutrientKey key, {int limit = 8}) {
  final list = kNutritionFoodCatalog
      .where((e) => e.per100g[key] >= _kNutrientPresent)
      .toList()
    ..sort((a, b) => b.per100g[key].compareTo(a.per100g[key]));
  if (list.length <= limit) return list;
  return list.take(limit).toList();
}

FoodItem? foodById(String id) => _catalogById[id];

class TodayNutrientFood {
  const TodayNutrientFood({
    required this.food,
    required this.amount,
  });
  final ParsedFood food;
  final double amount;
}

List<TodayNutrientFood> todayFoodsForNutrient(
  List<ParsedFood> foods,
  NutrientKey key,
) {
  final out = <TodayNutrientFood>[];
  for (final item in foods) {
    final cat = foodById(item.foodId);
    if (cat == null) continue;
    final amount = cat.per100g.scaledGrams(item.grams)[key];
    if (amount < _kNutrientPresent) continue;
    out.add(TodayNutrientFood(food: item, amount: amount));
  }
  out.sort((a, b) => b.amount.compareTo(a.amount));
  return out;
}
