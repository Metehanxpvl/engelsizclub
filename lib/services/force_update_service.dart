import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'force_update_logic.dart';

export 'force_update_logic.dart';

/// pubspec `+build` ile aynı tutulur (PackageInfo boş dönerse yedek).
const kAppBuildNumber = 200002;

/// Açılışta (ForceUpdateGate) semver kontrolü. Splash kilidi yok.
///
/// Kaynak: Supabase `app_settings.force_update` (Remote Config yok).
/// Android: "Güncelle" → Play In-App Update, olmazsa mağaza URL.
class ForceUpdateService extends ChangeNotifier {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  static const androidPackage = kForceUpdateAndroidPackage;
  static const defaultPlayUrl = kForceUpdatePlayUrl;
  static const defaultMarketUrl = kForceUpdateMarketUrl;
  static const defaultIosUrl = kForceUpdateIosUrl;

  /// Eski kilit alanı — her zaman false. İlk kare asla bloklanmaz.
  bool blocked = false;

  UpdatePromptKind promptKind = UpdatePromptKind.none;
  bool get showPrompt => promptKind != UpdatePromptKind.none;
  bool get isMandatory => promptKind == UpdatePromptKind.mandatory;

  String title = 'Yeni sürüm mevcut';
  String message = 'Engelsiz Club\'ın yeni sürümü yayınlandı.';
  String detail =
      'Uygulamanın en yeni özelliklerinden yararlanmak için uygulamanı güncelle.';
  String storeUrl = defaultPlayUrl;
  int localBuild = 0;
  String localVersion = '';
  String latestVersion = '';
  String minVersion = '';

  bool _checking = false;

  Future<void> check() async {
    if (kIsWeb) {
      if (promptKind != UpdatePromptKind.none) {
        promptKind = UpdatePromptKind.none;
        notifyListeners();
      }
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      await _loadPackageInfo();
      final remote = await _fetchRemote();
      if (remote == null) {
        // Fail-open: mevcut kartı kapatma (zaten gösteriliyorsa kalsın).
        return;
      }
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      latestVersion = remote.latestForIos(ios);
      minVersion = remote.minimumSupportedVersion;
      storeUrl = remote.storeUrlForIos(ios);
      if (storeUrl.isEmpty) {
        storeUrl = ios ? defaultIosUrl : defaultPlayUrl;
      }

      String? skipped;
      if (latestVersion.isNotEmpty) {
        skipped = await _readSkipped(latestVersion);
      }
      final next = resolveUpdatePrompt(
        current: localVersion,
        minSupported: minVersion,
        latest: latestVersion,
        skippedLatest: skipped,
      );
      if (next != promptKind) {
        promptKind = next;
        notifyListeners();
      } else if (next != UpdatePromptKind.none) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ForceUpdateService: $e');
    } finally {
      _checking = false;
    }
  }

  /// Arka plandan dönüş: semver yeniden; indirilmiş esnek güncellemeyi kur.
  Future<void> onResumed() async {
    if (kIsWeb) return;
    unawaited(check());
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

  Future<void> skipOptional() async {
    if (isMandatory) return;
    final v = latestVersion.trim();
    if (v.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(forceUpdateSkipPrefsKey(v), true);
      } catch (e) {
        debugPrint('ForceUpdate skip: $e');
      }
    }
    if (promptKind != UpdatePromptKind.none) {
      promptKind = UpdatePromptKind.none;
      notifyListeners();
    }
  }

  @Deprecated('Use skipOptional')
  void dismissIosPrompt() {
    unawaited(skipOptional());
  }

  Future<void> openStore() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final usedPlay = await _tryPlayInAppUpdate();
        if (usedPlay) return;
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

  Future<bool> _tryPlayInAppUpdate() async {
    AppUpdateInfo info;
    try {
      info = await InAppUpdate.checkForUpdate();
    } catch (e) {
      debugPrint('ForceUpdate Play check skipped: $e');
      return false;
    }
    final available = info.availableVersionCode ?? 0;
    final hasNewer = info.updateAvailability ==
            UpdateAvailability.updateAvailable &&
        available > 0;
    if (!hasNewer) return false;
    try {
      if (isMandatory && info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
      if (info.flexibleUpdateAllowed) {
        final result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) {
          await InAppUpdate.completeFlexibleUpdate();
        }
        return true;
      }
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
        return true;
      }
    } catch (e) {
      debugPrint('ForceUpdate Play start: $e');
    }
    return false;
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

  Future<String?> _readSkipped(String latest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(forceUpdateSkipPrefsKey(latest)) == true) {
        return latest;
      }
    } catch (e) {
      debugPrint('ForceUpdate skip read: $e');
    }
    return null;
  }

  Future<ForceUpdateRemoteConfig?> _fetchRemote() async {
    try {
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('key', 'force_update')
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (row == null) return null;
      final parsed = ForceUpdateRemoteConfig.fromJson(row['value']);
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      if (parsed.latestForIos(ios).trim().isEmpty) return null;
      return parsed;
    } catch (e) {
      debugPrint('ForceUpdate remote: $e');
      return null;
    }
  }
}
