import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engelsizclub/l10n/app_strings.dart';
import 'package:engelsizclub/widgets/store_download_prompt.dart';

void main() {
  testWidgets('StoreDownloadDialog shows prompt and dismisses on later',
      (tester) async {
    var later = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StoreDownloadDialog(
            onLater: () => later = true,
            onOpenAppStore: () {},
            onOpenPlay: () {},
          ),
        ),
      ),
    );

    expect(find.text(S.t('download_app_prompt')), findsOneWidget);
    expect(find.byType(StoreBadgeButton), findsNWidgets(2));

    await tester.tap(find.text(S.t('download_app_later')));
    await tester.pump();
    expect(later, isTrue);
  });

  test('web store prompt flag is sticky after dismiss', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(webStorePromptConsumed(prefs), isFalse);
    await webStorePromptMarkConsumed(prefs);
    expect(webStorePromptConsumed(prefs), isTrue);
    expect(prefs.getBool(kWebStorePromptPrefsKey), isTrue);
  });

  test('web store prompt is home-path only', () {
    expect(webStorePromptIsHomePath(Uri.parse('https://www.engelsizclub.com/')),
        isTrue);
    expect(
        webStorePromptIsHomePath(
            Uri.parse('https://www.engelsizclub.com/index.html')),
        isTrue);
    expect(
        webStorePromptIsHomePath(
            Uri.parse('https://www.engelsizclub.com/destek-sorgu.html')),
        isFalse);
    expect(
        webStorePromptIsHomePath(
            Uri.parse('https://www.engelsizclub.com/evde-egitim.html')),
        isFalse);
  });
}
