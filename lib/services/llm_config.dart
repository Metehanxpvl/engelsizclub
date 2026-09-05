/// LLM — istemcide API anahtarı yok. Analiz genel `gemini-proxy` URL’sine gider.
///
/// GEMINI_API_KEY / GROQ_API_KEY isteğe bağlı dart-define (AAB’ye konmaz).
/// Boşsa web ve native aynı public proxy’yi kullanır (Supabase Edge Function).
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

  static const groqModel = String.fromEnvironment(
    'GROQ_MODEL',
    defaultValue: 'llama-3.1-8b-instant',
  );

  /// Public Edge Function — anahtar değil. dart-define boşsa bu varsayılan.
  static const _defaultGeminiProxyUrl =
      'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/gemini-proxy';

  /// Tam proxy URL. Boş dart-define → [_defaultGeminiProxyUrl].
  static const geminiProxyUrl = String.fromEnvironment(
    'GEMINI_PROXY_URL',
    defaultValue: _defaultGeminiProxyUrl,
  );

  static String get geminiKey => geminiApiKey.trim();
  static String get groqKey => groqApiKey.trim();

  static String get trimmedGeminiProxyUrl =>
      geminiProxyUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static bool get hasGemini => geminiKey.isNotEmpty;
  static bool get hasGroq => groqKey.isNotEmpty;
  static bool get hasProxyUrl => trimmedGeminiProxyUrl.startsWith('http');

  /// Native AAB dahil: varsayılan proxy URL yeterli; dart-define anahtar gerekmez.
  static bool get hasVision => hasGemini || hasProxyUrl;

  static bool get isConfigured => hasGemini || hasGroq || hasProxyUrl;
}
