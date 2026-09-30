import 'food_dictionary.dart';
import 'nutrition_types.dart';

/// Gıda id -> 100 g besin değerleri. Parser bu haritayı kullanmaz.
final kNutritionDatabase = Map<String, NutrientAmounts>.unmodifiable({
  'egg': n(
    a: 160, d: 2.2, e: 1.1, b2: 0.46, b12: 0.89, folate: 47,
    ca: 56, fe: 1.8, zn: 1.3, k: 138, i: 50, se: 30, b6: 0.17,
  ),
  'white_cheese': n(
    a: 150, b2: 0.4, b12: 1.1, ca: 500, zn: 2.2, k: 90, i: 20, se: 12,
  ),
  'olive': n(e: 3.8, vk: 1.4, fe: 3.3, ca: 88, k: 42),
  'bread': n(b1: 0.2, b3: 2.5, folate: 40, fe: 1.8, mg: 30, zn: 0.8, k: 130, se: 18),
  'lentil_soup': n(b1: 0.12, folate: 45, fe: 1.6, mg: 18, zn: 0.8, k: 180, a: 40),
  'salad': n(a: 250, c: 18, vk: 80, folate: 40, k: 220, mg: 15),
  'chicken': n(b3: 12, b6: 0.6, b12: 0.3, fe: 0.7, zn: 1.0, se: 22, k: 250, mg: 25),
  'ayran': n(b2: 0.16, b12: 0.25, ca: 110, k: 140, i: 12, zn: 0.4),
  'almond': n(e: 25, b2: 1.1, mg: 270, zn: 3.1, ca: 269, k: 733, fe: 3.7),
  'banana': n(b6: 0.37, c: 8.7, k: 358, mg: 27, folate: 20),
  'milk': n(a: 46, b2: 0.18, b12: 0.45, d: 0.1, ca: 120, k: 150, i: 15),
  'yogurt': n(b2: 0.14, b12: 0.4, ca: 110, k: 155, zn: 0.5, i: 10),
  'rice': n(b1: 0.02, b3: 0.4, mg: 12, k: 35, se: 7),
  'tomato': n(a: 42, c: 14, k: 237, vk: 7.9, folate: 15),
  'spinach': n(a: 469, c: 28, vk: 483, folate: 194, fe: 2.7, mg: 79, k: 558, ca: 99),
  'broccoli': n(
    a: 31, c: 89, vk: 102, b6: 0.18, folate: 63, ca: 47, fe: 0.7, mg: 21, k: 316, e: 0.8,
  ),
  'orange': n(c: 53, folate: 30, k: 181, a: 11),
  'apple': n(c: 4.6, k: 107, vk: 2.2),
  'red_meat': n(b3: 6, b6: 0.4, b12: 2.0, fe: 2.6, zn: 4.5, se: 20, k: 318),
  'fish': n(d: 8, b12: 3.2, b3: 7, i: 40, se: 36, k: 350, zn: 0.6),
  'chickpea': n(folate: 172, fe: 2.9, mg: 48, zn: 1.5, k: 291, b6: 0.14),
  'olive_oil': n(e: 14, vk: 60),
  'walnut': n(e: 0.7, b6: 0.5, mg: 158, zn: 3.1, k: 441, folate: 98),
  'hazelnut': n(
    e: 15, c: 6.3, vk: 14, b1: 0.64, b2: 0.11, b3: 1.8, b6: 0.56,
    folate: 113, ca: 114, fe: 4.7, mg: 163, zn: 2.5, k: 680, se: 2.4,
  ),
  'cucumber': n(vk: 16, c: 2.8, k: 147),
  'potato': n(c: 19, b6: 0.3, k: 425, mg: 23, folate: 15),
  'sucuk': n(b1: 0.25, b3: 4.5, b6: 0.25, b12: 1.2, fe: 2.4, zn: 3.2, se: 18, k: 280, b2: 0.18),
  'mineral_water': n(ca: 15, mg: 10, k: 5),
  'soda_drink': n(k: 2),
  'coffee': n(b3: 0.5, k: 90, mg: 8),
  'tea': n(k: 18, mg: 3, folate: 1),
  'vegetables': n(a: 180, c: 22, vk: 40, folate: 35, k: 250, mg: 18, fe: 0.8),
  'carrot': n(a: 835, c: 5.9, vk: 13, k: 320, b6: 0.14),
  'pepper': n(c: 128, a: 157, vk: 7, b6: 0.29, folate: 46, k: 211),
  'cauliflower': n(c: 48, vk: 15, folate: 57, b6: 0.18, k: 299),
  'strawberry': n(c: 59, folate: 24, k: 153, vk: 2.2),
  'avocado': n(e: 2.1, vk: 21, folate: 81, k: 485, mg: 29, b6: 0.26),
  'cashew': n(e: 0.9, mg: 292, zn: 5.8, fe: 6.7, k: 660, b1: 0.42),
  'pistachio': n(b6: 1.7, e: 2.3, k: 1025, fe: 3.9, mg: 121),
  'peanut': n(b3: 12, e: 8.3, mg: 168, folate: 240, k: 705),
  'oats': n(b1: 0.76, fe: 4.7, mg: 177, zn: 4, k: 429, folate: 56),
  'lentils': n(folate: 181, fe: 3.3, mg: 36, zn: 1.3, k: 369, b1: 0.17),
  'honey': n(c: 0.5, k: 52, b2: 0.04),
});

final kCategoryNutrition = Map<FoodCategory, NutrientAmounts>.unmodifiable({
  FoodCategory.vegetable: n(a: 120, c: 20, vk: 40, folate: 30, k: 250, mg: 18, fe: 0.7),
  FoodCategory.fruit: n(c: 25, k: 180, folate: 15, a: 20),
  FoodCategory.nut: n(e: 8, mg: 150, zn: 2.5, k: 500, fe: 3, folate: 50),
  FoodCategory.dairy: n(ca: 120, b2: 0.16, b12: 0.4, k: 150, i: 12),
  FoodCategory.meat: n(b3: 6, b6: 0.4, b12: 1.2, fe: 1.8, zn: 2.5, k: 300, se: 18),
  FoodCategory.egg: n(a: 160, d: 2.2, b12: 0.89, ca: 56, fe: 1.8),
  FoodCategory.legume: n(folate: 140, fe: 2.5, mg: 40, zn: 1.3, k: 300, b1: 0.15),
  FoodCategory.grain: n(b1: 0.15, b3: 1.2, fe: 1.2, mg: 25, k: 120, se: 10),
  FoodCategory.soup: n(a: 40, folate: 25, fe: 1.0, k: 160, mg: 12),
  FoodCategory.dish: n(a: 80, c: 10, folate: 30, fe: 1.2, k: 200, mg: 18),
  FoodCategory.oil: n(e: 12, vk: 40),
  FoodCategory.snack: n(e: 1, fe: 1.2, k: 150, mg: 20),
  FoodCategory.sweet: n(ca: 40, k: 80, b2: 0.08),
  FoodCategory.drink: n(k: 20, mg: 5),
  FoodCategory.other: n(k: 50),
});

NutrientAmounts n({
  double a = 0,
  double c = 0,
  double d = 0,
  double e = 0,
  double vk = 0,
  double b1 = 0,
  double b2 = 0,
  double b3 = 0,
  double b6 = 0,
  double folate = 0,
  double b12 = 0,
  double ca = 0,
  double fe = 0,
  double mg = 0,
  double zn = 0,
  double k = 0,
  double i = 0,
  double se = 0,
}) {
  return NutrientAmounts.per100g(
    vitaminA: a,
    vitaminC: c,
    vitaminD: d,
    vitaminE: e,
    vitaminK: vk,
    vitaminB1: b1,
    vitaminB2: b2,
    vitaminB3: b3,
    vitaminB6: b6,
    folate: folate,
    vitaminB12: b12,
    calcium: ca,
    iron: fe,
    magnesium: mg,
    zinc: zn,
    potassium: k,
    iodine: i,
    selenium: se,
  );
}

NutrientAmounts nutritionAmountsFor(FoodDictionaryEntry entry) {
  return kNutritionDatabase[entry.id] ??
      kCategoryNutrition[entry.category] ??
      NutrientAmounts.zero();
}
