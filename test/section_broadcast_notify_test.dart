import 'package:engelsizclub/section_broadcast_notify.dart';
import 'package:engelsizclub/widgets/gezi_kampanya_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('broadcast titles include section names', () {
    expect(sectionBroadcastTitle(type: 'kampanya', title: 'Migros'), 'Kampanya: Migros');
    expect(sectionBroadcastTitle(type: 'etkinlik', title: 'Konser'), 'Etkinlik: Konser');
    expect(sectionBroadcastTitle(type: 'gezi', title: 'Anıtkabir'), 'Gezi Rehberi: Anıtkabir');
    expect(
      sectionBroadcastTitle(type: 'kariyer', title: 'Öğretmen'),
      'Engelsiz Kariyer: Öğretmen',
    );
  });

  test('broadcast refs are namespaced', () {
    expect(sectionBroadcastRef('kampanya', '12'), 'kp:12');
    expect(sectionBroadcastRef('etkinlik', '9'), 'et:9');
    expect(sectionBroadcastRef('gezi', '3'), 'gz:3');
    expect(sectionBroadcastRef('kariyer', 'abc'), 'kr:abc');
  });

  testWidgets('feed card shows notify megaphone for admin', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GeziKampanyaFeedCard(
            imageUrl: '',
            title: 'Test kampanya',
            description: 'KOD123',
            openPhotoOnTap: false,
            onNotify: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
  });

  testWidgets('feed card hides notify megaphone without callback', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GeziKampanyaFeedCard(
            imageUrl: '',
            title: 'Test kampanya',
            openPhotoOnTap: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.campaign_outlined), findsNothing);
  });
}
