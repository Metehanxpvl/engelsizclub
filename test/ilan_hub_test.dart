import 'package:engelsizclub/data/ilanlar_data.dart';
import 'package:engelsizclub/data/otomobil_catalog.dart';
import 'package:engelsizclub/services/catalog_adapters.dart';
import 'package:engelsizclub/widgets/otomobil_hasar_schematic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hub splits ikinciel product alts from general 2. el', () {
    expect(isIkincielProductHubAlt(kIkincielAltElEmegi), isTrue);
    expect(isIkincielProductHubAlt(kIkincielAltOrganik), isTrue);
    expect(isIkincielProductHubAlt(kIkincielAltOtomobil), isTrue);
    expect(isIkincielProductHubAlt(kIkincielAltMedikal), isTrue);
    expect(isIkincielGeneralAlt(kIkincielAltOtomobil), isFalse);
    expect(isIkincielProductHubAlt(kIkincielAltDiger), isFalse);
    expect(isIkincielGeneralAlt(kIkincielAltMedikal), isFalse);
    expect(isIkincielGeneralAlt(kIkincielAltElEmegi), isFalse);
    expect(
      kIkincielAltKategoriler,
      containsAll([
        kIkincielAltMedikal,
        kIkincielAltDiger,
        kIkincielAltElEmegi,
        kIkincielAltOrganik,
        kIkincielAltOtomobil,
      ]),
    );
  });

  test('ikinciel category strings resolve to hub alts', () {
    expect(ikincielAltKategoriOf('El Emeği Ürünler'), kIkincielAltElEmegi);
    expect(ikincielAltKategoriOf('organik urunler'), kIkincielAltOrganik);
    expect(ikincielAltKategoriOf('Otomobil'), kIkincielAltOtomobil);
    expect(ikincielAltKategoriOf('araba'), kIkincielAltOtomobil);
    expect(isOtomobilIlan('vasita'), isTrue);
    expect(ikincielAltKategoriOf('Medikal Malzemeler'), kIkincielAltMedikal);
    expect(ikincielAltKategoriOf(''), kIkincielAltDiger);
    expect(
      ikincielAltKategoriOf('Kiralık cihaz', extras: const ['Kiralık cihaz']),
      'Kiralık cihaz',
    );
  });

  test('aile sees only own uzman/bakici listings; uzman and bakici see all', () {
    expect(aileSeesOnlyOwnSeekListings('aile'), isTrue);
    expect(aileSeesOnlyOwnSeekListings(''), isTrue);
    expect(aileSeesOnlyOwnSeekListings('Aile'), isTrue);
    expect(aileSeesOnlyOwnSeekListings('uzman'), isFalse);
    expect(aileSeesOnlyOwnSeekListings('bakici'), isFalse);
    expect(aileSeesOnlyOwnSeekListings('bakıcı'), isFalse);
    expect(
      isSeekListingVisibleToViewer(
        ownerOnly: true,
        ownerEmail: 'a@b.com',
        viewerEmail: 'a@b.com',
      ),
      isTrue,
    );
    expect(
      isSeekListingVisibleToViewer(
        ownerOnly: true,
        ownerEmail: 'a@b.com',
        viewerEmail: 'other@b.com',
      ),
      isFalse,
    );
    expect(
      isSeekListingVisibleToViewer(
        ownerOnly: true,
        ownerEmail: 'a@b.com',
        viewerEmail: '',
      ),
      isFalse,
    );
    expect(
      isSeekListingVisibleToViewer(
        ownerOnly: false,
        ownerEmail: 'a@b.com',
        viewerEmail: 'other@b.com',
      ),
      isTrue,
    );
  });

  test('uzman hub uses existing category values', () {
    expect(isIlanIsAriyorum(kIlanCatIsAriyorum), isTrue);
    expect(isIlanIsAriyorum('iş arıyorum'), isTrue);
    expect(isIlanIsAriyorum(kIlanCatUzmanAriyorum), isFalse);
    expect(normalizeUzmanListingCategory('İş Arıyorum'), kIlanCatIsAriyorum);
    expect(normalizeUzmanListingCategory(null), kIlanCatUzmanAriyorum);
  });

  test('hub card display ids stay stable and ignore emoji icons', () {
    expect(kIlanHubUzman, 'ilan-hub-uzman');
    expect(ilanHubExtraId('Kiralık cihaz'), 'ilan-hub-x-kiralik-cihaz');
    expect(isIlanHubImageUrl('https://cdn.example.com/a.png'), isTrue);
    expect(isIlanHubImageUrl('📁'), isFalse);
    expect(isIlanHubImageUrl(''), isFalse);
    expect(
      CatalogAdapters.ilanHubStyle(kIlanHubUzman, 'Uzman Ara').title,
      'Uzman Ara',
    );
  });

  test('hub hidden flag is stored in catalog meta', () {
    expect(ilanHubMetaIsHidden(null), isFalse);
    expect(ilanHubMetaIsHidden({'hubKey': 'uzman'}), isFalse);
    expect(ilanHubMetaIsHidden({'hidden': false}), isFalse);
    expect(ilanHubMetaIsHidden({'hubKey': 'uzman', 'hidden': true}), isTrue);
    expect(isIlanHubHidden(kIlanHubUzman), isFalse);
  });

  test('form values map to existing kinds', () {
    expect(CatalogAdapters.ilanKindForFormValue(kIlanCatIsAriyorum), 'uzman');
    expect(CatalogAdapters.ilanKindForFormValue('Uzman Arıyorum'), 'uzman');
    expect(
      CatalogAdapters.ilanKindForFormValue('Bakıcı/Temizlik Görevlisi Arıyorum'),
      'bakici',
    );
    expect(CatalogAdapters.ilanKindForFormValue('2. El Alet'), 'ikinciel');
    expect(CatalogAdapters.ilanKindForFormValue(kIkincielAltElEmegi), 'ikinciel');
    expect(CatalogAdapters.ilanKindForFormValue(kIkincielAltOrganik), 'ikinciel');
    expect(CatalogAdapters.ilanKindForFormValue(kIkincielAltOtomobil), 'ikinciel');
    expect(CatalogAdapters.ilanKindForFormValue(kIkincielAltMedikal), 'ikinciel');
  });

  test('otomobil note encodes sahibinden fields and survives scrub', () {
    const spec = OtomobilSpec(
      marka: 'Renault',
      model: 'Clio',
      yil: '2018',
      km: '145000',
      yakit: 'Dizel',
      vites: 'Manuel',
    );
    final raw = encodeOtomobilNote(spec, 'Bakımlı araç. 0555 111 22 33 ara');
    final scrubbed = scrubIlanListingText(raw);
    final split = splitOtomobilNote(scrubbed);
    expect(split.spec?.marka, 'Renault');
    expect(split.spec?.model, 'Clio');
    expect(split.spec?.km, '145000');
    expect(visibleIlanNote(scrubbed), contains('Bakımlı'));
    expect(visibleIlanNote(scrubbed), isNot(contains('0555')));
    expect(visibleIlanNote(scrubbed), isNot(contains('[[EC_CAR]]')));
    expect(kIlanHubOtomobil, 'ilan-hub-otomobil');
    expect(otomobilModellerOf('Volkswagen'), contains('Golf'));
    expect(otomobilModellerOf('Citroen'), contains('C4 X'));
    expect(otomobilModellerOf('Citroen'), contains('C-Elysee'));
    expect(otomobilModellerOf('Citroen'), contains('Diğer'));
    expect(otomobilModellerOf('Renault'), contains('Megane Sedan'));
  });

  test('otomobil painted-panel map roundtrips in listing note', () {
    final spec = OtomobilSpec(
      marka: 'Citroen',
      model: 'C4 X',
      hasar: const {
        'sag_arka_camurluk': kOtomobilHasarLokal,
        'kaput': kOtomobilHasarBoya,
      },
    );
    final split = splitOtomobilNote(encodeOtomobilNote(spec, 'Temiz'));
    expect(split.spec?.hasar['sag_arka_camurluk'], kOtomobilHasarLokal);
    expect(split.spec?.hasar['kaput'], kOtomobilHasarBoya);
    expect(split.spec?.hasarSatirlari, hasLength(2));
    final toggled = otomobilHasarToggle(spec.hasar, 'sag_arka_camurluk');
    expect(toggled['sag_arka_camurluk'], kOtomobilHasarBoya);
    expect(otomobilParcaLabel('sag_arka_camurluk'), 'Sağ Arka Çamurluk');
  });

  test('schematic uses sahibinden image and maps rear-right fender', () {
    expect(kOtomobilHasarAsset, 'assets/images/otomobil_hasar.png');
    const size = Size(634, 625);
    expect(
      hitOtomobilParca(const Offset(317, 55), size),
      'on_tampon',
    );
    expect(
      hitOtomobilParca(const Offset(480, 490), size),
      'sag_arka_camurluk',
    );
  });
}
