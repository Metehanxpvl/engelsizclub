import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// pubspec `+build` ile aynı tutulur (PackageInfo boş dönerse yedek).
const kAppBuildNumber = 201201;

/// Otomatik güncelleme — ilk kareden sonra, asla boot kilidi yok.
///
/// Android: Play’de daha yeni sürüm varsa Google Play uygulama sayfasına gider
/// (uygulama içi güncelleme katmanı yok — gri ekran bırakmaz).
/// iOS: App Store lookup; mağaza sürümü yerel sürüme göre gerçekten yeniyse
/// App Store güncelleme sayfasına gider (1.1 vs 1.0.x döngüsü yok).
/// Web: kapalı (Google giriş gri ekran akışına dokunulmaz).
int compareAppVersions(String a, String b) {
  List<int> parts(String raw) {
    final cleaned = raw.trim().split(RegExp(r'[^0-9.]+')).first;
    return [
      for (final p in cleaned.split('.')) int.tryParse(p) ?? 0,
    ];
  }

  final pa = parts(a);
  final pb = parts(b);
  final n = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < n; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

bool appStoreHasNewerVersion({
  required String localVersion,
  required String storeVersion,
}) {
  if (localVersion.trim().isEmpty || storeVersion.trim().isEmpty) return false;
  return compareAppVersions(storeVersion, localVersion) > 0;
}

class ForceUpdateService extends ChangeNotifier {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  static const androidPackage = 'com.sakircaykara.engelsizclub';
  static const iosBundleId = 'com.sakircaykara.engelsizclub';
  static const iosAppId = '6799422264';
  static const defaultPlayUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const defaultMarketUrl = 'market://details?id=$androidPackage';
  static const defaultIosUrl =
      'https://apps.apple.com/tr/app/engelsiz-club/id$iosAppId';
  static const defaultIosMarketUrl = 'itms-apps://apps.apple.com/app/id$iosAppId';

  /// Eski kilit alanı — her zaman false. İlk kare asla bloklanmaz.
  bool blocked = false;

  bool iosUpdateAvailable = false;
  bool androidUpdateAvailable = false;
  String message =
      'Yeni bir sürüm yayınlandı. Mağazadan güncelleyebilirsiniz.';
  String storeUrl = defaultPlayUrl;
  int localBuild = 0;
  String localVersion = '';
  String storeVersion = '';

  bool _checking = false;
  bool _androidStoreOpened = false;
  bool _iosStoreOpened = false;
  bool _androidDismissed = false;
  bool _iosDismissed = false;

  bool get showUpdateSheet =>
      !kIsWeb && (androidUpdateAvailable || iosUpdateAvailable);

  Future<void> check() async {
    if (kIsWeb) {
      var changed = false;
      if (iosUpdateAvailable) {
        iosUpdateAvailable = false;
        changed = true;
      }
      if (androidUpdateAvailable) {
        androidUpdateAvailable = false;
        changed = true;
      }
      if (changed) notifyListeners();
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      await _loadPackageInfo();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _checkPlayInAppUpdate(openStoreNow: true);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _checkAppStore(openStoreNow: true);
      }
    } catch (e) {
      debugPrint('ForceUpdateService: $e');
    } finally {
      _checking = false;
    }
  }

  /// Arka plandan dönüş: hâlâ güncelleme varsa kartı göster, mağazayı tekrar açma.
  Future<void> onResumed() async {
    if (kIsWeb) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _checkPlayInAppUpdate(openStoreNow: false);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _checkAppStore(openStoreNow: false);
      }
    } catch (e) {
      debugPrint('ForceUpdate resume: $e');
    }
  }

  void dismissIosPrompt() {
    _iosDismissed = true;
    if (iosUpdateAvailable) {
      iosUpdateAvailable = false;
      notifyListeners();
    }
  }

  void dismissAndroidPrompt() {
    _androidDismissed = true;
    if (androidUpdateAvailable) {
      androidUpdateAvailable = false;
      notifyListeners();
    }
  }

  void dismissUpdatePrompt() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      dismissAndroidPrompt();
    } else {
      dismissIosPrompt();
    }
  }

  Future<void> openStore() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final market = Uri.parse(defaultMarketUrl);
        if (await canLaunchUrl(market)) {
          final ok =
              await launchUrl(market, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final market = Uri.parse(defaultIosMarketUrl);
        if (await canLaunchUrl(market)) {
          final ok =
              await launchUrl(market, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
        storeUrl = defaultIosUrl;
      }
      final uri = Uri.tryParse(storeUrl);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('ForceUpdate openStore: $e');
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      localBuild = int.tryParse(info.buildNumber.trim()) ?? 0;
      localVersion = info.version.trim();
    } catch (e) {
      debugPrint('ForceUpdateService PackageInfo: $e');
    }
    if (localBuild <= 0) localBuild = kAppBuildNumber;
  }

  Future<void> _checkPlayInAppUpdate({required bool openStoreNow}) async {
    AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (e) {
      // Sideload / emülatör / Play yok — fail-open, gri kilit yok.
      debugPrint('ForceUpdate Play check skipped: $e');
      return;
    }

    final available = info.availableVersionCode ?? 0;
    final hasNewer = info.updateAvailability ==
            UpdateAvailability.updateAvailable &&
        available > 0 &&
        available > localBuild;
    debugPrint(
      'ForceUpdate Play: local=$localBuild store=$available '
      'avail=${info.updateAvailability}',
    );
    if (!hasNewer) {
      if (androidUpdateAvailable) {
        androidUpdateAvailable = false;
        notifyListeners();
      }
      return;
    }

    storeVersion = available.toString();
    if (!androidUpdateAvailable && !_androidDismissed) {
      androidUpdateAvailable = true;
      notifyListeners();
    }
    if (openStoreNow && !_androidStoreOpened) {
      _androidStoreOpened = true;
      await openStore();
    }
  }

  Future<void> _checkAppStore({required bool openStoreNow}) async {
    String remote = '';
    try {
      final uri = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': iosBundleId,
        'country': 'tr',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return;
      final first = results.first;
      if (first is Map) {
        remote = first['version']?.toString().trim() ?? '';
      }
    } catch (e) {
      debugPrint('ForceUpdate App Store lookup skipped: $e');
      return;
    }
    final hasNewer = appStoreHasNewerVersion(
      localVersion: localVersion,
      storeVersion: remote,
    );
    debugPrint(
      'ForceUpdate App Store: local=$localVersion store=$remote newer=$hasNewer',
    );
    if (!hasNewer) {
      if (iosUpdateAvailable) {
        iosUpdateAvailable = false;
        notifyListeners();
      }
      return;
    }

    storeVersion = remote;
    storeUrl = defaultIosUrl;
    message =
        'Yeni bir sürüm yayınlandı. App Store’dan güncelleyebilirsiniz.';
    if (!iosUpdateAvailable && !_iosDismissed) {
      iosUpdateAvailable = true;
      notifyListeners();
    }
    if (openStoreNow && !_iosStoreOpened && !_iosDismissed) {
      _iosStoreOpened = true;
      await openStore();
    }
  }
}
