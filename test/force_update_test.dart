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
    test('TEST 1: 1.0.80 vs 1.0.81 optional', () {
      expect(
        resolveUpdatePrompt(
          current: '1.0.80',
          minSupported: '1.0.0',
          latest: '1.0.81',
        ),
        UpdatePromptKind.optional,
      );
    });

    test('TEST 2: equal versions → no screen', () {
      expect(
        resolveUpdatePrompt(
          current: '1.0.81',
          minSupported: '1.0.75',
          latest: '1.0.81',
        ),
        UpdatePromptKind.none,
      );
    });

    test('TEST 3: 1.0.82 > latest → no screen', () {
      expect(
        resolveUpdatePrompt(
          current: '1.0.82',
          minSupported: '1.0.75',
          latest: '1.0.81',
        ),
        UpdatePromptKind.none,
      );
    });

    test('TEST 4: 1.0.74 < min 1.0.75 force', () {
      expect(
        resolveUpdatePrompt(
          current: '1.0.74',
          minSupported: '1.0.75',
          latest: '1.0.81',
        ),
        UpdatePromptKind.mandatory,
      );
    });

    test('TEST 5: optional with min 1.0.75 latest 1.0.81', () {
      expect(
        resolveUpdatePrompt(
          current: '1.0.80',
          minSupported: '1.0.75',
          latest: '1.0.81',
        ),
        UpdatePromptKind.optional,
      );
    });

    test('TEST 6: offline fail-open', () async {
      final kind = await resolveUpdatePromptFromFetch(
        current: '1.0.80',
        fetch: () async => throw Exception('offline'),
      );
      expect(kind, UpdatePromptKind.none);
    });

    test('TEST 7: API error fail-open', () async {
      final kind = await resolveUpdatePromptFromFetch(
        current: '1.0.74',
        fetch: () async => throw Exception('500'),
      );
      expect(kind, UpdatePromptKind.none);
    });

    test('TEST 8: skip persists same version', () async {
      SharedPreferences.setMockInitialValues({});
      const latest = '1.0.81';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(forceUpdateSkipPrefsKey(latest), true);

      final skipped = prefs.getBool(forceUpdateSkipPrefsKey(latest)) == true
          ? latest
          : null;
      expect(
        resolveUpdatePrompt(
          current: '1.0.80',
          minSupported: '1.0.75',
          latest: latest,
          skippedLatest: skipped,
        ),
        UpdatePromptKind.none,
      );
    });

    test('TEST 9: new version shows again after skip', () async {
      SharedPreferences.setMockInitialValues({
        forceUpdateSkipPrefsKey('1.0.81'): true,
      });
      final prefs = await SharedPreferences.getInstance();
      const prev = '1.0.81';
      const next = '1.0.82';
      final skippedPrev = prefs.getBool(forceUpdateSkipPrefsKey(prev)) == true
          ? prev
          : null;
      expect(
        resolveUpdatePrompt(
          current: '1.0.80',
          minSupported: '1.0.75',
          latest: next,
          skippedLatest: skippedPrev,
        ),
        UpdatePromptKind.optional,
      );
      expect(prefs.getBool(forceUpdateSkipPrefsKey(next)), isNot(true));
    });
  });
}
