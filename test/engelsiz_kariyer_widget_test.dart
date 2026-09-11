import 'package:engelsizclub/gezi_kampanya_store.dart';
import 'package:engelsizclub/widgets/gezi_kampanya_home_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Engelsiz Kariyer kutusu en solda; diğer kutular duruyor', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GeziKampanyaHomeSection(userEmail: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(kShowEngelsizKariyerTile, isTrue);
    expect(find.text('Engelsiz Kariyer'), findsOneWidget);
    expect(find.text('Gezi Rehberi'), findsOneWidget);
    expect(find.text('Kampanyalar'), findsOneWidget);
    expect(find.text('Etkinlikler'), findsOneWidget);
    final kariyer = tester.getTopLeft(find.text('Engelsiz Kariyer'));
    final gezi = tester.getTopLeft(find.text('Gezi Rehberi'));
    final kampanya = tester.getTopLeft(find.text('Kampanyalar'));
    final etkinlik = tester.getTopLeft(find.text('Etkinlikler'));
    expect(kariyer.dx, lessThan(gezi.dx));
    expect(gezi.dx, lessThan(kampanya.dx));
    expect(kampanya.dx, lessThan(etkinlik.dx));
    expect(kKariyerTileKey, 'kariyer');
  });
}
