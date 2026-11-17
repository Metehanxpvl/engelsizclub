import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/utils/tr_norm.dart';

void main() {
  group('normTrForSearch', () {
    test('Özel matches ozel', () {
      expect(normTrForSearch('Özel'), 'ozel');
      expect(normTrForSearch('özel'), 'ozel');
      expect(
        normTrForSearch('Özel Eğitim Merkezi').contains('ozel'),
        isTrue,
      );
      expect(
        normTrForSearch('Özel Eğitim Merkezi')
            .contains(normTrForSearch('ozel')),
        isTrue,
      );
    });

    test('İstanbul matches istanbul', () {
      expect(normTrForSearch('İstanbul'), 'istanbul');
      expect(normTrForSearch('istanbul'), 'istanbul');
      expect(normTrForSearch('İSTANBUL'), 'istanbul');
      // No leftover combining dot from İ → i̇
      expect(normTrForSearch('İstanbul').contains('\u0307'), isFalse);
    });

    test('dotted I / undotted ı both fold to i', () {
      expect(normTrForSearch('Iğdır'), 'igdir');
      expect(normTrForSearch('ığdır'), 'igdir');
    });

    test('other Turkish specials fold', () {
      expect(normTrForSearch('Şğüç'), 'sguc');
      expect(normTrForSearch('ÇANKAYA'), 'cankaya');
    });
  });

  group('haystackMatchesQuery', () {
    test('multi-word query matches split fields', () {
      const hay = 'X Fizik Tedavi Merkezi Kadıköy İstanbul';
      expect(haystackMatchesQuery(hay, 'kadıköy fizik tedavi'), isTrue);
      expect(haystackMatchesQuery(hay, 'Kadikoy Fizik'), isTrue);
    });

    test('full-string contains would fail but tokens pass', () {
      const name = 'Özel ABC Eğitim ve Rehabilitasyon Merkezi';
      const address = 'Kadıköy, İstanbul';
      final hay = '$name $address';
      // Contiguous full query is NOT in a single field:
      expect(normTrForSearch(name).contains('kadikoy fizik'), isFalse);
      expect(haystackMatchesQuery(hay, 'özel eğitim kadıköy'), isTrue);
    });

    test('unrelated tokens fail', () {
      expect(
        haystackMatchesQuery('Fizik Tedavi Merkezi', 'otel banka'),
        isFalse,
      );
    });
  });
}
