import '../models/product_safety.dart';
import 'e_number_explanations.dart';

/// FAO 2019 / Open Food Facts pratik NOVA: yalnız içindekiler + katkı sınıfı.
/// Fabrika süreci uydurulmaz. İşaret yoksa veya liste okunamazsa null.
class NovaFromIngredients {
  NovaFromIngredients._();

  /// OFF varsa dokunma. Yoksa etiket kuralı; o da yoksa rapor aynı kalır.
  static SafetyReport applyIfMissing(
    SafetyReport report, {
    String? ingredients,
  }) {
    if (report.novaGroup != null) return report;
    final group = classify(
      ingredients: [
        ingredients,
        report.ingredientsSummary,
      ].whereType<String>().join('\n'),
      additives: report.additives,
    );
    if (group == null) return report;
    return report.copyWith(
      novaGroup: group,
      novaGroupSource: LabelScoreSource.estimate,
    );
  }

  static NovaGroup? classify({
    String? ingredients,
    Iterable<AdditiveHit> additives = const [],
  }) {
    final raw = (ingredients ?? '').trim();
    final folded = _fold(raw);
    final usable = ProductRecord.isUsableIngredientText(raw) ||
        (folded.isNotEmpty &&
            (_isCulinary(folded) || _isWholeFood(folded)));
    final codes = <String>{
      for (final a in additives)
        if (ENumberExplanations.normalizeCode(a.code).startsWith('e'))
          ENumberExplanations.normalizeCode(a.code),
      ...ENumberExplanations.extractECodes(raw),
    };

    if (!usable && codes.isEmpty) return null;

    if (_hasIndustrialMarker(folded) ||
        codes.any(_isCosmeticAdditive)) {
      return NovaGroup.four;
    }

    if (!usable) return null;

    final parts = _parts(folded);
    if (parts.isEmpty) return null;

    var culinary = 0;
    var whole = 0;
    for (final p in parts) {
      if (_isCulinary(p)) {
        culinary++;
      } else if (_isWholeFood(p)) {
        whole++;
      } else {
        // Tanınmayan parça: 1–3 uydurma.
        return null;
      }
    }

    if (whole == 0 && culinary > 0) return NovaGroup.two;
    if (whole > 0 && culinary == 0) return NovaGroup.one;
    if (whole > 0 && culinary > 0) return NovaGroup.three;
    return null;
  }

  static bool _isCosmeticAdditive(String code) {
    final info = ENumberExplanations.lookup(code);
    if (info != null) {
      final fn = _fold(info.functionTr);
      const markers = <String>[
        'renklendirici',
        'emulgator',
        'tatlandirici',
        'lezzet arttirici',
        'lezzet artirici',
        'kivam',
        'jelestirici',
        'parlatici',
        'dolgu',
        'nem tutucu',
        'modifiye nisasta',
      ];
      if (markers.any(fn.contains)) return true;
    }
    final m = RegExp(r'^e(\d{3,4})').firstMatch(code);
    if (m == null) return false;
    final n = int.tryParse(m.group(1)!);
    if (n == null) return false;
    if (n >= 100 && n <= 199) return true; // renk
    if (n >= 400 && n <= 499) return true; // emülgatör / kıvam
    if (n >= 620 && n <= 640) return true; // lezzet artırıcı
    if (n >= 950 && n <= 969) return true; // tatlandırıcı
    if (n >= 1400 && n <= 1451) return true; // modifiye nişasta
    return false;
  }

  static bool _hasIndustrialMarker(String folded) {
    const keys = <String>[
      'aroma',
      'aromasi',
      'aromalandirici',
      'flavor',
      'flavour',
      'flavouring',
      'hidrolize',
      'hydrolyzed',
      'hydrolysed',
      'hidrojenize',
      'hydrogenated',
      'maltodekstrin',
      'maltodextrin',
      'glukoz surubu',
      'glukoz-fruktoz',
      'glukoz fruktoz',
      'fruktoz surubu',
      'glucose syrup',
      'fructose syrup',
      'high fructose',
      'misir surubu',
      'invert seker',
      'inverted sugar',
      'invert sugar',
      'modifiye nisasta',
      'modified starch',
      'protein izolat',
      'protein isolate',
      'izole protein',
      'whey protein',
      'peynir alti suyu tozu',
      'peyniralti suyu tozu',
      'kazeinat',
      'caseinate',
      'monosodyum glutamat',
      'monosodium glutamate',
      'emulgator',
      'emulsifier',
      'stabilizator',
      'stabiliser',
      'stabilizer',
      'kivam arttirici',
      'kivam artirici',
      'thickener',
      'renk verici',
      'renklendirici',
      'colour',
      'colorant',
      'tatlandirici',
      'sweetener',
      'aspartam',
      'asesulfam',
      'sukraloz',
      'sakarin',
    ];
    return keys.any(folded.contains);
  }

  static List<String> _parts(String folded) {
    final cleaned = folded
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .replaceAll(RegExp(r'\d+(?:[.,]\d+)?\s*%'), ' ');
    final raw = cleaned.split(RegExp(r'[,;•|\n/]+|\s+ve\s+|\.(?:\s|$)'));
    final out = <String>[];
    for (final piece in raw) {
      var p = piece.trim();
      p = p.replaceAll(RegExp(r'^[-–—.:]+|[-–—.:]+$'), '').trim();
      if (p.isEmpty) continue;
      if (_isIgnore(p)) continue;
      out.add(p);
    }
    return out;
  }

  static bool _isIgnore(String p) {
    const exact = <String>{
      'icindekiler',
      'icerik',
      'ingredients',
      'ingredient',
      'su',
      'icme suyu',
      'water',
      'aqua',
      'mayali su',
    };
    if (exact.contains(p)) return true;
    if (p.startsWith('icindekiler')) return true;
    if (p.contains('iz miktarda') || p.contains('eser miktarda')) return true;
    if (p.contains('may contain') || p.contains('alerjen')) return true;
    if (RegExp(r'^e\d{3,4}[a-z]{0,3}$').hasMatch(p)) return true;
    const additiveNames = <String>[
      'sitrik asit',
      'citric acid',
      'askorbik asit',
      'ascorbic acid',
      'laktik asit',
      'lactic acid',
      'asetik asit',
      'acetic acid',
      'potasyum sorbat',
      'sodyum benzoat',
      'sodyum karbonat',
      'sodyum bikarbonat',
      'karbonat',
      'asitlik duzenleyici',
      'koruyucu',
      'antioksidan',
    ];
    if (additiveNames.any((k) => p == k || p.startsWith('$k '))) return true;
    return false;
  }

  static bool _isCulinary(String p) {
    const keys = <String>[
      'tuz',
      'deniz tuzu',
      'kaya tuzu',
      'salt',
      'sea salt',
      'seker',
      'toz seker',
      'kesme seker',
      'sugar',
      'sucrose',
      'bal',
      'honey',
      'sirke',
      'uzum sirkesi',
      'elma sirkesi',
      'vinegar',
      'yag',
      'zeytinyagi',
      'zeytin yagi',
      'aycicek yagi',
      'aycicegi yagi',
      'misir yagi',
      'kanola yagi',
      'tereyag',
      'tereyagi',
      'bitkisel yag',
      'palm yagi',
      'oil',
      'olive oil',
      'sunflower oil',
      'butter',
    ];
    return keys.any((k) => _tokenHas(p, k));
  }

  static bool _isWholeFood(String p) {
    const keys = <String>[
      'sut',
      'sut tozu',
      'yogurt',
      'ayran',
      'kefir',
      'peynir',
      'lor',
      'yumurta',
      'un',
      'bugday unu',
      'tam bugday',
      'pirinc',
      'pirinc unu',
      'patates',
      'elma',
      'muz',
      'armut',
      'portakal',
      'limon',
      'cilek',
      'uzum',
      'domates',
      'salatalik',
      'havuc',
      'sogan',
      'sarimsak',
      'biber',
      'et',
      'tavuk',
      'dana',
      'kuzu',
      'hindi',
      'balik',
      'ton',
      'somon',
      'mercimek',
      'nohut',
      'fasulye',
      'bezelye',
      'zeytin',
      'ceviz',
      'findik',
      'badem',
      'yulaf',
      'misir',
      'arpa',
      'bulgur',
      'kinoa',
      'makarna',
      'sehriye',
      'kakao',
      'kahve',
      'cay',
      'maya',
      'yeast',
      'kultur',
      'starter',
      'milk',
      'egg',
      'flour',
      'wheat',
      'rice',
      'potato',
      'tomato',
      'apple',
      'banana',
      'chicken',
      'beef',
      'fish',
      'oat',
      'lentil',
      'chickpea',
      'bean',
    ];
    return keys.any((k) => _tokenHas(p, k));
  }

  static bool _tokenHas(String part, String key) {
    if (part == key) return true;
    if (key.length <= 3) {
      return RegExp('(?:^|\\s)$key(?:\\s|\$)').hasMatch(part);
    }
    return part == key ||
        part.startsWith('$key ') ||
        part.endsWith(' $key') ||
        part.contains(' $key ');
  }

  static String _fold(String s) {
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
}
