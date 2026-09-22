import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'force_update_logic.dart';

export 'force_update_logic.dart';

/// pubspec marketing / `+build` ile aynı tutulur (PackageInfo boş dönerse yedek).
const kAppVersionName = '1.1.15';
const kAppBuildNumber = 200013;

/// Açılışta semver + Play kontrolü. Splash kilidi yok.
///
/// Kaynak: Supabase `app_settings.force_update`.
/// CTA: Android → Google Play, iOS → App Store.
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
  String storeUrl = defaultPlayUrl;
  int localBuild = 0;
  String localVersion = '';
  String latestVersion = '';
  String minVersion = '';

  bool _checking = false;

  String get storeCtaLabel => 'Güncelle';

  String get detail {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Devam etmek için App Store\'dan uygulamayı güncelleyin.';
    }
    return 'Devam etmek için Google Play\'den uygulamayı güncelleyin.';
  }

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
      var next = UpdatePromptKind.none;
      final remote = await _fetchRemote();
      if (remote != null) {
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
        next = resolveUpdatePrompt(
          current: localVersion,
          minSupported: minVersion,
          latest: latestVersion,
          skippedLatest: skipped,
        );
      }
      if (next == UpdatePromptKind.none &&
          defaultTargetPlatform == TargetPlatform.android) {
        next = await _playStoreUpdateKind();
        if (next != UpdatePromptKind.none) {
          storeUrl = defaultPlayUrl;
          latestVersion =
              latestVersion.isNotEmpty ? latestVersion : localVersion;
        }
      }
      if (kDebugMode) {
        debugPrint(
          'ForceUpdate: current=$localVersion min=$minVersion '
          'latest=$latestVersion → $next',
        );
      }
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

  /// Arka plandan dönüş: semver yeniden kontrol.
  Future<void> onResumed() async {
    if (kIsWeb) return;
    unawaited(check());
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
      final ios = defaultTargetPlatform == TargetPlatform.iOS;
      if (!ios) {
        final market = Uri.parse(defaultMarketUrl);
        if (await canLaunchUrl(market)) {
          final ok =
              await launchUrl(market, mode: LaunchMode.externalApplication);
          if (ok) return;
        }
        final play = Uri.parse(
          storeUrl.isNotEmpty ? storeUrl : defaultPlayUrl,
        );
        await launchUrl(play, mode: LaunchMode.externalApplication);
        return;
      }
      await _openIosStore();
    } catch (e) {
      debugPrint('ForceUpdate openStore: $e');
    }
  }

  Future<void> _openIosStore() async {
    const id = kForceUpdateIosAppStoreId;
    final seen = <String>{};
    final candidates = <Uri>[];
    void add(String raw) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return;
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.scheme.isEmpty) return;
      if (!seen.add(uri.toString())) return;
      candidates.add(uri);
    }

    add(storeUrl);
    add(kForceUpdateIosWebFallbackUrl);
    add('itms-apps://itunes.apple.com/app/id$id');
    add('itms-apps://apps.apple.com/tr/app/engelsiz-club/id$id');
    add(kForceUpdateIosUrl);
    add(defaultIosUrl);

    const modes = <LaunchMode>[
      LaunchMode.externalApplication,
      LaunchMode.externalNonBrowserApplication,
      LaunchMode.platformDefault,
    ];
    for (final uri in candidates) {
      for (final mode in modes) {
        try {
          if (await launchUrl(uri, mode: mode)) return;
        } catch (e) {
          debugPrint('ForceUpdate iOS launch $uri $mode: $e');
        }
      }
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
    if (localVersion.isEmpty) localVersion = kAppVersionName;
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

  /// Play'de daha yeni versionCode varsa kart göster (Google Play'e gider).
  Future<UpdatePromptKind> _playStoreUpdateKind() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      final available = info.availableVersionCode ?? 0;
      final hasNewer = info.updateAvailability ==
              UpdateAvailability.updateAvailable &&
          available > 0 &&
          available > localBuild;
      if (!hasNewer) return UpdatePromptKind.none;
      return UpdatePromptKind.optional;
    } catch (e) {
      debugPrint('ForceUpdate Play check skipped: $e');
      return UpdatePromptKind.none;
    }
  }
}
