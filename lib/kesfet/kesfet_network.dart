import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

/// Keşfet ön yüklemesi için bağlantı türü: Wi-Fi / kablolu ise videonun ilk
/// saniyeleri önceden indirilir, mobil veride yalnız oynatıcı hazırlanır.
class KesfetNetwork {
  KesfetNetwork._();

  static bool _unmetered = false;
  static StreamSubscription<List<ConnectivityResult>>? _sub;

  /// Wi-Fi veya kablolu bağlantı (bilinmiyorsa false → hafif ön yükleme).
  static bool get isUnmetered => _unmetered;

  static void ensureStarted() {
    if (_sub != null) return;
    final c = Connectivity();
    _sub = c.onConnectivityChanged.listen(_apply, onError: (_) {});
    unawaited(c.checkConnectivity().then(_apply).catchError((_) {}));
  }

  static void _apply(List<ConnectivityResult> r) {
    _unmetered = r.contains(ConnectivityResult.wifi) ||
        r.contains(ConnectivityResult.ethernet);
  }
}
