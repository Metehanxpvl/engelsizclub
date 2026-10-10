import 'package:engelsizclub/iyilik_market_store.dart';
import 'package:engelsizclub/kredi_store.dart';
import 'package:engelsizclub/widgets/iyilik_market_konfeti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forum share snack awards market points only for new topics', () {
    expect(
      forumShareSnack(isEdit: true, isExpert: false, awardedMarket: true),
      'Gönderi güncellendi ✅',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: false, awardedMarket: false),
      'Gönderiniz paylaşıldı — herkes görebilir ✅',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: false, awardedMarket: true),
      'Gönderiniz paylaşıldı — herkes görebilir ✅ +1 iyilik market puanı',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: true, awardedMarket: false),
      'Köşe yazınız paylaşıldı — herkes görebilir ✅',
    );
  });

  test('ilan share snack awards market points only for new cloud posts', () {
    expect(
      ilanShareSnack(isEdit: true, awardedMarket: true),
      'İlan güncellendi ✅',
    );
    expect(
      ilanShareSnack(isEdit: false, awardedMarket: false),
      'İlanınız yayınlandı ✅',
    );
    expect(
      ilanShareSnack(isEdit: false, awardedMarket: true),
      'İlanınız yayınlandı. +1 iyilik market puanı',
    );
  });

  test('harita snack uses market points not kredi', () {
    expect(haritaShareSnack(awardedMarket: true),
        'Yer kaydedildi. +1 iyilik market puanı');
    expect(haritaShareSnack(awardedMarket: false), 'Yer kaydedildi.');
    expect(
      kIyilikMarketTebrik,
      'Tebrikler 1 iyilik market puanı kazandınız',
    );
  });

  test('old iyilik share helper still distinguishes roles', () {
    expect(awardsIyilikForShare('aile'), isTrue);
    expect(awardsIyilikForShare('uzman'), isFalse);
    expect(awardsIyilikForShare('bakici'), isFalse);
  });

  testWidgets('konfeti overlay hides after animation', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IyilikMarketKonfeti(
            playId: 1,
            onFinished: () => finished = true,
          ),
        ),
      ),
    );
    expect(find.textContaining('Tebrikler'), findsOneWidget);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pump();
    await tester.pump();
    expect(finished, isTrue);
    expect(find.textContaining('Tebrikler'), findsNothing);
  });
}
