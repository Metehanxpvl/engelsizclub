import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/product_safety.dart';
import '../utils/async_timeout.dart';

/// Open Food Facts — ücretsiz, API anahtarı yok.
/// https://world.openfoodfacts.org/api
class OpenFoodFactsService {
  OpenFoodFactsService._();

  static const _userAgent =
      'EngelsizClub/1.0 (https://engelsizclub.com; aile@engelsizclub.com)';

  /// Web XHR cannot set User-Agent (CORS preflight). Native keeps the OFF UA.
  static Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (!kIsWeb) 'User-Agent': _userAgent,
      };

  static const _searchFields =
      'code,product_name,product_name_tr,generic_name,generic_name_tr,'
      'brands,brand,image_front_small_url,image_front_url,image_url,'
      'countries_tags,ingredients_text,ingredients_text_tr';

  static final _fields = [
    'product_name',
    'product_name_tr',
    'generic_name',
    'generic_name_tr',
    'brands',
    'brand',
    'quantity',
    'serving_size',
    'ingredients_text',
    'ingredients_text_tr',
    'allergens',
    'allergens_tags',
    'allergens_from_ingredients',
    'traces',
    'traces_tags',
    'additives_tags',
    'additives_original_tags',
    'image_url',
    'image_front_url',
    'nutriments',
    'categories_tags',
    'labels_tags',
    'nutriscore_grade',
    'nutrition_grades',
    'nutrition_grade_fr',
    'nova_group',
    'nova_groups',
  ].join(',');

  /// Ürün yoksa `null`.
  static Future<OffProduct?> fetchByBarcode(String barcode) async {
    final code = normalizeBarcode(barcode);
    if (code == null) return null;

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$code.json',
    ).replace(queryParameters: {'fields': _fields, 'lc': 'tr'});

    final res = await withNetworkTimeout(
      http.get(uri, headers: _headers),
      timeout: const Duration(seconds: 15),
      message: 'Open Food Facts yanıt vermedi. Lütfen tekrar deneyin.',
    );

    if (res.statusCode == 404) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Open Food Facts hata (${res.statusCode}).');
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) return null;

    final status = decoded['status'];
    if (status == 0 || status == '0') return null;

    final product = decoded['product'];
    if (product is! Map<String, dynamic>) return null;

    return OffProduct.fromApi(code, product);
  }

  static String? normalizeBarcode(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 4 || digits.length > 18) return null;
    return digits;
  }

  static bool isNameCacheKey(String raw) =>
      raw.trim().toLowerCase().startsWith('name:');

  /// Barkod yoksa önbellek anahtarı (`name:ulker-cikolata`). En az 4 karakter.
  static String nameCacheKey(String name) {
    var s = name.trim().toLowerCase();
    s = s
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c');
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    s = s.replaceAll(RegExp(r'-{2,}'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    if (s.length > 72) s = s.substring(0, 72);
    if (s.length < 2) s = 'item';
    return 'name:$s';
  }

  /// Ada göre açık veri araması. Türkiye eşleşmeleri öne alınır;
  /// TR filtresi boşaltırsa dünya sonuçları korunur (içecekler dahil).
  static Future<List<OffSearchHit>> searchByName(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];

    List<OffSearchHit> hits = const [];
    try {
      hits = await _searchCgi(q, countryCode: 'tr');
    } catch (e, st) {
      debugPrint('OFF cgi arama (tr): $e\n$st');
    }
    if (hits.isEmpty) {
      try {
        hits = await _searchCgi(q, countryCode: null);
      } catch (e, st) {
        debugPrint('OFF cgi arama (dünya): $e\n$st');
      }
    }
    if (hits.length < 5) {
      try {
        final extra = await _searchApiV2(q);
        hits = _mergeHits(hits, extra);
      } catch (e, st) {
        debugPrint('OFF v2 arama: $e\n$st');
      }
    }
    hits.sort(_compareTurkeyFirst);
    if (hits.length > 20) return hits.sublist(0, 20);
    return hits;
  }

  static Future<List<OffSearchHit>> _searchCgi(
    String q, {
    String? countryCode,
  }) async {
    final params = <String, String>{
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '20',
      'lc': 'tr',
    };
    if (countryCode != null && countryCode.trim().isNotEmpty) {
      params['cc'] = countryCode.trim();
    }
    return _parseSearchResponse(await _getSearch(
      Uri.parse('https://world.openfoodfacts.org/cgi/search.pl')
          .replace(queryParameters: params),
    ));
  }

  static Future<List<OffSearchHit>> _searchApiV2(String q) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/search',
    ).replace(queryParameters: {
      'search_terms': q,
      'page_size': '20',
      'lc': 'tr',
      'fields': _searchFields,
    });
    return _parseSearchResponse(await _getSearch(uri));
  }

  static Future<http.Response> _getSearch(Uri uri) {
    return withNetworkTimeout(
      http.get(uri, headers: _headers),
      timeout: const Duration(seconds: 15),
      message: 'Open Food Facts arama yanıt vermedi.',
    );
  }

  static List<OffSearchHit> _parseSearchResponse(http.Response res) {
    if (res.statusCode == 429 ||
        res.statusCode == 502 ||
        res.statusCode == 503 ||
        res.statusCode == 504) {
      debugPrint('OFF arama ${res.statusCode}; boş liste (yedek denenecek).');
      return const [];
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('Open Food Facts arama hata (${res.statusCode}).');
    }
    final body = res.body.trimLeft();
    if (body.isEmpty || body.startsWith('<')) {
      debugPrint('OFF arama JSON değil; boş liste.');
      return const [];
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return const [];
    final raw = decoded['products'] ?? decoded['hits'];
    if (raw is! List) return const [];
    final out = <OffSearchHit>[];
    for (final e in raw) {
      if (e is! Map) continue;
      final map = Map<String, dynamic>.from(e);
      final hit = OffSearchHit.fromApi(map);
      if (hit != null) out.add(hit);
    }
    return out;
  }

  static List<OffSearchHit> _mergeHits(
    List<OffSearchHit> a,
    List<OffSearchHit> b,
  ) {
    final seen = <String>{};
    final out = <OffSearchHit>[];
    for (final h in [...a, ...b]) {
      final k = (h.barcode ?? h.cacheKey).toLowerCase();
      if (!seen.add(k)) continue;
      out.add(h);
    }
    return out;
  }

  static int _compareTurkeyFirst(OffSearchHit a, OffSearchHit b) {
    final t = (b.turkeyPreferred ? 1 : 0) - (a.turkeyPreferred ? 1 : 0);
    if (t != 0) return t;
    final ing = (b.hasIngredients ? 1 : 0) - (a.hasIngredients ? 1 : 0);
    if (ing != 0) return ing;
    final code = (b.barcode != null ? 1 : 0) - (a.barcode != null ? 1 : 0);
    return code;
  }
}

/// Ada göre arama satırı (barkod yoksa [cacheKey] = name:…).
class OffSearchHit {
  const OffSearchHit({
    required this.cacheKey,
    required this.productName,
    this.barcode,
    this.brand,
    this.imageUrl,
    this.turkeyPreferred = false,
    this.hasIngredients = false,
  });

  final String cacheKey;
  final String productName;
  final String? barcode;
  final String? brand;
  final String? imageUrl;
  final bool turkeyPreferred;
  final bool hasIngredients;

  static OffSearchHit? fromApi(Map<String, dynamic> p) {
    final name = OffProduct._firstNonEmpty([
      p['product_name_tr'],
      p['generic_name_tr'],
      p['product_name'],
      p['generic_name'],
    ]);
    if (name == null || name.trim().length < 2) return null;
    final code = OpenFoodFactsService.normalizeBarcode(
      p['code']?.toString() ?? p['barcode']?.toString() ?? '',
    );
    final brand = OffProduct._firstNonEmpty([p['brands'], p['brand']]);
    final image = OffProduct._firstNonEmpty([
      p['image_front_small_url'],
      p['image_front_url'],
      p['image_url'],
    ]);
    final countries = OffProduct._asStringList(p['countries_tags']);
    final turkey = countries.any((c) {
      final s = c.toLowerCase().replaceFirst(RegExp(r'^[a-z]{2}:'), '');
      return s == 'tr' ||
          s == 'turkey' ||
          s == 'turkiye' ||
          s == 'türkiye' ||
          s.contains('turkey') ||
          s.contains('turkiye') ||
          s.contains('türkiye');
    });
    final ingredients = OffProduct._firstNonEmpty([
      p['ingredients_text_tr'],
      p['ingredients_text'],
    ]);
    return OffSearchHit(
      cacheKey: code ?? OpenFoodFactsService.nameCacheKey(name),
      productName: name.trim(),
      barcode: code,
      brand: brand,
      imageUrl: image,
      turkeyPreferred: turkey,
      hasIngredients: ProductRecord.isUsableIngredientText(ingredients),
    );
  }
}

class OffProduct {
  const OffProduct({
    required this.barcode,
    this.productName,
    this.brand,
    this.quantity,
    this.ingredients,
    this.imageUrl,
    this.allergenTags = const [],
    this.allergenText = '',
    this.additiveTags = const [],
    this.tracesText = '',
    this.sugarsPer100g,
    this.saltPer100g,
    this.caffeineMg,
    this.categories = const [],
    this.nutriScore,
    this.novaGroup,
  });

  final String barcode;
  final String? productName;
  final String? brand;
  final String? quantity;
  final String? ingredients;
  final String? imageUrl;
  final List<String> allergenTags;
  final String allergenText;
  final List<String> additiveTags;
  final String tracesText;
  final double? sugarsPer100g;
  final double? saltPer100g;
  final double? caffeineMg;
  final List<String> categories;
  final NutriScoreGrade? nutriScore;
  final NovaGroup? novaGroup;

  /// Kısa Türkçe chip (CİPS…). Eşleşme yoksa null — uydurulmaz.
  String? get categoryLabel => categoryChipFromTags(categories);

  bool get hasUsableIngredients =>
      ProductRecord.isUsableIngredientText(ingredients);

  /// Ad tek başına tam kayıt değildir. Gerçek içindekiler gerekir.
  bool get isComplete => hasUsableIngredients;

  /// Gemini metin isteği için OFF alanları (görsel yok).
  String get catalogHint {
    final lines = <String>[
      if ((brand ?? '').trim().isNotEmpty) 'brand: ${brand!.trim()}',
      if ((quantity ?? '').trim().isNotEmpty) 'quantity: ${quantity!.trim()}',
      if (allergenText.trim().isNotEmpty) 'allergens: ${allergenText.trim()}',
      if (tracesText.trim().isNotEmpty) 'traces: ${tracesText.trim()}',
      if (additiveTags.isNotEmpty)
        'additive_tags: ${additiveTags.take(24).join(', ')}',
      if (categories.isNotEmpty)
        'categories: ${categories.take(12).join(', ')}',
      if (sugarsPer100g != null) 'sugars_100g: $sugarsPer100g',
      if (saltPer100g != null) 'salt_100g: $saltPer100g',
      if (nutriScore != null) 'nutriscore_grade: ${nutriScore!.letter}',
      if (novaGroup != null) 'nova_group: ${novaGroup!.number}',
    ];
    return lines.join('\n');
  }

  factory OffProduct.fromApi(String barcode, Map<String, dynamic> p) {
    final name = _firstNonEmpty([
      p['product_name_tr'],
      p['generic_name_tr'],
      p['product_name'],
      p['generic_name'],
    ]);
    final ingredients = _firstNonEmpty([
      p['ingredients_text_tr'],
      p['ingredients_text'],
    ]);
    final image = _firstNonEmpty([
      p['image_front_url'],
      p['image_url'],
    ]);

    final nutriments = p['nutriments'];
    double? sugars;
    double? salt;
    double? caffeine;
    if (nutriments is Map) {
      sugars = _asDouble(
        nutriments['sugars_100g'] ?? nutriments['sugars'],
      );
      salt = _asDouble(
        nutriments['salt_100g'] ?? nutriments['salt'],
      );
      if (salt == null) {
        final sodium = _asDouble(
          nutriments['sodium_100g'] ?? nutriments['sodium'],
        );
        if (sodium != null) salt = sodium * 2.5;
      }
      caffeine = _asDouble(
        nutriments['caffeine_100g'] ?? nutriments['caffeine'],
      );
    }

    return OffProduct(
      barcode: barcode,
      productName: name,
      brand: _firstNonEmpty([p['brands'], p['brand']]),
      quantity: _firstNonEmpty([p['quantity'], p['serving_size']]),
      ingredients: ingredients,
      imageUrl: image,
      allergenTags: [
        ..._asStringList(p['allergens_tags']),
        ..._asStringList(p['traces_tags']),
      ],
      allergenText: [
        p['allergens'],
        p['allergens_from_ingredients'],
      ].whereType<Object>().map((e) => e.toString()).join(' '),
      additiveTags: [
        ..._asStringList(p['additives_tags']),
        ..._asStringList(p['additives_original_tags']),
      ],
      tracesText: p['traces']?.toString() ?? '',
      sugarsPer100g: sugars,
      saltPer100g: salt,
      caffeineMg: caffeine,
      categories: _asStringList(p['categories_tags']),
      nutriScore: NutriScoreGrade.tryParse(
        p['nutriscore_grade'] ??
            p['nutrition_grades'] ??
            p['nutrition_grade_fr'],
      ),
      novaGroup: NovaGroup.tryParse(p['nova_group'] ?? p['nova_groups']),
    );
  }

  ProductRecord toRecord(SafetyReport safety) {
    return ProductRecord(
      barcode: barcode,
      productName: productName,
      ingredients: ingredients,
      safety: safety,
      imageUrl: imageUrl,
      source: 'openfoodfacts',
    );
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final v in values) {
      final s = v?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return null;
  }

  static List<String> _asStringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e.toString().trim().isNotEmpty) e.toString().trim(),
    ];
  }

  static double? _asDouble(Object? raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw.replaceAll(',', '.'));
    return null;
  }

  static String? categoryChipFromTags(List<String> tags) {
    const map = <String, String>{
      'chips': 'CİPS',
      'crisps': 'CİPS',
      'potato-crisps': 'CİPS',
      'potato-chips': 'CİPS',
      'beverages': 'İÇECEK',
      'sodas': 'İÇECEK',
      'colas': 'İÇECEK',
      'soft-drinks': 'İÇECEK',
      'carbonated-drinks': 'İÇECEK',
      'ayrans': 'İÇECEK',
      'ayran': 'İÇECEK',
      'lassis': 'İÇECEK',
      'drinkable-yogurts': 'İÇECEK',
      'fermented-milk-drinks': 'İÇECEK',
      'yoghurt-drinks': 'İÇECEK',
      'fruit-juices': 'MEYVE SUYU',
      'fruit-juices-and-nectars': 'MEYVE SUYU',
      'waters': 'SU',
      'spring-waters': 'SU',
      'teas': 'ÇAY',
      'coffees': 'KAHVE',
      'yogurts': 'YOĞURT',
      'milks': 'SÜT',
      'cheeses': 'PEYNİR',
      'biscuits': 'BİSKÜVİ',
      'cookies': 'BİSKÜVİ',
      'chocolates': 'ÇİKOLATA',
      'confectioneries': 'ŞEKERLEME',
      'candies': 'ŞEKERLEME',
      'breads': 'EKMEK',
      'breakfast-cereals': 'KAHVALTILIK',
      'pastas': 'MAKARNA',
      'ice-creams': 'DONDURMA',
      'jams': 'REÇEL',
      'sauces': 'SOS',
      'snacks': 'ATIŞTIRMALIK',
      'salty-snacks': 'ATIŞTIRMALIK',
      'baby-foods': 'BEBEK MAMASI',
      'frozen-foods': 'DONDURULMUŞ',
    };
    for (final raw in tags) {
      final slug = raw.toLowerCase().replaceFirst(RegExp(r'^[a-z]{2}:'), '');
      final direct = map[slug];
      if (direct != null) return direct;
    }
    for (final raw in tags) {
      final slug = raw.toLowerCase().replaceFirst(RegExp(r'^[a-z]{2}:'), '');
      for (final e in map.entries) {
        if (slug == e.key || slug.endsWith('-${e.key}')) return e.value;
      }
    }
    return null;
  }
}
