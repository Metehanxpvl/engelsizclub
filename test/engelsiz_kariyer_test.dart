import 'package:engelsizclub/engelsiz_kariyer_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge hides and edits without touching catalog ids', () {
    const catalog = [
      KariyerJob(
        id: '00009800137',
        title: 'Engelli ve Yaşlı Bakım Elemanı',
        city: 'Bursa / İnegöl',
        date: '08.10.2026',
        applyUrl: 'https://esube.iskur.gov.tr/Istihdam/AcikIsIlanDetay.aspx?uiID=00009800137',
      ),
      KariyerJob(
        id: '00009798341',
        title: 'Engelli ve Yaşlı Bakım Elemanı',
        city: 'Kayseri / Kocasinan',
        date: '07.10.2026',
        applyUrl: 'https://example.com/a',
      ),
    ];
    final overrides = KariyerOverrideMap.fromJson({
      'hidden': ['00009798341'],
      'edits': {
        '00009800137': {
          'title': 'Bakım elemanı (düzenlendi)',
          'city': 'Bursa',
        },
        'custom-1': {
          'title': 'Elle eklenen',
          'city': 'Ankara',
          'apply_url': 'https://esube.iskur.gov.tr/',
          'custom': true,
        },
      },
    });
    final merged = mergeKariyerJobs(catalog: catalog, overrides: overrides);
    expect(merged.length, 3);
    expect(merged[0].title, 'Bakım elemanı (düzenlendi)');
    expect(merged[0].city, 'Bursa');
    expect(merged[0].hidden, isFalse);
    expect(merged[1].id, '00009798341');
    expect(merged[1].hidden, isTrue);
    expect(merged[2].id, 'custom-1');
    expect(merged[2].custom, isTrue);
    expect(merged.where((j) => !j.hidden).map((j) => j.id).toList(), [
      '00009800137',
      'custom-1',
    ]);
  });

  test('sektor normalizes İŞKUR labels and filters client-side', () {
    expect(normalizeKariyerSektor('kamu', ''), kKariyerSektorKamu);
    expect(normalizeKariyerSektor('', 'Özel'), kKariyerSektorOzel);
    expect(normalizeKariyerSektor('ozel', 'Kamu'), kKariyerSektorKamu);
    const kamu = KariyerJob(
      id: 'k1',
      title: 'Kamu ilanı',
      city: 'Ankara',
      date: '01.01.2027',
      applyUrl: 'https://esube.iskur.gov.tr/',
      employerType: 'Kamu',
      sektor: 'kamu',
    );
    const ozel = KariyerJob(
      id: 'o1',
      title: 'Özel ilan',
      city: 'Bursa',
      date: '01.01.2027',
      applyUrl: 'https://esube.iskur.gov.tr/',
      employerType: 'Özel',
    );
    const custom = KariyerJob(
      id: 'custom-1',
      title: 'Elle',
      city: 'İzmir',
      date: '',
      applyUrl: 'https://esube.iskur.gov.tr/',
      custom: true,
    );
    expect(kariyerMatchesSektor(kamu, kKariyerSektorAll), isTrue);
    expect(kariyerMatchesSektor(ozel, kKariyerSektorAll), isTrue);
    expect(kariyerMatchesSektor(kamu, kKariyerSektorKamu), isTrue);
    expect(kariyerMatchesSektor(ozel, kKariyerSektorKamu), isFalse);
    expect(kariyerMatchesSektor(kamu, kKariyerSektorOzel), isFalse);
    expect(kariyerMatchesSektor(ozel, kKariyerSektorOzel), isTrue);
    expect(kariyerMatchesSektor(custom, kKariyerSektorKamu), isTrue);
    expect(KariyerJob.fromJson({'id': 'x', 'title': 't', 'employerType': 'Özel'}).sektor, kKariyerSektorOzel);
  });

  test('homepage tile order constant: kariyer is leftmost key', () {
    const keys = ['kariyer', 'gezi', 'kampanya', 'etkinlik'];
    expect(keys.first, 'kariyer');
    expect(keys.last, 'etkinlik');
  });
}
