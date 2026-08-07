/// Google Maps / Places API anahtar yapılandırması.
///
/// Cloud Console'da açık olmalı:
///   Places API (New), Maps SDK for Android, Maps SDK for iOS, Maps JavaScript API
///
/// dart-define ile override:
///   flutter build appbundle --dart-define=GOOGLE_MAPS_API_KEY=AIza...
class GooglePlacesConfig {
  GooglePlacesConfig._();

  static const _fromEnv = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  static const _fromEnvLegacy = String.fromEnvironment(
    'GOOGLE_PLACES_API_KEY',
    defaultValue: '',
  );

  /// Proje anahtarı (Android / iOS / Places / Maps JS).
  static const apiKeyFallback = 'AIzaSyAHDu7hYJInYdPhrg8i0YdEzgfl0lL502o';

  static String get apiKey {
    if (_fromEnv.trim().isNotEmpty) return _fromEnv.trim();
    if (_fromEnvLegacy.trim().isNotEmpty) return _fromEnvLegacy.trim();
    return apiKeyFallback.trim();
  }

  static bool get isConfigured {
    final k = apiKey;
    return k.isNotEmpty &&
        !k.startsWith('YOUR_') &&
        k.toLowerCase() != 'changeme';
  }
}
