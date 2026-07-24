import 'package:flutter/material.dart';

class RightItem {
  const RightItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.icon,
    required this.color,
    required this.bg,
    required this.minRate,
    required this.maxAge,
    required this.incomeLimit,
    required this.desc,
    required this.steps,
    required this.where,
  });

  final String id;
  final String title;
  final String amount;
  final String category;
  final String icon;
  final Color color;
  final Color bg;
  final int minRate;
  final int maxAge;
  final bool incomeLimit;
  final String desc;
  final List<String> steps;
  final String where;
}

class CozgerGrup {
  const CozgerGrup({
    required this.range,
    required this.label,
    required this.kisa,
    required this.color,
    required this.bg,
    this.agir = false,
  });

  final String range;
  final String label;
  final String kisa;
  final Color color;
  final Color bg;
  final bool agir;
}

const cozgerGruplari = <CozgerGrup>[
  CozgerGrup(
    range: '%20–39',
    label: 'Özel Gereksinim Vardır',
    kisa: 'ÖGV',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
  ),
  CozgerGrup(
    range: '%40–49',
    label: 'Hafif Düzeyde Özel Gereksinim Vardır',
    kisa: 'Hafif',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE8F5EE),
  ),
  CozgerGrup(
    range: '%50–59',
    label: 'Orta Düzeyde Özel Gereksinim Vardır',
    kisa: 'Orta',
    color: Color(0xFFE8A020),
    bg: Color(0xFFFEF3E2),
  ),
  CozgerGrup(
    range: '%60–69',
    label: 'İleri Düzeyde Özel Gereksinim Vardır',
    kisa: 'İleri',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
  ),
  CozgerGrup(
    range: '%70–79',
    label: 'Çok İleri Düzeyde Özel Gereksinim Vardır',
    kisa: 'Çok İleri',
    color: Color(0xFFC0392B),
    bg: Color(0xFFFDE8E8),
    agir: true,
  ),
  CozgerGrup(
    range: '%80–89',
    label: 'Belirgin Düzeyde Özel Gereksinim Vardır',
    kisa: 'BÖGV',
    color: Color(0xFF8E44AD),
    bg: Color(0xFFF5EEFB),
    agir: true,
  ),
  CozgerGrup(
    range: '%90–100',
    label: 'Özel Koşul Gereksinimi Vardır',
    kisa: 'ÖKGV',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    agir: true,
  ),
];

const allRights = <RightItem>[
  RightItem(
    id: 'evde-bakim',
    title: 'Evde Bakım Maaşı',
    amount: '≈ ₺12.000 / ay',
    category: 'maddi',
    icon: '🏠',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    minRate: 50,
    maxAge: 18,
    incomeLimit: true,
    desc:
        'Evde bakıma muhtaç ağır engelli bireylerin yakınlarına Sosyal Hizmetler tarafından ödenen aylık destek. Hane halkı gelir testi yapılır.',
    steps: [
      "E-Devlet üzerinden 'Evde Bakım Hizmeti' başvurusu yapın",
      'Sağlık kurulundan %50+ bakıma muhtaç raporu alın',
      "İl Sosyal Hizmetler Müdürlüğü'ne başvurun",
      'Hane halkı gelir testi yapılır',
    ],
    where: 'e-Devlet · İl Sosyal Hizmetler Müdürlüğü',
  ),
  RightItem(
    id: 'engelli-maas',
    title: 'Engelli Aylığı',
    amount: '₺4.000 – ₺8.000 / ay',
    category: 'maddi',
    icon: '💳',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
    minRate: 40,
    maxAge: 99,
    incomeLimit: true,
    desc:
        'SGK veya Sosyal Yardımlaşma Vakfı tarafından ödenen aylık. Gelir testi uygulanır; çalışmayan engelli bireyler için geçerlidir.',
    steps: [
      'Sağlık Kurulu Raporu alın (%40+ engel oranı)',
      "SGK veya SYDV'ye başvurun",
      '18 yaş altı için veli belgesi gerekir',
      'Hesaba her ay otomatik yatırılır',
    ],
    where: 'SGK · Sosyal Yardımlaşma Vakfı',
  ),
  RightItem(
    id: 'yardimci-arac',
    title: 'Yardımcı Araç-Gereç Desteği',
    amount: 'SGK karşılar',
    category: 'maddi',
    icon: '♿',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Tekerlekli sandalye, yürüteç, ortez, protez, işitme cihazı ve benzeri yardımcı araçlar SGK tarafından karşılanmaktadır.',
    steps: [
      'Hekim raporu ve SGK sevki alın',
      'SGK sözleşmeli firma veya ortez merkezine gidin',
      'Katkı payı varsa ödenir; ücretsiz seçenekler mevcuttur',
    ],
    where: 'SGK · Sözleşmeli medikal firmalar',
  ),
  RightItem(
    id: 'otv-muafiyet',
    title: 'ÖTV Muafiyetli Araç Alımı',
    amount: '2026 fiyat sınırı: ₺2.873.900',
    category: 'vergi',
    icon: '🚗',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        '4 farklı grup engelli bireye ÖTV istisnası tanınmaktadır. 10 yılda bir hak kullanılabilir; araç beş yıl geçmeden ÖTV ödenmeksizin satılamaz.\n\n'
        "Grup 1 — %90+ engellilik: Özel tertibat şartı aranmaz, bizzat kullanma zorunluluğu yoktur.\n"
        "Grup 2 — 18 yaş altı, ÇÖZGER'de 'ÖKGV' ibaresi bulunanlar: Aynı muafiyetten yararlanabilir.\n"
        'Grup 3 — %40+ ortopedik engellilik nedeniyle sürücü belgesi alamayanlar: İlk iktisapta ÖTV istisnası.\n'
        "Grup 4 — Özel tertibatlı araç bizzat kullananlar (%90 altı): Sağlık raporunda 'sadece hareket ettirici aksamda özel tertibatlı taşıt kullanması gerekir' ibaresi ve geçerli engelli sürücü belgesi zorunludur.\n\n"
        "Araç sınırları: 87.03 (binek/SUV — ₺2.873.900), 87.04 (van/kamyonet — ≤2800 cm³), 87.11 (motosiklet). Yerli katkı oranı en az %40 olmalıdır.\n\n"
        'Deprem, sel, yangın, heyelan veya kaza nedeniyle araç kullanılamaz hale gelirse 10 yıl dolmadan yeni araçta yeniden ÖTV istisnası uygulanır.',
    steps: [
      'Sağlık Kurulu Raporu alın (hangi gruba girdiğinizi öğrenin)',
      "Vergi Dairesi'ne başvurarak ÖTV istisna belgesi düzenletin",
      'Grup 4 iseniz: geçerli B sınıfı engelli sürücü belgesi şarttır',
      "87.03 kapsamında araçta fiyat ₺2.873.900'ı (2026) aşmamalıdır",
      'Yetkili bayi ile sözleşme yapılır; araç engelli adına tescil edilir',
      '5 yıl sonra ÖTV ödenmeksizin satış hakkı doğar',
    ],
    where: 'Vergi Dairesi · Trafik Tescil · Araç Yetkili Bayii',
  ),
  RightItem(
    id: 'mtv-muafiyet',
    title: 'MTV Muafiyeti (Araç Vergisi)',
    amount: 'Tam muafiyet veya kısmi',
    category: 'vergi',
    icon: '📃',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F0FF),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        '%90 ve üzeri engellilik: Kendi adına kayıtlı araçta özel tertibat şartı aranmaksızın MTV\'den tam muafiyet. Tam teşekküllü devlet hastanesi sağlık kurulu raporu vergi dairesine ibraz edilir.\n\n'
        '%90 altı engellilik: Yalnızca özel tertibatlı araçlarda MTV muafiyeti geçerlidir. Teknik belge, proje raporu ve MTV istisnası bildirim formu istenir.',
    steps: [
      '%90+ ise: devlet hastanesi sağlık kurulu raporu hazırlayın',
      'Araç tescil belgesi, engelli kimlik kartı ve raporu vergi dairesine götürün',
      '%90 altı ise ayrıca: araç teknik belgesi, özel tertibat proje raporu ve MTV istisnası bildirim formu gerekir',
      'Vergi dairesi muafiyet işlemini tescil eder; yıllık otomatik uygulanır',
    ],
    where: 'Bağlı olunan Vergi Dairesi',
  ),
  RightItem(
    id: 'park-karti',
    title: 'Engelli Park Kartı (Mavi İşaret)',
    amount: 'Ücretsiz',
    category: 'ulasim',
    icon: '🅿️',
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Engelli park kartı yalnızca üzerine araç tescil edilmiş engellilere verilir. Kullanım için Trafik Denetleme Amirliğine başvuru gerekir.\n\n'
        'Her 20 park yerinden biri engelliler için ayrılmak zorundadır (Otopark Yönetmeliği). Engelli park yerine izinsiz park eden engelli olmayanlara iki kat para cezası uygulanır (2918 sayılı Kanun, md. 61).',
    steps: [
      'Engelli sağlık kurulu raporu ve araç tescil belgesiyle başvurun',
      'Trafik Denetleme Şube Amirliği veya İlçe Emniyet Müdürlüğü\'ne gidin',
      'Park kartı (mavi işaret) ücretsiz teslim edilir',
      'Kartı araç ön camına asın; her park değişiminde görünür yerde bulundurulmalıdır',
    ],
    where: 'Trafik Denetleme Şube/Bürü Amirliği · İlçe Emniyet Müdürlüğü',
  ),
  RightItem(
    id: 'engelli-ehliyet',
    title: 'Engelli Sürücü Belgesi (B Sınıfı)',
    amount: 'Ücretsiz / Normal ücret',
    category: 'ulasim',
    icon: '🪪',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        "1 Ocak 2016'dan önce alınan H sınıfı engelli sürücü belgeleri 31/07/2025'e kadar geçerliydi. Bu tarihten sonra B sınıfı sürücü belgesi (engellilik kodları işlenmiş) geçerlidir.\n\n"
        'B sınıfı engelli ehliyeti için 18 yaşını doldurmuş olmak ve aile hekimine başvurmak gerekir; aile hekimi İl Sağlık Komisyonu\'na sevk eder.',
    steps: [
      '18 yaşını doldurun',
      "Aile hekimine başvurarak İl Sağlık Komisyonu'na sevk alın",
      'Komisyon raporuyla sürücü kursu ve sınavına katılın',
      'Engellilik durumuna uygun özel tertibat kodları B sınıfı belgeye işlenir',
    ],
    where: 'Aile Hekimi → İl Sağlık Komisyonu → Sürücü Kursu → Trafik Tescil',
  ),
  RightItem(
    id: 'kdv-indirim',
    title: 'KDV İndirimi – Medikal & Araç',
    amount: "%18'den %1'e",
    category: 'vergi',
    icon: '🛒',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Tekerlekli sandalye, yürüteç, ortez/protez ve engelliye özel araç tadilat hizmetlerinde KDV %1 uygulanır.',
    steps: [
      'Sağlık raporu ve engel kimliği ile medikal firmaya gidin',
      "Faturada 'engelli bireye satış' ibaresi istenir",
      'Araç tadilat için ÖTV muafiyet belgesi gerekir',
    ],
    where: 'SGK sözleşmeli medikal firmalar · Yetkili servisler',
  ),
  RightItem(
    id: 'gelir-vergisi',
    title: 'Gelir Vergisi İndirimi',
    amount: '₺3.000–₺6.000 / yıl',
    category: 'vergi',
    icon: '📊',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Engelli çalışanlara ve engelli çocuğu olan çalışan ebeveynlere yıllık gelir vergisi matrahından indirim hakkı tanınır.',
    steps: [
      'İşverenin insan kaynakları birimine engel raporunu ibraz edin',
      'Vergi dairesine de bildirim yapılması önerilir',
      'Özel eğitim ve sağlık harcamaları da indirim kapsamına girebilir',
    ],
    where: 'Vergi Dairesi · İşveren İK',
  ),
  RightItem(
    id: 'ozel-egitim',
    title: 'Ücretsiz Özel Eğitim',
    amount: 'Haftada 8 saat',
    category: 'egitim',
    icon: '📚',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    minRate: 0,
    maxAge: 18,
    incomeLimit: false,
    desc:
        "MEB'e bağlı özel eğitim ve rehabilitasyon merkezlerinde haftada 8 saate kadar ücretsiz hizmet. RAM raporu zorunludur.",
    steps: [
      "RAM'a başvurun (randevu alın)",
      'RAM raporu ve Özel Eğitim Değerlendirme Kurulu kararı alın',
      'MEB sözleşmeli rehabilitasyon merkezini seçin',
      'Her yıl yenileme gerekir',
    ],
    where: 'RAM (Rehberlik ve Araştırma Merkezi)',
  ),
  RightItem(
    id: 'ram-raporu',
    title: 'RAM Raporu Nasıl Alınır?',
    amount: 'Ücretsiz',
    category: 'egitim',
    icon: '📋',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
    minRate: 0,
    maxAge: 18,
    incomeLimit: false,
    desc:
        'Özel eğitim hizmetlerinden yararlanmak için zorunlu değerlendirme raporu. Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır.',
    steps: [
      "İlçenizdeki RAM'a randevu alın",
      'Doktor raporu, okul belgesi, kimlik fotokopisiyle gidin',
      'Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır',
      'Rapor genellikle 1-3 hafta içinde hazırlanır',
    ],
    where: 'Rehberlik ve Araştırma Merkezi (RAM)',
  ),
  RightItem(
    id: 'kaynaştirma',
    title: 'Kaynaştırma Eğitimi Hakkı',
    amount: 'Anayasal hak',
    category: 'egitim',
    icon: '🏫',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    minRate: 0,
    maxAge: 18,
    incomeLimit: false,
    desc:
        'Engelli çocuklar, akranlarıyla birlikte eğitim alma hakkına sahiptir. Okul, destek eğitim odası ve özel kaynaştırma programı oluşturmak zorundadır.',
    steps: [
      'RAM raporuyla okul müdürlüğüne başvurun',
      'Destek eğitim odası saatleri planlanır',
      'BEP (Bireyselleştirilmiş Eğitim Planı) hazırlanır',
      'İlköğretimden liseye kadar sürer',
    ],
    where: 'İlçe Milli Eğitim Müdürlüğü · Okul Müdürlüğü',
  ),
  RightItem(
    id: 'engelli-kimlik',
    title: 'Engelli Kimlik Kartı',
    amount: 'Ücretsiz',
    category: 'ulasim',
    icon: '🪪',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Pek çok ayrıcalık ve indirimlere kapı açan resmi kimlik kartı. Nüfus müdürlüğünden veya e-Devlet üzerinden alınır.',
    steps: [
      'Sağlık Kurulu Raporu (%40+ engel oranı)',
      "Nüfus Müdürlüğü'ne başvurun veya e-Devlet kullanın",
      'Fotoğraf ve kimlik fotokopisi',
      '1-2 hafta içinde kart teslim edilir',
    ],
    where: 'İlçe Nüfus Müdürlüğü · e-Devlet',
  ),
  RightItem(
    id: 'ulasim',
    title: 'Ücretsiz Toplu Taşıma',
    amount: 'Belediye kartı',
    category: 'ulasim',
    icon: '🚌',
    color: Color(0xFF6B9AC4),
    bg: Color(0xFFEEF5FB),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Engelli kimlik kartı ile metro, otobüs, tramvayda ücretsiz veya indirimli seyahat. Refakatçi de bazı illerde indirimden yararlanır.',
    steps: [
      'Engelli kimlik kartı ile belediye ulaşım müdürlüğüne başvurun',
      'İstanbul: İETT, Ankara: EGO, İzmir: ESHOT',
      'Ücretsiz akıllı kart verilir',
      'Bir refakatçi de indirimden yararlanır (bazı illerde)',
    ],
    where: 'Belediye Ulaşım Müdürlükleri',
  ),
  RightItem(
    id: 'tcdd-thy',
    title: 'TCDD & THY İndirimleri',
    amount: '%50 indirim',
    category: 'ulasim',
    icon: '✈️',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        "Tren yolculuklarında %50, Türk Hava Yolları'nda engelli indirim tarifesi. Refakatçi de indirimden yararlanabilir.",
    steps: [
      'TCDD: bilet alırken engelli kimliği ibraz edin',
      "THY: thy.com'da 'Özel Yolcular' bölümünden bilet alın",
      'Refakatçi de indirimden yararlanabilir',
    ],
    where: 'TCDD Bilet Gişeleri · thy.com',
  ),
  RightItem(
    id: 'sehir-ici-park',
    title: 'Engelli Park Kartı',
    amount: 'Ücretsiz',
    category: 'ulasim',
    icon: '🅿️',
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Engelli park kartı ile engellilere ayrılmış park alanlarını kullanma hakkı tanınır. Ayrıca mavi hatlarda ücretsiz park imkânı mevcuttur.',
    steps: [
      "Engelli sağlık kurulu raporu ile Belediye Trafik Müdürlüğü'ne başvurun",
      'Engelli park kartı (maviişaret) temin edilir',
      'Araç ön camına asılır',
    ],
    where: 'Belediye Trafik Müdürlüğü · Emniyet Trafik Birimleri',
  ),
  RightItem(
    id: 'emlak-vergisi',
    title: 'Emlak Vergisi Muafiyeti',
    amount: "200 m²'ye kadar",
    category: 'vergi',
    icon: '🏡',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    minRate: 0,
    maxAge: 99,
    incomeLimit: true,
    desc:
        'Tek meskeni olan ve belirli gelir sınırının altındaki engelli bireyler emlak vergisinden muaf tutulur. Yıllık gelir kontrolü yapılır.',
    steps: [
      'Tek meskene sahip olunması gerekir',
      'Yıllık brüt gelir sınırı kontrol edilmeli',
      'Engel raporu ve beyanname ile başvurun',
    ],
    where: 'İlçe Belediyesi Gelir Müdürlüğü',
  ),
  RightItem(
    id: 'su-faturasi',
    title: 'Su Faturası İndirimi',
    amount: '%50 indirim',
    category: 'vergi',
    icon: '💧',
    color: Color(0xFF3B82F6),
    bg: Color(0xFFEFF6FF),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        "Engelli bireyin yaşadığı hanede su ve kanalizasyon faturasında %50'ye kadar indirim. İl ve belediyeye göre kota farklılık gösterebilir.",
    steps: [
      'Engelli sağlık kurulu raporu ve engelli kimlik kartıyla başvurun',
      'İkametgâh belgesi ve su abonelik sözleşmesi gerekir',
      'İSKİ / ASKİ / İZSU gibi kuruma başvurun',
      'Onaylı indirim bir sonraki faturadan itibaren yansıtılır',
    ],
    where: 'Belediye Su ve Kanalizasyon İdaresi (İSKİ / ASKİ / İZSU)',
  ),
  RightItem(
    id: 'telefon-indirimi',
    title: 'Telefon & İnternet İndirimi',
    amount: '%25–50 indirim',
    category: 'vergi',
    icon: '📱',
    color: Color(0xFF10B981),
    bg: Color(0xFFECFDF5),
    minRate: 40,
    maxAge: 99,
    incomeLimit: false,
    desc:
        'Engelli abonelere BTK kapsamında internet ve telefon faturalarında indirim uygulanmaktadır. Operatörden talep edilmesi gerekir.',
    steps: [
      'Engelli kimlik kartı ile GSM operatörüne başvurun',
      'Engel raporu ibraz edin',
      'Engelli tarifesine geçiş yapılır',
    ],
    where: 'GSM Operatör Müşteri Hizmetleri · BTK',
  ),
];

const rightsCategories = [
  RightsCategory(id: 'tümü', label: 'Tümü', icon: '📋'),
  RightsCategory(id: 'maddi', label: 'Maddi', icon: '💰'),
  RightsCategory(id: 'vergi', label: 'Vergi & Araç', icon: '🚗'),
  RightsCategory(id: 'egitim', label: 'Eğitim', icon: '📚'),
  RightsCategory(id: 'ulasim', label: 'Ulaşım', icon: '🚌'),
];

class RightsCategory {
  const RightsCategory({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final String icon;
}

List<RightItem> filterRights({
  required String yasGrubu,
  required String cozgerGrup,
  required String rate,
  required String age,
  required String income,
}) {
  int getRateNum() => rate == '40-69' ? 55 : rate == '70-89' ? 80 : 95;
  int getAgeNum() => age == '0-6' ? 3 : age == '7-17' ? 12 : 20;

  int cozgerMinOran(String grup) {
    switch (grup) {
      case '%20–39':
        return 20;
      case '%40–49':
        return 40;
      case '%50–59':
        return 50;
      case '%60–69':
        return 60;
      case '%70–79':
        return 70;
      case '%80–89':
        return 80;
      case '%90–100':
        return 90;
      default:
        return 0;
    }
  }

  return allRights.where((r) {
    if (yasGrubu == '18alti') {
      final minOran = cozgerMinOran(cozgerGrup);
      if (minOran < r.minRate) return false;
      if (getAgeNum() > r.maxAge) return false;
    } else {
      if (rate.isEmpty) return false;
      if (getRateNum() < r.minRate) return false;
      if (getAgeNum() > r.maxAge) return false;
      if (r.incomeLimit && income == 'high') return false;
    }
    return true;
  }).toList();
}

CozgerGrup? findCozgerGrup(String range) {
  for (final g in cozgerGruplari) {
    if (g.range == range) return g;
  }
  return null;
}
