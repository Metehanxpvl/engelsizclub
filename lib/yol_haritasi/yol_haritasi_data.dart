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
    this.bilgi = false,
  });

  final String baslik;
  final IconData icon;
  final List<YolMadde> maddeler;

  /// Dal başlığının altındaki kısa not (ör. "Doktorunuz önerdiyse").
  final String? not;

  /// Bu soru "Evet" cevaplanmazsa dal hiç gösterilmez.
  final String? sadeceEvetIse;

  /// Bilgi dalı: ilerlemeye dahil edilmez, ✓/– butonları gösterilmez.
  final bool bilgi;
}

YolMadde _ym(String satir) {
  final p = satir.split('|');
  return YolMadde(p[0], p[1], p[2]);
}

YolDal _gozdenKacabilenler(List<String> satirlar) => YolDal(
      baslik: 'Gözden kaçabilenler',
      icon: Icons.lightbulb_outline,
      bilgi: true,
      not: 'Fark ederseniz doktorunuza sorun',
      maddeler: [for (final s in satirlar) _ym(s)],
    );

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

final List<YolTani> yolTanilari = [
  YolTani(
    id: 'otizm',
    ad: 'Otizm',
    kaynak: 'NICE CG128 / CG170',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Çocuk ve Ergen Psikiyatrisi', 'Tanı, takip ve ÇÖZGER süreci'),
          YolMadde('d2', 'KBB / Odyoloji', 'İşitme kaybını dışlamak için'),
          YolMadde('d3', 'Tıbbi Genetik', 'Genetik değerlendirme ve danışmanlık'),
          YolMadde('d4', 'Çocuk Nörolojisi', 'Nöbet veya beceri kaybı varsa'),
          YolMadde('d5', 'Beslenme / Gastroenteroloji', 'Seçici yeme, kabızlık'),
          YolMadde('d6', 'Çocuk Diş Hekimi', 'Düzenli diş kontrolü'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
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
      _gozdenKacabilenler([
        'g1|Uyku sorunları|Pediatri veya Çocuk Psikiyatrisi',
        'g2|Dikkat eksikliği veya kaygı|Çocuk Psikiyatrisi',
        'g3|Kazanılmış becerilerin kaybı|Vakit kaybetmeden doktorunuza',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
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
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Çocuk Nörolojisi', 'Tanı, nöbet ve EEG takibi'),
          YolMadde('d2', 'Fiziksel Tıp ve Rehabilitasyon', 'Fizyoterapi planı, ortez, gerekirse botoks'),
          YolMadde('d3', 'Çocuk Ortopedisi', 'Kalça, omurga ve ayak takibi'),
          YolMadde('d4', 'Göz', 'Şaşılık ve görme kontrolü'),
          YolMadde('d5', 'KBB / Odyoloji', 'İşitme testi'),
          YolMadde('d6', 'Beslenme / Gastroenteroloji', 'Yutma, reflü, kilo alımı'),
          YolMadde('d7', 'Çocuk Diş Hekimi', 'Düzenli diş kontrolü'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
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
      _gozdenKacabilenler([
        'g1|Ağrı ve uyku sorunları|Pediatri veya Çocuk Nörolojisi',
        'g2|Salya kontrolü güçlüğü|KBB veya Çocuk Nörolojisi',
        'g3|Davranış veya duygusal zorluklar|Çocuk Psikiyatrisi',
        'g4|Kabızlık|Gastroenteroloji',
      ]),
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
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Tıbbi Genetik', 'Kromozom analizi, genetik danışmanlık'),
          YolMadde('d2', 'Çocuk Kardiyolojisi', 'Ekokardiyografi (kalp taraması)'),
          YolMadde('d3', 'Çocuk Endokrinolojisi', 'Tiroid testleri, düzenli takip'),
          YolMadde('d4', 'KBB / Odyoloji', 'Düzenli işitme testi'),
          YolMadde('d5', 'Göz', 'Katarakt, şaşılık, gözlük ihtiyacı'),
          YolMadde('d6', 'Pediatri / Hematoloji', 'Tam kan sayımı'),
          YolMadde('d7', 'Uyku değerlendirmesi', 'Uyku apnesi taraması'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
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
      _gozdenKacabilenler([
        'g1|Beslenme ve yutma güçlüğü|Beslenme, Dil ve konuşma terapisi',
        'g2|Kabızlık, kilo alamama, karın ağrısı|Gastroenteroloji (çölyak açısından)',
        'g3|Otizm veya davranış belirtileri|Çocuk Psikiyatrisi',
        'g4|Nöbet|Çocuk Nörolojisi',
        'g5|Boyun ağrısı, yürüyüşte veya el kullanımında değişiklik|Vakit kaybetmeden doktorunuza',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'dehb',
    ad: 'DEHB',
    kaynak: 'NICE NG87, AAP 2019',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Çocuk ve Ergen Psikiyatrisi', 'Tanı ve tedavi planı'),
          YolMadde('d2', 'Pediatri', 'Genel sağlık, uyku, büyüme takibi'),
          YolMadde('d3', 'KBB / Odyoloji ve Göz', 'İşitme ve görme sorununu dışlamak için'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Ebeveyn eğitimi', 'Davranış yönetimi için aile programı'),
          YolMadde('t2', 'Okul iş birliği', 'Öğretmenle ortak plan, sınıf içi düzenlemeler'),
          YolMadde('t3', 'Psikolojik destek', 'Bilişsel davranışçı terapi, sosyal beceri'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Uyku sorunları|Pediatri',
        'g2|Okuma, yazma veya matematikte güçlük|RAM ve özel eğitim',
        'g3|Kaygı veya duygu durumu değişiklikleri|Çocuk Psikiyatrisi',
        'g4|Tikler|Çocuk Nörolojisi veya Psikiyatri',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'gelisim',
    ad: 'Gelişim Geriliği / Zihinsel Yetersizlik',
    kaynak: 'AAP klinik raporları',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Gelişimsel Pediatri / Çocuk Gelişim', 'Gelişim değerlendirmesi'),
          YolMadde('d2', 'Çocuk Nörolojisi', 'Nörolojik muayene'),
          YolMadde('d3', 'Tıbbi Genetik', 'Altta yatan neden için'),
          YolMadde('d4', 'KBB / Odyoloji', 'İşitme testi'),
          YolMadde('d5', 'Göz', 'Görme kontrolü'),
          YolMadde('d6', 'Çocuk Metabolizma', 'Doktorunuz gerek görürse'),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Özel eğitim / erken müdahale', 'Bilişsel ve günlük beceriler'),
          YolMadde('t2', 'Fizyoterapi', 'Motor gelişim'),
          YolMadde('t3', 'Ergoterapi', 'İnce motor, günlük yaşam'),
          YolMadde('t4', 'Dil ve konuşma terapisi', 'İletişim'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Nöbet|Çocuk Nörolojisi',
        'g2|Otizm veya davranış belirtileri|Çocuk Psikiyatrisi',
        'g3|Beslenme güçlüğü|Beslenme, Dil ve konuşma terapisi',
        'g4|Uyku sorunları|Pediatri',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'konusma',
    ad: 'İletişim Bozukluğu / Konuşma Gecikmesi',
    kaynak: 'Genel klinik yaklaşım',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'KBB / Odyoloji', 'İlk adım: işitme testi'),
          YolMadde('d2', 'Pediatri / Çocuk Gelişim', 'Genel gelişim değerlendirmesi'),
          YolMadde('d3', 'Çocuk ve Ergen Psikiyatrisi', 'Doktorunuz gerek görürse'),
          YolMadde('d4', 'Çocuk Nörolojisi', 'Doktorunuz gerek görürse'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Dil ve konuşma terapisi', 'Değerlendirme ve terapi'),
          YolMadde('t2', 'Aile eğitimi', 'Evde dil gelişimini destekleme'),
          YolMadde('t3', 'Özel eğitim', 'Gerekirse'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Göz teması, ilgi ve oyunda farklılıklar|Çocuk Psikiyatrisi',
        'g2|Sık kulak enfeksiyonu|KBB',
        'g3|Çiğneme veya yutma güçlüğü|Dil ve konuşma terapisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'duyu',
    ad: 'Duyu Bütünleme Sorunları',
    kaynak: 'Genel klinik yaklaşım; tek başına tanı olarak tartışmalıdır',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde(
            'd1',
            'Gelişimsel Pediatri / Çocuk Psikiyatrisi',
            'Eşlik eden durumların (otizm, DEHB) değerlendirilmesi',
          ),
          YolMadde('d2', 'KBB / Odyoloji ve Göz', 'İşitme ve görme kontrolü'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Ergoterapi', 'Duyusal değerlendirme ve günlük yaşam'),
          YolMadde('t2', 'Aile eğitimi', 'Evde duyusal düzenlemeler'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Uyku sorunları|Pediatri',
        'g2|Belirgin yemek seçiciliği|Beslenme, Ergoterapi',
        'g3|Dikkat sorunları|Çocuk Psikiyatrisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'sma',
    ad: 'SMA (Spinal Müsküler Atrofi)',
    kaynak: 'SMA Bakım Standartları Uzlaşı Raporu (2018)',
    sorular: [
      YolSoru(
        id: 'yurume',
        metin: 'Destek almadan yürüyebiliyor mu?',
        evetIseGerekYok: ['e2', 'e3'],
      ),
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Çocuk Nörolojisi', 'Tanı ve ilaç tedavisi takibi'),
          YolMadde('d2', 'Tıbbi Genetik', 'Genetik doğrulama, aile danışmanlığı'),
          YolMadde('d3', 'Çocuk Göğüs Hastalıkları', 'Solunum takibi'),
          YolMadde('d4', 'Beslenme / Gastroenteroloji', 'Yutma, kilo alımı'),
          YolMadde('d5', 'Çocuk Ortopedisi', 'Omurga ve kalça takibi'),
          YolMadde('d6', 'Fiziksel Tıp ve Rehabilitasyon', 'Rehabilitasyon planı'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Fizyoterapi', 'Motor beceriler, solunum egzersizleri'),
          YolMadde('t2', 'Ergoterapi', 'Günlük yaşam, oturma pozisyonu'),
          YolMadde('t3', 'Dil ve konuşma terapisi', 'Yutma ve beslenme'),
        ],
      ),
      YolDal(
        baslik: 'Cihaz ve ekipman',
        not: 'Doktorunuz önerdiyse',
        icon: Icons.accessible_outlined,
        maddeler: [
          YolMadde('e1', 'Ortez / korse', 'Doktor reçetesiyle'),
          YolMadde('e2', 'Tekerlekli sandalye (manuel / akülü)', 'İhtiyaca göre'),
          YolMadde('e3', 'Ayakta durma sehpası', 'Kemik ve kalça sağlığı'),
          YolMadde('e4', 'Solunum / öksürük destek cihazı', 'Göğüs hastalıkları doktoru önerdiyse'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Omurga eğriliği (skolyoz)|Çocuk Ortopedisi',
        'g2|Sık solunum yolu enfeksiyonu|Çocuk Göğüs Hastalıkları',
        'g3|Kabızlık veya reflü|Gastroenteroloji',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'dmd',
    ad: 'Duchenne Müsküler Distrofi (DMD)',
    kaynak: 'DMD Bakım Önerileri (2018)',
    sorular: [
      YolSoru(
        id: 'yurume',
        metin: 'Destek almadan yürüyebiliyor mu?',
        evetIseGerekYok: ['e2'],
      ),
      _okulSorusu,
    ],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Çocuk Nörolojisi (Nöromüsküler)', 'Tanı ve tedavi takibi'),
          YolMadde('d2', 'Çocuk Kardiyolojisi', 'Düzenli kalp takibi'),
          YolMadde('d3', 'Çocuk Göğüs Hastalıkları', 'Solunum fonksiyon testleri'),
          YolMadde('d4', 'Çocuk Endokrinolojisi', 'Büyüme ve kemik sağlığı'),
          YolMadde('d5', 'Çocuk Ortopedisi', 'Kontraktür ve omurga takibi'),
          YolMadde('d6', 'Tıbbi Genetik', 'Aile için taşıyıcılık danışmanlığı'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Fizyoterapi', 'Germe, kontraktürleri önleme'),
          YolMadde('t2', 'Ergoterapi', 'Günlük yaşam becerileri'),
          YolMadde('t3', 'Psikolojik destek', 'Çocuk ve aile için'),
          YolMadde('t4', 'Özel eğitim', 'Öğrenme desteği gerekirse'),
        ],
      ),
      YolDal(
        baslik: 'Cihaz ve ekipman',
        not: 'Doktorunuz önerdiyse',
        icon: Icons.accessible_outlined,
        maddeler: [
          YolMadde('e1', 'Gece ateli (AFO)', 'Doktor reçetesiyle'),
          YolMadde('e2', 'Tekerlekli sandalye', 'İhtiyaca göre'),
          YolMadde('e3', 'Ayakta durma sehpası', 'Doktorunuz önerdiyse'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Öğrenme veya dikkat güçlüğü|RAM, Çocuk Psikiyatrisi',
        'g2|Hızlı kilo artışı|Beslenme',
        'g3|Kemik kırığı|Endokrinoloji, Ortopedi',
        'g4|Duygusal zorluklar|Psikolojik destek',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'premature',
    ad: 'Prematüre Bebek',
    kaynak: 'NICE NG72',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Pediatri / Yenidoğan takip polikliniği', 'Düzenli gelişim izlemi'),
          YolMadde('d2', 'Göz', 'ROP (prematüre retinopatisi) taraması'),
          YolMadde('d3', 'KBB / Odyoloji', 'İşitme taraması'),
          YolMadde('d4', 'Çocuk Nörolojisi', 'Doktorunuz gerek görürse'),
          YolMadde('d5', 'Beslenme', 'Büyüme ve beslenme takibi'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Erken müdahale / gelişim desteği', 'Gelişim değerlendirmesine göre'),
          YolMadde('t2', 'Fizyoterapi', 'Motor gelişim gerekirse'),
          YolMadde('t3', 'Ergoterapi', 'Beslenme ve duyusal destek gerekirse'),
        ],
      ),
      YolDal(
        baslik: 'Destek',
        icon: Icons.groups_outlined,
        maddeler: [
          YolMadde('s1', 'Prematüre Gelişim Rehberi', 'Uygulamadaki rehberi incele'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Göz ve işitme kontrollerinin aksaması|Göz, Odyoloji',
        'g2|Oturma veya yürümede gecikme|Fizyoterapi',
        'g3|Kilo alamama, beslenme güçlüğü|Beslenme',
        'g4|Okul çağında dikkat veya öğrenme güçlüğü|RAM, Çocuk Psikiyatrisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'isitme',
    ad: 'İşitme Kaybı',
    kaynak: 'JCIH 2019',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'KBB', 'Tanı ve tedavi'),
          YolMadde('d2', 'Odyoloji', 'Ayrıntılı işitme testleri, cihaz ayarı'),
          YolMadde('d3', 'Tıbbi Genetik', 'Nedeni araştırmak için'),
          YolMadde('d4', 'Göz', 'Görme kontrolü'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'İşitsel-sözel terapi / dil ve konuşma', 'Dil gelişimi'),
          YolMadde('t2', 'Özel eğitim', 'İşitme yetersizliği olan çocuklar için'),
        ],
      ),
      YolDal(
        baslik: 'Cihaz ve ekipman',
        not: 'Doktorunuz önerdiyse',
        icon: Icons.accessible_outlined,
        maddeler: [
          YolMadde('e1', 'İşitme cihazı', 'Odyolog ayarıyla'),
          YolMadde('e2', 'Koklear implant değerlendirmesi', 'KBB önerdiyse'),
          YolMadde('e3', 'FM sistem', 'Okulda duymayı kolaylaştırır'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Görme kontrolü|Göz',
        'g2|Denge sorunları|KBB veya Fiziksel Tıp ve Rehabilitasyon',
        'g3|Dil gelişiminde duraklama|Odyoloji, Dil ve konuşma terapisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'gorme',
    ad: 'Görme Yetersizliği (CVI dahil)',
    kaynak: 'Genel klinik yaklaşım',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Göz (Çocuk Oftalmolojisi)', 'Tanı ve takip'),
          YolMadde('d2', 'Çocuk Nörolojisi', 'Serebral görme bozukluğunda (CVI)'),
          YolMadde('d3', 'Az görme değerlendirmesi', 'Kalan görmeyi en iyi kullanmak için'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Görme rehabilitasyonu / erken müdahale', 'Görsel becerileri geliştirme'),
          YolMadde('t2', 'Ergoterapi', 'Günlük yaşam becerileri'),
          YolMadde('t3', 'Özel eğitim', 'Görme yetersizliği olan çocuklar için'),
          YolMadde('t4', 'Oryantasyon ve mobilite', 'Güvenli bağımsız hareket'),
        ],
      ),
      YolDal(
        baslik: 'Cihaz ve ekipman',
        not: 'Doktorunuz önerdiyse',
        icon: Icons.accessible_outlined,
        maddeler: [
          YolMadde('e1', 'Gözlük', 'Göz doktoru reçetesiyle'),
          YolMadde('e2', 'Az görme cihazları', 'Büyüteç, ekran büyütme vb.'),
          YolMadde('e3', 'Beyaz baston', 'Gerekirse'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Gelişimde gecikme|Gelişimsel Pediatri',
        'g2|Uyku düzeni sorunları|Pediatri',
        'g3|Nöbet|Çocuk Nörolojisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'epilepsi',
    ad: 'Epilepsi',
    kaynak: 'NICE NG217',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('d1', 'Çocuk Nörolojisi', 'Tanı, EEG ve ilaç takibi'),
          YolMadde('d2', 'Pediatri', 'Genel sağlık takibi'),
          YolMadde('d3', 'Tıbbi Genetik', 'Doktorunuz gerek görürse'),
          YolMadde(
            'd4',
            'Çocuk ve Ergen Psikiyatrisi',
            'Dikkat, davranış veya duygu sorunlarında',
          ),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
        ],
      ),
      YolDal(
        baslik: 'Terapiler',
        icon: Icons.accessibility_new_outlined,
        maddeler: [
          YolMadde('t1', 'Özel eğitim', 'Öğrenme desteği'),
        ],
      ),
      YolDal(
        baslik: 'Destek',
        icon: Icons.groups_outlined,
        maddeler: [
          YolMadde(
            's1',
            'Nöbet acil planı',
            'Aile ve okul için yazılı plan, doktorunuzla hazırlayın',
          ),
          YolMadde('s2', 'Acil ilaç', 'Doktorunuz önerdiyse'),
        ],
      ),
      _gozdenKacabilenler([
        'g1|Uyku sorunları|Pediatri',
        'g2|Dikkat veya öğrenme güçlüğü|RAM, Çocuk Psikiyatrisi',
        'g3|Kaygı veya duygu durumu değişiklikleri|Çocuk Psikiyatrisi',
        'g4|İlaç yan etkisi şüphesi|Çocuk Nörolojisi',
      ]),
      _okulDali,
      _raporDali,
    ],
  ),
  YolTani(
    id: 'genetik',
    ad: 'Diğer / Genetik / nadir hastalık',
    kaynak: 'Genel klinik yaklaşım; tanıya göre uzman onayı gerekir',
    sorular: [_okulSorusu],
    dallar: [
      YolDal(
        baslik: 'Doktorlar',
        icon: Icons.medical_services_outlined,
        maddeler: [
          YolMadde('dp', 'Çocuk Sağlığı ve Hastalıkları (Pediatri)', 'Genel sağlık takibi, büyüme, aşılar; diğer bölümlere yönlendirme'),
          YolMadde('d1', 'Tıbbi Genetik', 'Genetik test, aile için danışmanlık'),
          YolMadde('d2', 'Çocuk Metabolizma', 'Metabolik hastalık varsa'),
          YolMadde('d3', 'Çocuk Nörolojisi', 'Gelişim ve nöbet takibi'),
          YolMadde('d4', 'Tanıya özel branşlar', 'Kalp, göz, böbrek vb. etkilenen organa göre'),
          YolMadde('dgp', 'Gelişimsel Pediatri', 'Gelişimin bütüncül takibi (çoğunlukla üniversite hastanelerinde)'),
          YolMadde('dcp', 'Çocuk ve Ergen Psikiyatrisi', 'Davranış, dikkat, uyku ve duygusal sorunlar için'),
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
      _gozdenKacabilenler([
        'g1|Beslenme güçlüğü|Beslenme',
        'g2|Uyku sorunları|Pediatri',
        'g3|Nöbet|Çocuk Nörolojisi',
        'g4|Davranış değişiklikleri|Çocuk Psikiyatrisi',
      ]),
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

const Map<String, String> yolNeIseYarar = {
  'Nöromüsküler': 'Kas hastalıklarında uzmanlaşmış çocuk nörolojisi.',
  'Çocuk Nörolojisi': 'Beyin, sinir ve kas sistemi; nöbet ve gelişim takibi.',
  'Fiziksel Tıp': 'Rehabilitasyon planı, fizyoterapi reçetesi, ortez ve cihazlar.',
  'Ortopedi': 'Kemik, eklem, kalça ve omurga sağlığı.',
  'Odyoloji': 'Ayrıntılı işitme testleri ve işitme cihazı ayarı.',
  'KBB': 'Kulak, burun, boğaz; işitme ve sık kulak enfeksiyonları.',
  'Göz': 'Görme keskinliği, şaşılık, gözlük ve göz sağlığı.',
  'Gastroenteroloji': 'Yutma, reflü, kabızlık ve kilo alımı.',
  'Diş': 'Diş ve ağız sağlığı; özel gereksinimli çocuklara deneyimli hekimler.',
  'Psikiyatri': 'Gelişim, dikkat, davranış ve duygu durumu; ÇÖZGER sürecinde de rol alır.',
  'Genetik': 'Altta yatan genetik nedeni araştırır, aileye danışmanlık verir.',
  'Kardiyoloji': 'Kalp yapısı ve ritmi; ekokardiyografi.',
  'Endokrinoloji': 'Hormonlar, tiroid, büyüme ve kemik sağlığı.',
  'Göğüs': 'Akciğer ve solunum takibi.',
  'Metabolizma': 'Doğuştan metabolik hastalıkların tanı ve takibi.',
  'Uyku': 'Horlama, uyku apnesi ve uyku düzeni sorunları.',
  'Gelişim': 'Çocuğun genel gelişiminin yaşına göre değerlendirilmesi.',
  'Pediatri': 'Genel sağlık, büyüme, aşılar ve tüm takibin koordinasyonu.',
  'Az görme': 'Kalan görmeyi en iyi kullanmak için cihaz ve yöntemler.',
  'Fizyoterapi': 'Oturma, ayakta durma, yürüme gibi hareket becerilerini destekler.',
  'Ergoterapi': 'Giyinme, yemek yeme, kalem tutma gibi günlük becerilere destek olur.',
  'Dil ve konuşma': 'Konuşma, anlama, iletişim; yutma ve beslenme güçlüğünde de çalışır.',
  'İşitsel-sözel': 'İşitme cihazı veya implantla dinleme ve konuşmayı geliştirir.',
  'Özel eğitim': 'Bireysel programla öğrenme, iletişim ve günlük beceriler.',
  'Erken müdahale': '0-3 yaşta gelişimi desteklemek için erken başlanan programlar.',
  'Ebeveyn eğitimi': 'Ailenin evde davranış ve rutinleri yönetmesine destek.',
  'Aile eğitimi': 'Terapide öğrenilenlerin evde uygulanmasına destek.',
  'Okul iş birliği': 'Öğretmenle ortak plan, sınıf içi düzenlemeler.',
  'Psikolojik destek': 'Çocuk ve ailenin duygusal yükünü paylaşmak için.',
  'Görme rehabilitasyonu': 'Görsel becerileri ve kalan görmenin kullanımını geliştirir.',
  'Oryantasyon': 'Güvenli ve bağımsız hareket etmeyi öğretir.',
};

/// Başlıkta ilk eşleşen anahtarın "ne işe yarar" açıklamasını döner.
String? yolNeIseYararBul(String baslik) {
  for (final entry in yolNeIseYarar.entries) {
    if (baslik.contains(entry.key)) return entry.value;
  }
  return null;
}
