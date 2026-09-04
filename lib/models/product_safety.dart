/// Ürün + içerik özeti (Supabase `products.safety_report`).
/// Tıbbi teşhis / “güvenlidir” iddiası yok; yalnızca etiket notları.
enum ChildSuitability {
  suitable,
  caution,
  unsuitable,
  unknown;

  static ChildSuitability fromJson(Object? raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'suitable':
      case 'none':
      case 'uygun':
        return ChildSuitability.suitable;
      case 'caution':
      case 'notes':
      case 'dikkat':
      case 'amber':
        return ChildSuitability.caution;
      case 'unsuitable':
      case 'concerns':
      case 'uygun_degil':
        return ChildSuitability.unsuitable;
      default:
        return ChildSuitability.unknown;
    }
  }

  /// Bilgi notu düzeyi (tıbbi iddia değil).
  String get jsonValue {
    switch (this) {
      case ChildSuitability.suitable:
        return 'none';
      case ChildSuitability.caution:
        return 'notes';
      case ChildSuitability.unsuitable:
        return 'concerns';
      case ChildSuitability.unknown:
        return 'unknown';
    }
  }
}

class AllergenHit {
  const AllergenHit({
    required this.key,
    required this.labelTr,
    this.source = 'heuristic',
  });

  final String key;
  final String labelTr;
  final String source;

  factory AllergenHit.fromJson(Map<String, dynamic> json) {
    return AllergenHit(
      key: json['key']?.toString() ?? '',
      labelTr: json['labelTr']?.toString() ??
          json['label_tr']?.toString() ??
          '',
      source: json['source']?.toString() ?? 'heuristic',
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'labelTr': labelTr,
        'source': source,
      };
}

/// Etiket / açık verideki katkı yoğunluğu (tıbbi teşhis değil).
/// Bar soldan sağa: Aşırı → Yok (kırmızı → yeşil).
/// [bilinmiyor]: içindekiler yok / okunamadı — boş `additives[]` ≠ Yok.
enum AdditiveRiskLevel {
  asiri,
  cok,
  az,
  cokAz,
  yok,
  bilinmiyor;

  bool get isUnknown => this == AdditiveRiskLevel.bilinmiyor;

  static AdditiveRiskLevel? tryFromJson(Object? raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'asiri':
      case 'aşırı':
      case 'extreme':
        return AdditiveRiskLevel.asiri;
      case 'cok':
      case 'çok':
      case 'high':
        return AdditiveRiskLevel.cok;
      case 'az':
      case 'low':
        return AdditiveRiskLevel.az;
      case 'cokaz':
      case 'cok_az':
      case 'çok az':
      case 'cok az':
      case 'very_low':
      case 'verylow':
        return AdditiveRiskLevel.cokAz;
      case 'yok':
      case 'none':
      case 'absent':
        return AdditiveRiskLevel.yok;
      case 'bilinmiyor':
      case 'unknown':
      case 'missing':
      case 'unread':
        return AdditiveRiskLevel.bilinmiyor;
      default:
        return null;
    }
  }

  String get jsonValue {
    switch (this) {
      case AdditiveRiskLevel.asiri:
        return 'asiri';
      case AdditiveRiskLevel.cok:
        return 'cok';
      case AdditiveRiskLevel.az:
        return 'az';
      case AdditiveRiskLevel.cokAz:
        return 'cokAz';
      case AdditiveRiskLevel.yok:
        return 'yok';
      case AdditiveRiskLevel.bilinmiyor:
        return 'bilinmiyor';
    }
  }

  String get labelTr {
    switch (this) {
      case AdditiveRiskLevel.asiri:
        return 'Aşırı';
      case AdditiveRiskLevel.cok:
        return 'Çok';
      case AdditiveRiskLevel.az:
        return 'Az';
      case AdditiveRiskLevel.cokAz:
        return 'Çok Az';
      case AdditiveRiskLevel.yok:
        return 'Yok';
      case AdditiveRiskLevel.bilinmiyor:
        return 'Bilinmiyor';
    }
  }

  /// Bilgilendirme cümlesi — tıbbi iddia / “güvenli” yok.
  String get infoSentence {
    switch (this) {
      case AdditiveRiskLevel.asiri:
      case AdditiveRiskLevel.cok:
        return 'Bu üründe katkı maddesi yoğunluğu yüksek görünüyor';
      case AdditiveRiskLevel.az:
        return 'Bu üründe katkı maddesi yoğunluğu orta görünüyor';
      case AdditiveRiskLevel.cokAz:
        return 'Bu üründe katkı maddesi yoğunluğu düşük görünüyor';
      case AdditiveRiskLevel.yok:
        return 'Etiket / açık veri kaynaklarında katkı maddesi görünmüyor';
      case AdditiveRiskLevel.bilinmiyor:
        return 'İçerik okunamadı; katkı düzeyi bilinmiyor. Bu bir güvenlik değerlendirmesi değildir.';
    }
  }

  /// Katkı yoğunluğu 1–10 (yüksek = daha fazla katkı kodu). Sağlık puanı değil.
  /// Bilinmiyor iken skor gösterilmez.
  int? get densityScore {
    switch (this) {
      case AdditiveRiskLevel.asiri:
        return 10;
      case AdditiveRiskLevel.cok:
        return 8;
      case AdditiveRiskLevel.az:
        return 5;
      case AdditiveRiskLevel.cokAz:
        return 3;
      case AdditiveRiskLevel.yok:
        return 1;
      case AdditiveRiskLevel.bilinmiyor:
        return null;
    }
  }

  /// E621, E951, E250 ve benzeri daha sık işaretlenen kodlar + `flag`.
  static const higherConcernCodes = <String>{
    'e102', 'e104', 'e110', 'e122', 'e124', 'e129',
    'e211',
    'e249', 'e250', 'e251', 'e252',
    'e320', 'e321',
    'e621',
    'e950', 'e951', 'e952', 'e954', 'e955', 'e961', 'e962', 'e969',
  };

  /// Eski önbellekte alan yoksa `additives[]` uzunluğu + kaygı kodlarından türet.
  /// Katkı kodu varsa içindekiler metni olmasa da düzey hesaplanır.
  /// Kod yok + gerçek içindekiler → **Yok**. Kod yok + içindekiler yok → **Bilinmiyor**
  /// (yeşil Yok uydurulmaz).
  static AdditiveRiskLevel fromAdditives(
    Iterable<AdditiveHit> additives, {
    bool ingredientsKnown = false,
  }) {
    var count = 0;
    var concern = 0;
    for (final a in additives) {
      var raw = a.code.trim();
      if (raw.isEmpty) raw = a.labelTr.trim();
      if (raw.isEmpty) continue;
      var code = raw.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');
      if (!code.startsWith('e') &&
          RegExp(r'^\d{3,4}[a-z]{0,3}$').hasMatch(code)) {
        code = 'e$code';
      }
      final extracted = RegExp(r'e\d{3,4}[a-z]{0,3}').firstMatch(code);
      if (extracted != null) code = extracted.group(0)!;
      if (code.isEmpty) continue;
      count++;
      final flagged = a.flag == 'child' || a.flag == 'dye' || a.flag == 'caution';
      if (flagged || higherConcernCodes.contains(code)) concern++;
    }
    if (count == 0) {
      return ingredientsKnown
          ? AdditiveRiskLevel.yok
          : AdditiveRiskLevel.bilinmiyor;
    }
    AdditiveRiskLevel level;
    if (count >= 10) {
      level = AdditiveRiskLevel.asiri;
    } else if (count >= 6) {
      level = AdditiveRiskLevel.cok;
    } else if (count >= 3) {
      level = AdditiveRiskLevel.az;
    } else {
      level = AdditiveRiskLevel.cokAz;
    }
    if (concern >= 3) return AdditiveRiskLevel.asiri;
    if (concern >= 1) {
      const lastKnown = 4; // yok
      final i = (level.index - 1).clamp(0, lastKnown);
      return AdditiveRiskLevel.values[i];
    }
    return level;
  }
}

/// Nutri-Score A–E (bilgilendirme). Yoksa null — E varsayılmaz.
enum NutriScoreGrade {
  a,
  b,
  c,
  d,
  e;

  String get letter {
    switch (this) {
      case NutriScoreGrade.a:
        return 'A';
      case NutriScoreGrade.b:
        return 'B';
      case NutriScoreGrade.c:
        return 'C';
      case NutriScoreGrade.d:
        return 'D';
      case NutriScoreGrade.e:
        return 'E';
    }
  }

  String get titleTr => 'Besleyicilik Düzeyi';

  static const unknownLabelTr = 'Bilinmiyor';

  String get subtitleTr {
    switch (this) {
      case NutriScoreGrade.a:
        return 'En Yüksek Besin Değeri';
      case NutriScoreGrade.b:
        return 'Yüksek Besin Değeri';
      case NutriScoreGrade.c:
        return 'Orta Besin Değeri';
      case NutriScoreGrade.d:
        return 'Düşük Besin Değeri';
      case NutriScoreGrade.e:
        return 'En Düşük Besin Değeri';
    }
  }

  static NutriScoreGrade? tryParse(Object? raw) {
    if (raw == null) return null;
    var s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^[a-z]{2}:'), '');
    if (s == 'unknown' ||
        s == 'not-applicable' ||
        s == 'not_applicable' ||
        s == 'n/a' ||
        s == 'none' ||
        s == 'null' ||
        s.contains('unknown')) {
      return null;
    }
    if (s.length == 1 && 'abcde'.contains(s)) {
      return _fromLetter(s);
    }
    final m = RegExp(r'(?:grade|nutriscore|nutri[_\s-]*score)[_:\s-]*([a-e])\b')
        .firstMatch(s);
    if (m != null) return _fromLetter(m.group(1)!);
    if (RegExp(r'^[a-e]$').hasMatch(s)) return _fromLetter(s);
    return null;
  }

  static NutriScoreGrade? _fromLetter(String letter) {
    switch (letter) {
      case 'a':
        return NutriScoreGrade.a;
      case 'b':
        return NutriScoreGrade.b;
      case 'c':
        return NutriScoreGrade.c;
      case 'd':
        return NutriScoreGrade.d;
      case 'e':
        return NutriScoreGrade.e;
      default:
        return null;
    }
  }
}

/// NOVA 1–4 (bilgilendirme). Yoksa null — 4 varsayılmaz.
enum NovaGroup {
  one,
  two,
  three,
  four;

  int get number {
    switch (this) {
      case NovaGroup.one:
        return 1;
      case NovaGroup.two:
        return 2;
      case NovaGroup.three:
        return 3;
      case NovaGroup.four:
        return 4;
    }
  }

  String get titleTr => 'İşlenmişlik Düzeyi';

  String get subtitleTr {
    switch (this) {
      case NovaGroup.one:
        return 'Az İşlenmiş / İşlenmemiş';
      case NovaGroup.two:
        return 'İşlenmiş Mutfak Malzemesi';
      case NovaGroup.three:
        return 'İşlenmiş Ürün';
      case NovaGroup.four:
        return 'Aşırı İşlenmiş Ürün';
    }
  }

  static const unknownLabelTr = 'Bilinmiyor';

  /// OFF / Gemini / önbellek: ilk geçerli 1–4. Kelimeden 1/4 uydurulmaz.
  static NovaGroup? tryParseFirst(Iterable<Object?> values) {
    for (final v in values) {
      final g = tryParse(v);
      if (g != null) return g;
    }
    return null;
  }

  /// Standart alan adları (novaGroup, nova_group, nova-group, tags, nutriments).
  static NovaGroup? fromLooseJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return null;
    final nutriments = json['nutriments'];
    return tryParseFirst([
      json['novaGroup'],
      json['nova_group'],
      json['nova_groups'],
      json['nova_groups_tags'],
      json['nova-group'],
      json['nova_group_100g'],
      json['nova-group_100g'],
      json['novaGroupNumber'],
      json['nova'],
      json['NOVA'],
      if (nutriments is Map) nutriments['nova-group'],
      if (nutriments is Map) nutriments['nova_group'],
      if (nutriments is Map) nutriments['nova-group_100g'],
      if (nutriments is Map) nutriments['nova_group_100g'],
    ]);
  }

  static NovaGroup? tryParse(Object? raw) {
    if (raw == null) return null;
    if (raw is Map) {
      return tryParseFirst([
        raw['novaGroup'],
        raw['nova_group'],
        raw['nova_groups'],
        raw['nova_groups_tags'],
        raw['nova-group'],
        raw['group'],
        raw['nova'],
        raw['value'],
      ]);
    }
    if (raw is Iterable && raw is! String) {
      for (final e in raw) {
        final g = tryParse(e);
        if (g != null) return g;
      }
      return null;
    }
    if (raw is int && raw >= 1 && raw <= 4) return _fromNumber(raw);
    if (raw is num) {
      final n = raw.round();
      if (n >= 1 && n <= 4) return _fromNumber(n);
    }
    var s = raw.toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    s = s.replaceFirst(RegExp(r'^[a-z]{2}:'), '');
    if (s == 'unknown' ||
        s == 'not-applicable' ||
        s == 'not_applicable' ||
        s == 'n/a' ||
        s == 'none' ||
        s == 'null' ||
        s == '0' ||
        s.contains('unknown')) {
      return null;
    }
    if (RegExp(r'^[1-4]$').hasMatch(s)) return _fromNumber(int.parse(s));
    // OFF: "4-ultra-processed-food", "en:3-processed-foods"
    final leading = RegExp(r'^([1-4])(?:\b|[-_])').firstMatch(s);
    if (leading != null) return _fromNumber(int.parse(leading.group(1)!));
    final tagged = RegExp(r'(?:nova[_\s-]*groups?[:\s-]*)([1-4])\b').firstMatch(s);
    if (tagged != null) return _fromNumber(int.parse(tagged.group(1)!));
    // Gemini: "nova: 4", "NOVA 3", "nova-4"
    final labeled = RegExp(r'(?:^|[^\w])nova[:\s-]*([1-4])\b').firstMatch(s);
    if (labeled != null) return _fromNumber(int.parse(labeled.group(1)!));
    return null;
  }

  static NovaGroup? _fromNumber(int n) {
    switch (n) {
      case 1:
        return NovaGroup.one;
      case 2:
        return NovaGroup.two;
      case 3:
        return NovaGroup.three;
      case 4:
        return NovaGroup.four;
      default:
        return null;
    }
  }
}

/// Skor kaynağı. Gemini her zaman [estimate]; OFF [openfoodfacts].
enum LabelScoreSource {
  openfoodfacts,
  estimate,
  unknown;

  String get jsonValue {
    switch (this) {
      case LabelScoreSource.openfoodfacts:
        return 'openfoodfacts';
      case LabelScoreSource.estimate:
        return 'estimate';
      case LabelScoreSource.unknown:
        return 'unknown';
    }
  }

  bool get isEstimate => this == LabelScoreSource.estimate;
  bool get isUnknown => this == LabelScoreSource.unknown;
  bool get isOff => this == LabelScoreSource.openfoodfacts;

  static LabelScoreSource? tryParse(Object? raw) {
    switch ((raw ?? '').toString().trim().toLowerCase()) {
      case 'openfoodfacts':
      case 'off':
      case 'open_food_facts':
        return LabelScoreSource.openfoodfacts;
      case 'estimate':
      case 'estimated':
      case 'llm':
      case 'gemini':
      case 'etiket':
        return LabelScoreSource.estimate;
      case 'unknown':
      case 'none':
      case 'missing':
        return LabelScoreSource.unknown;
      default:
        return null;
    }
  }
}

/// 100 g’daki şeker / tuz için etiket bandı (FSA tarzı eşikler, tıbbi değil).
enum NutrientBand {
  az,
  orta,
  yuksek,
  cokYuksek;

  String get labelTr {
    switch (this) {
      case NutrientBand.az:
        return 'Az';
      case NutrientBand.orta:
        return 'Orta';
      case NutrientBand.yuksek:
        return 'Yüksek';
      case NutrientBand.cokYuksek:
        return 'Çok Yüksek';
    }
  }

  /// Şeker g / 100 g — yoksa null (uydurma).
  static NutrientBand? fromSugarPer100g(double? grams) {
    if (grams == null) return null;
    if (grams <= 5) return NutrientBand.az;
    if (grams <= 12.5) return NutrientBand.orta;
    if (grams <= 22.5) return NutrientBand.yuksek;
    return NutrientBand.cokYuksek;
  }

  /// Tuz g / 100 g — yoksa null (uydurma).
  static NutrientBand? fromSaltPer100g(double? grams) {
    if (grams == null) return null;
    if (grams <= 0.3) return NutrientBand.az;
    if (grams <= 1.0) return NutrientBand.orta;
    if (grams <= 1.5) return NutrientBand.yuksek;
    return NutrientBand.cokYuksek;
  }
}

class AdditiveHit {
  const AdditiveHit({
    required this.code,
    required this.labelTr,
    this.flag,
  });

  final String code;
  final String labelTr;
  /// `child` | `dye` | `caution` | null
  final String? flag;

  factory AdditiveHit.fromJson(Map<String, dynamic> json) {
    final flag = json['flag']?.toString().trim();
    return AdditiveHit(
      code: json['code']?.toString() ?? '',
      labelTr: json['labelTr']?.toString() ??
          json['label_tr']?.toString() ??
          '',
      flag: (flag == null || flag.isEmpty) ? null : flag,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'labelTr': labelTr,
        if (flag != null) 'flag': flag,
      };
}

class SafetyReport {
  const SafetyReport({
    this.allergens = const [],
    this.additives = const [],
    this.childSuitable = ChildSuitability.unknown,
    this.warnings = const [],
    this.summaryTr = '',
    this.ingredientsSummary = '',
    this.additiveRiskLevel,
    this.additiveDensityScore,
    this.sugarsPer100g,
    this.saltPer100g,
    this.categoryLabel,
    this.nutriScore,
    this.nutriScoreSource,
    this.novaGroup,
    this.novaGroupSource,
  });

  /// Olası alerjenler (etiket / açık veri).
  final List<AllergenHit> allergens;
  final List<AdditiveHit> additives;
  /// Bilgi notu düzeyi — tıbbi “çocuk için güvenli” iddiası değildir.
  final ChildSuitability childSuitable;
  final List<String> warnings;
  final String summaryTr;
  final String ingredientsSummary;
  /// Yoksa [resolvedAdditiveRisk] `additives` uzunluğundan türetilir.
  final AdditiveRiskLevel? additiveRiskLevel;
  /// 1–10 katkı yoğunluğu (bilgilendirme). Yoksa düzeyden türetilir.
  final int? additiveDensityScore;
  final double? sugarsPer100g;
  final double? saltPer100g;
  /// Kısa kategori etiketi (CİPS, İÇECEK…). Yoksa chip gösterilmez.
  final String? categoryLabel;
  /// Nutri-Score A–E. Yoksa seçim yok (E varsayılmaz).
  final NutriScoreGrade? nutriScore;
  /// [openfoodfacts] | [estimate] | [unknown]. Gemini her zaman estimate.
  final LabelScoreSource? nutriScoreSource;
  /// NOVA 1–4. Yoksa seçim yok (4 varsayılmaz).
  final NovaGroup? novaGroup;
  final LabelScoreSource? novaGroupSource;

  bool get hasScoreLookup =>
      nutriScoreSource != null && novaGroupSource != null;

  bool get nutriIsEstimate =>
      nutriScore != null && (nutriScoreSource?.isEstimate ?? true);

  bool get novaIsEstimate =>
      novaGroup != null && (novaGroupSource?.isEstimate ?? true);

  List<AllergenHit> get possibleAllergens => allergens;
  List<String> get notes => warnings;
  String get infoSummary =>
      summaryTr.trim().isNotEmpty ? summaryTr : ingredientsSummary;

  /// Alerjen / katkı / gerçek içindekiler özeti — “içerik sınırlı” yer tutucu değil.
  /// Ürün adından heuristic alerjen tek başına tam kayıt sayılmaz.
  /// Katkı kodu olması NOVA veya yeşil Yok anlamına gelmez.
  bool get hasUsableContent {
    if (additives.any((a) => a.code.trim().isNotEmpty)) return true;
    if (ProductRecord.isUsableIngredientText(ingredientsSummary)) return true;
    if (allergens.any((a) => a.source == 'openfoodfacts')) return true;
    return false;
  }

  /// Her gösterimde yeniden hesapla: eski `safety_report` alanı yoksa /
  /// `bilinmiyor` donmuşsa bile E-kodları + içindekiler metninden türet.
  AdditiveRiskLevel resolvedAdditiveRisk({
    Iterable<AdditiveHit>? display,
    bool ingredientsKnown = false,
  }) {
    return AdditiveRiskLevel.fromAdditives(
      display ?? additives,
      ingredientsKnown: ingredientsKnown,
    );
  }

  int? resolvedDensityScore({
    Iterable<AdditiveHit>? display,
    bool ingredientsKnown = false,
  }) {
    return resolvedAdditiveRisk(
      display: display,
      ingredientsKnown: ingredientsKnown,
    ).densityScore;
  }

  factory SafetyReport.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return const SafetyReport();
    final allergenRaw = json['possibleAllergens'] ??
        json['possible_allergens'] ??
        json['allergens'];
    final noteRaw = json['notes'] ?? json['warnings'];
    final category = _emptyToNull(
      json['categoryLabel'] ?? json['category_label'] ?? json['category'],
    );
    return SafetyReport(
      allergens: _mapList(allergenRaw, AllergenHit.fromJson),
      additives: _mapAdditives(json['additives']),
      childSuitable: ChildSuitability.fromJson(
        json['notesLevel'] ??
            json['notes_level'] ??
            json['childSuitable'] ??
            json['child_suitable'],
      ),
      warnings: [
        for (final w in (noteRaw as List?) ?? const [])
          if (w.toString().trim().isNotEmpty) w.toString().trim(),
      ],
      summaryTr: json['infoSummary']?.toString() ??
          json['info_summary']?.toString() ??
          json['summaryTr']?.toString() ??
          json['summary_tr']?.toString() ??
          '',
      ingredientsSummary: json['ingredientsSummary']?.toString() ??
          json['ingredients_summary']?.toString() ??
          '',
      additiveRiskLevel: AdditiveRiskLevel.tryFromJson(
        json['additiveRiskLevel'] ?? json['additive_risk_level'],
      ),
      additiveDensityScore: _asInt(
        json['additiveDensityScore'] ?? json['additive_density_score'],
      ),
      sugarsPer100g: _asDouble(
        json['sugarsPer100g'] ?? json['sugars_per_100g'] ?? json['sugars'],
      ),
      saltPer100g: _asDouble(
        json['saltPer100g'] ?? json['salt_per_100g'] ?? json['salt'],
      ),
      categoryLabel: category,
      nutriScore: NutriScoreGrade.tryParse(
        json['nutriScore'] ??
            json['nutri_score'] ??
            json['nutriscore_grade'] ??
            json['nutriscoreGrade'] ??
            json['nutrition_grades'],
      ),
      nutriScoreSource: LabelScoreSource.tryParse(
        json['nutriScoreSource'] ?? json['nutri_score_source'],
      ),
      novaGroup: NovaGroup.fromLooseJson(json),
      novaGroupSource: LabelScoreSource.tryParse(
        json['novaGroupSource'] ?? json['nova_group_source'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'ingredientsSummary': ingredientsSummary,
        'possibleAllergens': [for (final a in allergens) a.toJson()],
        'allergens': [for (final a in allergens) a.toJson()],
        'additives': [for (final a in additives) a.toJson()],
        'infoSummary': summaryTr,
        'summaryTr': summaryTr,
        'notes': warnings,
        'warnings': warnings,
        'notesLevel': childSuitable.jsonValue,
        'additiveRiskLevel': (additiveRiskLevel ?? AdditiveRiskLevel.bilinmiyor)
            .jsonValue,
        if (additiveDensityScore != null)
          'additiveDensityScore': additiveDensityScore,
        if (sugarsPer100g != null) 'sugarsPer100g': sugarsPer100g,
        if (saltPer100g != null) 'saltPer100g': saltPer100g,
        if (categoryLabel != null && categoryLabel!.trim().isNotEmpty)
          'categoryLabel': categoryLabel!.trim(),
        if (nutriScore != null) 'nutriScore': nutriScore!.letter,
        if (nutriScoreSource != null)
          'nutriScoreSource': nutriScoreSource!.jsonValue,
        if (novaGroup != null) 'novaGroup': novaGroup!.number,
        if (novaGroupSource != null)
          'novaGroupSource': novaGroupSource!.jsonValue,
      };

  SafetyReport copyWith({
    List<AllergenHit>? allergens,
    List<AdditiveHit>? additives,
    ChildSuitability? childSuitable,
    List<String>? warnings,
    String? summaryTr,
    String? ingredientsSummary,
    AdditiveRiskLevel? additiveRiskLevel,
    int? additiveDensityScore,
    double? sugarsPer100g,
    double? saltPer100g,
    String? categoryLabel,
    NutriScoreGrade? nutriScore,
    LabelScoreSource? nutriScoreSource,
    NovaGroup? novaGroup,
    LabelScoreSource? novaGroupSource,
  }) {
    return SafetyReport(
      allergens: allergens ?? this.allergens,
      additives: additives ?? this.additives,
      childSuitable: childSuitable ?? this.childSuitable,
      warnings: warnings ?? this.warnings,
      summaryTr: summaryTr ?? this.summaryTr,
      ingredientsSummary: ingredientsSummary ?? this.ingredientsSummary,
      additiveRiskLevel: additiveRiskLevel ?? this.additiveRiskLevel,
      additiveDensityScore: additiveDensityScore ?? this.additiveDensityScore,
      sugarsPer100g: sugarsPer100g ?? this.sugarsPer100g,
      saltPer100g: saltPer100g ?? this.saltPer100g,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      nutriScore: nutriScore ?? this.nutriScore,
      nutriScoreSource: nutriScoreSource ?? this.nutriScoreSource,
      novaGroup: novaGroup ?? this.novaGroup,
      novaGroupSource: novaGroupSource ?? this.novaGroupSource,
    );
  }

  /// OFF varsa resmi skor; yoksa mevcut (tahmin dahil) korunur. Uydurma yok.
  SafetyReport withOffScores({
    NutriScoreGrade? offNutri,
    NovaGroup? offNova,
  }) {
    return copyWith(
      nutriScore: offNutri ?? nutriScore,
      nutriScoreSource: offNutri != null
          ? LabelScoreSource.openfoodfacts
          : nutriScoreSource,
      novaGroup: offNova ?? novaGroup,
      novaGroupSource:
          offNova != null ? LabelScoreSource.openfoodfacts : novaGroupSource,
    );
  }

  /// OFF > tahmin > bilinmiyor. E/4 uydurulmaz.
  SafetyReport mergeLabelScores(SafetyReport? other) {
    if (other == null) return this;
    return copyWith(
      nutriScore: _preferNutri(this, other).$1,
      nutriScoreSource: _preferNutri(this, other).$2,
      novaGroup: _preferNova(this, other).$1,
      novaGroupSource: _preferNova(this, other).$2,
    );
  }

  /// Bakılan ama bulunamayan skorları [unknown] işaretle (yeniden OFF yok).
  SafetyReport markScoresLookedUp() {
    return copyWith(
      nutriScoreSource: nutriScore != null
          ? (nutriScoreSource ?? LabelScoreSource.estimate)
          : (nutriScoreSource ?? LabelScoreSource.unknown),
      novaGroupSource: novaGroup != null
          ? (novaGroupSource ?? LabelScoreSource.estimate)
          : (novaGroupSource ?? LabelScoreSource.unknown),
    );
  }

  bool scoresDiffer(SafetyReport other) {
    return nutriScore != other.nutriScore ||
        nutriScoreSource != other.nutriScoreSource ||
        novaGroup != other.novaGroup ||
        novaGroupSource != other.novaGroupSource;
  }

  static (NutriScoreGrade?, LabelScoreSource?) _preferNutri(
    SafetyReport a,
    SafetyReport b,
  ) {
    if (a.nutriScore != null && a.nutriScoreSource?.isOff == true) {
      return (a.nutriScore, a.nutriScoreSource);
    }
    if (b.nutriScore != null && b.nutriScoreSource?.isOff == true) {
      return (b.nutriScore, b.nutriScoreSource);
    }
    if (a.nutriScore != null) {
      return (a.nutriScore, a.nutriScoreSource ?? LabelScoreSource.estimate);
    }
    if (b.nutriScore != null) {
      return (b.nutriScore, b.nutriScoreSource ?? LabelScoreSource.estimate);
    }
    if (a.nutriScoreSource == LabelScoreSource.unknown ||
        b.nutriScoreSource == LabelScoreSource.unknown) {
      return (null, LabelScoreSource.unknown);
    }
    return (null, a.nutriScoreSource ?? b.nutriScoreSource);
  }

  static (NovaGroup?, LabelScoreSource?) _preferNova(
    SafetyReport a,
    SafetyReport b,
  ) {
    if (a.novaGroup != null && a.novaGroupSource?.isOff == true) {
      return (a.novaGroup, a.novaGroupSource);
    }
    if (b.novaGroup != null && b.novaGroupSource?.isOff == true) {
      return (b.novaGroup, b.novaGroupSource);
    }
    if (a.novaGroup != null) {
      return (a.novaGroup, a.novaGroupSource ?? LabelScoreSource.estimate);
    }
    if (b.novaGroup != null) {
      return (b.novaGroup, b.novaGroupSource ?? LabelScoreSource.estimate);
    }
    if (a.novaGroupSource == LabelScoreSource.unknown ||
        b.novaGroupSource == LabelScoreSource.unknown) {
      return (null, LabelScoreSource.unknown);
    }
    return (null, a.novaGroupSource ?? b.novaGroupSource);
  }

  static List<T> _mapList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) parse,
  ) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map<String, dynamic>)
          parse(e)
        else if (e is Map)
          parse(Map<String, dynamic>.from(e)),
    ];
  }

  /// Gemini bazen `["E500"]` veya `{code:"E500"}` döner; kodu kaçırma.
  static List<AdditiveHit> _mapAdditives(Object? raw) {
    if (raw is! List) return const [];
    final out = <AdditiveHit>[];
    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        out.add(AdditiveHit.fromJson(e));
      } else if (e is Map) {
        out.add(AdditiveHit.fromJson(Map<String, dynamic>.from(e)));
      } else {
        final s = e.toString().trim();
        if (s.isEmpty) continue;
        out.add(AdditiveHit(code: s, labelTr: s));
      }
    }
    return out;
  }

  static String? _emptyToNull(Object? raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty || s.length > 28) return null;
    return s;
  }

  static double? _asDouble(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim().replaceAll(',', '.');
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  static int? _asInt(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    return int.tryParse(raw.toString().trim());
  }
}

class ProductRecord {
  const ProductRecord({
    required this.barcode,
    this.id,
    this.productName,
    this.ingredients,
    this.safety = const SafetyReport(),
    this.imageUrl,
    this.source = 'openfoodfacts',
    this.fromCache = false,
  });

  final String? id;
  final String barcode;
  final String? productName;
  final String? ingredients;
  final SafetyReport safety;
  final String? imageUrl;
  final String source;
  final bool fromCache;

  bool get isFound =>
      (productName != null && productName!.trim().isNotEmpty) ||
      (ingredients != null && ingredients!.trim().isNotEmpty);

  bool get hasUsableIngredients => isUsableIngredientText(ingredients);

  /// Katkı barı için: gerçek içindekiler metni (ad / NOVA / katkı listesi yetmez).
  bool get knowsIngredientList =>
      hasUsableIngredients ||
      isUsableIngredientText(safety.ingredientsSummary);

  /// Ad / alerjen etiketi tek başına yetmez. Gerçek içindekiler veya dolu rapor.
  bool get isComplete => hasUsableIngredients || safety.hasUsableContent;

  static bool isUsableIngredientText(String? raw) {
    final s = raw?.trim() ?? '';
    if (s.length < 4) return false;
    var folded = s.toLowerCase();
    folded = folded
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    const thin = <String>[
      'icindekiler metni sinirli',
      'icindekiler metni yok',
      'icerik bilgisi sinirli',
      'urun bilgisi sinirli',
      'icerik yok',
      'etiket okunamadi',
      'bilinmiyor',
      'bilgi yok',
      'unknown',
      'n/a',
      'not available',
      'none',
      'yok',
    ];
    for (final t in thin) {
      if (folded == t || folded.startsWith('$t.') || folded.startsWith('$t;')) {
        return false;
      }
    }
    return true;
  }

  factory ProductRecord.fromJson(
    Map<String, dynamic> json, {
    bool fromCache = false,
  }) {
    final reportRaw = json['safety_report'];
    Map<String, dynamic>? report;
    if (reportRaw is Map<String, dynamic>) {
      report = reportRaw;
    } else if (reportRaw is Map) {
      report = Map<String, dynamic>.from(reportRaw);
    }

    return ProductRecord(
      id: json['id']?.toString(),
      barcode: json['barcode']?.toString() ?? '',
      productName: _emptyToNull(json['product_name'] ?? json['productName']),
      ingredients: _emptyToNull(json['ingredients']),
      safety: SafetyReport.fromJson(report),
      imageUrl: _emptyToNull(json['image_url'] ?? json['imageUrl']),
      source: json['source']?.toString() ?? 'openfoodfacts',
      fromCache: fromCache,
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'barcode': barcode.trim(),
        'product_name': productName,
        'ingredients': ingredients,
        'safety_report': safety.toJson(),
        if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          'image_url': imageUrl!.trim(),
        'source': source,
      };

  ProductRecord copyWith({
    String? barcode,
    String? productName,
    String? ingredients,
    SafetyReport? safety,
    String? imageUrl,
    bool? fromCache,
    String? source,
  }) {
    return ProductRecord(
      id: id,
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      ingredients: ingredients ?? this.ingredients,
      safety: safety ?? this.safety,
      imageUrl: imageUrl ?? this.imageUrl,
      source: source ?? this.source,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  static String? _emptyToNull(Object? raw) {
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return null;
    return s;
  }
}
