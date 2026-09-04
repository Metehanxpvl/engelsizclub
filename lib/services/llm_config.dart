/// LLM anahtarları — yalnız compile-time dart-define; kaynak/SQL/asset yok.
///
///   flutter run --dart-define=GEMINI_API_KEY=your_key
///
/// Web CORS: tarayıcı Google’a gidemez. Önce
/// `gemini-proxy` anon Bearer (oturum JWT yok) — aynı Supabase HTTPS.
/// Yedek: GEMINI_PROXY_URL veya R2_WORKER_URL POST /gemini.
///
/// Etiket görsel analizi: Gemini (flash-latest → 3.8-flash → lite).
/// gemini-3.6-flash asılıyor; zincire alınmaz. 1.5 / 2.0 / 2.5-flash emekli 404.
/// Çağrı zinciri sonraki modeli dener; model-404 fonksiyon-yok değildir.
/// Groq yalnız isteğe bağlı metin yedeği.
class LlmConfig {
  LlmConfig._();

  static const geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static const groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const geminiModel = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-flash-latest',
  );

  /// Canlıda 200 olanlar önce (flash-latest → 3.8-flash → lite).
  /// gemini-3.6-flash asılır; zincire alma.
  static const geminiFallbackModels = <String>[
    'gemini-flash-latest',
    'gemini-3.8-flash',
    'gemini-flash-lite-latest',
  ];

  /// Fotoğraf → çizgi film (Nano Banana 2). Metin flash modelleri IMAGE üretmez.
  /// GA adlar; `-preview` sürümleri 2026-06-25’te kapandı.
  static const geminiImageModel = String.fromEnvironment(
    'GEMINI_IMAGE_MODEL',
    defaultValue: 'gemini-3.1-flash-image',
  );

  /// `gemini-3.1-flash-lite-image` diye bir model yok — listeye alma.
  static const geminiImageFallbackModels = <String>[
    'gemini-3.1-flash-image',
    'gemini-3-pro-image',
  ];

  /// Google görsel üretimi AB/TR IP’lerine kapalı: eu-central-1’den
  /// 400 FAILED_PRECONDITION “Image generation is not available in your
  /// country.” döner. Edge Function varsayılan olarak kullanıcıya en yakın
  /// bölgede koşar (TR → eu-central-1), bu yüzden görsel istekleri ABD
  /// bölgesine sabitlenir. Metin analizi kısıtlı değil; oraya dokunma.
  static const geminiImageRegion = String.fromEnvironment(
    'GEMINI_IMAGE_REGION',
    defaultValue: 'us-east-1',
  );

  /// İlk bölge kısıt/kesinti yaşarsa sıradaki ABD bölgesi denenir.
  static const geminiImageRegionFallbacks = <String>[
    'us-east-1',
    'us-west-1',
  ];

  static List<String> get imageRegions {
    final first = geminiImageRegion.trim();
    return <String>[
      if (first.isNotEmpty) first,
      ...geminiImageRegionFallbacks,
    ];
  }

  static const groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );

  /// Tam proxy URL (…/gemini). Boşsa [R2Config.workerUrl] + /gemini.
  static const geminiProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: '',
  );

  static String get geminiKey => geminiApiKey.trim();
  static String get groqKey => groqApiKey.trim();

  static String get trimmedGeminiProxyUrl =>
      geminiProxyUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get hasGemini => geminiKey.isNotEmpty;
  static bool get hasGroq => groqKey.isNotEmpty;
  static bool get hasProxyUrl => trimmedGeminiProxyUrl.startsWith('http');

  static bool get hasVision => hasGemini;

  static bool get isConfigured => hasGemini || hasGroq;
}
