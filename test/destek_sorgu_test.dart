import 'package:engelsizclub/data/destek_sorgu_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SGK pay is min(quote, SUT) and pocket is the rest', () {
    final calc = DestekSorguHesap.fromQuote(16934.40, 20000)!;
    expect(calc.sgkPay, 16934.40);
    expect(calc.pocket, closeTo(3065.60, 0.001));
  });

  test('quote below SUT has no out-of-pocket', () {
    final calc = DestekSorguHesap.fromQuote(1848, 1500)!;
    expect(calc.sgkPay, 1500);
    expect(calc.pocket, 0);
  });

  test('renewal labels follow official miat, not invented months', () {
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'aktif').renewLabel,
      '5 yıl',
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'havali-minder').renewLabel,
      '5 yıl',
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'cpap').renewLabel,
      '10 yıl',
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'kafo').renewLabel,
      '2 yıl',
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'bez-yetiskin').renewLabel,
      'SUT’ta miat belirtilmemiş',
    );
  });

  test('catalog prices match official SUT annex cells', () {
    expect(kDestekSorguFallback.any((e) => e.id == 'kafo'), isTrue);
    expect(kDestekSorguFallback.any((e) => e.id == 'transfemoral'), isTrue);
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'kafo').sutPrice,
      5312.16,
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'cpap').sutPrice,
      3265.92,
    );
    expect(
      kDestekSorguFallback.firstWhere((e) => e.id == 'bez-yetiskin').sutPrice,
      6.31,
    );
    expect(kDestekSorguFallback.any((e) => e.sutPrice == 3592.51), isFalse);
    expect(kDestekSorguFallback.any((e) => e.sutPrice == 832.92), isFalse);
    expect(kDestekSorguFallback.any((e) => e.sutPrice == 3500), isFalse);
    expect(kDestekSorguFallback.length, 30);
  });
}
