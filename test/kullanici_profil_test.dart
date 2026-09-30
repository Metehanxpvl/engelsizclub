import 'package:engelsizclub/kullanici_profil_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uzman özgeçmişi json roundtrip and visible on aile', () {
    const uzman = KullaniciProfil(
      adSoyad: 'Ayşe Yılmaz',
      meslek: 'Fizyoterapist',
      egitim: 'Hacettepe PT 2016',
      deneyimYili: '8 yıl',
      uzmanliklar: 'CP, spina bifida',
      sertifikalar: 'NDT',
      calismaSekli: 'Evde / merkez',
      hakkimda: 'Ailelerle çalışırım',
    );
    expect(uzman.hasOzgecmis, isTrue);
    final back = KullaniciProfil.fromJson(uzman.toJson());
    expect(back.meslek, 'Fizyoterapist');
    expect(back.egitim, 'Hacettepe PT 2016');
    expect(back.deneyimYili, '8 yıl');
    expect(back.uzmanliklar, 'CP, spina bifida');
    expect(back.sertifikalar, 'NDT');
    expect(back.calismaSekli, 'Evde / merkez');
    expect(back.hasOzgecmis, isTrue);

    final aile = KullaniciProfil(
      adSoyad: back.adSoyad,
      meslek: back.meslek,
      egitim: back.egitim,
      deneyimYili: back.deneyimYili,
      uzmanliklar: back.uzmanliklar,
      sertifikalar: back.sertifikalar,
      calismaSekli: back.calismaSekli,
      hakkimda: back.hakkimda,
      aileRolu: 'Anne',
      arananDestek: 'Fizyoterapi',
    );
    expect(aile.hasOzgecmis, isTrue);
    expect(aile.aileRolu, 'Anne');
    expect(aile.meslek, 'Fizyoterapist');
  });
}
