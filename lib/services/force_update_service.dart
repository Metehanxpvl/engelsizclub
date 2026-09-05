import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/async_timeout.dart';

/// pubspec `+build` ile aynı tutulur (PackageInfo boş dönerse yedek).
const kAppBuildNumber = 108;

/// Otomatik güncelleme — ilk kareden sonra, asla boot kilidi yok.
///
/// Android: yalnız Play In-App Update. Play daha yeni sürüm yoksa hiçbir şey.
/// iOS: App Store lookup; varsa kapatılabilir sayfa. Fail-open.
/// Web: kapalı.
class ForceUpdateService extends ChangeNotifier {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  static const androidPackage = 'com.sakircaykara.engelsizclub';
  static const iosBundleId = 'com.sakircaykara.engelsizclub';
  static const defaultPlayUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const defaultMarketUrl = 'market://details?id=$androidPackage';
  static const defaultIosSearchUrl =
      'https://apps.apple.com/tr/search?term=Engelsiz%20Club';

  /// Eski kilit alanı — her zaman false. İlk kare asla bloklanmaz.
  bool blocked = false;

  bool iosUpdateAvailable = false;
  String message =
      'Yeni bir sürüm yayınlandı. İsterseniz uygulamayı güncelleyebilirsiniz.';
  String storeUrl = defaultPlayUrl;
  int localBuild = 0;
  String localVersion = '';
  String storeVersion = '';

  bool _checking = false;
  bool _androidPrompted = false;
  bool _iosDismissed = false;

  Future<void> check() async {
    if (kIsWeb) {
      if (iosUpdateAvailable) {
        iosUpdateAvailable = false;
        notifyListeners();
      }
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      await _loadPackageInfo();
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _checkPlayInAppUpdate();
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _checkAppStore();
      }
    } catch (e) {
      debugPrint('ForceUpdateService: $e');
    } finally {
      _checking = false;
    }
  }

  /// Arka plandan dönüş: indirilmiş esnek güncellemeyi kur. Yeniden sorma.
  Future<void> onResumed() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
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

  Future<void> openStore() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final market = Uri.parse(defaultMarketUrl);
        if (await canLaunchUrl(market)) {
          final ok =
              await launchUrl(market, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
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

  Future<void> _checkPlayInAppUpdate() async {
    if (_androidPrompted) return;
    AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (e) {
      // Sideload / emülatör / Play yok — fail-open.
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
      'avail=${info.updateAvailability} flex=${info.flexibleUpdateAllowed} '
      'imm=${info.immediateUpdateAllowed}',
    );
    if (!hasNewer) return;

    _androidPrompted = true;
    try {
      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
        return;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (e) {
      debugPrint('ForceUpdate Play start: $e');
      _androidPrompted = false;
    }
  }

  Future<void> _checkAppStore() async {
    if (_iosDismissed) return;
    try {
      final uri = Uri.https('itunes.apple.com', '/lookup', {
        'bundleId': iosBundleId,
        'country': 'tr',
      });
      final res = await withNetworkTimeout(
        http.get(uri).timeout(const Duration(seconds: 8)),
        timeout: const Duration(seconds: 10),
        message: 'App Store sürüm bilgisi alınamadı.',
      );
      if (res.statusCode != 200) return;
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) return;
      final results = decoded['results'];
      if (results is! List || results.isEmpty) return;
      final first = results.first;
      if (first is! Map) return;
      final version = (first['version'] ?? '').toString().trim();
      final trackUrl = (first['trackViewUrl'] ?? '').toString().trim();
      if (version.isEmpty) return;
      storeVersion = version;
      if (trackUrl.startsWith('http')) storeUrl = trackUrl;

      final newer = _isStoreVersionNewer(storeVersion, localVersion);
      debugPrint(
        'ForceUpdate iOS: local=$localVersion store=$storeVersion newer=$newer',
      );
      if (!newer) {
        if (iosUpdateAvailable) {
          iosUpdateAvailable = false;
          notifyListeners();
        }
        return;
      }
      if (!iosUpdateAvailable) {
        iosUpdateAvailable = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ForceUpdate App Store: $e');
    }
  }

  /// `1.0.100` > `1.0.99`. Eşit veya parse edilemezse false (fail-open).
  static bool _isStoreVersionNewer(String store, String local) {
    if (store.isEmpty || local.isEmpty) return false;
    final a = store.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final b = local.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
    final n = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < n; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av > bv) return true;
      if (av < bv) return false;
    }
    return false;
  }
}
