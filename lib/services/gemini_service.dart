import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_report.dart';
import '../models/product_safety.dart';
import '../utils/async_timeout.dart';
import 'allergen_analyzer.dart';
import 'e_number_explanations.dart';
import 'llm_config.dart';
import 'open_food_facts_service.dart';
import 'r2_config.dart';

class GeminiAnalyzeResult {
  const GeminiAnalyzeResult({this.record, this.error});

  final ProductRecord? record;
  final String? error;

  bool get hasRecord => record != null;
}

class GeminiMedicineResult {
  const GeminiMedicineResult({this.record, this.error});

  final MedicineRecord? record;
  final String? error;
}

/// Etiket görseli veya barkod+ad metin → safety_report.
/// Anahtar sunucuda: Edge Function `gemini-proxy` (GEMINI_API_KEY).
/// Web: tarayıcı Google’a POST etmez (CORS). Sıra:
/// `supabase.functions.invoke('gemini-proxy')`, sonra GEMINI_PROXY_URL /
/// R2 Worker POST /gemini. Native: dart-define anahtar yedek.
class GeminiService {
  GeminiService._();

  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const _maxOcrChars = 3500;
  static const _maxImageBytes = 8 * 1024 * 1024;

  static const _supabaseProxy =
      'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/gemini-proxy';

  static String? lastError;

  static String get _key => _apiKey.trim();
  static bool get isConfigured => _key.isNotEmpty;

  /// Web: proxy; native: dart-define anahtar veya Groq.
  static bool get canCall => isConfigured || kIsWeb || LlmConfig.hasGroq;

  /// Web’de proxy olduğu için istemci anahtarı olmasa da görsel analiz denenir.
  static bool get hasVision => isConfigured || kIsWeb;

  static Future<ProductRecord?> analyze({
    String barcode = '',
    String ocrText = '',
    String? productHint,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    final result = await analyzeDetailed(
      barcode: barcode,
      ocrText: ocrText,
      productHint: productHint,
      imageBytes: imageBytes,
      imageMimeType: imageMimeType,
    );
    return result.record;
  }

  static Future<GeminiAnalyzeResult> analyzeDetailed({
    String barcode = '',
    String ocrText = '',
    String? productHint,
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
    String? brand,
    String? quantity,
    String? offFields,
  }) async {
    lastError = null;
    final ocr = ocrText.trim();
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    final code = barcode.trim();
    final hint = (productHint ?? '').trim();
    final catalog =
        !hasImage && ocr.isEmpty && (code.isNotEmpty || hint.isNotEmpty);
    if (!hasImage && ocr.isEmpty && !catalog) {
      lastError = 'Barkod, ürün adı veya etiket bilgisi yok.';
      debugPrint('Gemini: $lastError');
      return GeminiAnalyzeResult(error: lastError);
    }
    if (!canCall) {
      lastError = 'Analiz anahtarı tanımlı değil.';
      debugPrint('Gemini: $lastError');
      return GeminiAnalyzeResult(error: lastError);
    }

    debugPrint(
      'Gemini analiz: image=${hasImage ? imageBytes.lengthInBytes : 0}B '
      'ocr=${ocr.length} barcode=$code catalog=$catalog '
      'web=$kIsWeb key=$isConfigured',
    );

    final clipped =
        ocr.length > _maxOcrChars ? ocr.substring(0, _maxOcrChars) : ocr;
    final prompt = _prompt(
      barcode: code,
      ocr: clipped,
      productHint: hint.isEmpty ? productHint : hint,
      brand: brand,
      quantity: quantity,
      offFields: offFields,
      forImage: hasImage,
      forCatalog: catalog,
    );

    String? raw;
    String? callError;
    if (hasImage && hasVision) {
      final vision = await _geminiVision(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: imageMimeType,
      );
      raw = vision.$1;
      callError = vision.$2;
    }
    if ((raw == null || raw.isEmpty)) {
      final textOnly = await _gemini(prompt);
      raw ??= textOnly.$1;
      callError ??= textOnly.$2;
    }
    if ((raw == null || raw.isEmpty) &&
        !hasImage &&
        LlmConfig.hasGroq) {
      raw = await _groq(prompt);
    }
    if (raw == null || raw.isEmpty) {
      lastError = callError ??
          'Analiz servisi yanıt vermedi. Daha sonra tekrar deneyin.';
      debugPrint('Gemini boş yanıt: $lastError');
      return GeminiAnalyzeResult(error: lastError);
    }

    final map = _parseJsonObject(raw);
    if (map == null) {
      lastError = 'Analiz yanıtı okunamadı (JSON değil).';
      debugPrint('Gemini JSON parse başarısız. ham=${raw.length} karakter');
      return GeminiAnalyzeResult(error: lastError);
    }

    final extracted =
        OpenFoodFactsService.normalizeBarcode(_str(map['barcode']));
    final given = OpenFoodFactsService.normalizeBarcode(barcode) ??
        barcode.trim();
    final resolved = extracted ?? (given.isNotEmpty ? given : '');

    final name = _str(
      map['product_name'] ??
          map['productName'] ??
          map['name'] ??
          map['urun_adi'],
    );
    final ingredients = _ingredientsFrom(map);
    var report = SafetyReport.fromJson(
      map['safety_report'] is Map
          ? Map<String, dynamic>.from(map['safety_report'] as Map)
          : map['safetyReport'] is Map
              ? Map<String, dynamic>.from(map['safetyReport'] as Map)
              : null,
    );

    debugPrint(
      'Gemini parse: name="${name.length > 40 ? name.substring(0, 40) : name}" '
      'ingredients=${ingredients.length} karakter',
    );

    final local = AllergenAnalyzer.analyze(
      ingredients: ingredients,
      productName: name,
    );
    report = _merge(report, local);
    report = AllergenAnalyzer.finalize(
      report,
      categoryLabel: _str(
        map['categoryLabel'] ?? map['category_label'] ?? map['category'],
      ),
      sugarsPer100g: _num(map['sugarsPer100g'] ?? map['sugars_per_100g']),
      saltPer100g: _num(map['saltPer100g'] ?? map['salt_per_100g']),
      ingredients: ingredients,
    );
    report = _applyGeminiScores(report, map);

    if (report.summaryTr.trim().isEmpty) {
      report = AllergenAnalyzer.finalize(
        report.copyWith(
          summaryTr: AllergenAnalyzer.disclaimer,
          ingredientsSummary: report.ingredientsSummary.isEmpty
              ? ingredients
              : report.ingredientsSummary,
        ),
        ingredients: ingredients,
      );
    }

    if (!ProductRecord.isUsableIngredientText(ingredients)) {
      lastError ??=
          'İçindekiler listesi belirsiz. İsteğe bağlı etiket fotoğrafı '
          'daha net olabilir.';
      debugPrint('Gemini: içindekiler boş / yetersiz');
    }

    return GeminiAnalyzeResult(
      record: ProductRecord(
        barcode: resolved,
        productName: name.isEmpty ? null : name,
        ingredients: ingredients.isEmpty ? null : ingredients,
        safety: report,
        source: 'llm',
      ),
      error: lastError,
    );
  }

  /// Küpür / prospektüs görseli → ilaç JSON.
  /// Varsayılan canlı model gemini-3.6-flash (1.5-flash Google 404 / emekli).
  /// Model 404 olursa [_geminiGenerate] zinciri dener; fonksiyon-yok 404 değil.
  static const _medicineModels = <String>[
    'gemini-3.6-flash',
  ];

  static Future<GeminiMedicineResult> analyzeMedicine({
    String barcode = '',
    String ocrText = '',
    String medicineName = '',
    Uint8List? imageBytes,
    String imageMimeType = 'image/jpeg',
  }) async {
    lastError = null;
    final ocr = ocrText.trim();
    final typedName = medicineName.trim();
    final hasImage = imageBytes != null && imageBytes.isNotEmpty;
    final code = barcode.trim();
    if (!hasImage && ocr.isEmpty && typedName.isEmpty) {
      lastError = 'Küpür veya prospektüs görseli yok.';
      debugPrint('Gemini ilaç: $lastError');
      return GeminiMedicineResult(error: lastError);
    }
    if (!canCall) {
      lastError = 'Analiz anahtarı tanımlı değil.';
      debugPrint('Gemini ilaç: $lastError');
      return GeminiMedicineResult(error: lastError);
    }

    debugPrint(
      'Gemini ilaç: image=${hasImage ? imageBytes.lengthInBytes : 0}B '
      'ocr=${ocr.length} name=${typedName.length} barcode=$code web=$kIsWeb',
    );

    final clipped =
        ocr.length > _maxOcrChars ? ocr.substring(0, _maxOcrChars) : ocr;
    final prompt = _medicinePrompt(
      barcode: code,
      ocr: clipped,
      medicineName: typedName,
    );

    String? raw;
    String? callError;
    if (hasImage && hasVision) {
      final vision = await _geminiVision(
        prompt: prompt,
        imageBytes: imageBytes,
        mimeType: imageMimeType,
        preferredModels: _medicineModels,
      );
      raw = vision.$1;
      callError = vision.$2;
    }
    if (raw == null || raw.isEmpty) {
      final textOnly = await _gemini(
        prompt,
        preferredModels: _medicineModels,
      );
      raw ??= textOnly.$1;
      callError ??= textOnly.$2;
    }
    if (raw == null || raw.isEmpty) {
      lastError = callError ??
          'Analiz servisi yanıt vermedi. Daha sonra tekrar deneyin.';
      debugPrint('Gemini ilaç boş yanıt: $lastError');
      return GeminiMedicineResult(error: lastError);
    }

    final map = _parseJsonObject(raw);
    if (map == null) {
      lastError = 'Analiz yanıtı okunamadı (JSON değil).';
      debugPrint('Gemini ilaç JSON parse başarısız. ham=${raw.length} karakter');
      return GeminiMedicineResult(error: lastError);
    }

    var record = MedicineRecord.fromGemini(map, barcode: code);
    if (record.medicineName.trim().isEmpty && typedName.isNotEmpty) {
      record = record.copyWith(medicineName: typedName);
    }
    if (!record.isFound) {
      lastError =
          'Prospektüste okunabilir ilaç adı veya kullanım bilgisi yok.';
      debugPrint('Gemini ilaç: alanlar boş');
      return GeminiMedicineResult(error: lastError);
    }
    return GeminiMedicineResult(record: record);
  }

  static String _medicinePrompt({
    required String barcode,
    required String ocr,
    String medicineName = '',
  }) {
    final barcodeLine = barcode.trim().isEmpty
        ? 'Barkod görselde varsa yaz; yoksa boş bırak.'
        : 'Barkod (varsa doğrula, uydurma): $barcode';
    final typed = medicineName.trim();
    final nameOnly = typed.isNotEmpty && ocr.isEmpty;
    final source = nameOnly
        ? 'Görev: kullanıcının yazdığı ilaç adı için kamuya açık küpür / '
            'prospektüs bilgisine dayanan, yalnızca bilgi amaçlı kısa özet. '
            'Görsel yok; fotoğraf zorunlu değil. Teşhis koyma, tedavi veya doz '
            'önerisi verme, eksik alanı uydurma. Bu bir reçete değildir. '
            'Emin değilsen ilgili alanı "" veya [] bırak.'
        : 'Görev: ilaç kutusunun arka yüzü (küpür) veya prospektüs görselinden / '
            'metninden yalnızca etikette veya prospektüste yer alan bilgileri çıkar. '
            'Teşhis koyma, tedavi veya doz önerisi verme, eksik alanı uydurma. '
            'Emin değilsen ilgili alanı "" veya [] bırak; '
            '"etikette/prospektüste okunamadı" yazılabilir.';
    return '''
$source
Kesinlik dili yasak: "kesinlikle güvenlidir", "kesinlikle alma", "doktor yerine geçer", "kullanın", "tedavi eder".
Dil: Türkçe, bilgi amaçlı. Özetler "etikette/prospektüste yer alan" çerçevede kalsın. Reçete / tıbbi emir yok.
$barcodeLine
${typed.isEmpty ? '' : 'İlaç adı (kullanıcı yazdı): $typed\n'}${ocr.isEmpty ? '' : 'ocr:\n$ocr\n'}
Yalnız JSON (başka metin yok; markdown çiti olabilir):
{"product_name":"Ürün veya İlaç Adı","active_ingredient":"Etken Madde (İlaçlar için)","ingredients":"İçindekiler veya kullanım amacı listesi","usage":"Kullanım talimatı özeti","side_effects":["Olası yan etkiler listesi"],"drug_interactions":["Birlikte kullanılmaması veya dikkat edilmesi gereken etken maddeler / ilaç grupları"],"safety_report":{"allergens":["Alerjenler"],"additives":["Katkı maddeleri"],"summary":"Genel bilgilendirme özeti"}}
product_name: kutuda/prospektüste görünen ad veya kullanıcının yazdığı ad (eski alan medicine_name de kabul). Yoksa "".
active_ingredient: etken madde. Yoksa "".
ingredients: içindekiler veya kullanım amacı; yalnız etiket/prospektüste yazan. Yoksa "".
usage: nasıl kullanılır özeti; yalnız etiket/prospektüste yazan. Doz uydurma yok.
side_effects: kısa string dizisi. Yoksa [].
drug_interactions: prospektüste yer alan etkileşimler / birlikte kullanılmaması gereken etken maddeler veya ilaç grupları. Bilgi amaçlı; "kesinlikle alma" emri yok. Yoksa [].
safety_report.summary: genel bilgilendirme (eski alan safety_warnings de kabul).
Uydurma ve tıbbi kesinlik yok.
''';
  }

  static String _prompt({
    required String barcode,
    required String ocr,
    String? productHint,
    String? brand,
    String? quantity,
    String? offFields,
    bool forImage = false,
    bool forCatalog = false,
  }) {
    final hint = (productHint ?? '').trim();
    final brandLine = (brand ?? '').trim();
    final qtyLine = (quantity ?? '').trim();
    final extra = (offFields ?? '').trim();
    final String source;
    final String ingredientsRule;
    if (forImage) {
      source =
          'Görev: etiket görselindeki İÇİNDEKİLER / INGREDIENTS bloğunu satır satır çıkar. '
          'Ürün adı yetmez. Ön yüz / marka / slogan değil; bileşen listesini oku.';
      ingredientsRule =
          'ingredients: İÇİNDEKİLER / INGREDIENTS panelini baştan sona, virgülle '
          'ayrılmış yaz. Liste dizi de olabilir. Okunmuyorsa "".';
    } else if (forCatalog) {
      source =
          'Görev: görsel yok. Barkod ve ürün adından (varsa marka / miktar / açık veri) '
          'bilgi amaçlı içindekiler, olası alerjenler ve E-kodları doldur. '
          'Bu barkodlu markalı ürünün veya yaygın gıda/içeceğin (ayran, kola, su, süt, '
          'meyve suyu) bilinen tipik içindekilerini yaz. İçecekleri atlama. '
          'Emin değilsen infoSummary’de belirsizliği belirt; yine de tipik listeyi dene.';
      ingredientsRule =
          'ingredients: virgülle ayrılmış tam liste (string veya dizi). '
          'Bu EAN/barkod + marka için bilinen içindekiler. '
          'Hiçbir kaynak yoksa "". Tıbbi kesinlik yok.';
    } else {
      source =
          'Etiket metninden İÇİNDEKİLER bloğunu çıkar. Ürün adı yetmez.';
      ingredientsRule =
          'ingredients: metindeki içindekiler listesini olduğu gibi yaz. Yoksa "".';
    }
    final barcodeLine = barcode.trim().isEmpty
        ? 'barcode: (görselde varsa rakamları yaz)'
        : 'barcode: $barcode';
    return '''
$source Kısa JSON. Teşhis veya tıbbi tavsiye değil; kesin emin olma dili kullanma.
Yasak: "kesinlikle güvenlidir", "alerji yapmaz", "doktor yerine geçer", "tıbben onaylı", "güvenli".
Dil: "barındırabilir", "bileşen listesinde yer alıyor", "etikete göre olası".
$barcodeLine
${hint.isEmpty ? '' : 'product_name: $hint\n'}${brandLine.isEmpty ? '' : 'brand: $brandLine\n'}${qtyLine.isEmpty ? '' : 'quantity: $qtyLine\n'}${extra.isEmpty ? '' : 'open_food_facts:\n$extra\n'}${ocr.isEmpty ? '' : 'ocr:\n$ocr\n'}
$ingredientsRule
Yalnız JSON:
{"barcode":"","product_name":"","ingredients":"","categoryLabel":"","safety_report":{"ingredientsSummary":"","possibleAllergens":[{"key":"","labelTr":""}],"additives":[{"code":"e500","labelTr":"","flag":"note"}],"additiveRiskLevel":"bilinmiyor","notesLevel":"unknown|none|notes|concerns","notes":[],"infoSummary":"","sugarsPer100g":null,"saltPer100g":null,"categoryLabel":"","nutriScore":null,"novaGroup":null}}
additives: listedeki tüm E-kodları (E500, E330…); labelTr boş bırakılabilir.
additiveRiskLevel: asiri|cok|az|cokAz|yok|bilinmiyor. E-kodu sayısından türet. Gerçek içindekiler var ve E-kodu yoksa yok. İçindekiler yok ve katkı tag/E-kodu yoksa bilinmiyor (yeşil yok uydurma).
categoryLabel: kısa Türkçe kategori (CİPS, İÇECEK…) biliniyorsa; yoksa "".
sugarsPer100g / saltPer100g: yalnız sayı varsa; yoksa null. Uydurma.
nutriScore: yalnız A–E. Open Food Facts nutriscore_grade veya etiket üzerinde basılıysa yaz. Emin değilsen null. Rastgele E/D uydurma.
novaGroup: yalnız 1–4. Open Food Facts nova_group veya etiket açıkça belirtiyorsa yaz. Emin değilsen null. Rastgele 4 uydurma.
infoSummary Türkçe 1-2 cümle; tıbbi iddia, kesinlik veya "güvenli" yok. Belirsizlik varsa söyle.
Bu gıda ve içecek etiket analizidir (ayran, kola, su, süt, meyve suyu, soda, çay, kahve dahildir). İçeceği "gıda değil" deyip boş JSON dönme. drug_interactions yazma. Odak: içindekiler, alerjenler, katkılar (E-kodları), varsa Nutri-Score/NOVA.
''';
  }

  static Future<(String?, String?)> _geminiVision({
    required String prompt,
    required Uint8List imageBytes,
    required String mimeType,
    List<String>? preferredModels,
  }) async {
    if (imageBytes.lengthInBytes > _maxImageBytes) {
      final err =
          'Etiket okunamadı: görsel çok büyük (${imageBytes.lengthInBytes} bayt).';
      debugPrint(err);
      return (null, err);
    }
    final mime = mimeType.trim().toLowerCase().startsWith('image/')
        ? mimeType.trim()
        : 'image/jpeg';
    return _geminiGenerate(
      prompt: prompt,
      extraParts: [
        {
          'inlineData': {
            'mimeType': mime,
            'data': base64Encode(imageBytes),
          },
        },
      ],
      timeout: const Duration(seconds: 40),
      preferredModels: preferredModels,
    );
  }

  static Future<(String?, String?)> _gemini(
    String prompt, {
    List<String>? preferredModels,
  }) =>
      _geminiGenerate(
        prompt: prompt,
        extraParts: const [],
        timeout: const Duration(seconds: 30),
        preferredModels: preferredModels,
      );

  static Future<(String?, String?)> _geminiGenerate({
    required String prompt,
    required List<Map<String, Object>> extraParts,
    Duration timeout = const Duration(seconds: 20),
    List<String>? preferredModels,
  }) async {
    // 1.5-flash emekli (Google 404). 404 = model yok, gemini-proxy fonksiyon yok değil.
    final models = <String>[
      ...?preferredModels,
      LlmConfig.geminiModel,
      'gemini-3.6-flash',
      'gemini-flash-latest',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ];
    final seen = <String>{};
    String? lastFail;
    for (final model in models) {
      if (model.isEmpty || !seen.add(model)) continue;
      final payload = <String, Object>{
        'contents': [
          {
            'parts': [
              {'text': prompt},
              ...extraParts,
            ],
          },
        ],
        'generationConfig': {
          'temperature': 0.1,
          'maxOutputTokens': extraParts.isEmpty ? 2048 : 4096,
          'responseMimeType': 'application/json',
        },
      };
      try {
        final res = await _postGemini(
          model: model,
          payload: payload,
          timeout: timeout,
        );
        if (res == null) {
          lastFail ??= lastError ??
              'Analiz isteği gönderilemedi (proxy veya ağ).';
          if (_isFatalProxyFail(lastFail)) break;
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastFail = _httpErrorTr(res.statusCode, res.body);
          debugPrint('Gemini $model ${res.statusCode}: ${res.body}');
          // Google model 404 → sonraki model. Yalnız gerçek fonksiyon-yok 404 fatal.
          if (_isFatalProxyStatus(res.statusCode, res.body)) break;
          if (_isGoogleModelNotFound(res.statusCode, res.body)) {
            debugPrint('Gemini $model 404 (model emekli/yok), sonraki deneniyor');
          }
          continue;
        }
        final decoded = jsonDecode(res.body);
        if (decoded is! Map) {
          lastFail = 'Etiket okunamadı: beklenmeyen yanıt.';
          continue;
        }
        if (decoded['error'] is Map) {
          lastFail = _googleErrorTr(decoded['error'] as Map);
          debugPrint('Gemini $model error: ${decoded['error']}');
          if (_isGoogleModelNotFound(res.statusCode, res.body)) {
            debugPrint('Gemini $model NOT_FOUND (model), sonraki deneniyor');
          }
          continue;
        }
        final candidates = decoded['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          lastFail =
              'Analiz modeli aday döndürmedi. Daha sonra tekrar deneyin.';
          debugPrint('Gemini $model: candidates boş');
          continue;
        }
        final first = candidates.first;
        if (first is Map) {
          final finish = first['finishReason']?.toString();
          if (finish != null &&
              finish.isNotEmpty &&
              finish != 'STOP' &&
              finish != 'MAX_TOKENS') {
            debugPrint('Gemini $model finishReason=$finish');
          }
        }
        final content = first is Map ? first['content'] : null;
        final parts = content is Map ? content['parts'] : null;
        if (parts is! List || parts.isEmpty) {
          lastFail = 'Etiket okunamadı: model metin döndürmedi.';
          continue;
        }
        final text = parts.first['text']?.toString();
        if (text != null && text.trim().isNotEmpty) return (text, null);
        lastFail = 'Etiket okunamadı: boş model yanıtı.';
      } catch (e, st) {
        lastFail = _exceptionTr(e);
        debugPrint('Gemini hata ($model): $e\n$st');
      }
    }
    return (null, lastFail);
  }

  static Future<http.Response?> _postGemini({
    required String model,
    required Map<String, Object> payload,
    required Duration timeout,
  }) async {
    final invoked = await _postViaSupabaseInvoke(
      model: model,
      payload: payload,
      timeout: timeout,
    );
    if (invoked != null) return invoked;

    final proxied = await _postViaProxy(
      model: model,
      payload: payload,
      timeout: timeout,
    );
    if (proxied != null) return proxied;
    debugPrint(
      'Gemini proxy yanıt vermedi; istemci anahtarı varsa Google deneniyor.',
    );
    if (_key.isEmpty) return null;
    if (kIsWeb) {
      lastError ??=
          'Tarayıcı Google’a doğrudan bağlanamaz (CORS). '
          'Supabase gemini-proxy gerekli.';
      return null;
    }
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent',
    ).replace(queryParameters: {'key': _key});
    return withNetworkTimeout(
      http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ),
      timeout: timeout,
      message: 'Analiz yanıt vermedi. Lütfen tekrar deneyin.',
    );
  }

  static Map<String, Object> _proxyBody(
    String model,
    Map<String, Object> payload,
  ) {
    final body = <String, Object>{'model': model, ...payload};
    final prompt = _promptFromPayload(payload);
    if (prompt != null) body['prompt'] = prompt;
    return body;
  }

  static String? _promptFromPayload(Map<String, Object> payload) {
    final contents = payload['contents'];
    if (contents is! List || contents.isEmpty) return null;
    final first = contents.first;
    if (first is! Map) return null;
    final parts = first['parts'];
    if (parts is! List) return null;
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        final t = (part['text'] as String).trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  /// Same-origin-ish CORS as the rest of the app (Supabase HTTPS API).
  static Future<http.Response?> _postViaSupabaseInvoke({
    required String model,
    required Map<String, Object> payload,
    required Duration timeout,
  }) async {
    try {
      final client = Supabase.instance.client;
      debugPrint('Gemini invoke gemini-proxy model=$model');
      final res = await withNetworkTimeout(
        client.functions.invoke(
          'gemini-proxy',
          body: _proxyBody(model, payload),
        ),
        timeout: timeout,
        message: 'Analiz yanıt vermedi. Lütfen tekrar deneyin.',
      );
      return _functionResponseToHttp(res);
    } on FunctionException catch (e) {
      lastError = _functionExceptionTr(e);
      debugPrint('Gemini invoke ${e.status}: $lastError');
      return http.Response(
        _functionExceptionBody(e),
        e.status,
        headers: const {'content-type': 'application/json'},
      );
    } catch (e, st) {
      lastError = _exceptionTr(e);
      debugPrint('Gemini invoke hata: $e\n$st');
      return null;
    }
  }

  static http.Response _functionResponseToHttp(FunctionResponse res) {
    final data = res.data;
    if (data is String) {
      return http.Response(data, res.status);
    }
    return http.Response(
      jsonEncode(data ?? const <String, dynamic>{}),
      res.status,
      headers: const {'content-type': 'application/json'},
    );
  }

  static String _functionExceptionBody(FunctionException e) {
    final details = e.details;
    if (details is String && details.trim().isNotEmpty) return details;
    if (details != null) {
      try {
        return jsonEncode(details);
      } catch (_) {}
    }
    return jsonEncode({
      'error': {
        'message': e.reasonPhrase ?? 'FunctionException',
        'status': e.status,
      },
    });
  }

  static Future<http.Response?> _postViaProxy({
    required String model,
    required Map<String, Object> payload,
    required Duration timeout,
  }) async {
    final urls = <String>[
      if (LlmConfig.hasProxyUrl) LlmConfig.trimmedGeminiProxyUrl,
      if (R2Config.hasWorker) '${R2Config.trimmedWorkerUrl}/gemini',
      _supabaseProxy,
    ];
    final body = jsonEncode(_proxyBody(model, payload));
    String? lastFail;
    for (final url in urls) {
      try {
        debugPrint('Gemini proxy POST $url model=$model');
        final headers = <String, String>{
          'Content-Type': 'application/json',
          ..._supabaseHeaders(url),
        };
        final res = await withNetworkTimeout(
          http.post(Uri.parse(url), headers: headers, body: body),
          timeout: timeout,
          message: 'Analiz yanıt vermedi. Lütfen tekrar deneyin.',
        );
        if (res.statusCode == 404 && _isMissingFunctionBody(res.body)) {
          lastFail = _httpErrorTr(res.statusCode, res.body);
          debugPrint('Gemini proxy 404 (fonksiyon yok): $url');
          continue;
        }
        return res;
      } catch (e, st) {
        lastFail = _exceptionTr(e);
        debugPrint('Gemini proxy hata ($url): $e\n$st');
      }
    }
    if (lastFail != null) lastError = lastFail;
    return null;
  }

  /// Yalnız Supabase “Requested function was not found”. Google model 404 değil.
  static bool _isMissingFunctionBody(String body) {
    return body.toLowerCase().contains('requested function was not found');
  }

  /// Google generateContent: emekli/bilinmeyen model. gemini-proxy yok sayılmaz.
  static bool _isGoogleModelNotFound(int status, String body) {
    if (_isMissingFunctionBody(body)) return false;
    if (status == 404) return true;
    final lower = body.toLowerCase();
    return lower.contains('not_found') &&
        (lower.contains('model') ||
            lower.contains('gemini-') ||
            lower.contains('is not found'));
  }

  static bool _isFatalProxyStatus(int status, String body) {
    if (status == 401 || status == 403) return true;
    if (status == 404 && _isMissingFunctionBody(body)) return true;
    if (status == 503) {
      final lower = body.toLowerCase();
      return lower.contains('gemini_api_key') || lower.contains('tanımlı değil');
    }
    return false;
  }

  static bool _isFatalProxyFail(String? message) {
    if (message == null || message.isEmpty) return false;
    final e = message.toLowerCase();
    return e.contains('401') ||
        e.contains('403') ||
        e.contains('requested function was not found') ||
        e.contains('fonksiyonu yok') ||
        e.contains('yetkisiz') ||
        e.contains('tanımlı değil');
  }

  static Map<String, String> _supabaseHeaders(String url) {
    if (!url.contains('supabase.co/functions')) return const {};
    try {
      final client = Supabase.instance.client;
      final key = client.headers['apikey'] ?? '';
      final token = client.auth.currentSession?.accessToken ?? key;
      if (key.isEmpty) return const {};
      return {
        'apikey': key,
        'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return const {};
    }
  }

  static String _clipBody(String body, [int max = 180]) {
    final t = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static String _httpErrorTr(int status, String body) {
    final lower = body.toLowerCase();
    final clip = _clipBody(body);
    if (status == 401) {
      return 'Analiz yetkisiz (401). ${clip.isEmpty ? 'JWT veya anon anahtar.' : clip}';
    }
    if (status == 400 && lower.contains('api key')) {
      return 'Analiz anahtarı geçersiz (400).';
    }
    if (status == 403 ||
        (lower.contains('permission') && lower.contains('api_key'))) {
      return 'Analiz anahtarı yetkisiz veya kısıtlı (403).';
    }
    if (status == 404) {
      if (_isMissingFunctionBody(body)) {
        return 'Analiz fonksiyonu yok (404 gemini-proxy). '
            'Supabase Dashboard → Edge Functions → Deploy.';
      }
      return 'Analiz modeli bulunamadı (404). $clip';
    }
    if (status == 429) {
      return 'Analiz kotası doldu (429). Biraz sonra tekrar deneyin.';
    }
    if (status == 503 &&
        (lower.contains('gemini_api_key') || lower.contains('tanımlı değil'))) {
      return 'Analiz anahtarı sunucuda tanımlı değil (503 GEMINI_API_KEY). '
          'Dashboard → Edge Functions → gemini-proxy → Secrets.';
    }
    if (status >= 500) {
      return 'Analiz servisi yanıt vermiyor ($status). $clip';
    }
    return 'Analiz hatası ($status). $clip';
  }

  static String _functionExceptionTr(FunctionException e) {
    final body = _functionExceptionBody(e);
    return _httpErrorTr(e.status, body);
  }

  static bool isTransportError(String? error) {
    if (error == null || error.trim().isEmpty) return false;
    final e = error.toLowerCase();
    return e.contains('401') ||
        e.contains('403') ||
        e.contains('404') ||
        e.contains('429') ||
        e.contains('500') ||
        e.contains('502') ||
        e.contains('503') ||
        e.contains('cors') ||
        e.contains('proxy') ||
        e.contains('fonksiyon') ||
        e.contains('gönderilemedi') ||
        e.contains('zaman aşımı') ||
        e.contains('yetkisiz') ||
        e.contains('anahtar') ||
        e.contains('ağ');
  }

  static String _googleErrorTr(Map error) {
    final msg = error['message']?.toString() ?? '';
    final status = error['status']?.toString() ?? '';
    final lower = '$msg $status'.toLowerCase();
    if (lower.contains('api key') || lower.contains('api_key')) {
      return 'Analiz anahtarı geçersiz.';
    }
    if (lower.contains('not found') || lower.contains('not_found')) {
      return 'Analiz modeli bulunamadı.';
    }
    if (lower.contains('resource_exhausted') || lower.contains('quota')) {
      return 'Analiz kotası doldu. Biraz sonra tekrar deneyin.';
    }
    if (msg.trim().isEmpty) {
      return 'Analiz servisi hata verdi.';
    }
    return 'Analiz: $msg';
  }

  static String _exceptionTr(Object e) {
    final s = e.toString();
    final lower = s.toLowerCase();
    if (lower.contains('xmlhttprequest') ||
        lower.contains('failed to fetch') ||
        lower.contains('cors') ||
        lower.contains('clientexception')) {
      return 'Tarayıcı analiz servisine ulaşamadı (CORS). Proxy (Cloudflare /gemini veya Supabase gemini-proxy) gerekli.';
    }
    if (e is NetworkTimeoutException) {
      return 'Analiz zaman aşımına uğradı. Tekrar deneyin.';
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return 'Analiz zaman aşımına uğradı. Tekrar deneyin.';
    }
    return 'Analiz hatası: $s';
  }

  static Future<String?> _groq(String prompt) async {
    try {
      final res = await withNetworkTimeout(
        http.post(
          Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${LlmConfig.groqKey}',
          },
          body: jsonEncode({
            'model': LlmConfig.groqModel,
            'temperature': 0.2,
            'max_tokens': 1024,
            'response_format': {'type': 'json_object'},
            'messages': [
              {
                'role': 'system',
                'content': 'Yalnız geçerli JSON döndür. Tıbbi kesinlik yok.',
              },
              {'role': 'user', 'content': prompt},
            ],
          }),
        ),
        timeout: const Duration(seconds: 20),
        message: 'Analiz yanıt vermedi. Lütfen tekrar deneyin.',
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('Groq ${res.statusCode}: ${res.body}');
        return null;
      }
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return null;
      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final msg = choices.first['message'];
      return msg is Map ? msg['content']?.toString() : null;
    } catch (e, st) {
      debugPrint('Groq hata: $e\n$st');
      return null;
    }
  }

  static Map<String, dynamic>? _parseJsonObject(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      s = s.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      s = s.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(s.substring(start, end + 1));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (e) {
      debugPrint('Gemini JSON decode: $e');
    }
    return null;
  }

  static String _ingredientsFrom(Map<String, dynamic> map) {
    const keys = [
      'ingredients',
      'ingredients_text',
      'ingredientsText',
      'ingredients_text_tr',
      'icindekiler',
      'içindekiler',
      'ingredient_list',
      'ingredientList',
    ];
    for (final k in keys) {
      final text = _asIngredientText(map[k]);
      if (ProductRecord.isUsableIngredientText(text)) return text;
    }
    final report = map['safety_report'] ?? map['safetyReport'];
    if (report is Map) {
      for (final k in ['ingredientsSummary', 'ingredients_summary', 'ingredients']) {
        final text = _asIngredientText(report[k]);
        if (ProductRecord.isUsableIngredientText(text)) return text;
      }
    }
    for (final k in keys) {
      final text = _asIngredientText(map[k]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static String _asIngredientText(Object? raw) {
    if (raw == null) return '';
    if (raw is String) return raw.trim();
    if (raw is List) {
      final parts = <String>[];
      for (final e in raw) {
        if (e == null) continue;
        if (e is String) {
          final t = e.trim();
          if (t.isNotEmpty) parts.add(t);
        } else if (e is Map) {
          final t = _str(
            e['text'] ??
                e['name'] ??
                e['ingredient'] ??
                e['id'] ??
                e['value'],
          );
          if (t.isNotEmpty) parts.add(t);
        } else {
          final t = e.toString().trim();
          if (t.isNotEmpty) parts.add(t);
        }
      }
      return parts.join(', ');
    }
    return raw.toString().trim();
  }

  static String _str(Object? raw) {
    if (raw == null) return '';
    if (raw is List) return _asIngredientText(raw);
    return raw.toString().trim();
  }

  static double? _num(Object? raw) {
    if (raw == null) return null;
    if (raw is num) return raw.toDouble();
    final s = raw.toString().trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(0)!);
  }

  static SafetyReport _merge(SafetyReport llm, SafetyReport local) {
    final allergens = <String, AllergenHit>{
      for (final a in [...llm.allergens, ...local.allergens])
        if (a.key.isNotEmpty) a.key: a,
    };
    final additives = <String, AdditiveHit>{
      for (final a in [...llm.additives, ...local.additives])
        if (a.code.trim().isNotEmpty)
          ENumberExplanations.normalizeCode(a.code):
              ENumberExplanations.enrich(a),
    };
    final warnings = <String>{...llm.warnings, ...local.warnings};
    var child = llm.childSuitable;
    if (child == ChildSuitability.unknown) child = local.childSuitable;
    if (local.childSuitable == ChildSuitability.unsuitable ||
        llm.childSuitable == ChildSuitability.unsuitable) {
      child = ChildSuitability.unsuitable;
    } else if (local.childSuitable == ChildSuitability.caution &&
        child == ChildSuitability.suitable) {
      child = ChildSuitability.caution;
    }
    final summary = llm.summaryTr.trim().isNotEmpty
        ? llm.summaryTr
        : local.summaryTr;
    final ingSummary = llm.ingredientsSummary.trim().isNotEmpty
        ? llm.ingredientsSummary
        : local.ingredientsSummary;
    return AllergenAnalyzer.finalize(
      SafetyReport(
        allergens: allergens.values.toList(),
        additives: additives.values.toList(),
        childSuitable: child,
        warnings: warnings.toList(),
        summaryTr: summary,
        ingredientsSummary: ingSummary,
        sugarsPer100g: llm.sugarsPer100g ?? local.sugarsPer100g,
        saltPer100g: llm.saltPer100g ?? local.saltPer100g,
        categoryLabel: (llm.categoryLabel ?? '').trim().isNotEmpty
            ? llm.categoryLabel
            : local.categoryLabel,
        nutriScore: llm.nutriScore ?? local.nutriScore,
        nutriScoreSource: llm.nutriScore != null
            ? LabelScoreSource.estimate
            : local.nutriScoreSource,
        novaGroup: llm.novaGroup ?? local.novaGroup,
        novaGroupSource: llm.novaGroup != null
            ? LabelScoreSource.estimate
            : local.novaGroupSource,
      ),
      ingredients: ingSummary,
    );
  }

  /// Gemini skorları her zaman tahmini; OFF kaynağı iddia edilmez.
  static SafetyReport _applyGeminiScores(
    SafetyReport report,
    Map<String, dynamic> map,
  ) {
    final nested = map['safety_report'] is Map
        ? Map<String, dynamic>.from(map['safety_report'] as Map)
        : map['safetyReport'] is Map
            ? Map<String, dynamic>.from(map['safetyReport'] as Map)
            : const <String, dynamic>{};
    final nutri = NutriScoreGrade.tryParse(
      map['nutriScore'] ??
          map['nutriscore_grade'] ??
          nested['nutriScore'] ??
          nested['nutriscore_grade'] ??
          report.nutriScore?.letter,
    );
    final nova = NovaGroup.tryParse(
      map['novaGroup'] ??
          map['nova_group'] ??
          nested['novaGroup'] ??
          nested['nova_group'] ??
          report.novaGroup?.number,
    );
    return report.copyWith(
      nutriScore: nutri ?? report.nutriScore,
      nutriScoreSource: (nutri ?? report.nutriScore) != null
          ? LabelScoreSource.estimate
          : report.nutriScoreSource,
      novaGroup: nova ?? report.novaGroup,
      novaGroupSource: (nova ?? report.novaGroup) != null
          ? LabelScoreSource.estimate
          : report.novaGroupSource,
    );
  }
}
