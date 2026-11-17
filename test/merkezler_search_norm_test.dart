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
}
