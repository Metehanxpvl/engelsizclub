import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_catalog_service.dart';
import '../utils/async_timeout.dart';

/// pubspec `+build` ile aynı tutulur (PackageInfo boş dönerse yedek).
const kAppBuildNumber = 103;

/// Mağazadaki zorunlu / yeni sürüm. Web'de kapalı.
class ForceUpdateService extends ChangeNotifier {
  ForceUpdateService._();
  static final ForceUpdateService instance = ForceUpdateService._();

  static const androidPackage = 'com.sakircaykara.engelsizclub';
  static const defaultPlayUrl =
      'https://play.google.com/store/apps/details?id=$androidPackage';
  static const defaultMarketUrl = 'market://details?id=$androidPackage';

  bool blocked = false;
  String message =
      'Yeni bir sürüm yayınlandı. Devam etmek için uygulamayı güncelleyin.';
  String storeUrl = defaultPlayUrl;
  int localBuild = 0;
  int requiredBuild = 0;

  bool _checking = false;

  Future<void> check() async {
    if (kIsWeb) {
      if (blocked) {
        blocked = false;
        notifyListeners();
      }
      return;
    }
    if (_checking) return;
    _checking = true;
    try {
      await _checkOnce();
    } catch (e) {
      debugPrint('ForceUpdateService: $e');
    } finally {
      _checking = false;
    }
  }

  Future<void> _checkOnce() async {
    try {
      final info = await PackageInfo.fromPlatform();
      localBuild = int.tryParse(info.buildNumber.trim()) ?? 0;
    } catch (e) {
      debugPrint('ForceUpdateService PackageInfo: $e');
    }
    if (localBuild <= 0) localBuild = kAppBuildNumber;

    final cfg = await _fetchConfig();
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final minBuild = _asInt(
      cfg == null
          ? null
          : (ios ? cfg['ios_min_build'] : cfg['android_min_build']),
    );
    final latestBuild = _asInt(
      cfg == null
          ? null
          : (ios ? cfg['ios_latest_build'] : cfg['android_latest_build']),
    );
    // latest_build yalnızca bilgi; kilit YALNIZ min_build.
    // latest'i kilit eşiği yapmak, uzak "son sürüm" yazılınca herkesi kilitler.
    requiredBuild = minBuild;
    if (latestBuild > requiredBuild) {
      debugPrint('ForceUpdate latest=$latestBuild (info only, lock uses min)');
    }

    final msg = (cfg == null ? '' : (cfg['message']?.toString() ?? '')).trim();
    if (msg.isNotEmpty) message = msg;
    final urlKey = ios ? 'ios_url' : 'android_url';
    final url = (cfg == null ? '' : (cfg[urlKey]?.toString() ?? '')).trim();
    storeUrl = url.isNotEmpty
        ? url
        : (ios
            ? 'https://apps.apple.com/tr/search?term=Engelsiz%20Club'
            : defaultPlayUrl);

    // Fail-open: config yok / min bu derlemeden büyükse (yanlış SQL) kilit yok.
    final must = cfg != null &&
        minBuild > 0 &&
        minBuild <= kAppBuildNumber &&
        localBuild > 0 &&
        localBuild < minBuild;
    debugPrint(
      'ForceUpdate: local=$localBuild required=$requiredBuild blocked=$must',
    );

    if (blocked != must) {
      blocked = must;
      notifyListeners();
    } else if (must) {
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

  Future<Map<String, dynamic>?> _fetchConfig() async {
    try {
      final row = await withNetworkTimeout(
        Supabase.instance.client
            .from('app_settings')
            .select('value')
            .eq('key', 'force_update')
            .maybeSingle(),
      );
      final parsed = _asMap(row?['value']);
      if (parsed != null) return parsed;
    } catch (e) {
      debugPrint('ForceUpdateService fetch: $e');
    }
    try {
      return _asMap(AppCatalogService.instance.setting('force_update'));
    } catch (_) {
      return null;
    }
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic>? _asMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }
}
