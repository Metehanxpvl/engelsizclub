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

String _intakeSharePhrase(NutrientStat stat) {
  final pct = stat.percentage.round();
  return 'Girilen besinlere göre tahmini ${stat.key.labelTr.toLowerCase()} alımı '
      'günlük referans hedefinin yaklaşık %$pct’sini karşılıyor.';
}

String buildNutritionSummary(NutritionAnalysis analysis) {
  final low = analysis
      .lowest(n: 4)
      .where((e) => e.percentage < 80)
      .map((e) => e.key.labelTr)
      .toList();
  final strong = analysis.nutrients.values
      .where((e) => e.percentage >= 80)
      .toList();
  if (low.isEmpty) {
    return 'Bugünkü kayıtlara göre tahmini mikro besin alımı günlük referans '
        'hedeflerine yakın görünüyor. Bu, laboratuvar veya teşhis sonucu değildir.';
  }
  if (strong.isEmpty) {
    return 'Bugünkü kayıtlara göre tahmini alım birçok mikro besinde günlük '
        'referans hedefinin altında görünüyor. Özellikle ${low.take(3).join(', ')} '
        'daha düşük. Bu bir eksiklik teşhisi değildir.';
  }
  return 'Bugünkü kayıtlara göre bazı mikro besin hedeflerini daha iyi karşılarken '
      '${low.take(3).join(', ')} açısından daha düşük bir alım görülüyor. '
      'Sonuçlar tahmini günlük karşılama oranıdır; teşhis değildir.';
}

List<String> buildNutritionRecommendations(NutritionAnalysis analysis) {
  final recs = <String>[];
  for (final s in analysis.lowest(n: 3)) {
    if (s.percentage >= 80) continue;
    final sources = kNutrientFoodSources[s.key] ?? '';
    recs.add(
      '${_intakeSharePhrase(s)} ${s.key.labelTr} içeren besinleri '
      '($sources) artırmak günlük referans hedefe yaklaşmana yardımcı olabilir.',
    );
  }
  final vitC = analysis.nutrients[NutrientKey.vitaminC];
  final iron = analysis.nutrients[NutrientKey.iron];
  if (vitC != null && iron != null && vitC.percentage >= 40 && iron.percentage < 100) {
    recs.add(
      'C vitamini içeren sebze ve meyveler bitkisel kaynaklı demirin emilimine '
      'yardımcı olabilir. Demir yüzdesi besin kompozisyonuna göredir; emilim bonusu eklenmedi.',
    );
  }
  if (analysis.analyzedFoods.any((e) => !e.portionSpecified)) {
    recs.add(
      'Porsiyon belirtilmeyen gıdalar standart (yaşa uygun) porsiyon üzerinden '
      'yaklaşık hesaplandı.',
    );
  }
  if (analysis.unknownTokens.isNotEmpty) {
    recs.add(
      'Bazı ifadeler tanınamadı; analiz yalnızca eşleşen gıdalarla devam etti.',
    );
  }
  recs.add(
    'Bu skor tıbbi anlam taşımaz. Günlük beslenme hedefinin yaklaşık ne kadarının '
    'karşılandığını gösteren tahmini bir analizdir.',
  );
  return recs;
}

/// Kural tabanlı analiz. Hedefler IOM/NIH DRI tablosundan gelir.
/// Skor yapay olarak yükseltilmez.
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
  final parsed = parseNutritionInput(trimmed, profile: profile);
  return nutritionAnalysisFromFoods(
    foods: parsed.foods,
    unknownTokens: parsed.unknown,
    date: day,
    rawInput: trimmed,
    profile: profile,
  );
}

/// Aynı DRI tablosuyla ParsedFood listesinden karne.
NutritionAnalysis nutritionAnalysisFromFoods({
  required List<ParsedFood> foods,
  required DateTime date,
  required NutritionUserProfile profile,
  String rawInput = '',
  List<String> unknownTokens = const [],
}) {
  if (foods.isEmpty) {
    throw StateError('Bu girişte analiz edilebilecek bir gıda bulunamadı.');
  }
  final day = DateTime(date.year, date.month, date.day);
  var total = NutrientAmounts.zero();
  var macros = MacroAmounts.zero();
  final scaledFoods = <ParsedFood>[];
  for (final item in foods) {
    final food = foodById(item.foodId);
    if (food == null) {
      scaledFoods.add(item);
      continue;
    }
    total += food.per100g.scaledGrams(item.grams);
    final itemMacros = food.macrosPer100g.scaledGrams(item.grams);
    macros += itemMacros;
    scaledFoods.add(item.copyWith(macros: itemMacros));
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

  final withPortion = scaledFoods.where((e) => e.portionSpecified).length;
  final draft = NutritionAnalysis(
    nutrients: nutrients,
    analyzedFoods: scaledFoods,
    confidence: nutritionConfidence(
      parsed: scaledFoods.length,
      withPortion: withPortion,
      unknown: unknownTokens.length,
    ),
    unknownTokens: unknownTokens,
    date: day,
    rawInput: rawInput,
    profile: profile,
    macros: macros,
  );
  return NutritionAnalysis(
    nutrients: draft.nutrients,
    analyzedFoods: draft.analyzedFoods,
    confidence: draft.confidence,
    unknownTokens: draft.unknownTokens,
    date: draft.date,
    rawInput: draft.rawInput,
    profile: draft.profile,
    analysisSummary: buildNutritionSummary(draft),
    recommendations: buildNutritionRecommendations(draft),
    macros: draft.macros,
  );
}

/// Gram düzenlemesi sonrası parser’ın yeniden okuyacağı metin.
String foodsToRawInput(List<ParsedFood> foods) {
  return foods
      .map((f) => '${f.grams.round()} g ${f.labelTr}')
      .join(', ');
}

/// Lokal öğünleri toplayıp günlük karneyi üretir (AI yok).
NutritionAnalysis combineMealAnalyses(
  List<NutritionAnalysis> meals, {
  required DateTime date,
  required NutritionUserProfile profile,
}) {
  if (meals.isEmpty) {
    throw StateError('Bugün kaydedilmiş bir öğün yok.');
  }
  return nutritionAnalysisFromFoods(
    foods: [for (final m in meals) ...m.analyzedFoods],
    unknownTokens: [for (final m in meals) ...m.unknownTokens],
    date: date,
    rawInput: meals.map((e) => e.rawInput).where((e) => e.isNotEmpty).join('\n'),
    profile: profile,
  );
}
