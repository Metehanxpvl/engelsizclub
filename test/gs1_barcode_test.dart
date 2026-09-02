import 'package:flutter_test/flutter_test.dart';

import 'package:engelsizclub/utils/gs1_barcode.dart';

void main() {
  test('AI (01) parentheses → EAN-13', () {
    const raw =
        '(01)08699529150121(21)12345678901234(17)251231(10)LOT42';
    expect(Gs1Barcode.lookupCode(raw), '8699529150121');
  });

  test('concatenated GS1 Data Matrix → GTIN', () {
    const raw = '010869952915012121ABC12345678901725123110LOT42';
    expect(Gs1Barcode.lookupCode(raw), '8699529150121');
  });

  test('FNC1 / GS separated AI 01', () {
    const gs = '\u001D';
    final raw = '0108699529150121${gs}2112345678901234${gs}17251231${gs}10LOT';
    expect(Gs1Barcode.lookupCode(raw), '8699529150121');
  });

  test('FNC1 prefix (ASCII 232) then AI 01', () {
    expect(
      Gs1Barcode.lookupCode('\u00E80108699529150121\u00E821ABC'),
      '8699529150121',
    );
  });

  test('AIM prefix ]d2 then AI 01', () {
    expect(
      Gs1Barcode.lookupCode(']d2010869952915012110LOT'),
      '8699529150121',
    );
  });

  test('raw EAN-13 / GTIN-14 / EAN-8', () {
    expect(Gs1Barcode.lookupCode('8699529150121'), '8699529150121');
    expect(Gs1Barcode.lookupCode('08699529150121'), '8699529150121');
    expect(Gs1Barcode.lookupCode('86912345'), '86912345');
  });

  test('non-GTIN payload is ignored', () {
    expect(Gs1Barcode.lookupCode('https://example.com/ilac'), isNull);
    expect(Gs1Barcode.lookupCode(''), isNull);
  });

  test('e-KT HTTPS is a prospectus URL; GS1 resolver is not', () {
    expect(
      Gs1Barcode.prospectusHttpUrl('https://ekt.example/parol'),
      'https://ekt.example/parol',
    );
    expect(
      Gs1Barcode.prospectusHttpUrl('https://id.gs1.org/01/08699529150121'),
      isNull,
    );
    expect(Gs1Barcode.prospectusHttpUrl('0108699529150121'), isNull);
  });

  test('GS1 Digital Link URL → EAN-13', () {
    expect(
      Gs1Barcode.lookupCode('https://id.gs1.org/01/08699529150121'),
      '8699529150121',
    );
    expect(
      Gs1Barcode.lookupCode(
        'https://example.com/01/08699529150121/21/LOT42',
      ),
      '8699529150121',
    );
    expect(
      Gs1Barcode.lookupCode('https://brand.example/p?01=08699529150121'),
      '8699529150121',
    );
  });

  test('cache keys include GTIN-14 and EAN-13', () {
    expect(
      Gs1Barcode.cacheKeys('8699529150121'),
      containsAll(['8699529150121', '08699529150121']),
    );
  });

  test('GS1 check digit for known EAN-13', () {
    expect(Gs1Barcode.checkDigit('869971701010'), 9);
  });

  test('lookupCandidates try GTIN-14, EAN-13, with/without check', () {
    final from14 = Gs1Barcode.lookupCandidates('08699529150121');
    expect(
      from14.map((c) => c.value),
      containsAll(['8699529150121', '08699529150121']),
    );
    expect(from14.map((c) => c.form), contains('raw'));
    expect(from14.map((c) => c.form), contains('gtin14_pad'));

    final noCheck = Gs1Barcode.lookupCandidates('869971701010');
    expect(noCheck.map((c) => c.value), contains('8699717010109'));
    expect(noCheck.map((c) => c.form), contains('ean13_add_check'));
  });
}
