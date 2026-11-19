import 'package:flutter/material.dart';

/// "Tanı aldık, şimdi ne yapmalı?" yol haritası içeriği.
///
/// Bilgilendirme amaçlıdır; içerik uluslararası rehberlerden uyarlanmıştır
/// ve yayın öncesi uzman onayından geçirilmelidir.

class YolMadde {
  const YolMadde(this.id, this.baslik, this.aciklama);
  final String id;
  final String baslik;
  final String aciklama;
}

class YolDal {
  const YolDal({
    required this.baslik,
    required this.icon,
    required this.maddeler,
    this.not,
    this.sadeceEvetIse,
  });

  final String baslik;
  final IconData icon;
  final List<YolMadde> maddeler;

  /// Dal başlığının altındaki kısa not (ör. "Doktorunuz önerdiyse").
  final String? not;

  /// Bu soru "Evet" cevaplanmazsa dal hiç gösterilmez.
  final String? sadeceEvetIse;
}

class YolSoru {
  const YolSoru({
    required this.id,
    required this.metin,
    this.evetIseGerekYok = const [],
    this.hayirIseGerekYok = const [],
  });

  final String id;
  final String metin;

  /// "Evet" cevabında otomatik "Gerek yok" işaretlenecek madde id'leri.
  final List<String> evetIseGerekYok;

  /// "Hayır" cevabında otomatik "Gerek yok" işaretlenecek madde id'leri.
  final List<String> hayirIseGerekYok;
}

class YolTani {
  const YolTani({
    required this.id,
    required this.ad,
    required this.kaynak,
    required this.sorular,
    required this.dallar,
  });

  final String id;
  final String ad;
  final String kaynak;
  final List<YolSoru> sorular;
  final List<YolDal> dallar;
}

const _okulSorusu = YolSoru(id: 'okul', metin: 'Çocuğunuz okula gidiyor mu?');

const _okulDali = YolDal(
  baslik: 'Okul ve eğitim',
  icon: Icons.school_outlined,
  sadeceEvetIse: 'okul',
  maddeler: [
    YolMadde('ok1', 'Okul yerleştirmesi', 'Kaynaştırma veya özel eğitim sınıfı'),
    YolMadde('ok2', 'BEP hazırlanması', 'Bireyselleştirilmiş Eğitim Programı'),
  ],
);

const _raporDali = YolDal(
  baslik: 'Raporlar ve haklar',
  icon: Icons.description_outlined,
  maddeler: [
    YolMadde('rp1', 'ÇÖZGER raporu', 'Yetkili devlet hastanesinin sağlık kurulundan'),
    YolMadde('rp2', 'RAM değerlendirmesi', 'Destek eğitim raporu için'),
    YolMadde('rp3', 'Rehabilitasyon merkezine kayıt', 'Destek eğitim raporuyla'),
    YolMadde('rp4', 'Haklarını kontrol et', 'Hak Sorgulama ve Destek Sorgulama bölümlerinden'),
  ],
);

const List<YolTani> yolTanilari = [
  YolTani(
    id: 'sp',
    ad: 'Serebral Palsi',
    kaynak: 'NICE NG62',
    sorular: [
      YolSoru(
        id: 'yurume',
        metin: 'Destek almadan yürüyebiliyor mu?',
        evetIseGerekYok: ['e2', 'e3', 'e4'],
      ),
      YolSoru(
        id: 'beslenme',
        metin: 'Ağızdan rahat beslenebiliyor mu?',
        evetIseGerekYok: ['d6'],
      ),
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Çocuk Nörolojisi', 'Tanı, nöbet ve EEG takibi'),
          YolMadde('d2', 'Fiziksel Tıp ve Rehabilitasyon', 'Fizyoterapi planı, ortez, gerekirse botoks'),
          YolMadde('d3', 'Çocuk Ortopedisi', 'Kalça, omurga ve ayak takibi'),
          YolMadde('d4', 'Göz', 'Şaşılık ve görme kontrolü'),
          YolMadde('d5', 'KBB / Odyoloji', 'İşitme testi'),
          YolMadde('d6', 'Beslenme / Gastroenteroloji', 'Yutma, reflü, kilo alımı'),
          YolMadde('d7', 'Çocuk Diş Hekimi', 'Düzenli diş kontrolü'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Fizyoterapi', 'Oturma, ayakta durma, yürüme'),
          YolMadde('t2', 'Ergoterapi', 'İnce motor ve günlük yaşam becerileri'),
          YolMadde('t3', 'Dil ve konuşma terapisi', 'İletişim, yutma ve beslenme'),
          YolMadde('t4', 'Özel eğitim', 'Bilişsel gelişim, okul hazırlığı'),
        ],
      ),
      YolDal(
        baslik: 'Cihaz ve ekipman',
        not: 'Doktorunuz önerdiyse',
        icon: Icons.accessible_outlined,
        maddeler: [
          YolMadde('e1', 'Ortez (AFO / el ateli)', 'FTR doktorunun reçetesiyle'),
          YolMadde('e2', 'Oturma ünitesi', 'Doğru pozisyon için'),
          YolMadde('e3', 'Yürüteç / tekerlekli sandalye', '2. el ilanlarda da bulunabilir'),
          YolMadde('e4', 'Ayakta durma sehpası', 'Kemik ve kalça sağlığı için'),
        ],
      ),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'otizm',
    ad: 'Otizm',
    kaynak: 'NICE CG128 / CG170',
    sorular: [
      YolSoru(
        id: 'yemek',
        metin: 'Yemek seçme veya kabızlık sorunu var mı?',
        hayirIseGerekYok: ['d5'],
      ),
      YolSoru(
        id: 'nobet',
        metin: 'Nöbet veya beceri kaybı oldu mu?',
        hayirIseGerekYok: ['d4'],
      ),
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Çocuk ve Ergen Psikiyatrisi', 'Tanı, takip ve ÇÖZGER süreci'),
          YolMadde('d2', 'KBB / Odyoloji', 'İşitme kaybını dışlamak için'),
          YolMadde('d3', 'Tıbbi Genetik', 'Genetik değerlendirme ve danışmanlık'),
          YolMadde('d4', 'Çocuk Nörolojisi', 'Nöbet veya beceri kaybı varsa'),
          YolMadde('d5', 'Beslenme / Gastroenteroloji', 'Seçici yeme, kabızlık'),
          YolMadde('d6', 'Çocuk Diş Hekimi', 'Düzenli diş kontrolü'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Bireysel özel eğitim', 'İletişim, sosyal ve günlük beceriler'),
          YolMadde('t2', 'Dil ve konuşma terapisi', 'Konuşma ve alternatif iletişim'),
          YolMadde('t3', 'Ergoterapi', 'Duyusal ihtiyaçlar, günlük yaşam'),
          YolMadde('t4', 'Aile eğitimi', 'Evde uygulama için'),
        ],
      ),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'down',
    ad: 'Down Sendromu',
    kaynak: 'AAP 2022 Down Sendromu Sağlık İzlem Rehberi',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Tıbbi Genetik', 'Kromozom analizi, genetik danışmanlık'),
          YolMadde('d2', 'Çocuk Kardiyolojisi', 'Ekokardiyografi (kalp taraması)'),
          YolMadde('d3', 'Çocuk Endokrinolojisi', 'Tiroid testleri, düzenli takip'),
          YolMadde('d4', 'KBB / Odyoloji', 'Düzenli işitme testi'),
          YolMadde('d5', 'Göz', 'Katarakt, şaşılık, gözlük ihtiyacı'),
          YolMadde('d6', 'Pediatri / Hematoloji', 'Tam kan sayımı'),
          YolMadde('d7', 'Uyku değerlendirmesi', 'Uyku apnesi taraması'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Fizyoterapi', 'Kas gevşekliği, motor gelişim'),
          YolMadde('t2', 'Dil ve konuşma terapisi', 'Konuşma, beslenme'),
          YolMadde('t3', 'Ergoterapi', 'İnce motor, günlük yaşam'),
          YolMadde('t4', 'Özel eğitim / erken müdahale', 'Bilişsel gelişim'),
        ],
      ),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'genetik',
    ad: 'Genetik / nadir hastalık',
    kaynak: 'Genel klinik yaklaşım; tanıya göre uzman onayı gerekir',
    sorular: [
      YolSoru(
        id: 'metabolik',
        metin: 'Doktorunuz metabolik hastalık dedi mi?',
        hayirIseGerekYok: ['d2'],
      ),
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Tıbbi Genetik', 'Genetik test, aile için danışmanlık'),
          YolMadde('d2', 'Çocuk Metabolizma', 'Metabolik hastalık varsa'),
          YolMadde('d3', 'Çocuk Nörolojisi', 'Gelişim ve nöbet takibi'),
          YolMadde('d4', 'Tanıya özel branşlar', 'Kalp, göz, böbrek vb. etkilenen organa göre'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Fizyoterapi', 'Gerekiyorsa motor destek'),
          YolMadde('t2', 'Ergoterapi', 'Günlük yaşam becerileri'),
          YolMadde('t3', 'Dil ve konuşma terapisi', 'İletişim ve beslenme'),
          YolMadde('t4', 'Özel eğitim', 'Bilişsel gelişim'),
        ],
      ),
      YolDal(
        baslik: 'Destek',
        icon: Icons.groups_outlined,
        maddeler: [
          YolMadde('s1', 'Hasta / aile derneği', 'Aynı tanıyı yaşayan ailelerle tanışma'),
          YolMadde('s2', 'Özel mama / ilaç raporu', 'Gerekiyorsa doktorunuzla'),
        ],
      ),
      _okulDali,
      _raporDali,
    ],
  ),
];

YolTani? yolTaniBul(String? id) {
  for (final t in yolTanilari) {
    if (t.id == id) return t;
  }
  return null;
}
