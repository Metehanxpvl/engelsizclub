import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Google Play Store / Play Services erişilebilir mi?
///
/// Bazı cihazlarda (Play kapalı, eski GMS, Knox profili) native Play SDK
/// "Something went wrong — Check that Google Play is enabled…" diyalogu gösterir;
/// bu yüzden faturalandırma öncesi sessizce kontrol edilir.
Future<bool> isGooglePlayAvailable() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
  try {
    return await InAppPurchase.instance
        .isAvailable()
        .timeout(const Duration(seconds: 4), onTimeout: () => false);
  } catch (e) {
    debugPrint('Google Play availability: $e');
    return false;
  }
}
