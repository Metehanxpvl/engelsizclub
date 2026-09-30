// Günlük vitamin & mineral karnesi — domain tipleri.

enum NutrientGroup { vitamin, mineral }

enum NutrientKey {
  vitaminA,
  vitaminC,
  vitaminD,
  vitaminE,
  vitaminK,
  vitaminB1,
  vitaminB2,
  vitaminB3,
  vitaminB6,
  folate,
  vitaminB12,
  calcium,
  iron,
  magnesium,
  zinc,
  potassium,
  iodine,
  selenium,
}

extension NutrientKeyX on NutrientKey {
  NutrientGroup get group => index < 11 ? NutrientGroup.vitamin : NutrientGroup.mineral;

  String get labelTr => switch (this) {
        NutrientKey.vitaminA => 'Vitamin A',
        NutrientKey.vitaminC => 'Vitamin C',
        NutrientKey.vitaminD => 'Vitamin D',
        NutrientKey.vitaminE => 'Vitamin E',
        NutrientKey.vitaminK => 'Vitamin K',
        NutrientKey.vitaminB1 => 'Vitamin B1 – Tiamin',
        NutrientKey.vitaminB2 => 'Vitamin B2 – Riboflavin',
        NutrientKey.vitaminB3 => 'Vitamin B3 – Niasin',
        NutrientKey.vitaminB6 => 'Vitamin B6',
        NutrientKey.folate => 'Vitamin B9 – Folat',
        NutrientKey.vitaminB12 => 'Vitamin B12',
        NutrientKey.calcium => 'Kalsiyum',
        NutrientKey.iron => 'Demir',
        NutrientKey.magnesium => 'Magnezyum',
        NutrientKey.zinc => 'Çinko',
        NutrientKey.potassium => 'Potasyum',
        NutrientKey.iodine => 'İyot',
        NutrientKey.selenium => 'Selenyum',
      };

  String get unit => switch (this) {
        NutrientKey.vitaminA ||
        NutrientKey.vitaminK ||
        NutrientKey.folate ||
        NutrientKey.iodine ||
        NutrientKey.selenium =>
          'µg',
        NutrientKey.vitaminD || NutrientKey.vitaminB12 => 'µg',
        _ => 'mg',
      };

  String get shortLabelTr => switch (this) {
        NutrientKey.vitaminB1 => 'B1',
        NutrientKey.vitaminB2 => 'B2',
        NutrientKey.vitaminB3 => 'B3',
        NutrientKey.vitaminB6 => 'B6',
        NutrientKey.folate => 'Folat',
        NutrientKey.vitaminB12 => 'B12',
        _ => labelTr,
      };

  String get driId => switch (this) {
        NutrientKey.vitaminA => 'vitamin_a',
        NutrientKey.vitaminC => 'vitamin_c',
        NutrientKey.vitaminD => 'vitamin_d',
        NutrientKey.vitaminE => 'vitamin_e',
        NutrientKey.vitaminK => 'vitamin_k',
        NutrientKey.vitaminB1 => 'thiamin',
        NutrientKey.vitaminB2 => 'riboflavin',
        NutrientKey.vitaminB3 => 'niacin',
        NutrientKey.vitaminB6 => 'vitamin_b6',
        NutrientKey.folate => 'folate',
        NutrientKey.vitaminB12 => 'vitamin_b12',
        NutrientKey.calcium => 'calcium',
        NutrientKey.iron => 'iron',
        NutrientKey.magnesium => 'magnesium',
        NutrientKey.zinc => 'zinc',
        NutrientKey.potassium => 'potassium',
        NutrientKey.iodine => 'iodine',
        NutrientKey.selenium => 'selenium',
      };

  String get id => driId;
}

enum NutritionUnit { piece, g, ml, unknown }

enum NutritionConfidence { low, medium, high }

extension NutritionConfidenceX on NutritionConfidence {
  String get labelTr => switch (this) {
        NutritionConfidence.high => 'Yüksek',
        NutritionConfidence.medium => 'Orta',
        NutritionConfidence.low => 'Düşük',
      };
}

class NutrientAmounts {
  const NutrientAmounts(this.values);

  factory NutrientAmounts.zero() =>
      NutrientAmounts({for (final k in NutrientKey.values) k: 0});

  factory NutrientAmounts.per100g({
    double vitaminA = 0,
    double vitaminC = 0,
    double vitaminD = 0,
    double vitaminE = 0,
    double vitaminK = 0,
    double vitaminB1 = 0,
    double vitaminB2 = 0,
    double vitaminB3 = 0,
    double vitaminB6 = 0,
    double folate = 0,
    double vitaminB12 = 0,
    double calcium = 0,
    double iron = 0,
    double magnesium = 0,
    double zinc = 0,
    double potassium = 0,
    double iodine = 0,
    double selenium = 0,
  }) {
    return NutrientAmounts({
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
    });
  }

  final Map<NutrientKey, double> values;

  double operator [](NutrientKey k) => values[k] ?? 0;

  NutrientAmounts operator +(NutrientAmounts o) {
    return NutrientAmounts({
      for (final k in NutrientKey.values) k: this[k] + o[k],
    });
  }

  /// [grams] kadar tüketim; profil 100 g içindir.
  NutrientAmounts scaledGrams(double grams) {
    final f = grams / 100.0;
    return NutrientAmounts({
      for (final k in NutrientKey.values) k: this[k] * f,
    });
  }
}

class NutrientStat {
  const NutrientStat({
    required this.key,
    required this.intake,
    required this.target,
    required this.percentage,
    required this.unit,
    this.referenceType = NutrientReferenceType.rda,
    this.upperLimit,
  });

  final NutrientKey key;
  final double intake;
  final double target;
  final double percentage;
  final String unit;
  final NutrientReferenceType referenceType;
  final double? upperLimit;

  bool get inTargetBand => percentage >= 80 && percentage <= 120;

  Map<String, dynamic> toJson() => {
        'intake': intake,
        'target': target,
        'percentage': percentage,
        'unit': unit,
        'referenceType': referenceType.name,
        if (upperLimit != null) 'upperLimit': upperLimit,
      };
}

class ParsedFood {
  const ParsedFood({
    required this.foodId,
    required this.labelTr,
    required this.emoji,
    required this.quantity,
    required this.unit,
    required this.grams,
    required this.portionSpecified,
    required this.raw,
  });

  final String foodId;
  final String labelTr;
  final String emoji;
  final double quantity;
  final NutritionUnit unit;
  final double grams;
  final bool portionSpecified;
  final String raw;

  String get displayLine {
    if (!portionSpecified) return '$emoji $labelTr (porsiyon belirtilmedi)';
    return switch (unit) {
      NutritionUnit.piece => '$emoji ${quantity.toStringAsFixed(quantity == quantity.roundToDouble() ? 0 : 1)} $labelTr',
      NutritionUnit.g => '$emoji ${quantity.toStringAsFixed(0)} g $labelTr',
      NutritionUnit.ml => '$emoji ${quantity.toStringAsFixed(0)} ml $labelTr',
      NutritionUnit.unknown => '$emoji $labelTr',
    };
  }
}

class NutritionAnalysis {
  const NutritionAnalysis({
    required this.nutrients,
    required this.analyzedFoods,
    required this.confidence,
    required this.unknownTokens,
    required this.date,
    required this.rawInput,
    this.profile = const NutritionUserProfile(),
    this.version = kNutritionAnalysisVersion,
  });

  final Map<NutrientKey, NutrientStat> nutrients;
  final List<ParsedFood> analyzedFoods;
  final NutritionConfidence confidence;
  final List<String> unknownTokens;
  final DateTime date;
  final String rawInput;
  final String version;
  final NutritionUserProfile profile;

  int get inRangeCount =>
      nutrients.values.where((e) => e.inTargetBand).length;

  int get nutrientCount => NutrientKey.values.length;

  String get balanceLabel {
    if (inRangeCount >= 9) return 'Dengeli';
    if (inRangeCount >= 5) return 'Kısmen dengeli';
    return 'Eksikler öne çıkıyor';
  }

  /// Referansların %100 ile sınırlı ortalaması; tıbbi başarı skoru değildir.
  double get overallFillPercent {
    var sum = 0.0;
    for (final s in nutrients.values) {
      sum += s.percentage.clamp(0, 100);
    }
    if (nutrients.isEmpty) return 0;
    return sum / nutrients.length;
  }

  Map<String, dynamic> get summary => {
        'inRangeCount': inRangeCount,
        'nutrientCount': nutrientCount,
        'balanceLabel': balanceLabel,
        'confidence': confidence.name,
        'profile': profile.id,
        'overallFillPercent': overallFillPercent.round(),
      };

  List<NutrientStat> lowest({int n = 3}) {
    final list = nutrients.values.toList()
      ..sort((a, b) => a.percentage.compareTo(b.percentage));
    return list.take(n).toList();
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'confidence': confidence.name,
        'profile': profile.id,
        'date': date.toIso8601String(),
        'summary': summary,
        'nutrients': {
          for (final e in nutrients.entries) e.key.id: e.value.toJson(),
        },
        'foods': [
          for (final f in analyzedFoods)
            {
              'food': f.foodId,
              'quantity': f.quantity,
              'unit': f.unit.name,
              'grams': f.grams,
              'portionSpecified': f.portionSpecified,
            },
        ],
      };
}

const kNutritionAnalysisVersion = '3';
const kNutritionMinInputChars = 6;

enum NutritionSex { male, female, all }

enum NutritionLifeStage { standard, pregnancy, lactation }

enum NutrientReferenceType { rda, ai }

extension NutrientReferenceTypeX on NutrientReferenceType {
  String get labelTr => switch (this) {
        NutrientReferenceType.rda => 'RDA',
        NutrientReferenceType.ai => 'AI',
      };
}

enum NutritionAgeBand {
  y1to3(1, 3),
  y4to8(4, 8),
  y9to13(9, 13),
  y14to18(14, 18),
  y19to50(19, 50),
  y51to70(51, 70),
  y71plus(71, null);

  const NutritionAgeBand(this.ageMin, this.ageMax);
  final int ageMin;
  final int? ageMax;

  String get id => name;

  String get labelTr => switch (this) {
        NutritionAgeBand.y1to3 => '1–3 yaş',
        NutritionAgeBand.y4to8 => '4–8 yaş',
        NutritionAgeBand.y9to13 => '9–13 yaş',
        NutritionAgeBand.y14to18 => '14–18 yaş',
        NutritionAgeBand.y19to50 => '19–50 yaş',
        NutritionAgeBand.y51to70 => '51–70 yaş',
        NutritionAgeBand.y71plus => '71+ yaş',
      };

  /// 9+ DRI’de potasyum (ve 14+ çoğu vitamin) cinsiyete göre ayrılır.
  bool get needsSex => ageMin >= 9;

  int get representativeAge => ageMin;
}

class NutritionUserProfile {
  const NutritionUserProfile({
    this.ageBand = NutritionAgeBand.y19to50,
    this.sex = NutritionSex.male,
    this.lifeStage = NutritionLifeStage.standard,
  });

  static const adultMale = NutritionUserProfile();

  final NutritionAgeBand ageBand;
  final NutritionSex sex;
  final NutritionLifeStage lifeStage;

  NutritionSex get effectiveSex =>
      ageBand.needsSex ? (sex == NutritionSex.all ? NutritionSex.male : sex) : NutritionSex.all;

  String get id =>
      '${ageBand.id}_${effectiveSex.name}_${lifeStage.name}';

  String get labelTr {
    if (!ageBand.needsSex) return ageBand.labelTr;
    final sexLabel =
        effectiveSex == NutritionSex.female ? 'Kadın' : 'Erkek';
    return '${ageBand.labelTr} · $sexLabel';
  }
}

enum NutritionBand { low, mid, target, above, high }

NutritionBand nutritionBand(double percentage) {
  if (percentage < 50) return NutritionBand.low;
  if (percentage < 80) return NutritionBand.mid;
  if (percentage <= 120) return NutritionBand.target;
  if (percentage <= 150) return NutritionBand.above;
  return NutritionBand.high;
}

extension NutritionBandX on NutritionBand {
  String get labelTr => switch (this) {
        NutritionBand.low => 'Kritik Eksik',
        NutritionBand.mid => 'Geliştirilmeli',
        NutritionBand.target => 'İdeal Hedef',
        NutritionBand.above => 'Hedef üstü',
        NutritionBand.high => 'Yüksek Alım',
      };

  String get rangeTr => switch (this) {
        NutritionBand.low => '%0–49',
        NutritionBand.mid => '%50–79',
        NutritionBand.target => '%80–120',
        NutritionBand.above => '%121–150',
        NutritionBand.high => '%150+',
      };

  String get meaningTr => switch (this) {
        NutritionBand.low => 'Kritik eksik',
        NutritionBand.mid => 'Geliştirilmeli',
        NutritionBand.target => 'İdeal hedef',
        NutritionBand.above => 'Hedefin üzerinde',
        NutritionBand.high => 'Yüksek alım',
      };
}
