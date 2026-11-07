import 'package:engelsizclub/google_auth_service.dart';
import 'package:engelsizclub/services/force_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('store version code matches pubspec +build fallback', () {
    expect(kAppBuildNumber, 201201);
    expect(ForceUpdateService.androidPackage, 'com.sakircaykara.engelsizclub');
    expect(ForceUpdateService.iosAppId, '6799422264');
  });

  test('Android update opens the Play Store listing, not an in-app overlay', () {
    expect(
      ForceUpdateService.defaultPlayUrl,
      'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    );
    expect(
      ForceUpdateService.defaultMarketUrl,
      'market://details?id=com.sakircaykara.engelsizclub',
    );
    expect(ForceUpdateService.instance.blocked, isFalse);
  });

  test('iOS update opens the App Store listing', () {
    expect(
      ForceUpdateService.defaultIosUrl,
      contains('id6799422264'),
    );
    expect(
      ForceUpdateService.defaultIosMarketUrl,
      'itms-apps://apps.apple.com/app/id6799422264',
    );
  });

  test('App Store version compare does not loop on truncated 1.1 vs 1.1.x', () {
    expect(compareAppVersions('1.1.25', '1.1.23'), greaterThan(0));
    expect(compareAppVersions('1.1.23', '1.1.25'), lessThan(0));
    expect(
      appStoreHasNewerVersion(localVersion: '1.1.25', storeVersion: '1.1.23'),
      isFalse,
    );
    expect(
      appStoreHasNewerVersion(localVersion: '1.1.22', storeVersion: '1.1.23'),
      isTrue,
    );
    expect(
      appStoreHasNewerVersion(localVersion: '1.1.25', storeVersion: '1.1'),
      isFalse,
    );
    expect(
      appStoreHasNewerVersion(localVersion: '1.0.103', storeVersion: '1.1.23'),
      isTrue,
    );
  });

  test('web Google gray-screen recovery stays enabled', () {
    expect(
      GoogleAuthService.reloadsAfterSuccessfulWebSignIn(isWeb: true),
      isTrue,
    );
    expect(
      GoogleAuthService.hidesAuthFormDuringPicker(isWeb: true),
      isFalse,
    );
  });
}
