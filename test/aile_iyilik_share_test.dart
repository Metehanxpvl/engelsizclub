import 'package:engelsizclub/kredi_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forum share snack awards iyilik only for new aile topics', () {
    expect(
      forumShareSnack(isEdit: true, isExpert: false, awardedIyilik: true),
      'Gönderi güncellendi ✅',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: false, awardedIyilik: false),
      'Gönderiniz paylaşıldı — herkes görebilir ✅',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: false, awardedIyilik: true),
      'Gönderiniz paylaşıldı — herkes görebilir ✅ +2 iyilik puanı 💚',
    );
    expect(
      forumShareSnack(isEdit: false, isExpert: true, awardedIyilik: false),
      'Köşe yazınız paylaşıldı — herkes görebilir ✅',
    );
  });

  test('ilan share snack awards iyilik only for new cloud posts', () {
    expect(
      ilanShareSnack(isEdit: true, awardedIyilik: true),
      'İlan güncellendi ✅',
    );
    expect(
      ilanShareSnack(isEdit: false, awardedIyilik: false),
      'İlanınız yayınlandı ✅',
    );
    expect(
      ilanShareSnack(isEdit: false, awardedIyilik: true),
      'İlanınız yayınlandı. +2 iyilik puanı 💚',
    );
  });

  test('only aile role gets iyilik for shares', () {
    expect(awardsIyilikForShare('aile'), isTrue);
    expect(awardsIyilikForShare('uzman'), isFalse);
    expect(awardsIyilikForShare('bakici'), isFalse);
    expect(awardsIyilikForShare('bakıcı'), isFalse);
    expect(isProfUserType('uzman'), isTrue);
    expect(isProfUserType('bakıcı'), isTrue);
    expect(isAileUserType('uzman'), isFalse);
    expect(isAileUserType('bakici'), isFalse);
  });
}
