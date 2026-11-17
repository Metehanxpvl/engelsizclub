import 'package:engelsizclub/dernekler_store.dart';
import 'package:engelsizclub/widgets/dernekler_home_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are SERÇEV and Down Sendromlular Derneği with links', () {
    expect(kDefaultDernekler, hasLength(2));
    expect(kDefaultDernekler[0].title, 'SERÇEV');
    expect(kDefaultDernekler[0].hasLink, isTrue);
    expect(kDefaultDernekler[1].title, 'Down Sendromlular Derneği');
    expect(kDefaultDernekler[1].hasLink, isTrue);
  });

  test('visibleDernekler copies unmodifiable lists before sort', () {
    final frozen = List<DernekItem>.unmodifiable(kDefaultDernekler);
    final shown = visibleDernekler(frozen, admin: true);
    expect(shown, hasLength(2));
    expect(shown.first.title, 'SERÇEV');
  });

  test('hasLink requires http(s)', () {
    expect(
      const DernekItem(id: 1, title: 'A', websiteUrl: 'example.com').hasLink,
      isFalse,
    );
    expect(
      const DernekItem(
        id: 1,
        title: 'A',
        websiteUrl: 'https://example.com',
      ).hasLink,
      isTrue,
    );
  });

  testWidgets('Dernekler heading sits above two named tiles in one row',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DerneklerHomeSection(userEmail: ''),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dernekler'), findsOneWidget);
    expect(find.text('SERÇEV'), findsOneWidget);
    expect(find.text('Down Sendromlular Derneği'), findsOneWidget);
    expect(find.text('Bilgi Kütüphanesi'), findsNothing);
    final left = tester.getTopLeft(find.text('SERÇEV'));
    final right = tester.getTopLeft(find.text('Down Sendromlular Derneği'));
    expect(left.dx, lessThan(right.dx));
    expect((left.dy - right.dy).abs(), lessThan(2));
  });
}
