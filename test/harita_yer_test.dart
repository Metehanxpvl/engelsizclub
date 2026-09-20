import 'package:engelsizclub/harita_yer_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('haritaFoldName folds Turkish and strips junk', () {
    expect(haritaFoldName('  Güneş Özel Eğitim  '), 'gunes ozel egitim');
    expect(haritaFoldName('İstanbul'), 'istanbul');
  });

  test('aile: every 5 reports awards one iyilik point', () {
    expect(haritaIyilikOdulThisReport(0), isFalse);
    expect(haritaIyilikOdulThisReport(4), isFalse);
    expect(haritaIyilikOdulThisReport(5), isTrue);
    expect(haritaIyilikOdulThisReport(9), isFalse);
    expect(haritaIyilikOdulThisReport(10), isTrue);
    expect(haritaIyilikKalan(0), 5);
    expect(haritaIyilikKalan(1), 4);
    expect(haritaIyilikKalan(5), 0);
    expect(haritaIyilikKalan(7), 3);
  });
}
