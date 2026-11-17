import 'nutrition_types.dart';

/// NIH ODS / IOM DRI (RDA veya AI). Hamilelik ve emzirme satırları henüz yok.
class DriNutrientReference {
  const DriNutrientReference({
    required this.nutrient,
    required this.ageMin,
    required this.sex,
    required this.target,
    required this.unit,
    required this.referenceType,
    required this.lifeStage,
    this.ageMax,
    this.upperLimit,
    this.upperLimitUnit,
  });

  final NutrientKey nutrient;
  final int ageMin;
  final int? ageMax;
  final NutritionSex sex;
  final double target;
  final String unit;
  final NutrientReferenceType referenceType;
  final double? upperLimit;
  final String? upperLimitUnit;
  final NutritionLifeStage lifeStage;

  String get foodSources => kNutrientFoodSources[nutrient] ?? '';

  bool coversAge(int age) {
    if (age < ageMin) return false;
    if (ageMax == null) return true;
    return age <= ageMax!;
  }
}

/// Eski çağrılar için sade görünüm (19–50 erkek).
class NutrientReference {
  const NutrientReference({
    required this.target,
    required this.foodSources,
    required this.referenceType,
    this.upperLimit,
  });

  final double target;
  final String foodSources;
  final NutrientReferenceType referenceType;
  final double? upperLimit;
}

const kAdultNutritionProfileId = 'y19to50_male_standard';

const kNutrientFoodSources = <NutrientKey, String>{
  NutrientKey.vitaminA:
      'karaciğer, havuç, tatlı patates, ıspanak ve koyu yeşil yapraklı sebzeler.',
  NutrientKey.vitaminC: 'portakal, kivi, biber, çilek ve brokoli.',
  NutrientKey.vitaminD:
      'yağlı balıklar, yumurta sarısı ve D vitamini ile zenginleştirilmiş ürünler.',
  NutrientKey.vitaminE: 'badem, ayçiçek yağı, fındık ve avokado.',
  NutrientKey.vitaminK:
      'ıspanak, brokoli, lahana ve diğer yeşil yapraklı sebzeler.',
  NutrientKey.vitaminB1: 'tam tahıllar, baklagiller ve ayçiçek çekirdeği.',
  NutrientKey.vitaminB2: 'süt ürünleri, yumurta ve badem.',
  NutrientKey.vitaminB3: 'tavuk, hindi, sucuk, yer fıstığı ve tam tahıllar.',
  NutrientKey.vitaminB6: 'tavuk, muz, patates ve nohut.',
  NutrientKey.folate:
      'yeşil yapraklılar, baklagiller ve zenginleştirilmiş tahıllar.',
  NutrientKey.vitaminB12: 'yumurta, süt ürünleri, et, sucuk ve balık.',
  NutrientKey.calcium:
      'süt, yoğurt, peynir, maden suyu ve koyu yeşil yapraklılar.',
  NutrientKey.iron: 'kırmızı et, sucuk, baklagiller, yumurta ve kuru meyve.',
  NutrientKey.magnesium: 'badem, ıspanak, baklagiller, kahve ve tam tahıllar.',
  NutrientKey.zinc: 'et, sucuk, kabak çekirdeği, baklagiller ve süt ürünleri.',
  NutrientKey.potassium: 'muz, patates, yoğurt, kahve ve baklagiller.',
  NutrientKey.iodine: 'iyotlu tuz, deniz ürünleri ve süt ürünleri.',
  NutrientKey.selenium: 'yumurta, balık, et ve Brezilya cevizi.',
};

NutrientReferenceType _typeOf(NutrientKey key) {
  if (key == NutrientKey.vitaminK || key == NutrientKey.potassium) {
    return NutrientReferenceType.ai;
  }
  return NutrientReferenceType.rda;
}

double? _ul(NutrientKey key, int ageMin) {
  bool a(int min) => ageMin >= min;
  switch (key) {
    case NutrientKey.vitaminA:
      if (ageMin <= 3) return 600;
      if (ageMin <= 8) return 900;
      if (ageMin <= 13) return 1700;
      if (ageMin <= 18) return 2800;
      return 3000;
    case NutrientKey.vitaminC:
      if (ageMin <= 3) return 400;
      if (ageMin <= 8) return 650;
      if (ageMin <= 13) return 1200;
      if (ageMin <= 18) return 1800;
      return 2000;
    case NutrientKey.vitaminD:
      if (ageMin <= 3) return 63;
      if (ageMin <= 8) return 75;
      return 100;
    case NutrientKey.vitaminE:
      if (ageMin <= 3) return 200;
      if (ageMin <= 8) return 300;
      if (ageMin <= 13) return 600;
      if (ageMin <= 18) return 800;
      return 1000;
    case NutrientKey.vitaminB6:
      if (ageMin <= 8) return 30;
      if (ageMin <= 13) return 40;
      if (ageMin <= 18) return 60;
      return 100;
    case NutrientKey.folate:
      if (ageMin <= 3) return 300;
      if (ageMin <= 8) return 400;
      if (ageMin <= 13) return 600;
      if (ageMin <= 18) return 800;
      return 1000;
    case NutrientKey.calcium:
      if (ageMin <= 8) return 2500;
      if (ageMin <= 18) return 3000;
      if (a(51)) return 2000;
      return 2500;
    case NutrientKey.iron:
      return ageMin <= 13 ? 40 : 45;
    case NutrientKey.zinc:
      if (ageMin <= 3) return 7;
      if (ageMin <= 8) return 12;
      if (ageMin <= 13) return 23;
      if (ageMin <= 18) return 34;
      return 40;
    case NutrientKey.iodine:
      if (ageMin <= 3) return 200;
      if (ageMin <= 8) return 300;
      if (ageMin <= 13) return 600;
      if (ageMin <= 18) return 900;
      return 1100;
    case NutrientKey.selenium:
      if (ageMin <= 3) return 90;
      if (ageMin <= 8) return 150;
      if (ageMin <= 13) return 280;
      return 400;
    default:
      return null;
  }
}

DriNutrientReference _dri({
  required NutrientKey nutrient,
  required int ageMin,
  required int? ageMax,
  required NutritionSex sex,
  required double target,
}) {
  final ul = _ul(nutrient, ageMin);
  return DriNutrientReference(
    nutrient: nutrient,
    ageMin: ageMin,
    ageMax: ageMax,
    sex: sex,
    target: target,
    unit: nutrient.unit,
    referenceType: _typeOf(nutrient),
    upperLimit: ul,
    upperLimitUnit: ul == null ? null : nutrient.unit,
    lifeStage: NutritionLifeStage.standard,
  );
}

List<DriNutrientReference> _pack({
  required int ageMin,
  required int? ageMax,
  required NutritionSex sex,
  required double vitaminA,
  required double vitaminC,
  required double vitaminD,
  required double vitaminE,
  required double vitaminK,
  required double vitaminB1,
  required double vitaminB2,
  required double vitaminB3,
  required double vitaminB6,
  required double folate,
  required double vitaminB12,
  required double calcium,
  required double iron,
  required double magnesium,
  required double zinc,
  required double potassium,
  required double iodine,
  required double selenium,
}) {
  const keys = NutrientKey.values;
  final targets = <NutrientKey, double>{
    NutrientKey.vitaminA: vitaminA,
    NutrientKey.vitaminC: vitaminC,
    NutrientKey.vitaminD: vitaminD,
    NutrientKey.vitaminE: vitaminE,
    NutrientKey.vitaminK: vitaminK,
    NutrientKey.vitaminB1: vitaminB1,
    NutrientKey.vitaminB2: vitaminB2,
    NutrientKey.vitaminB3: vitaminB3,
    NutrientKey.vitaminB6: vitaminB6,
    NutrientKey.folate: folate,
    NutrientKey.vitaminB12: vitaminB12,
    NutrientKey.calcium: calcium,
    NutrientKey.iron: iron,
    NutrientKey.magnesium: magnesium,
    NutrientKey.zinc: zinc,
    NutrientKey.potassium: potassium,
    NutrientKey.iodine: iodine,
    NutrientKey.selenium: selenium,
  };
  return [
    for (final k in keys)
      _dri(
        nutrient: k,
        ageMin: ageMin,
        ageMax: ageMax,
        sex: sex,
        target: targets[k]!,
      ),
  ];
}

/// IOM/NIH DRI satırları. Tahmin yok; 9–13 potasyum cinsiyete göre ayrı.
final List<DriNutrientReference> kDriNutrientReferences = [
  // 1–3, sex: all
  ..._pack(
    ageMin: 1,
    ageMax: 3,
    sex: NutritionSex.all,
    vitaminA: 300,
    vitaminC: 15,
    vitaminD: 15,
    vitaminE: 6,
    vitaminK: 30,
    vitaminB1: 0.5,
    vitaminB2: 0.5,
    vitaminB3: 6,
    vitaminB6: 0.5,
    folate: 150,
    vitaminB12: 0.9,
    calcium: 700,
    iron: 7,
    magnesium: 80,
    zinc: 3,
    potassium: 2000,
    iodine: 90,
    selenium: 20,
  ),
  // 4–8, sex: all
  ..._pack(
    ageMin: 4,
    ageMax: 8,
    sex: NutritionSex.all,
    vitaminA: 400,
    vitaminC: 25,
    vitaminD: 15,
    vitaminE: 7,
    vitaminK: 55,
    vitaminB1: 0.6,
    vitaminB2: 0.6,
    vitaminB3: 8,
    vitaminB6: 0.6,
    folate: 200,
    vitaminB12: 1.2,
    calcium: 1000,
    iron: 10,
    magnesium: 130,
    zinc: 5,
    potassium: 2300,
    iodine: 90,
    selenium: 30,
  ),
  // 9–13 cinsiyetsiz vitamin/mineraller (potasyum hariç)
  ..._pack(
    ageMin: 9,
    ageMax: 13,
    sex: NutritionSex.all,
    vitaminA: 600,
    vitaminC: 45,
    vitaminD: 15,
    vitaminE: 11,
    vitaminK: 60,
    vitaminB1: 0.9,
    vitaminB2: 0.9,
    vitaminB3: 12,
    vitaminB6: 1.0,
    folate: 300,
    vitaminB12: 1.8,
    calcium: 1300,
    iron: 8,
    magnesium: 240,
    zinc: 8,
    potassium: 2300,
    iodine: 120,
    selenium: 40,
  ),
  _dri(
    nutrient: NutrientKey.potassium,
    ageMin: 9,
    ageMax: 13,
    sex: NutritionSex.male,
    target: 2500,
  ),
  _dri(
    nutrient: NutrientKey.potassium,
    ageMin: 9,
    ageMax: 13,
    sex: NutritionSex.female,
    target: 2300,
  ),
  // 14–18 erkek
  ..._pack(
    ageMin: 14,
    ageMax: 18,
    sex: NutritionSex.male,
    vitaminA: 900,
    vitaminC: 75,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 75,
    vitaminB1: 1.2,
    vitaminB2: 1.3,
    vitaminB3: 16,
    vitaminB6: 1.3,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1300,
    iron: 11,
    magnesium: 410,
    zinc: 11,
    potassium: 3000,
    iodine: 150,
    selenium: 55,
  ),
  // 14–18 kadın
  ..._pack(
    ageMin: 14,
    ageMax: 18,
    sex: NutritionSex.female,
    vitaminA: 700,
    vitaminC: 65,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 75,
    vitaminB1: 1.0,
    vitaminB2: 1.0,
    vitaminB3: 14,
    vitaminB6: 1.2,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1300,
    iron: 15,
    magnesium: 360,
    zinc: 9,
    potassium: 2300,
    iodine: 150,
    selenium: 55,
  ),
  // 19–50 erkek (NIH/IOM)
  ..._pack(
    ageMin: 19,
    ageMax: 50,
    sex: NutritionSex.male,
    vitaminA: 900,
    vitaminC: 90,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 120,
    vitaminB1: 1.2,
    vitaminB2: 1.3,
    vitaminB3: 16,
    vitaminB6: 1.3,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1000,
    iron: 8,
    magnesium: 420,
    zinc: 11,
    potassium: 3400,
    iodine: 150,
    selenium: 55,
  ),
  // 19–50 kadın
  ..._pack(
    ageMin: 19,
    ageMax: 50,
    sex: NutritionSex.female,
    vitaminA: 700,
    vitaminC: 75,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 90,
    vitaminB1: 1.1,
    vitaminB2: 1.1,
    vitaminB3: 14,
    vitaminB6: 1.3,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1000,
    iron: 18,
    magnesium: 320,
    zinc: 8,
    potassium: 2600,
    iodine: 150,
    selenium: 55,
  ),
  // 51–70 erkek — B6 1.7, Ca 1000, D 15
  ..._pack(
    ageMin: 51,
    ageMax: 70,
    sex: NutritionSex.male,
    vitaminA: 900,
    vitaminC: 90,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 120,
    vitaminB1: 1.2,
    vitaminB2: 1.3,
    vitaminB3: 16,
    vitaminB6: 1.7,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1000,
    iron: 8,
    magnesium: 420,
    zinc: 11,
    potassium: 3400,
    iodine: 150,
    selenium: 55,
  ),
  // 51–70 kadın — B6 1.5, Ca 1200, demir 8
  ..._pack(
    ageMin: 51,
    ageMax: 70,
    sex: NutritionSex.female,
    vitaminA: 700,
    vitaminC: 75,
    vitaminD: 15,
    vitaminE: 15,
    vitaminK: 90,
    vitaminB1: 1.1,
    vitaminB2: 1.1,
    vitaminB3: 14,
    vitaminB6: 1.5,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1200,
    iron: 8,
    magnesium: 320,
    zinc: 8,
    potassium: 2600,
    iodine: 150,
    selenium: 55,
  ),
  // 71+ erkek — D 20, Ca 1200
  ..._pack(
    ageMin: 71,
    ageMax: null,
    sex: NutritionSex.male,
    vitaminA: 900,
    vitaminC: 90,
    vitaminD: 20,
    vitaminE: 15,
    vitaminK: 120,
    vitaminB1: 1.2,
    vitaminB2: 1.3,
    vitaminB3: 16,
    vitaminB6: 1.7,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1200,
    iron: 8,
    magnesium: 420,
    zinc: 11,
    potassium: 3400,
    iodine: 150,
    selenium: 55,
  ),
  // 71+ kadın — D 20, Ca 1200
  ..._pack(
    ageMin: 71,
    ageMax: null,
    sex: NutritionSex.female,
    vitaminA: 700,
    vitaminC: 75,
    vitaminD: 20,
    vitaminE: 15,
    vitaminK: 90,
    vitaminB1: 1.1,
    vitaminB2: 1.1,
    vitaminB3: 14,
    vitaminB6: 1.5,
    folate: 400,
    vitaminB12: 2.4,
    calcium: 1200,
    iron: 8,
    magnesium: 320,
    zinc: 8,
    potassium: 2600,
    iodine: 150,
    selenium: 55,
  ),
];

DriNutrientReference? _pickRow({
  required NutrientKey key,
  required int age,
  required NutritionSex sex,
  required NutritionLifeStage lifeStage,
}) {
  final rows = kDriNutrientReferences
      .where(
        (r) =>
            r.nutrient == key &&
            r.lifeStage == lifeStage &&
            r.coversAge(age),
      )
      .toList();
  if (rows.isEmpty) return null;
  DriNutrientReference? exact;
  DriNutrientReference? any;
  for (final r in rows) {
    if (r.sex == sex) exact = r;
    if (r.sex == NutritionSex.all) any = r;
  }
  return exact ?? any ?? rows.first;
}

Map<NutrientKey, DriNutrientReference> resolveDriReferences(
  NutritionUserProfile profile,
) {
  if (profile.lifeStage != NutritionLifeStage.standard) {
    throw StateError(
      'Hamilelik ve emzirme referansları henüz açık değil; standart profil kullanın.',
    );
  }
  final age = profile.ageBand.representativeAge;
  final sex = profile.effectiveSex;
  final out = <NutrientKey, DriNutrientReference>{};
  for (final key in NutrientKey.values) {
    final row = _pickRow(
      key: key,
      age: age,
      sex: sex,
      lifeStage: NutritionLifeStage.standard,
    );
    if (row == null) {
      throw StateError('DRI satırı bulunamadı: ${key.driId}');
    }
    out[key] = row;
  }
  return out;
}

/// 19–50 erkek — kaynak metinleri ve eski çağrılar.
Map<NutrientKey, NutrientReference> get kAdultNutrientReferences {
  final rows = resolveDriReferences(NutritionUserProfile.adultMale);
  return {
    for (final e in rows.entries)
      e.key: NutrientReference(
        target: e.value.target,
        foodSources: e.value.foodSources,
        referenceType: e.value.referenceType,
        upperLimit: e.value.upperLimit,
      ),
  };
}

Map<NutrientKey, NutrientReference> nutrientReferencesFor(
  NutritionUserProfile profile,
) {
  final rows = resolveDriReferences(profile);
  return {
    for (final e in rows.entries)
      e.key: NutrientReference(
        target: e.value.target,
        foodSources: e.value.foodSources,
        referenceType: e.value.referenceType,
        upperLimit: e.value.upperLimit,
      ),
  };
}
