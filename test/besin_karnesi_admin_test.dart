import 'package:engelsizclub/admin_config.dart';
import 'package:engelsizclub/pages/besin_karnesi_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isAppAdmin matches existing admin email set', () {
    expect(isAppAdmin('sakir.caykara@gmail.com'), isTrue);
    expect(isAppAdmin('aile@example.com'), isFalse);
    expect(isAppAdmin(null), isFalse);
  });

  testWidgets('member can open Günlük Besin Analizi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => BesinKarnesiPage.open(
                  context,
                  userEmail: 'aile@example.com',
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Günlük Besin Analizi'), findsOneWidget);
    expect(find.textContaining('yöneticiler'), findsNothing);
  });

  testWidgets('guest without email cannot open karnesi', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => BesinKarnesiPage.open(
                  context,
                  userEmail: '',
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Günlük Besin Analizi'), findsNothing);
    expect(find.textContaining('üye olmanız'), findsOneWidget);
  });

  testWidgets('Karnemi Çıkar shows analyzing overlay then results', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => BesinKarnesiPage.open(
                  context,
                  userEmail: 'aile@example.com',
                ),
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.enterText(find.byType(TextField), '2 yumurta peynir sucuk');
    await tester.tap(find.widgetWithText(FilledButton, 'Karnemi Çıkar 🚀'));
    await tester.pump();
    expect(find.text('Analiz ediliyor'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Analiz ediliyor'), findsNothing);
    expect(find.text('Günün Mikro Besin Özeti'), findsOneWidget);
  });
}
