import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product_safety.dart';
import '../utils/async_timeout.dart';
import 'allergen_analyzer.dart';
import 'gemini_service.dart';
import 'open_food_facts_service.dart';
import 'r2_storage_service.dart';

enum ProductLookupStatus {
  cached,
  fetched,
  needsLabelPhoto,
  needsLlmKey,
  notFound,
}

class ProductLookupResult {
  const ProductLookupResult({
    required this.status,
    this.product,
    this.error,
    this.barcode,
  });

  final ProductLookupStatus status;
  final ProductRecord? product;
  final String? error;
  final String? barcode;

  bool get isNotFound => status == ProductLookupStatus.notFound;
  bool get needsPhoto => status == ProductLookupStatus.needsLabelPhoto;
  bool get needsKey => status == ProductLookupStatus.needsLlmKey;
  bool get isIncomplete =>
      product != null && !product!.isComplete;
}

/// Ada göre arama sonucu (önbellek veya Open Food Facts).
class ProductNameHit {
  const ProductNameHit({
    required this.cacheKey,
    required this.name,
    this.brand,
    this.imageUrl,
    this.source = 'cache',
    this.barcode,
  });

  final String cacheKey;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String source;
  final String? barcode;
}

/// Önbellek (Supabase `products`) + eksik barkod akışı.
///
/// Tam kayıt (gerçek içindekiler veya dolu safety_report) → hemen göster.
/// Yalnız ad / boş içindekiler → Open Food Facts, sonra Gemini **metin**
/// (barkod + ad; fotoğraf zorunlu değil). Fotoğraf isteğe bağlı netleştirme.
class ProductRepository {
  ProductRepository._();

  static const needsPhotoMessage =
      'Bu barkod açık kaynakta yok. İsteğe bağlı etiket fotoğrafı '
      'daha net içindekiler sağlayabilir.';

  static const incompleteIngredientsMessage =
      'Ürün bulundu; içindekiler etiketten tamamlanıyor. '
      'İsterseniz daha net için etiket fotoğrafı ekleyebilirsiniz.';

  static const retakeIngredientsPhotoMessage =
      'İçindekiler belirsiz. Daha net için isteğe bağlı etiket fotoğrafı çekebilirsiniz.';

  static const needsKeyMessage =
      'Analiz anahtarı tanımlı değil (GEMINI_API_KEY veya proxy).';

  static SupabaseClient get _db => Supabase.instance.client;

  static Future<ProductLookupResult> lookup(
    String rawBarcode, {
    Uint8List? labelImageBytes,
    String imageContentType = 'image/jpeg',
    String? ocrText,
    String? productHint,
    String? brandHint,
  }) async {
    final photoBytes =
        (labelImageBytes != null && labelImageBytes.isNotEmpty)
            ? labelImageBytes
            : null;
    final hasPhoto = photoBytes != null;
    final text = (ocrText ?? '').trim();
    final trimmed = rawBarcode.trim();
    final nameKey =
        OpenFoodFactsService.isNameCacheKey(trimmed) ? trimmed : null;
    final ean = nameKey == null
        ? OpenFoodFactsService.normalizeBarcode(trimmed)
        : null;
    final cacheKey = ean ?? nameKey;

    if (cacheKey == null && !hasPhoto && text.isEmpty) {
      return const ProductLookupResult(
        status: ProductLookupStatus.notFound,
        error: 'Geçerli bir barkod değil.',
      );
    }

    try {
      ProductRecord? seed;
      OffProduct? off;
      final hintName = (productHint ?? '').trim();
      if (nameKey != null && hintName.isNotEmpty) {
        seed = ProductRecord(
          barcode: nameKey,
          productName: hintName,
        );
      }

      if (cacheKey != null) {
        final cached = await findByBarcode(cacheKey);
        if (cached != null) {
          if (_isCacheComplete(cached) &&
              !hasPhoto &&
              cached.safety.hasScoreLookup) {
            return ProductLookupResult(
              status: ProductLookupStatus.cached,
              product: cached,
              barcode: cacheKey,
            );
          }
          seed = _mergeEnrich(seed, cached);
          if (_isCacheComplete(cached) &&
              !hasPhoto &&
              !cached.safety.hasScoreLookup) {
            try {
              off = ean == null
                  ? null
                  : await OpenFoodFactsService.fetchByBarcode(ean);
              final filled = cached.copyWith(
                safety: cached.safety
                    .withOffScores(
                      offNutri: off?.nutriScore,
                      offNova: off?.novaGroup,
                    )
                    .markScoresLookedUp(),
              );
              final stored = await save(filled);
              return ProductLookupResult(
                status: ProductLookupStatus.cached,
                product: stored,
                barcode: cacheKey,
              );
            } catch (e, st) {
              debugPrint('OFF skor doldurma atlandı: $e\n$st');
              return ProductLookupResult(
                status: ProductLookupStatus.cached,
                product: cached,
                barcode: cacheKey,
              );
            }
          }
        }
      }

      if (ean != null) {
        off ??= await OpenFoodFactsService.fetchByBarcode(ean);
        if (off != null) {
          final safety = AllergenAnalyzer.analyze(
            off: off,
            ingredients: off.ingredients,
            productName: off.productName,
          ).markScoresLookedUp();
          var record = off.toRecord(safety);
          record = await _attachImage(
            record,
            code: ean,
            bytes: photoBytes,
            contentType: imageContentType,
          );
          seed = _mergeEnrich(seed, record);
          if (record.hasUsableIngredients && !hasPhoto) {
            final stored = await save(record);
            return ProductLookupResult(
              status: ProductLookupStatus.fetched,
              product: stored,
              barcode: ean,
            );
          }
        }
      }

      if (!hasPhoto && text.isEmpty) {
        final code = cacheKey;
        if (code != null && GeminiService.canCall) {
          return _enrichWithGeminiText(
            ean: code,
            seed: seed,
            off: off,
            productHint: hintName.isNotEmpty
                ? hintName
                : (seed?.productName ?? off?.productName ?? ''),
            brandHint: brandHint ?? off?.brand,
          );
        }
        if (seed != null && seed.isFound) {
          await save(seed);
          return ProductLookupResult(
            status: ProductLookupStatus.fetched,
            product: seed,
            barcode: cacheKey ?? seed.barcode,
            error: GeminiService.canCall
                ? incompleteIngredientsMessage
                : needsKeyMessage,
          );
        }
        if (!GeminiService.canCall) {
          return ProductLookupResult(
            status: ProductLookupStatus.needsLlmKey,
            product: seed,
            barcode: cacheKey ?? seed?.barcode,
            error: needsKeyMessage,
          );
        }
        return ProductLookupResult(
          status: ProductLookupStatus.notFound,
          barcode: cacheKey,
          error: needsPhotoMessage,
        );
      }

      if (hasPhoto && !GeminiService.hasVision && !GeminiService.canCall) {
        return ProductLookupResult(
          status: ProductLookupStatus.needsLlmKey,
          product: seed,
          barcode: ean ?? seed?.barcode,
          error: needsKeyMessage,
        );
      }

      final photoKey = photoBytes == null ? null : _photoKey(photoBytes);
      if (ean == null && photoKey != null) {
        final cachedPhoto = await findByBarcode(photoKey);
        if (cachedPhoto != null && _isCacheComplete(cachedPhoto)) {
          return ProductLookupResult(
            status: ProductLookupStatus.cached,
            product: cachedPhoto,
            barcode: photoKey,
          );
        }
        seed ??= cachedPhoto;
      }

      final uploadKey = ean ?? photoKey ?? 'label';
      String? imageUrl;
      if (photoBytes != null) {
        try {
          imageUrl = await _uploadLabel(
            code: uploadKey,
            bytes: photoBytes,
            contentType: imageContentType,
          );
        } catch (e, st) {
          debugPrint('R2 etiket yükleme atlandı, Gemini devam: $e\n$st');
        }
      }

      final llmResult = await GeminiService.analyzeDetailed(
        barcode: ean ?? '',
        ocrText: text,
        productHint: seed?.productName ?? off?.productName,
        imageBytes: photoBytes,
        imageMimeType: imageContentType,
        brand: off?.brand,
        quantity: off?.quantity,
        offFields: off?.catalogHint,
      );
      var llm = llmResult.record;
      if (llm == null && ean != null && GeminiService.canCall) {
        debugPrint('Gemini görsel boş, metin deneniyor.');
        final textFill = await _enrichWithGeminiText(
          ean: ean,
          seed: seed,
          off: off,
        );
        if (textFill.product != null) return textFill;
      }
      if (llm == null) {
        final err = llmResult.error ??
            GeminiService.lastError ??
            'Analiz tamamlanamadı.';
        debugPrint('Gemini kayıt yok: $err');
        if (seed != null && seed.isFound) {
          await save(seed);
          return ProductLookupResult(
            status: ProductLookupStatus.fetched,
            product: seed,
            barcode: ean ?? seed.barcode,
            error: err,
          );
        }
        return ProductLookupResult(
          status: ProductLookupStatus.notFound,
          barcode: ean ?? photoKey,
          error: err,
        );
      }

      final extracted = OpenFoodFactsService.normalizeBarcode(llm.barcode);
      var resolved = extracted ?? ean ?? photoKey ?? llm.barcode.trim();
      if (resolved.isEmpty && photoKey != null) resolved = photoKey;
      if (resolved.isEmpty) {
        resolved = 'text_${DateTime.now().millisecondsSinceEpoch}';
      }

      if (extracted != null && extracted != ean) {
        final cachedByCode = await findByBarcode(extracted);
        if (cachedByCode != null && cachedByCode.hasUsableIngredients) {
          return ProductLookupResult(
            status: ProductLookupStatus.cached,
            product: cachedByCode,
            barcode: extracted,
          );
        }
        if (cachedByCode != null) {
          seed = _mergeEnrich(seed, cachedByCode);
        }
      }

      var record = llm.barcode == resolved
          ? llm
          : llm.copyWith(barcode: resolved);
      if (imageUrl != null) {
        record = record.copyWith(imageUrl: imageUrl);
      }
      record = _mergeEnrich(seed, record);
      record = _withOffScores(record, off);
      if (record.barcode != resolved) {
        record = record.copyWith(barcode: resolved);
      }

      if (!record.hasUsableIngredients) {
        await save(record);
        debugPrint('Gemini ad var, içindekiler belirsiz');
        return ProductLookupResult(
          status: ProductLookupStatus.fetched,
          product: record,
          barcode: resolved,
          error: record.isFound
              ? (llmResult.error ?? retakeIngredientsPhotoMessage)
              : (llmResult.error ?? 'Analiz tamamlanamadı.'),
        );
      }

      final stored = await save(record);
      return ProductLookupResult(
        status: ProductLookupStatus.fetched,
        product: stored,
        barcode: resolved,
      );
    } catch (e, st) {
      debugPrint('Barkod arama hatası: $e\n$st');
      return ProductLookupResult(
        status: ProductLookupStatus.notFound,
        barcode: ean,
        error: 'Arama hatası: $e',
      );
    }
  }

  /// Tam önbellek: gerçek içindekiler metni şart.
  /// Yalnız ad / alerjen etiketi / boş rapor → Gemini doldursun (ilaçtaki gibi).
  static bool _isCacheComplete(ProductRecord record) {
    return record.hasUsableIngredients;
  }

  static Future<ProductLookupResult> _enrichWithGeminiText({
    required String ean,
    ProductRecord? seed,
    OffProduct? off,
    String? productHint,
    String? brandHint,
  }) async {
    final hint = (productHint ?? seed?.productName ?? off?.productName ?? '')
        .trim();
    debugPrint('Gemini metin doldurma: barcode=$ean name=$hint');
    final llmResult = await GeminiService.analyzeDetailed(
      barcode: OpenFoodFactsService.isNameCacheKey(ean) ? '' : ean,
      productHint: hint,
      brand: (brandHint ?? off?.brand)?.trim(),
      quantity: off?.quantity,
      offFields: off?.catalogHint,
    );
    final llm = llmResult.record;
    if (llm == null) {
      final err = llmResult.error ??
          GeminiService.lastError ??
          'Analiz servisi yanıt vermedi.';
      if (seed != null && seed.isFound) {
        await save(seed);
        return ProductLookupResult(
          status: ProductLookupStatus.fetched,
          product: seed,
          barcode: ean,
          error: err,
        );
      }
      return ProductLookupResult(
        status: ProductLookupStatus.notFound,
        barcode: ean,
        error: err,
      );
    }
    var record = _mergeEnrich(seed, llm);
    record = _withOffScores(record, off);
    final extracted = OpenFoodFactsService.normalizeBarcode(llm.barcode);
    if (extracted != null) {
      record = record.copyWith(barcode: extracted);
    } else if (record.barcode.trim().isEmpty) {
      record = record.copyWith(barcode: ean);
    }
    final stored = await save(record);
    final shown = stored.isFound || stored.hasUsableIngredients
        ? stored
        : (seed != null && seed.isFound ? _mergeEnrich(seed, stored) : stored);
    if (!shown.isFound && !shown.hasUsableIngredients) {
      return ProductLookupResult(
        status: ProductLookupStatus.notFound,
        barcode: ean,
        product: shown.productName != null ? shown : seed,
        error: llmResult.error ??
            GeminiService.lastError ??
            'Ürün bilgisi tamamlanamadı.',
      );
    }
    return ProductLookupResult(
      status: ProductLookupStatus.fetched,
      product: shown,
      barcode: ean,
      error: shown.hasUsableIngredients
          ? null
          : (llmResult.error ?? retakeIngredientsPhotoMessage),
    );
  }

  static ProductRecord _mergeEnrich(
    ProductRecord? base,
    ProductRecord incoming,
  ) {
    if (base == null) return incoming;
    final incomingName = (incoming.productName ?? '').trim();
    final name = incomingName.isNotEmpty ? incoming.productName : base.productName;
    final ingredients = ProductRecord.isUsableIngredientText(incoming.ingredients)
        ? incoming.ingredients
        : (ProductRecord.isUsableIngredientText(base.ingredients)
            ? base.ingredients
            : (incoming.ingredients ?? base.ingredients));
    final safety = _mergeSafety(base.safety, incoming.safety);
    final incomingImage = (incoming.imageUrl ?? '').trim();
    final image =
        incomingImage.isNotEmpty ? incoming.imageUrl : base.imageUrl;
    final source = ProductRecord.isUsableIngredientText(incoming.ingredients)
        ? incoming.source
        : base.source;
    final barcode = base.barcode.trim().isNotEmpty
        ? base.barcode
        : incoming.barcode;
    return ProductRecord(
      id: base.id,
      barcode: barcode,
      productName: name,
      ingredients: ingredients,
      safety: safety,
      imageUrl: image,
      source: source,
      fromCache: false,
    );
  }

  static SafetyReport _mergeSafety(SafetyReport? base, SafetyReport incoming) {
    final primary = incoming.hasUsableContent
        ? incoming
        : ((base?.hasUsableContent ?? false) ? base! : incoming);
    return primary.mergeLabelScores(base).mergeLabelScores(incoming);
  }

  static ProductRecord _withOffScores(ProductRecord record, OffProduct? off) {
    return record.copyWith(
      safety: record.safety
          .withOffScores(offNutri: off?.nutriScore, offNova: off?.novaGroup)
          .markScoresLookedUp(),
    );
  }

  static String _photoKey(Uint8List bytes) {
    final hash = sha256.convert(bytes).toString();
    return 'photo_${hash.substring(0, 16)}';
  }

  static String _ilikeContains(String raw) {
    final s = raw
        .trim()
        .replaceAll('%', '')
        .replaceAll('_', '')
        .replaceAll(',', ' ')
        .replaceAll("'", '')
        .replaceAll(RegExp(r'\s+'), ' ');
    return '%$s%';
  }

  /// Ada göre: Supabase önbellek + Open Food Facts (içecekler dahil).
  /// TR tercihi sıralamada; boş liste olursa dünya sonuçları kalır.
  static Future<List<ProductNameHit>> searchByName(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final hits = <ProductNameHit>[];
    final seen = <String>{};

    void add(ProductNameHit hit) {
      final key = hit.cacheKey.trim().toLowerCase();
      if (key.isEmpty || !seen.add(key)) return;
      hits.add(hit);
    }

    try {
      final pattern = _ilikeContains(q);
      final rows = await withNetworkTimeout(
        _db
            .from('products')
            .select()
            .ilike('product_name', pattern)
            .limit(8),
        message: 'Ürün adı araması yanıt vermedi.',
      );
      for (final row in rows) {
        final rec = ProductRecord.fromJson(
          Map<String, dynamic>.from(row),
          fromCache: true,
        );
          final name = (rec.productName ?? '').trim();
          if (name.isEmpty) continue;
          add(
            ProductNameHit(
              cacheKey: rec.barcode,
              name: name,
              imageUrl: rec.imageUrl,
              source: 'cache',
              barcode: OpenFoodFactsService.normalizeBarcode(rec.barcode),
            ),
          );
      }
    } catch (e, st) {
      debugPrint('products ada arama: $e\n$st');
    }

    // Her zaman OFF birleştir — önbellek '%su%' gibi kısa içecek adlarını
    // doldurup açık veri aramasını atlamasın. Kategori / NOVA filtresi yok.
    try {
      final offHits = await OpenFoodFactsService.searchByName(q);
      for (final h in offHits) {
        add(
          ProductNameHit(
            cacheKey: h.cacheKey,
            name: h.productName,
            brand: h.brand,
            imageUrl: h.imageUrl,
            source: 'openfoodfacts',
            barcode: h.barcode,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('OFF ada arama: $e\n$st');
    }

    if (hits.length > 20) return hits.sublist(0, 20);
    return hits;
  }

  /// OFF/önbellek boşsa ürün adı ile Gemini metin (fotoğraf yok) — içecekler dahil.
  static Future<ProductNameHit?> searchNameWithGemini(String query) async {
    final hint = query.trim();
    if (hint.length < 2) return null;
    try {
      final key = OpenFoodFactsService.nameCacheKey(hint);
      final result = await lookup(key, productHint: hint);
      final rec = result.product;
      if (rec == null || !rec.isFound) return null;
      final name = (rec.productName ?? '').trim();
      return ProductNameHit(
        cacheKey: rec.barcode.trim().isEmpty ? key : rec.barcode,
        name: name.isEmpty ? hint : name,
        imageUrl: rec.imageUrl,
        source: 'llm',
        barcode: OpenFoodFactsService.normalizeBarcode(rec.barcode),
      );
    } catch (e, st) {
      debugPrint('Gemini ada arama: $e\n$st');
      return null;
    }
  }

  static Future<ProductRecord?> findByBarcode(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    try {
      final row = await withNetworkTimeout(
        _db.from('products').select().eq('barcode', code).maybeSingle(),
        message: 'Ürün önbelleği okunamadı.',
      );
      if (row == null) return null;
      return ProductRecord.fromJson(row, fromCache: true);
    } on PostgrestException catch (e) {
      debugPrint('products SELECT: ${e.message}');
      return null;
    }
  }

  /// Var olan tam kaydı ezmez. Eksik satırı içindekiler / rapor / görsel ile günceller.
  static Future<ProductRecord> save(ProductRecord product) async {
    final existing = await findByBarcode(product.barcode);
    if (existing != null && existing.hasUsableIngredients) {
      final merged = existing.safety.mergeLabelScores(product.safety);
      if (existing.safety.scoresDiffer(merged)) {
        return _update(existing.copyWith(safety: merged.markScoresLookedUp()));
      }
      return existing;
    }
    if (existing == null) {
      return insertIfAbsent(product);
    }
    return _update(product);
  }

  /// Var olan satırı güncellemez. Çakışmada tekrar okur.
  static Future<ProductRecord> insertIfAbsent(ProductRecord product) async {
    final existing = await findByBarcode(product.barcode);
    if (existing != null) return existing;

    try {
      final row = await withNetworkTimeout(
        _db.from('products').insert(product.toInsertJson()).select().single(),
        message: 'Ürün önbelleğe yazılamadı.',
      );
      return ProductRecord.fromJson(row, fromCache: true);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final again = await findByBarcode(product.barcode);
        if (again != null) return again;
      }
      debugPrint('products INSERT atlandı: ${e.message}');
      return product;
    } catch (e, st) {
      debugPrint('products INSERT atlandı: $e\n$st');
      return product;
    }
  }

  static Future<ProductRecord> _update(ProductRecord product) async {
    try {
      final row = await withNetworkTimeout(
        _db
            .from('products')
            .update(product.toInsertJson())
            .eq('barcode', product.barcode.trim())
            .select()
            .maybeSingle(),
        message: 'Ürün önbelleği güncellenemedi.',
      );
      if (row != null) {
        return ProductRecord.fromJson(row, fromCache: true);
      }
      debugPrint('products UPDATE boş döndü (RLS veya satır yok).');
      return product;
    } on PostgrestException catch (e) {
      debugPrint('products UPDATE atlandı: ${e.message}');
      return product;
    } catch (e, st) {
      debugPrint('products UPDATE atlandı: $e\n$st');
      return product;
    }
  }

  static Future<ProductRecord> _attachImage(
    ProductRecord record, {
    required String code,
    Uint8List? bytes,
    required String contentType,
  }) async {
    if (bytes == null || bytes.isEmpty) return record;
    try {
      final url = await _uploadLabel(
        code: code,
        bytes: bytes,
        contentType: contentType,
      );
      if (url == null) return record;
      return record.copyWith(imageUrl: url);
    } catch (e, st) {
      debugPrint('R2 etiket görseli atlandı: $e\n$st');
      return record;
    }
  }

  static Future<String?> _uploadLabel({
    required String code,
    required Uint8List bytes,
    required String contentType,
  }) {
    final key =
        'product-labels/$code/${DateTime.now().millisecondsSinceEpoch}.jpg';
    return R2StorageService.upload(
      bytes: bytes,
      objectKey: key,
      contentType: contentType,
    );
  }
}
