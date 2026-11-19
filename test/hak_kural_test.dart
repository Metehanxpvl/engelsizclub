import 'package:engelsizclub/hak/hak_dosyasi.dart';
import 'package:engelsizclub/hak/hak_kural.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('degerlendir operators', () {
    test('>=', () {
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '>=', deger: 40),
          {'oran': 40},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '>=', deger: 40),
          {'oran': 39},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('<=', () {
      expect(
        degerlendir(
          const HakKural(alan: 'hane_kisi', op: '<=', deger: 4),
          {'hane_kisi': 4},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'hane_kisi', op: '<=', deger: 4),
          {'hane_kisi': 5},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('>', () {
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '>', deger: 40),
          {'oran': 41},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '>', deger: 40),
          {'oran': 40},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('<', () {
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '<', deger: 90),
          {'oran': 70},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'oran', op: '<', deger: 90),
          {'oran': 90},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('==', () {
      expect(
        degerlendir(
          const HakKural(alan: 'yas_grubu', op: '==', deger: '18alti'),
          {'yas_grubu': '18alti'},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'agir', op: '==', deger: true),
          {'agir': true},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'sgk', op: '==', deger: 'isci'),
          {'sgk': 'memur'},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('!=', () {
      expect(
        degerlendir(
          const HakKural(alan: 'rapor_turu', op: '!=', deger: 'yok'),
          {'rapor_turu': 'cozger'},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(alan: 'rapor_turu', op: '!=', deger: 'yok'),
          {'rapor_turu': 'yok'},
        ),
        KuralSonuc.saglanmiyor,
      );
    });

    test('in', () {
      expect(
        degerlendir(
          const HakKural(
            alan: 'sgk',
            op: 'in',
            deger: ['memur', 'isci', 'emekli'],
          ),
          {'sgk': 'isci'},
        ),
        KuralSonuc.saglaniyor,
      );
      expect(
        degerlendir(
          const HakKural(
            alan: 'sgk',
            op: 'in',
            deger: ['memur', 'isci'],
          ),
          {'sgk': 'calismiyor'},
        ),
        KuralSonuc.saglanmiyor,
      );
    });
  });

  test('unknown / missing field → bilinmiyor', () {
    expect(
      degerlendir(
        const HakKural(alan: 'oran', op: '>=', deger: 40),
        {},
      ),
      KuralSonuc.bilinmiyor,
    );
    expect(
      degerlendir(
        const HakKural(alan: 'il', op: '==', deger: 'Ankara'),
        {'yas_grubu': '18ustu'},
      ),
      KuralSonuc.bilinmiyor,
    );
  });

  test('kisi_basi_gelir derived from hane_gelir / hane_kisi', () {
    expect(
      degerlendir(
        const HakKural(alan: 'kisi_basi_gelir', op: '<=', deger: 5000),
        {'hane_gelir': 10000, 'hane_kisi': 2},
      ),
      KuralSonuc.saglaniyor,
    );
    expect(
      degerlendir(
        const HakKural(alan: 'kisi_basi_gelir', op: '<=', deger: 4000),
        {'hane_gelir': 10000, 'hane_kisi': 2},
      ),
      KuralSonuc.saglanmiyor,
    );
    expect(
      degerlendir(
        const HakKural(alan: 'kisi_basi_gelir', op: '<=', deger: 5000),
        {'hane_gelir': 10000},
      ),
      KuralSonuc.bilinmiyor,
    );
  });

  group('uygunlukKural', () {
    test('all saglaniyor → buyukIhtimalle', () {
      const d = HakDosyasi(
        kimler: [
          HakKriter(
            metin: 'Oran ≥ 40',
            kural: HakKural(alan: 'oran', op: '>=', deger: 40),
          ),
          HakKriter(
            metin: '18 altı',
            kural: HakKural(alan: 'yas_grubu', op: '==', deger: '18alti'),
          ),
        ],
      );
      expect(
        uygunlukKural(d, {'oran': 70, 'yas_grubu': '18alti'}),
        HakUygunluk.buyukIhtimalle,
      );
    });

    test('any saglanmiyor → uygunDegil', () {
      const d = HakDosyasi(
        kimler: [
          HakKriter(
            metin: 'Oran ≥ 40',
            kural: HakKural(alan: 'oran', op: '>=', deger: 40),
          ),
        ],
      );
      expect(
        uygunlukKural(d, {'oran': 20}),
        HakUygunluk.uygunDegil,
      );
    });

    test('unknown → sartlaraBagli', () {
      const d = HakDosyasi(
        kimler: [
          HakKriter(
            metin: 'Oran ≥ 40',
            kural: HakKural(alan: 'oran', op: '>=', deger: 40),
          ),
        ],
      );
      expect(uygunlukKural(d, {}), HakUygunluk.sartlaraBagli);
    });

    test('no ruled criteria → null', () {
      const d = HakDosyasi(
        kimler: [
          HakKriter(metin: 'Serbest metin'),
        ],
        ozet: 'x',
      );
      expect(uygunlukKural(d, {'oran': 40}), isNull);
    });
  });
}
