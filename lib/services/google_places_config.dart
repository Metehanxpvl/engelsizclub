/// Google Places API anahtarı.
///
/// Kullanım:
/// 1) Aşağıdaki [apiKeyFallback] alanına anahtarı yazın, VEYA
/// 2) Çalıştırırken / build alırken:
///    flutter run --dart-define=GOOGLE_PLACES_API_KEY=AIza...
///    flutter build web --dart-define=GOOGLE_PLACES_API_KEY=AIza...
///
/// Google Cloud Console → APIs & Services → Credentials
/// → Places API (Nearby Search / Place Details) etkinleştirin.
/// Web'de tarayıcı CORS kısıtı olabilir; mobil/desktop'ta tam çalışır.
class GooglePlacesConfig {
  GooglePlacesConfig._();

  /// dart-define ile gelen anahtar (öncelikli).
  static const _fromEnv = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  /// Sabit alan — anahtarınızı buraya yapıştırabilirsiniz.
  /// Örnek: 'AIzaSy................'
  static const apiKeyFallback = 'YOUR_GOOGLE_PLACES_API_KEY';

  static String get apiKey {
    if (_fromEnv.trim().isNotEmpty) return _fromEnv.trim();
    return apiKeyFallback.trim();
  }

  static bool get isConfigured {
    final k = apiKey;
    return k.isNotEmpty &&
        !k.startsWith('YOUR_') &&
        k.toLowerCase() != 'changeme';
  }
}
