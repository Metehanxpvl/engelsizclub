import 'package:engelsizclub/uzman_kosesi/expert_cv_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('admin health profession sort continues after existing groups', () {
    const groups = [
      MeslekGrubu(
        id: 1,
        key: 'fizyo',
        etiket: 'Fizyoterapist',
        ustGrup: kMeslekUstSaglik,
        sira: 20,
      ),
      MeslekGrubu(
        id: 2,
        key: 'bakici',
        etiket: 'Bakıcı',
        ustGrup: kMeslekUstBakim,
        sira: 90,
      ),
    ];
    expect(nextMeslekGrubuSira(groups, kMeslekUstSaglik), 30);
    expect(nextMeslekGrubuSira(const [], kMeslekUstSaglik), 10);
  });

  test('draft save only requires name and meslek', () {
    const d = ExpertCvProfile(fullName: 'Ayşe');
    final errs = validateExpertCv(
      draft: d,
      sablonlar: const [],
      fileUrls: const {},
    );
    expect(errs, contains('Meslek grubu'));
    expect(errs, isNot(contains('KVKK açık rıza onayı')));
  });

  test('publish requires kvkk; diploma file is optional', () {
    const diploma = MeslekAlanSablon(
      id: 1,
      meslekGrubuId: 1,
      alanKey: 'diploma',
      etiket: 'Diploma / meslek belgesi',
      tip: 'file',
      zorunlu: true,
    );
    final d = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      meslekGrubuId: 1,
      il: 'Ankara',
      kisaTanitim: 'x' * 12,
      kvkkOnay: false,
    );
    final errs = validateExpertCv(
      draft: d,
      sablonlar: const [diploma],
      fileUrls: const {},
      forPublish: true,
    );
    expect(errs, contains('KVKK açık rıza onayı'));
    expect(errs, isNot(contains('Diploma / meslek belgesi')));
  });

  test('file step always includes diploma even if template omitted it', () {
    expect(uzmanCvDosyaAlanlari(const []).single.alanKey, 'diploma');
    expect(
      uzmanCvDosyaAlanlari(const [
        MeslekAlanSablon(
          id: 1,
          meslekGrubuId: 1,
          alanKey: 'belge',
          etiket: 'Belge',
          tip: 'file',
        ),
      ]).map((e) => e.alanKey),
      ['belge', 'diploma'],
    );
    expect(
      uzmanCvDosyaAlanlari(const [kUzmanDiplomaDosyaAlani]).single.alanKey,
      'diploma',
    );
    expect(uzmanBelgeAlaniEtiketi('diploma'), 'Diploma / meslek belgesi');
  });

  test('diploma upload copy says a photo is enough', () {
    expect(kBelgeFotoAciklama, contains('fotoğrafı yeterlidir'));
    expect(kBelgeFotoAciklama, contains('PDF yüklemeniz gerekmez'));
    expect(kBelgeFotoOpsiyonelNot, contains('Zorunlu değil'));
    expect(belgeYukleButonMetni('diploma', yuklendi: false), 'Diploma fotoğrafı yükle');
    expect(belgeYukleButonMetni('diploma', yuklendi: true), 'Fotoğraf yüklendi');
    expect(belgeYukleButonMetni('belge', yuklendi: false), 'Belge fotoğrafı yükle');
  });

  test('shared diploma marks profile as verified', () {
    const withDiploma = ExpertCvProfile(
      meslekDetaylari: {'diploma': 'yuklendi'},
    );
    const without = ExpertCvProfile();
    expect(withDiploma.dogrulanmisProfil, isTrue);
    expect(without.dogrulanmisProfil, isFalse);
  });

  test('publish tanitim minimum is 10 characters', () {
    final short = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      meslekGrubuId: 1,
      il: 'Ankara',
      kisaTanitim: '123456789',
      kvkkOnay: true,
    );
    final ok = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      meslekGrubuId: 1,
      il: 'Ankara',
      kisaTanitim: '1234567890',
      kvkkOnay: true,
    );
    expect(
      validateExpertCv(draft: short, sablonlar: const [], fileUrls: const {}, forPublish: true),
      contains('Kısa tanıtım (en az 10 karakter)'),
    );
    expect(
      validateExpertCv(draft: ok, sablonlar: const [], fileUrls: const {}, forPublish: true),
      isNot(contains('Kısa tanıtım (en az 10 karakter)')),
    );
  });

  test('admin sees days live and whether points were paid', () {
    final now = DateTime.utc(2026, 11, 7);
    final live = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      status: 'published',
      publishedAt: DateTime.utc(2026, 10, 26),
      ilkAyKullanildi: true,
      odenenPuan: 0,
      ucretBitis: DateTime.utc(2026, 11, 25),
    );
    expect(uzmanProfilYayindaGun(live, now: now), 12);
    expect(uzmanProfilYayindaOzet(live, now: now), '12 gündür yayında');
    expect(
      uzmanProfilOdemeOzeti(live, now: now),
      'İlk 2 ay ücretsiz · henüz puan ödemedi',
    );
    const paid = ExpertCvProfile(odenenPuan: 5, ilkAyKullanildi: true);
    expect(uzmanProfilOdemeOzeti(paid), '5 puan ödendi');
    expect(paid.puanOdedi, isTrue);
    expect(uzmanProfilOdemeOzeti(const ExpertCvProfile()), 'Henüz puan ödemedi');
  });

  test('kart size costs 3 or 5 points; first 2 months are free', () {
    expect(uzmanKartPuan(1), 3);
    expect(uzmanKartPuan(2), 5);
    expect(kUzmanKartIlkUcretsizGun, 60);
    expect(uzmanKartYayinUcreti(existing: null, span: 2), 0);
    const used = ExpertCvProfile(ilkAyKullanildi: true);
    expect(uzmanKartYayinUcreti(existing: used, span: 1), 3);
    expect(uzmanKartYayinUcreti(existing: used, span: 2), 5);
    final covered = ExpertCvProfile(
      ilkAyKullanildi: true,
      ucretBitis: DateTime.now().add(const Duration(days: 10)),
    );
    expect(uzmanKartYayinUcreti(existing: covered, span: 2), 0);
    const expired = ExpertCvProfile(status: 'expired', ilkAyKullanildi: true);
    expect(uzmanKartYayinUcreti(existing: expired, span: 2), 5);
    expect(uzmanKartBoyutOzeti(1), 'Tek kutucuk · sonraki aylarda 3 puan');
    expect(uzmanKartBoyutOzeti(2), '2 kutucuk · sonraki aylarda 5 puan');
    expect(kUzmanKartUyeTarifeMetni, contains('ilk 2 ay ücretsiz'));
    expect(kUzmanKartUyeTarifeMetni, contains('tek kutucuk alan için 3 puan'));
    expect(kUzmanKartUyeTarifeMetni, contains('2 kutucuk alan için 5 puan'));
    expect(kUzmanKartUyeTarifeMetni, contains('hesabınızdan kesilir'));
    expect(kUzmanKartUstBilgi, kUzmanKartUyeTarifeMetni);
    expect(
      kUzmanYayinOnayBilgi,
      'Doğrulama yapıldıktan sonra profiliniz yayınlanacaktır.',
    );
    expect(
      uzmanKartUcretAciklamasi(span: 1, ucretsiz: true),
      contains('tek kutucuk alan için 3 puan hesabınızdan kesilir'),
    );
  });

  test('yer label is il / ilce', () {
    const p = ExpertCvProfile(il: 'İzmir', ilce: 'Bornova');
    expect(p.yerLabel, 'İzmir / Bornova');
  });

  test('textarea length is validated on publish', () {
    const s = MeslekAlanSablon(
      id: 1,
      meslekGrubuId: 1,
      alanKey: 'deneyim_aciklama',
      etiket: 'Deneyim açıklaması',
      tip: 'textarea',
      zorunlu: true,
    );
    final d = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      meslekGrubuId: 1,
      il: 'Ankara',
      kisaTanitim: 'x' * 12,
      kvkkOnay: true,
      meslekDetaylari: {'deneyim_aciklama': 'y' * 2001},
    );
    final errs = validateExpertCv(
      draft: d,
      sablonlar: const [s],
      fileUrls: const {},
      forPublish: true,
    );
    expect(errs, contains('Deneyim açıklaması (en fazla 2000 karakter)'));
  });

  test('publish does not require ilce deneyim or extra meslek fields', () {
    const s = MeslekAlanSablon(
      id: 1,
      meslekGrubuId: 1,
      alanKey: 'uzmanlik_alanlari',
      etiket: 'Uzmanlık alanları',
      tip: 'multi_select',
      zorunlu: true,
    );
    final d = ExpertCvProfile(
      fullName: 'Ayşe Yılmaz',
      meslekGrubuId: 1,
      il: 'Ankara',
      kisaTanitim: 'x' * 12,
      kvkkOnay: true,
    );
    expect(
      validateExpertCv(
        draft: d,
        sablonlar: const [s],
        fileUrls: const {},
        forPublish: true,
      ),
      isEmpty,
    );
  });

  test('contact preference can be message, phone or both', () {
    const both = ExpertCvProfile(
      iletisimTercihi: 'app_message',
      telefonIzin: true,
    );
    const phoneOnly = ExpertCvProfile(
      iletisimTercihi: 'phone',
      telefonIzin: true,
    );
    const messageOnly = ExpertCvProfile(iletisimTercihi: 'app_message');
    expect(both.iletisimMesaj, isTrue);
    expect(both.iletisimTelefon, isTrue);
    expect(both.iletisimOzet, 'Uygulama içi mesaj, Telefon');
    expect(phoneOnly.iletisimMesaj, isFalse);
    expect(phoneOnly.iletisimTelefon, isTrue);
    expect(messageOnly.iletisimTelefon, isFalse);
    expect(messageOnly.iletisimMesaj, isTrue);
  });

  test('cep telefonu is optional and read from detay', () {
    const empty = ExpertCvProfile();
    const filled = ExpertCvProfile(
      meslekDetaylari: {'cep_telefonu': '0555 111 22 33'},
    );
    expect(empty.cepTelefonu, isEmpty);
    expect(filled.cepTelefonu, '0555 111 22 33');
  });

  test('workplace address is optional and visible only to members', () {
    const empty = ExpertCvProfile();
    const filled = ExpertCvProfile(
      meslekDetaylari: {
        kUzmanIsYeriAdresKey: 'Atatürk Cad. No:12 Kadıköy / İstanbul',
      },
    );
    expect(empty.isYeriAdresi, isEmpty);
    expect(filled.isYeriAdresi, contains('Kadıköy'));
    expect(
      uzmanIsYeriAdresiGorunur(isGuest: true, userEmail: ''),
      isFalse,
    );
    expect(
      uzmanIsYeriAdresiGorunur(
        isGuest: false,
        userEmail: 'uye@engelsizclub.com',
      ),
      isTrue,
    );
    expect(
      uzmanIsYeriAdresiGorunur(
        isGuest: true,
        userEmail: '',
        isOwner: true,
      ),
      isTrue,
    );
    expect(kKvkkOnayMetni, contains('iş yeri adresi'));
    expect(kKvkkOnayMetni, contains('ev adresi'));
  });

  test('bakim profiles use the identity-check note', () {
    const p = ExpertCvProfile(ustGrup: 'Bakım ve Ev Desteği');
    expect(p.isBakim, isTrue);
    expect(kBakimKimlikNotu, contains('kimlik'));
    expect(kUzmanSorumlulukReddi, contains('bağımsızdır'));
  });

  test('bakim CV copy is not therapist-shaped', () {
    const bakici = ExpertCvProfile(
      meslekEtiket: 'Bakıcı',
      ustGrup: kMeslekUstBakim,
      calismaSekli: ['Yatılı', 'Gündüz'],
      engelliDeneyimi: true,
      meslekDetaylari: {
        'bakim_turu': ['Yaşlı', 'Engelli'],
        'yapabildikleri': ['Hijyen bakımı', 'Yemek hazırlama'],
        'calisma_duzeni': ['Yatılı'],
        'tercih_sigara': 'Sigara içilmeyen ev',
        'tercih_evcil': 'Fark etmez',
        kUzmanMezunBolumKey: 'Hasta ve Yaşlı Hizmetleri',
        'seans_suresi': '45 dk',
        'ekipman': true,
        'universite': 'Hacettepe',
      },
    );
    expect(bakici.isBakici, isTrue);
    expect(bakici.mezunBolum, 'Hasta ve Yaşlı Hizmetleri');
    expect(uzmanProfilEkranBasligi(bakici), 'Bakıcı profili');
    expect(uzmanIkinciAksiyonMetni(bakici), 'Hizmet talep et');
    expect(uzmanAdresKartBasligi(bakici), 'Hizmet adresi');
    expect(uzmanHeroUzmanlik(bakici), 'Yaşlı ve Engelli');
    expect(uzmanGrupKartBasligi(bakici), 'Bakım / hizmet');
    expect(uzmanGrupKartEtiketleri(bakici), containsAll(['Yaşlı', 'Engelli']));
    expect(uzmanUzmanlikKartBasligi(bakici), 'Yapabildikleri');
    expect(uzmanUzmanlikKartEtiketleri(bakici), contains('Hijyen bakımı'));
    final hizli = uzmanHizliBilgiler(bakici);
    expect(hizli.map((e) => e.label), isNot(contains('Seans süresi')));
    expect(hizli.map((e) => e.label), isNot(contains('Kendi ekipmanı')));
    expect(hizli.map((e) => e.label), contains('Çalışma düzeni'));
    expect(hizli.map((e) => e.label), contains('Mezun olunan bölüm'));
    expect(hizli.map((e) => e.value), contains('Hasta ve Yaşlı Hizmetleri'));
    expect(uzmanCvFormAdimBasliklari(bakim: true), contains('Bakım bilgileri'));
    expect(
      uzmanCvFormAdimBasliklari(bakim: true),
      isNot(contains('Fotoğraf / diploma')),
    );
    expect(uzmanCalismaSekliSecenekleri(bakim: true), contains('Yatılı'));
    expect(uzmanCalismaSekliSecenekleri(bakim: true), isNot(contains('Klinik')));
    final cleaned = uzmanDetayMeslekTemizle(
      Map<String, dynamic>.from(bakici.meslekDetaylari),
      bakim: true,
    );
    expect(cleaned.containsKey('seans_suresi'), isFalse);
    expect(cleaned.containsKey('bakim_turu'), isTrue);

    const ev = ExpertCvProfile(
      meslekEtiket: 'Ev Yardımı',
      ustGrup: kMeslekUstBakim,
      meslekDetaylari: {
        'hizmet_turu': ['Ev', 'Derin temizlik'],
        'kendi_malzeme': true,
        'ek_hizmetler': ['Ütü'],
      },
    );
    expect(ev.isBakici, isFalse);
    expect(
      uzmanHizliBilgiler(ev).map((e) => e.label),
      isNot(contains('Mezun olunan bölüm')),
    );
    expect(uzmanProfilEkranBasligi(ev), 'Ev Yardımı profili');
    expect(uzmanHeroUzmanlik(ev), 'Ev ve Derin temizlik');
    expect(
      uzmanHizliBilgiler(ev).map((e) => e.label),
      contains('Kendi malzemesi'),
    );
    expect(uzmanUzmanlikKartEtiketleri(ev), contains('Ütü'));
    expect(
      uzmanBakimVarsayilanSablonlari(grupKey: 'bakici')
          .map((e) => e.alanKey),
      containsAll(['bakim_turu', 'yapabildikleri', 'calisma_duzeni']),
    );
    expect(
      uzmanBakimVarsayilanSablonlari(grupKey: 'ev_yardimi')
          .map((e) => e.alanKey),
      containsAll(['hizmet_turu', 'kendi_malzeme', 'ek_hizmetler']),
    );
    expect(
      uzmanMeslekSablonlariVeyaBakimVarsayilan(
        sablonlar: const [],
        bakim: true,
        grupKey: 'bakici',
      ).map((e) => e.alanKey),
      contains('yapabildikleri'),
    );
    expect(
      uzmanMeslekSablonlariVeyaBakimVarsayilan(
        sablonlar: const [
          MeslekAlanSablon(
            id: 1,
            meslekGrubuId: 1,
            alanKey: 'seans_suresi',
            etiket: 'Seans süresi',
            tip: 'text',
          ),
        ],
        bakim: true,
        grupKey: 'bakici',
      ).map((e) => e.alanKey),
      contains('bakim_turu'),
    );
  });

  test('phone digits are stripped for tel: redirect', () {
    expect(uzmanTelDigits('0555 111 22 33'), '05551112233');
    expect(uzmanTelAranabilir('0555 111 22 33'), isTrue);
    expect(uzmanTelAranabilir('123'), isFalse);
    expect(uzmanTelAranabilir(''), isFalse);
  });

  test('review average and relative date', () {
    expect(uzmanYildizOrtalama(const []), 0);
    expect(uzmanYildizOrtalama(const [5, 4, 3]), 4);
    final now = DateTime(2026, 11, 7);
    expect(uzmanYorumTarih(DateTime(2026, 11, 7), now: now), 'Bugün');
    expect(uzmanYorumTarih(DateTime(2026, 11, 6), now: now), 'Dün');
    expect(uzmanYorumTarih(DateTime(2026, 10, 1), now: now), '01.10.2026');
  });

  test('profile display merges expertise tags without duplicates', () {
    const p = ExpertCvProfile(
      meslekEtiket: 'Fizyoterapist',
      meslekDetaylari: {
        'uzmanlik_alanlari': ['Pediatrik', 'Nörolojik rehabilitasyon'],
        'uzmanlik_ilgi': 'Pediatrik, duyu bütünleme',
      },
    );
    expect(uzmanHeroUzmanlik(p), 'Pediatrik ve Nörolojik rehabilitasyon');
    final tags = uzmanBenzersizEtiketler([
      p.meslekDetaylari['uzmanlik_alanlari'],
      p.meslekDetaylari['uzmanlik_ilgi'],
    ]);
    expect(tags.where((t) => t.toLowerCase() == 'pediatrik').length, 1);
    expect(tags, contains('duyu bütünleme'));
    expect(uzmanBasHarfler('Muhammet Baki Ünal'), 'MÜ');
    expect(uzmanProfilBakanOzeti(0), 'Henüz kimse bakmadı');
    expect(uzmanProfilBakanOzeti(1), '1 kişi baktı');
    expect(uzmanProfilBakanOzeti(12), '12 kişi baktı');
    expect(uzmanYildizOzeti(0, 0), kUzmanYorumYok);
    expect(uzmanYildizOzeti(4.5, 2), '4.5 / 5');
  });

  test('certificates merge free text and lists with institution lines', () {
    final rows = uzmanSertifikaSatirlari([
      'Duyu bütünleme → Yeşim Ünveren Akademi\nHalliwick → Johan Lambeck',
      ['Yutma rehabilitasyonu → Tomris Duymaz', 'Halliwick → Johan Lambeck'],
    ]);
    expect(rows.length, 3);
    expect(rows[0].baslik, 'Duyu bütünleme');
    expect(rows[0].kurum, 'Yeşim Ünveren Akademi');
    expect(rows[1].kurum, 'Johan Lambeck');
    expect(rows[2].baslik, 'Yutma rehabilitasyonu');
    expect(uzmanBoolGoster(true, evet: 'Yapıyor', hayir: 'Yapmıyor'), 'Yapıyor');
    expect(uzmanBoolGoster(false, evet: 'Var', hayir: 'Yok'), 'Yok');
    expect(uzmanBoolGoster(null), '');
  });

  test('existing profile certificates parse hyphen lines and skip Diger', () {
    final rows = uzmanSertifikaSatirlari([
      'Duyu bütünleme yeşim ünveren akademi\n'
          'Halliwick- Johan Lambeck\n'
          'Yutma Rehabilitasyonu- Tomris Duymaz',
      ['Diğer', 'Bobath'],
    ]);
    expect(rows.map((r) => r.baslik), contains('Halliwick'));
    expect(
      rows.firstWhere((r) => r.baslik == 'Halliwick').kurum,
      'Johan Lambeck',
    );
    expect(
      rows.firstWhere((r) => r.baslik == 'Yutma Rehabilitasyonu').kurum,
      'Tomris Duymaz',
    );
    expect(rows.any((r) => r.baslik == 'Diğer'), isFalse);
    expect(rows.any((r) => r.baslik == 'Bobath'), isTrue);
  });
}
