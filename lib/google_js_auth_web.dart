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

bool _isSuccessfulGoogleTokenMap(Map<String, String?> map) {
  final idToken = map['idToken'];
  if (idToken == null || idToken.isEmpty || idToken == 'null') return false;
  if (map['cancelled'] == 'true') return false;
  final err = map['error'];
  if (err != null && err.isNotEmpty && err != 'null') return false;
  return true;
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

  final raw = await js_util.promiseToFuture<dynamic>(
    js_util.callMethod(js_util.globalThis, '__engelsizGoogleSignIn', []),
  );
  if (raw == null) return null;
  final map = _mapFromJs(raw);
  // idToken alındı → Dart signInWithIdToken çağıracak. Restore + 1500ms
  // sonra oturum var ama UI kıpırdamadıysa index.html reload eder.
  // İptal/hata: zamanlayıcı yok.
  if (_isSuccessfulGoogleTokenMap(map)) {
    schedulePostGoogleAuthRecoveryJs();
  }
  return map;
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
  final map = _mapFromJs(raw);
  if (_isSuccessfulGoogleTokenMap(map)) {
    schedulePostGoogleAuthRecoveryJs();
  }
  return map;
}

/// Çıkışta GIS One Tap / overlay kalıntısını temizler.
void firebaseGoogleSignOutJs() {
  final bridge =
      js_util.getProperty(js_util.globalThis, '__engelsizGoogleSignOut');
  if (bridge == null) return;
  js_util.callMethod(js_util.globalThis, '__engelsizGoogleSignOut', []);
}

void restoreFlutterAfterGoogleJs() {
  final bridge =
      js_util.getProperty(js_util.globalThis, '__engelsizRestoreFlutter');
  if (bridge == null) return;
  js_util.callMethod(js_util.globalThis, '__engelsizRestoreFlutter', []);
}

/// Restore + (gerekirse) 1500ms sonra koşullu reload.
void schedulePostGoogleAuthRecoveryJs() {
  final bridge = js_util.getProperty(
    js_util.globalThis,
    '__engelsizSchedulePostGoogleAuthRecovery',
  );
  if (bridge == null) {
    restoreFlutterAfterGoogleJs();
    return;
  }
  js_util.callMethod(
    js_util.globalThis,
    '__engelsizSchedulePostGoogleAuthRecovery',
    [],
  );
}

/// Başarılı Google girişinden sonra UI kurtarma (koşullu reload).
void reloadAfterGoogleSignInJs() {
  schedulePostGoogleAuthRecoveryJs();
}
