import 'dart:html' as html;
import 'dart:js_util' as js_util;

Map<String, String?> _mapFromJs(dynamic raw) {
  if (raw == null) return {};
  final map = <String, String?>{};
  for (final key in [
    'idToken',
    'accessToken',
    'cancelled',
    'redirecting',
    'error',
    'empty',
  ]) {
    final v = js_util.getProperty(raw, key);
    if (v != null) map[key] = '$v';
  }
  return map;
}

/// index.html içindeki `window.__engelsizGoogleSignIn` köprüsü.
/// Google Identity Services → idToken (Firebase userinfo 401 yok).
Future<Map<String, String?>?> firebaseGooglePopupJs() async {
  final bridge =
      js_util.getProperty(js_util.globalThis, '__engelsizGoogleSignIn');
  if (bridge == null) {
    throw StateError(
      'Google giriş köprüsü yüklenmedi. Sayfayı yenileyin (Ctrl+Shift+R).',
    );
  }

  final raw = await js_util
      .promiseToFuture<dynamic>(
        js_util.callMethod(js_util.globalThis, '__engelsizGoogleSignIn', []),
      )
      .timeout(
        const Duration(seconds: 90),
        onTimeout: () => throw StateError(
          'Google giriş zaman aşımına uğradı. Tekrar deneyin.',
        ),
      );
  if (raw == null) return null;
  return _mapFromJs(raw);
}

/// Popup engellendiğinde redirect dönüşünü yakala.
Future<Map<String, String?>?> firebaseGoogleRedirectResultJs() async {
  final bridge =
      js_util.getProperty(js_util.globalThis, '__engelsizGoogleRedirectResult');
  if (bridge == null) return null;
  final raw = await js_util.promiseToFuture<dynamic>(
    js_util.callMethod(
      js_util.globalThis,
      '__engelsizGoogleRedirectResult',
      [],
    ),
  );
  if (raw == null) return null;
  return _mapFromJs(raw);
}

/// Telefonda GIS One Tap Flutter canvas altında kalıyor (Samsung vb.).
bool shouldUseGoogleAuthPage() {
  final ua = html.window.navigator.userAgent.toLowerCase();
  return ua.contains('android') ||
      ua.contains('iphone') ||
      ua.contains('ipad') ||
      ua.contains('ipod') ||
      ua.contains('mobile') ||
      ua.contains('samsung');
}

void goToGoogleAuthPage() {
  final origin = html.window.location.origin;
  html.window.location.assign('$origin/mobile_google_auth.html?return=web');
}
