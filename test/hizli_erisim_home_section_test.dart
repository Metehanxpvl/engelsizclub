import 'package:engelsizclub/widgets/hizli_erisim_home_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hızlı Erişim shows four shortcut tiles', (tester) async {
    var tarama = 0;
    var destek = 0;
    var haklar = 0;
    var harita = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HizliErisimHomeSection(
            onOpenTarama: () => tarama++,
            onOpenDestek: () => destek++,
            onOpenHaklar: () => haklar++,
            onOpenHarita: () => harita++,
          ),
        ),
      ),
    );

    expect(find.text('Hızlı Erişim'), findsOneWidget);
    expect(find.text('Tarama'), findsOneWidget);
    expect(find.text('Destek Sorgulama'), findsOneWidget);
    expect(find.text('Hak Sorgulama'), findsOneWidget);
    expect(find.text('Engelsiz Haritalar'), findsOneWidget);

    await tester.tap(find.text('Tarama'));
    await tester.tap(find.text('Destek Sorgulama'));
    await tester.tap(find.text('Hak Sorgulama'));
    await tester.tap(find.text('Engelsiz Haritalar'));
    await tester.pump();

    expect(tarama, 1);
    expect(destek, 1);
    expect(haklar, 1);
    expect(harita, 1);
  });

  testWidgets('Hızlı Erişim shows Yol Haritam card when callback given', (tester) async {
    var yol = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HizliErisimHomeSection(onOpenYolHaritasi: () => yol++),
        ),
      ),
    );
    expect(find.text('Yol Haritam'), findsOneWidget);
    await tester.tap(find.text('Yol Haritam'));
    await tester.pump();
    expect(yol, 1);
  });
}
