/// LLM anahtarları — yalnız compile-time dart-define; kaynak/SQL/asset yok.
///
///   flutter run --dart-define=GEMINI_API_KEY=your_key
///
/// Web CORS: tarayıcı Google’a gidemez. Önce
/// `supabase.functions.invoke('gemini-proxy')` (aynı Supabase HTTPS).
/// Yedek: GEMINI_PROXY_URL veya R2_WORKER_URL POST /gemini.
///
/// Etiket görsel analizi: Gemini (varsayılan gemini-3.6-flash).
/// gemini-1.5-flash emekli — Google 404; çağrı zinciri sonraki modeli dener.
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
    defaultValue: 'gemini-3.6-flash',
  );

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
