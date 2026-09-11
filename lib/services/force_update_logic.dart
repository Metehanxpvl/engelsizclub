/// Mağaza semver karşılaştırması (`1.0.9 < 1.0.10`). Build (`+200001`) yok sayılır.
int compareSemanticVersions(String a, String b) {
  final pa = semanticVersionParts(a);
  final pb = semanticVersionParts(b);
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

List<int> semanticVersionParts(String raw) {
  final core = raw.trim().split('+').first.split('-').first;
  final bits = core.split('.');
  int at(int i) {
    if (i >= bits.length) return 0;
    return int.tryParse(bits[i].trim()) ?? 0;
  }

  return [at(0), at(1), at(2)];
}

enum UpdatePromptKind { none, optional, mandatory }

/// [skippedLatest]: "Şimdi değil" ile saklanan sürüm. Yalnız opsiyoneli bastırır.
UpdatePromptKind resolveUpdatePrompt({
  required String current,
  required String minSupported,
  required String latest,
  String? skippedLatest,
}) {
  final cur = current.trim();
  final min = minSupported.trim();
  final lat = latest.trim();
  if (cur.isEmpty || lat.isEmpty) return UpdatePromptKind.none;

  final minOrZero = min.isEmpty ? '0.0.0' : min;
  if (compareSemanticVersions(cur, minOrZero) < 0) {
    return UpdatePromptKind.mandatory;
  }
  if (compareSemanticVersions(cur, lat) < 0) {
    final skipped = (skippedLatest ?? '').trim();
    if (skipped.isNotEmpty && compareSemanticVersions(skipped, lat) == 0) {
      return UpdatePromptKind.none;
    }
    return UpdatePromptKind.optional;
  }
  return UpdatePromptKind.none;
}

String forceUpdateSkipPrefsKey(String version) =>
    'force_update_skipped_v:${version.trim()}';

/// Ağ / parse hatalarında uygulama açık kalsın.
Future<UpdatePromptKind> resolveUpdatePromptFromFetch({
  required String current,
  required Future<({String min, String latest})?> Function() fetch,
  String? skippedLatest,
}) async {
  try {
    final remote = await fetch();
    if (remote == null) return UpdatePromptKind.none;
    return resolveUpdatePrompt(
      current: current,
      minSupported: remote.min,
      latest: remote.latest,
      skippedLatest: skippedLatest,
    );
  } catch (_) {
    return UpdatePromptKind.none;
  }
}

const kForceUpdatePlayUrl =
    'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub';
const kForceUpdateMarketUrl =
    'market://details?id=com.sakircaykara.engelsizclub';
const kForceUpdateIosUrl = 'https://apps.apple.com/app/id6799422264';
const kForceUpdateIosAppStoreId = '6799422264';
const kForceUpdateAndroidPackage = 'com.sakircaykara.engelsizclub';

class ForceUpdateRemoteConfig {
  const ForceUpdateRemoteConfig({
    required this.minimumSupportedVersion,
    required this.latestVersionAndroid,
    required this.latestVersionIOS,
    required this.androidUrl,
    required this.iosUrl,
  });

  final String minimumSupportedVersion;
  final String latestVersionAndroid;
  final String latestVersionIOS;
  final String androidUrl;
  final String iosUrl;

  String latestForIos(bool ios) =>
      ios ? latestVersionIOS : latestVersionAndroid;

  String storeUrlForIos(bool ios) => ios ? iosUrl : androidUrl;

  factory ForceUpdateRemoteConfig.fromJson(Object? raw) {
    final json = _asStringKeyMap(raw) ?? const <String, dynamic>{};
    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final v = json[key];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return fallback;
    }

    return ForceUpdateRemoteConfig(
      minimumSupportedVersion: pick(
        ['minimumSupportedVersion', 'minVersion', 'minimum_supported_version'],
        '0.0.0',
      ),
      latestVersionAndroid: pick([
        'latestVersionAndroid',
        'latest_version_android',
      ]),
      latestVersionIOS: pick([
        'latestVersionIOS',
        'latest_version_ios',
      ]),
      androidUrl: pick(
        ['android_url', 'androidUrl'],
        kForceUpdatePlayUrl,
      ),
      iosUrl: pick(
        ['ios_url', 'iosUrl'],
        kForceUpdateIosUrl,
      ),
    );
  }
}

Map<String, dynamic>? _asStringKeyMap(Object? raw) {
  if (raw is Map<String, dynamic>) return raw;
  if (raw is Map) {
    return raw.map((k, v) => MapEntry(k.toString(), v));
  }
  return null;
}
