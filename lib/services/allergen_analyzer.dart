import '../models/product_safety.dart';
import 'e_number_explanations.dart';
import 'nova_from_ingredients.dart';
import 'open_food_facts_service.dart';
import 'product_disclaimer.dart';

/// Ücretsiz heuristic: Open Food Facts + Türkçe anahtar kelimeler.
/// İçerik analizi; tıbbi teşhis / tedavi değildir.
class AllergenAnalyzer {
  AllergenAnalyzer._();

  static const disclaimer = kProductAnalysisDisclaimer;

  static SafetyReport analyze({
    OffProduct? off,
    String? ingredients,
    String? productName,
  }) {
    final text = [
      productName,
      ingredients,
      off?.ingredients,
      off?.allergenText,
      off?.tracesText,
      off?.allergenTags.join(' '),
      off?.additiveTags.join(' '),
      off?.categories.join(' '),
    ].whereType<String>().join(' ').toLowerCase();

    final folded = _foldTr(text);

    final allergens = <String, AllergenHit>{};
    void addAllergen(String key, String label, String source) {
      allergens.putIfAbsent(
        key,
        () => AllergenHit(key: key, labelTr: label, source: source),
      );
    }

    for (final tag in off?.allergenTags ?? const <String>[]) {
      final mapped = _allergenFromOffTag(tag);
      if (mapped != null) {
        addAllergen(mapped.$1, mapped.$2, 'openfoodfacts');
      }
    }

    for (final rule in _allergenRules) {
      if (rule.patterns.any(folded.contains)) {
        addAllergen(rule.key, rule.labelTr, 'heuristic');
      }
    }

    final additives = <String, AdditiveHit>{};
    for (final tag in off?.additiveTags ?? const <String>[]) {
      final hit = _additiveFromTag(tag);
      if (hit != null) additives[hit.code] = hit;
    }
    for (final code in ENumberExplanations.extractECodes(folded)) {
      additives.putIfAbsent(code, () => _additiveFromCode(code));
    }

    final warnings = <String>[];
    var child = ChildSuitability.suitable;

    if (allergens.isNotEmpty) {
      warnings.add(
        'Bu içerik şu olası alerjenleri barındırabilir: '
        '${allergens.values.map((e) => e.labelTr).join(', ')}.',
      );
      child = ChildSuitability.caution;
    }

    final flaggedAdditives = additives.values.where((a) => a.flag != null);
    if (flaggedAdditives.any((a) => a.flag == 'child' || a.flag == 'dye')) {
      warnings.add(
        'Bileşen listesinde şu katkı maddesi yer alıyor: '
        '${flaggedAdditives.map((e) => '${e.code.toUpperCase()} ${e.labelTr}').join(', ')}.',
      );
      child = ChildSuitability.caution;
    }

    final sugars = off?.sugarsPer100g;
    if (sugars != null && sugars >= 22) {
      warnings.add(
        'Etiket bilgisine göre 100 g’da yaklaşık ${sugars.toStringAsFixed(1)} g şeker yer alıyor.',
      );
      child = ChildSuitability.caution;
    } else if (sugars != null && sugars >= 15) {
      warnings.add(
        'Etiket bilgisine göre 100 g’da yaklaşık ${sugars.toStringAsFixed(1)} g şeker bildirilmiş.',
      );
      if (child == ChildSuitability.suitable) {
        child = ChildSuitability.caution;
      }
    }

    final caffeine = off?.caffeineMg;
    if (caffeine != null && caffeine > 0) {
      warnings.add(
        'Etiket bilgisine göre kafein (100 g/ml: ${caffeine.toStringAsFixed(1)}) yer alıyor olabilir.',
      );
      child = ChildSuitability.unsuitable;
    } else if (_hasCaffeine(folded)) {
      warnings.add(
        'Bileşen listesinde kafein, kahve veya enerji içeceği ifadesi yer alıyor olabilir.',
      );
      child = ChildSuitability.unsuitable;
    }

    if (_hasAlcohol(folded)) {
      warnings.add(
        'Bileşen listesinde alkol veya alkollü içecek ifadesi yer alıyor olabilir.',
      );
      child = ChildSuitability.unsuitable;
    }

    if (additives.values.any((a) => a.code == 'e951' || a.code == 'e962')) {
      warnings.add(
        'Bileşen listesinde aspartam (E951) yer alıyor.',
      );
      if (child != ChildSuitability.unsuitable) {
        child = ChildSuitability.caution;
      }
    }

    if (allergens.isEmpty &&
        additives.isEmpty &&
        warnings.isEmpty &&
        (ingredients == null || ingredients.trim().isEmpty) &&
        (off?.ingredients == null || off!.ingredients!.trim().isEmpty)) {
      child = ChildSuitability.unknown;
      warnings.add('İçerik bilgisi sınırlı; ambalaj etiketini kontrol edin.');
    }

    final summary = _summaryTr(
      name: off?.productName ?? productName,
      child: child,
      allergenCount: allergens.length,
      additiveCount: additives.length,
    );
    final ing = (off?.ingredients ?? ingredients ?? '').trim();
    final ingredientsKnown = ProductRecord.isUsableIngredientText(ing);
    final ingSummary = !ingredientsKnown
        ? 'İçindekiler metni yok.'
        : (ing.length > 220 ? '${ing.substring(0, 220)}…' : ing);

    final additiveList = ENumberExplanations.forDisplay(
      additives: [
        for (final a in additives.values) ENumberExplanations.enrich(a),
      ],
      ingredients: ing,
    );
    final risk = AdditiveRiskLevel.fromAdditives(
      additiveList,
      ingredientsKnown: ingredientsKnown,
    );

    return NovaFromIngredients.applyIfMissing(
      SafetyReport(
        allergens: allergens.values.toList(),
        additives: additiveList,
        childSuitable: child,
        warnings: warnings,
        summaryTr: summary,
        ingredientsSummary: ingSummary,
        additiveRiskLevel: risk,
        additiveDensityScore: risk.densityScore,
        sugarsPer100g: off?.sugarsPer100g,
        saltPer100g: off?.saltPer100g,
        categoryLabel: off?.categoryLabel,
        nutriScore: off?.nutriScore,
        nutriScoreSource: off?.nutriScore != null
            ? LabelScoreSource.openfoodfacts
            : null,
        novaGroup: off?.novaGroup,
        novaGroupSource:
            off?.novaGroup != null ? LabelScoreSource.openfoodfacts : null,
      ),
      ingredients: ing,
    );
  }

  /// Gemini birleşimi sonrası risk / besin alanlarını doldur (eski önbellek uyumlu).
  static SafetyReport finalize(
    SafetyReport report, {
    OffProduct? off,
    String? categoryLabel,
    double? sugarsPer100g,
    double? saltPer100g,
    String? ingredients,
  }) {
    final blob = [
      ingredients,
      report.ingredientsSummary,
      off?.ingredients,
    ].whereType<String>().join('\n');
    final additiveList = ENumberExplanations.forDisplay(
      additives: [
        for (final a in report.additives) ENumberExplanations.enrich(a),
      ],
      ingredients: blob,
    );
    final ingredientsKnown = ProductRecord.isUsableIngredientText(ingredients) ||
        ProductRecord.isUsableIngredientText(report.ingredientsSummary) ||
        (off != null && ProductRecord.isUsableIngredientText(off.ingredients));
    final risk = AdditiveRiskLevel.fromAdditives(
      additiveList,
      ingredientsKnown: ingredientsKnown,
    );
    final sugars = off?.sugarsPer100g ?? report.sugarsPer100g ?? sugarsPer100g;
    final salt = off?.saltPer100g ?? report.saltPer100g ?? saltPer100g;
    final category = _shortCategory(
      off?.categoryLabel ?? report.categoryLabel ?? categoryLabel,
    );
    return NovaFromIngredients.applyIfMissing(
      SafetyReport(
        allergens: report.allergens,
        additives: additiveList,
        childSuitable: report.childSuitable,
        warnings: report.warnings,
        summaryTr: report.summaryTr,
        ingredientsSummary: report.ingredientsSummary,
        additiveRiskLevel: risk,
        additiveDensityScore: risk.densityScore,
        sugarsPer100g: sugars,
        saltPer100g: salt,
        categoryLabel: category,
        nutriScore: off?.nutriScore ?? report.nutriScore,
        nutriScoreSource: off?.nutriScore != null
            ? LabelScoreSource.openfoodfacts
            : report.nutriScoreSource,
        novaGroup: off?.novaGroup ?? report.novaGroup,
        novaGroupSource: off?.novaGroup != null
            ? LabelScoreSource.openfoodfacts
            : report.novaGroupSource,
      ),
      ingredients: ingredients ?? blob,
    );
  }

  static String? _shortCategory(String? raw) {
    final s = raw?.trim();
    if (s == null || s.isEmpty || s.length > 28) return null;
    const aliases = <String, String>{
      'cips': 'CİPS',
      'chips': 'CİPS',
      'crisps': 'CİPS',
      'icecek': 'İÇECEK',
      'içecek': 'İÇECEK',
      'beverage': 'İÇECEK',
      'ayran': 'İÇECEK',
      'kola': 'İÇECEK',
      'meyve suyu': 'MEYVE SUYU',
      'su': 'SU',
      'sut': 'SÜT',
      'süt': 'SÜT',
      'yogurt': 'YOĞURT',
      'yoğurt': 'YOĞURT',
      'biskuvı': 'BİSKÜVİ',
      'biscuit': 'BİSKÜVİ',
      'cikolata': 'ÇİKOLATA',
      'chocolate': 'ÇİKOLATA',
    };
    final folded = s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    return aliases[folded] ?? s.toUpperCase();
  }

  static String _summaryTr({
    String? name,
    required ChildSuitability child,
    required int allergenCount,
    required int additiveCount,
  }) {
    final who = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : 'Bu ürün';
    switch (child) {
      case ChildSuitability.suitable:
        return 'Etiket bilgisine göre $who bileşen listesinde öne çıkan '
            'alerjen/katkı işareti bulunamadı. $disclaimer';
      case ChildSuitability.caution:
        return 'Etiket bilgisine göre $who içeriğinde $allergenCount olası '
            'alerjen ve $additiveCount katkı maddesi yer alıyor olabilir. $disclaimer';
      case ChildSuitability.unsuitable:
        return 'Etiket bilgisine göre $who bileşen listesinde kafein, alkol '
            'veya benzeri ifadeler yer alıyor olabilir. $disclaimer';
      case ChildSuitability.unknown:
        return '$who için yeterli içerik metni yok. $disclaimer';
    }
  }

  static bool _hasCaffeine(String folded) {
    const keys = [
      'kafein',
      'caffeine',
      'kahve',
      'enerji icecegi',
      'energy drink',
      'guarana',
      'mate',
    ];
    return keys.any(folded.contains);
  }

  static bool _hasAlcohol(String folded) {
    const keys = [
      'alkol',
      'alcohol',
      'etiket: alkollu',
      'bira',
      'sarap',
      'wine',
      'beer',
      'rakı',
      'raki',
    ];
    return keys.any(folded.contains);
  }

  static String _foldTr(String s) {
    return s
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u');
  }

  static (String, String)? _allergenFromOffTag(String raw) {
    final t = raw.toLowerCase().replaceAll(RegExp(r'^[a-z]{2}:'), '');
    const map = <String, (String, String)>{
      'gluten': ('gluten', 'Gluten'),
      'wheat': ('gluten', 'Gluten (buğday)'),
      'barley': ('gluten', 'Gluten (arpa)'),
      'rye': ('gluten', 'Gluten (çavdar)'),
      'oats': ('gluten', 'Gluten (yulaf)'),
      'milk': ('sut', 'Süt'),
      'lactose': ('sut', 'Laktoz / süt'),
      'eggs': ('yumurta', 'Yumurta'),
      'egg': ('yumurta', 'Yumurta'),
      'soybeans': ('soya', 'Soya'),
      'soy': ('soya', 'Soya'),
      'nuts': ('findik', 'Kabuklu yemiş'),
      'tree-nuts': ('findik', 'Kabuklu yemiş'),
      'peanuts': ('fistik', 'Yer fıstığı'),
      'peanut': ('fistik', 'Yer fıstığı'),
      'sesame-seeds': ('susam', 'Susam'),
      'sesame': ('susam', 'Susam'),
      'mustard': ('hardal', 'Hardal'),
      'sulphur-dioxide-and-sulphites': ('sulfit', 'Kükürt dioksit / sülfit'),
      'sulfites': ('sulfit', 'Sülfit'),
      'crustaceans': ('kabuklu', 'Kabuklu deniz ürünleri'),
      'fish': ('balik', 'Balık'),
      'celery': ('kereviz', 'Kereviz'),
      'lupin': ('bakla', 'Acı bakla (lupin)'),
      'molluscs': ('yumusakca', 'Yumuşakça'),
    };
    return map[t];
  }

  static AdditiveHit? _additiveFromTag(String raw) {
    final codes = ENumberExplanations.extractECodes(raw).toList();
    if (codes.isEmpty) return null;
    return _additiveFromCode(codes.first);
  }

  static AdditiveHit _additiveFromCode(String code) {
    return ENumberExplanations.enrich(
      AdditiveHit(code: code, labelTr: ''),
    );
  }
}

class _AllergenRule {
  const _AllergenRule(this.key, this.labelTr, this.patterns);
  final String key;
  final String labelTr;
  final List<String> patterns;
}

const _allergenRules = <_AllergenRule>[
  _AllergenRule('gluten', 'Gluten', [
    'gluten',
    'bugday',
    'arpa unu',
    'cavdar',
    'yulaf',
    'seitan',
    'bulgur',
  ]),
  _AllergenRule('sut', 'Süt', [
    ' sut',
    'sut tozu',
    'laktoz',
    'peynir',
    'tereyag',
    'krema',
    'whey',
    'kazein',
    'casein',
    'yoghurt',
    'yogurt',
  ]),
  _AllergenRule('yumurta', 'Yumurta', [
    'yumurta',
    'egg',
    'albumin',
    'ovalbumin',
  ]),
  _AllergenRule('soya', 'Soya', [
    'soya',
    'soybean',
    'lecithin (soya)',
    'lesitin (soya)',
  ]),
  _AllergenRule('findik', 'Kabuklu yemiş', [
    'findik',
    'badem',
    'ceviz',
    'kaju',
    'antep fistigi',
    'hazelnut',
    'almond',
    'walnut',
    'cashew',
    'pistachio',
    'pecan',
  ]),
  _AllergenRule('fistik', 'Yer fıstığı', [
    'yer fistigi',
    'fistık ezmesi',
    'peanut',
    'groundnut',
  ]),
  _AllergenRule('susam', 'Susam', [
    'susam',
    'tahin',
    'sesame',
  ]),
  _AllergenRule('hardal', 'Hardal', [
    'hardal',
    'mustard',
  ]),
  _AllergenRule('sulfit', 'Kükürt dioksit / sülfit', [
    'kukurt dioksit',
    'sulfit',
    'sulphite',
    'sulfite',
    'e220',
    'e221',
    'e222',
    'e223',
    'e224',
    'e228',
  ]),
  _AllergenRule('kabuklu', 'Kabuklu deniz ürünleri', [
    'karides',
    'midye',
    'istiridye',
    'yengec',
    'crustacean',
    'shrimp',
    'prawn',
    'crab',
  ]),
  _AllergenRule('balik', 'Balık', [
    ' balik',
    'anchovy',
    'somon',
    'ton baligi',
    'fish oil',
  ]),
  _AllergenRule('kereviz', 'Kereviz', [
    'kereviz',
    'celery',
  ]),
  _AllergenRule('bakla', 'Acı bakla (lupin)', [
    'aci bakla',
    'lupin',
    'lupine',
  ]),
  _AllergenRule('yumusakca', 'Yumuşakça', [
    'kalamar',
    'ahtapot',
    'mollusc',
    'squid',
  ]),
];
