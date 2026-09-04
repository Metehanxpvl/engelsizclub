import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/medicine_report.dart';
import '../models/product_safety.dart';
import '../utils/async_timeout.dart';
import 'allergen_analyzer.dart';
import 'e_number_explanations.dart';
import 'image_optimize_service.dart';
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
/// `gemini-proxy` **anon** Bearer (oturum JWT yok — misafir / süresi dolmuş
/// oturum 401 olmasın), sonra GEMINI_PROXY_URL / R2 Worker POST /gemini.
/// Native: dart-define anahtar yedek.
class GeminiService {
  GeminiService._();

  static const _apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const _maxOcrChars = 3500;
  static const _maxImageBytes = 8 * 1024 * 1024;
  static const _compressImageBytes = 350 * 1024;

  static const _supabaseProxy =
      'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/gemini-proxy';

  /// Public anon / publishable key — `main.dart` Supabase.initialize ile aynı.
  /// `client.headers['apikey']` çoğu sürümde boş; AuthHttpClient enjekte eder.
  static const _fallbackAnonKey =
      'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF';

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

  static const modelUnavailableMessage =
      'Analiz modeli şu an yanıt vermedi, tekrar deneyin.';

  /// Küpür / prospektüs görseli → ilaç JSON.
  /// Varsayılan canlı model gemini-flash-latest (3.8-flash).
  /// 3.6 asılır; 1.5/2.x emekli 404. Zincir sonraki modeli dener.
  static const _medicineModels = LlmConfig.geminiFallbackModels;

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
    if (!hasImage && ocr.isEmpty && typedName.isEmpty && code.isEmpty) {
      lastError = 'Küpür, prospektüs veya ilaç barkodu yok.';
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
      lastError = (!hasImage && ocr.isEmpty && typedName.isEmpty && code.isNotEmpty)
          ? 'Bu barkod için kamuya açık ilaç özeti bulunamadı.'
          : 'Prospektüste okunabilir ilaç adı veya kullanım bilgisi yok.';
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
    final nameOnly = typed.isNotEmpty && ocr.isEmpty && barcode.trim().isEmpty;
    final barcodeOnly =
        typed.isEmpty && ocr.isEmpty && barcode.trim().isNotEmpty;
    final namedBarcode =
        typed.isNotEmpty && ocr.isEmpty && barcode.trim().isNotEmpty;
    final String source;
    if (namedBarcode) {
      source =
          'Görev: Türkiye’de bu GTIN / barkod ile satılan ilacın (ad aşağıda, '
          'TİTCK SKRS / karekod eşleşmesi) kamuya açık kullanma talimatı '
          '(prospektüs / KT) özeti. Görsel yok; fotoğraf zorunlu değil. '
          'Ürün adını değiştirme. Teşhis koyma, tedavi veya doz önerisi verme, '
          'eksik alanı uydurma. Bu bir reçete değildir. '
          'Emin değilsen ilgili alanı "" veya [] bırak.';
    } else if (nameOnly) {
      source =
          'Görev: kullanıcının yazdığı ilaç adı için kamuya açık küpür / '
          'prospektüs bilgisine dayanan, yalnızca bilgi amaçlı kısa özet. '
          'Görsel yok; fotoğraf zorunlu değil. Teşhis koyma, tedavi veya doz '
          'önerisi verme, eksik alanı uydurma. Bu bir reçete değildir. '
          'Emin değilsen ilgili alanı "" veya [] bırak.';
    } else if (barcodeOnly) {
      source =
          'Görev: taranan ilaç barkodu / GS1 GTIN için kamuya açık küpür / '
          'prospektüs bilgisine dayanan, yalnızca bilgi amaçlı kısa özet. '
          'Görsel yok; fotoğraf zorunlu değil. Türkiye’de bu GTIN ile satılan '
          'ilacın adını, etken maddesini ve prospektüs özetini doldur. '
          'Teşhis koyma, tedavi veya doz önerisi verme, eksik alanı uydurma. '
          'Bu bir reçete değildir. Emin değilsen ilgili alanı "" veya [] bırak.';
    } else {
      source =
          'Görev: ilaç kutusunun arka yüzü (küpür) veya prospektüs görselinden / '
          'metninden yalnızca etikette veya prospektüste yer alan bilgileri çıkar. '
          'Teşhis koyma, tedavi veya doz önerisi verme, eksik alanı uydurma. '
          'Emin değilsen ilgili alanı "" veya [] bırak; '
          '"etikette/prospektüste okunamadı" yazılabilir.';
    }
    return '''
$source
Kesinlik dili yasak: "kesinlikle güvenlidir", "kesinlikle alma", "doktor yerine geçer", "kullanın", "tedavi eder".
Dil: Türkçe, bilgi amaçlı. Özetler "etikette/prospektüste yer alan" çerçevede kalsın. Reçete / tıbbi emir yok.
$barcodeLine
${typed.isEmpty ? '' : 'İlaç adı (kullanıcı yazdı veya TİTCK SKRS): $typed\n'}${ocr.isEmpty ? '' : 'ocr:\n$ocr\n'}
Yalnız JSON (başka metin yok; markdown çiti olabilir):
{"product_name":"Ürün veya İlaç Adı","active_ingredient":"Etken Madde (İlaçlar için)","indications":"Ne için kullanılır özeti","usage":"Nasıl kullanılır özeti","side_effects":["Olası yan etkiler listesi"],"drug_interactions":["Birlikte kullanılmaması veya dikkat edilmesi gereken etken maddeler / ilaç grupları"],"safety_report":{"allergens":["Alerjenler"],"additives":["Katkı maddeleri"],"summary":"Uyarılar / genel bilgilendirme özeti"}}
product_name: kutuda/prospektüste görünen ad veya verilen ad (eski alan medicine_name de kabul). Yoksa "".
active_ingredient: etken madde. Yoksa "".
indications: ne için kullanılır; yalnız kamuya açık KT / prospektüs. Yoksa "". Eski alan ingredients de kabul.
usage: nasıl kullanılır özeti. Doz uydurma yok. Yoksa "".
side_effects: kısa string dizisi. Bilinmiyorsa []. "Yok" / "Bilinmiyor" yazma.
drug_interactions: prospektüste yer alan etkileşimler / birlikte dikkat edilmesi gereken etken maddeler veya ilaç grupları. Bilgi amaçlı; "kesinlikle alma" emri yok. Bilinmiyorsa []. "Yok" yazma.
safety_report.summary: uyarılar / genel bilgilendirme (eski alan safety_warnings de kabul).
Uydurma ve tıbbi kesinlik yok. prospectus_url uydurma.
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
additiveRiskLevel: asiri|cok|az|cokAz|yok|bilinmiyor. E-kodu sayısından türet; NOVA/işlenmişlikten BAĞIMSIZ. Gerçek içindekiler var ve E-kodu yoksa yok. İçindekiler yok ve katkı tag/E-kodu yoksa bilinmiyor (yeşil yok uydurma). novaGroup null olsa bile E-kodlarından risk yaz.
categoryLabel: kısa Türkçe kategori (CİPS, İÇECEK…) biliniyorsa; yoksa "".
sugarsPer100g / saltPer100g: yalnız sayı varsa; yoksa null. Uydurma.
nutriScore: yalnız A–E. Open Food Facts nutriscore_grade veya etiket üzerinde basılıysa yaz. Emin değilsen null. Rastgele E/D uydurma.
novaGroup: yalnız 1–4. Open Food Facts nova_group / nova_groups_tags veya etiket açıkça belirtiyorsa yaz. Emin değilsen null (uygulama gri Bilinmiyor gösterir). 1 veya 4 uydurma.
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
    var bytes = imageBytes;
    var mime = mimeType.trim().toLowerCase().startsWith('image/')
        ? mimeType.trim()
        : 'image/jpeg';
    if (bytes.lengthInBytes > _compressImageBytes) {
      try {
        final opt = await ImageOptimizeService.forLabelScan(bytes);
        bytes = opt.bytes;
        mime = opt.contentType;
        debugPrint(
          'Gemini görsel sıkıştırıldı: ${imageBytes.lengthInBytes}B → ${bytes.lengthInBytes}B',
        );
      } catch (e) {
        debugPrint('Gemini görsel sıkıştırma atlandı: $e');
      }
    }
    return _geminiGenerate(
      prompt: prompt,
      extraParts: [
        {
          'inlineData': {
            'mimeType': mime,
            'data': base64Encode(bytes),
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
    // flash-latest → 3.8-flash → lite. 3.6 asılır; 1.5/2.x emekli 404.
    // Model 404 ≠ gemini-proxy fonksiyon yok. Zincir bitene kadar kullanıcıya 404 yok.
    const liteModel = 'gemini-flash-lite-latest';
    final models = <String>[
      ...?preferredModels,
      LlmConfig.geminiModel,
      ...LlmConfig.geminiFallbackModels,
    ];
    final seen = <String>{};
    String? lastFail;
    var lastWasModel404 = false;
    var retriedLiteOn503 = false;
    final perAttempt = extraParts.isEmpty
        ? const Duration(seconds: 12)
        : const Duration(seconds: 18);
    final slice = timeout < perAttempt ? timeout : perAttempt;
    final deadline = DateTime.now().add(
      extraParts.isEmpty
          ? const Duration(seconds: 40)
          : const Duration(seconds: 50),
    );
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
    for (final model in models) {
      if (model.isEmpty || !seen.add(model)) continue;
      if (model == 'gemini-3.6-flash') continue;
      if (DateTime.now().isAfter(deadline)) break;
      try {
        var res = await _postGemini(
          model: model,
          payload: payload,
          timeout: slice,
          proxyTimeout: extraParts.isEmpty
              ? const Duration(seconds: 40)
              : const Duration(seconds: 45),
        );
        if (res == null) {
          lastFail ??= lastError ??
              'Analiz isteği gönderilemedi (proxy veya ağ).';
          lastWasModel404 = false;
          if (_isFatalProxyFail(lastFail)) break;
          continue;
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          lastFail = _httpErrorTr(res.statusCode, res.body);
          debugPrint('Gemini $model ${res.statusCode}: ${res.body}');
          // Google model 404 → sonraki model. Yalnız gerçek fonksiyon-yok 404 fatal.
          if (_isFatalProxyStatus(res.statusCode, res.body)) break;
          lastWasModel404 = _isGoogleModelNotFound(res.statusCode, res.body);
          if (lastWasModel404) {
            debugPrint('Gemini $model 404 (model emekli/yok), sonraki deneniyor');
          }
          if (res.statusCode == 503) {
            if (!retriedLiteOn503 && DateTime.now().isBefore(deadline)) {
              retriedLiteOn503 = true;
              debugPrint('Gemini 503 — $liteModel bir kez daha deneniyor');
              final liteRes = await _postGemini(
                model: liteModel,
                payload: payload,
                timeout: slice,
                proxyTimeout: extraParts.isEmpty
                    ? const Duration(seconds: 40)
                    : const Duration(seconds: 45),
              );
              if (liteRes == null) {
                lastFail = lastError ?? lastFail;
                break;
              }
              if (liteRes.statusCode < 200 || liteRes.statusCode >= 300) {
                lastFail = _httpErrorTr(liteRes.statusCode, liteRes.body);
                debugPrint(
                  'Gemini $liteModel ${liteRes.statusCode}: ${liteRes.body}',
                );
                break;
              }
              res = liteRes;
            } else {
              break;
            }
          } else {
            continue;
          }
        }
        final decoded = jsonDecode(res.body);
        if (decoded is! Map) {
          lastFail = 'Etiket okunamadı: beklenmeyen yanıt.';
          lastWasModel404 = false;
          continue;
        }
        if (decoded['error'] is Map) {
          lastFail = _googleErrorTr(decoded['error'] as Map);
          debugPrint('Gemini $model error: ${decoded['error']}');
          lastWasModel404 = _isGoogleModelNotFound(res.statusCode, res.body);
          if (lastWasModel404) {
            debugPrint('Gemini $model NOT_FOUND (model), sonraki deneniyor');
          }
          if (_isMissingGeminiSecret(res.body) || _isFatalProxyFail(lastFail)) {
            break;
          }
          continue;
        }
        if (decoded['error'] is String) {
          lastFail = _httpErrorTr(
            res.statusCode >= 400 ? res.statusCode : 503,
            res.body,
          );
          debugPrint('Gemini $model error: ${decoded['error']}');
          if (_isMissingGeminiSecret(res.body) || _isFatalProxyFail(lastFail)) {
            break;
          }
          continue;
        }
        final candidates = decoded['candidates'];
        if (candidates is! List || candidates.isEmpty) {
          lastFail =
              'Analiz modeli aday döndürmedi. Daha sonra tekrar deneyin.';
          lastWasModel404 = false;
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
          lastWasModel404 = false;
          continue;
        }
        final text = parts.first['text']?.toString();
        if (text != null && text.trim().isNotEmpty) return (text, null);
        lastFail = 'Etiket okunamadı: boş model yanıtı.';
        lastWasModel404 = false;
      } catch (e, st) {
        lastFail = _exceptionTr(e);
        lastWasModel404 = false;
        debugPrint('Gemini hata ($model): $e\n$st');
      }
    }
    if (lastFail != null &&
        (lastFail.contains('503') ||
            lastFail.toLowerCase().contains('gemini anahtarı'))) {
      return (null, lastFail);
    }
    if (lastWasModel404 ||
        (lastFail != null &&
            (lastFail.contains('404') ||
                lastFail.toLowerCase().contains('bulunamadı') ||
                lastFail.toLowerCase().contains('not found')))) {
      return (null, modelUnavailableMessage);
    }
    return (null, lastFail ?? modelUnavailableMessage);
  }

  static Future<http.Response?> _postGemini({
    required String model,
    required Map<String, Object> payload,
    required Duration timeout,
    Duration? proxyTimeout,
  }) async {
    final wait = proxyTimeout ?? timeout;
    final invoked = await _postViaSupabaseInvoke(
      model: model,
      payload: payload,
      timeout: wait,
    );
    if (invoked != null && !_isSupabaseGatewayAuthFail(invoked)) {
      return invoked;
    }
    if (invoked != null) {
      debugPrint(
        'Gemini invoke ${invoked.statusCode} (JWT/gateway) — HTTP anon deneniyor',
      );
    }

    final proxied = await _postViaProxy(
      model: model,
      payload: payload,
      timeout: wait,
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
    final image = _imageFromPayload(payload);
    if (image != null) {
      body['imageBase64'] = image.$1;
      body['mimeType'] = image.$2;
    }
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

  static (String, String)? _imageFromPayload(Map<String, Object> payload) {
    final contents = payload['contents'];
    if (contents is! List) return null;
    for (final item in contents) {
      if (item is! Map) continue;
      final parts = item['parts'];
      if (parts is! List) continue;
      for (final part in parts) {
        if (part is! Map) continue;
        final inline = part['inlineData'] ?? part['inline_data'];
        if (inline is! Map) continue;
        final data = inline['data']?.toString().trim() ?? '';
        if (data.isEmpty) continue;
        final mime = inline['mimeType']?.toString() ??
            inline['mime_type']?.toString() ??
            'image/jpeg';
        return (data, mime);
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
      final anon = _supabaseAnonKey();
      if (anon.isEmpty) return null;
      debugPrint('Gemini invoke gemini-proxy model=$model auth=anon');
      final res = await withNetworkTimeout(
        client.functions.invoke(
          'gemini-proxy',
          body: _proxyBody(model, payload),
          headers: {
            'Authorization': 'Bearer $anon',
            'apikey': anon,
          },
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
    final lower = body.toLowerCase();
    final aboutModel = lower.contains('model') ||
        lower.contains('gemini-') ||
        lower.contains('no longer available') ||
        lower.contains('not_found') ||
        lower.contains('not found');
    if (status == 404 && aboutModel) return true;
    if (status == 404 && body.trim().isEmpty) return true;
    return lower.contains('not_found') &&
        (lower.contains('model') ||
            lower.contains('gemini-') ||
            lower.contains('is not found'));
  }

  static bool _isMissingGeminiSecret(String body) {
    final lower = body.toLowerCase();
    return lower.contains('gemini_api_key') ||
        lower.contains('tanımlı değil') ||
        (lower.contains('missing') && lower.contains('api_key'));
  }

  static bool _isFatalProxyStatus(int status, String body) {
    if (status == 401 || status == 403) return true;
    if (status == 404 && _isMissingFunctionBody(body)) return true;
    if (status == 503 && _isMissingGeminiSecret(body)) return true;
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
        e.contains('jwt') ||
        e.contains('oturum') ||
        e.contains('tanımlı değil') ||
        e.contains('dashboard secrets');
  }

  /// Same anon key gemini-proxy uses (guest / expired JWT yok).
  static String get supabaseAnonKeyForProxy => _supabaseAnonKey();

  /// gemini-proxy: never send a user session JWT (expired/invalid → gateway 401
  /// even when Verify JWT is off). Guest tarama uses the public anon key.
  static String _supabaseAnonKey() {
    try {
      final client = Supabase.instance.client;
      for (final raw in [
        client.headers['apikey'],
        client.auth.headers['apikey'],
      ]) {
        final key = (raw ?? '').trim();
        if (key.isEmpty) continue;
        if (key.toLowerCase().startsWith('bearer ')) continue;
        return key;
      }
    } catch (_) {}
    return _fallbackAnonKey;
  }

  static Map<String, String> _supabaseHeaders(String url) {
    if (!url.contains('supabase.co/functions')) return const {};
    final key = _supabaseAnonKey();
    if (key.isEmpty) return const {};
    return {
      'apikey': key,
      'Authorization': 'Bearer $key',
    };
  }

  static bool _isGoogleAuthError(String body) {
    final lower = body.toLowerCase();
    return lower.contains('api key') ||
        lower.contains('api_key') ||
        lower.contains('unauthenticated') ||
        (lower.contains('permission_denied') &&
            (lower.contains('generativelanguage') ||
                lower.contains('gemini')));
  }

  static bool _isSupabaseGatewayAuthFail(http.Response res) {
    if (res.statusCode != 401 && res.statusCode != 403) return false;
    return !_isGoogleAuthError(res.body);
  }

  static String _clipBody(String body, [int max = 180]) {
    final t = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }

  static const _countryBlockedMessage =
      'Google servisi bu bölgeden kapalı (ülke kısıtı).';

  /// Google 400/403 ülke kısıtı ya da gemini-proxy 451 COUNTRY_BLOCKED.
  static bool _isCountryBlocked(int status, String body) {
    final lower = body.toLowerCase();
    if (status == 451 || lower.contains('country_blocked')) return true;
    if (status != 400 && status != 403) return false;
    return lower.contains('not available in your country') ||
        lower.contains('user location is not supported');
  }

  static String _httpErrorTr(int status, String body) {
    final lower = body.toLowerCase();
    final clip = _clipBody(body);
    if (_isCountryBlocked(status, body)) return _countryBlockedMessage;
    if (status == 401) {
      if (_isGoogleAuthError(body)) {
        return 'Gemini anahtarı geçersiz (secret GEMINI_API_KEY).';
      }
      return 'Oturum/yetki: gemini-proxy JWT. '
          'Dashboard’da Verify JWT kapalı olmalı.';
    }
    if (status == 400 && lower.contains('api key')) {
      return 'Analiz anahtarı geçersiz (400).';
    }
    if (status == 403 ||
        (lower.contains('permission') && lower.contains('api_key'))) {
      if (_isGoogleAuthError(body) ||
          lower.contains('api key') ||
          lower.contains('api_key')) {
        return 'Gemini anahtarı geçersiz (secret GEMINI_API_KEY).';
      }
      return 'Analiz anahtarı yetkisiz veya kısıtlı (403).';
    }
    if (status == 404) {
      if (_isMissingFunctionBody(body)) {
        return 'Analiz fonksiyonu yok (404 gemini-proxy). '
            'Supabase Dashboard → Edge Functions → Deploy.';
      }
      return modelUnavailableMessage;
    }
    if (status == 429) {
      return 'Analiz kotası doldu (429). Biraz sonra tekrar deneyin.';
    }
    if (status == 503 && _isMissingGeminiSecret(body)) {
      return 'Gemini anahtarı tanımlı değil (Dashboard Secrets)';
    }
    if (status == 503) {
      return clip.isEmpty
          ? 'Analiz servisi yanıt vermiyor (503).'
          : 'Analiz servisi yanıt vermiyor (503). $clip';
    }
    if (status >= 500) {
      return clip.isEmpty
          ? 'Analiz servisi yanıt vermiyor ($status).'
          : 'Analiz servisi yanıt vermiyor ($status). $clip';
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
        e.contains('jwt') ||
        e.contains('oturum') ||
        e.contains('ağ');
  }

  static String _googleErrorTr(Map error) {
    final msg = error['message']?.toString() ?? '';
    final status = error['status']?.toString() ?? '';
    final lower = '$msg $status'.toLowerCase();
    if (lower.contains('api key') ||
        lower.contains('api_key') ||
        lower.contains('unauthenticated')) {
      return 'Gemini anahtarı geçersiz (secret GEMINI_API_KEY).';
    }
    if (lower.contains('not found') || lower.contains('not_found')) {
      return modelUnavailableMessage;
    }
    if (lower.contains('resource_exhausted') || lower.contains('quota')) {
      return 'Analiz kotası doldu. Biraz sonra tekrar deneyin.';
    }
    if (lower.contains('unavailable') || lower.contains('overload')) {
      return msg.trim().isEmpty
          ? 'Analiz servisi yanıt vermiyor (503).'
          : 'Analiz servisi yanıt vermiyor (503). $msg';
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
