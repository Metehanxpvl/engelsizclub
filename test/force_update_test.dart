import 'package:engelsizclub/services/force_update_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('semver', () {
    test('1.0.9 < 1.0.10', () {
      expect(compareSemanticVersions('1.0.9', '1.0.10'), lessThan(0));
      expect(compareSemanticVersions('1.0.10', '1.0.9'), greaterThan(0));
    });

    test('ignores +build metadata', () {
      expect(compareSemanticVersions('1.1.4+200001', '1.1.4'), 0);
    });
  });

  group('resolveUpdatePrompt', () {
    test('older than latest is optional', () {
      expect(
        resolveUpdatePrompt(
          current: '1.1.2',
          minSupported: '1.0.0',
          latest: '1.1.3',
        ),
        UpdatePromptKind.optional,
      );
    });

    test('equal versions → no screen', () {
      expect(
        resolveUpdatePrompt(
          current: '1.1.3',
          minSupported: '1.0.0',
          latest: '1.1.3',
        ),
        UpdatePromptKind.none,
      );
    });

    test('below min is mandatory', () {
      expect(
        resolveUpdatePrompt(
          current: '1.1.2',
          minSupported: '1.1.3',
          latest: '1.1.3',
        ),
        UpdatePromptKind.mandatory,
      );
    });

    test('offline fail-open', () async {
      final kind = await resolveUpdatePromptFromFetch(
        current: '1.1.2',
        fetch: () async => throw Exception('offline'),
      );
      expect(kind, UpdatePromptKind.none);
    });

    test('skip persists same version', () async {
      SharedPreferences.setMockInitialValues({});
      const latest = '1.1.3';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(forceUpdateSkipPrefsKey(latest), true);
      expect(
        resolveUpdatePrompt(
          current: '1.1.2',
          minSupported: '1.0.0',
          latest: latest,
          skippedLatest: latest,
        ),
        UpdatePromptKind.none,
      );
    });

    test('platform latest keys win over generic latestVersion', () {
      final cfg = ForceUpdateRemoteConfig.fromJson({
        'latestVersion': '9.9.9',
        'latestVersionAndroid': '1.1.3',
        'latestVersionIOS': '1.1.12',
      });
      expect(cfg.latestForIos(false), '1.1.3');
      expect(cfg.latestForIos(true), '1.1.12');
      expect(cfg.androidUrl, kForceUpdatePlayUrl);
    });
  });
}
