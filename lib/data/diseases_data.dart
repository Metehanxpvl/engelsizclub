import 'package:flutter/material.dart';

/// Ana sayfa hastalık rehberi — yerel fallback.
/// Canlı içerik: Supabase `app_diseases` + CatalogAdapters.diseases().

class FaqItem {
  const FaqItem(this.q, this.a);
  final String q;
  final String a;
}

class DiseaseInfo {
  const DiseaseInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.bg,
    required this.desc,
    required this.symptoms,
    required this.diagnosis,
    required this.support,
    required this.faq,
    this.photo,
  });

  final String id;
  final String name;
  final String icon;
  final Color color;
  final Color bg;
  final String? photo;
  final String desc;
  final List<String> symptoms;
  final String diagnosis;
  final List<String> support;
  final List<FaqItem> faq;
}

const kDiseases = <DiseaseInfo>[
  DiseaseInfo(
    id: 'otizm',
    name: 'Otizm Spektrum Bozukluğu',
    icon: '🧩',
    color: Color(0xFF5B8DD9),
    bg: Color(0xFFEEF3FC),
    photo: 'assets/images/otizm.png',
    desc:
        "Otizm Spektrum Bozukluğu (OSB), sosyal iletişim ve etkileşimde güçlük ile kısıtlı, tekrarlayıcı davranış örüntüleriyle karakterize, erken gelişimsel dönemde ortaya çıkan nörogelişimsel bir durumdur. Her bireyde farklı biçimde görülür; bu nedenle 'spektrum' adını alır.",
    symptoms: [
      'Göz temasından kaçınma veya sınırlı göz teması',
      'Dil ve konuşma gelişiminde gecikme ya da gerileme',
      'Tekrarlayıcı hareketler (el çırpma, sallanma)',
      'Rutin değişikliklerine aşırı direnç',
      'Duyusal uyaranlara (ses, ışık, dokunma) aşırı veya yetersiz tepki',
      'Akran ilişkilerinde güçlük, sosyal ipuçlarını okuyamama',
      'Sınırlı ilgi alanları ve obsesif odaklanma',
    ],
    diagnosis:
        'Çocuk gelişimi alanında uzman hekim tarafından DSM-5 ölçütleri esas alınarak kapsamlı gelişimsel değerlendirme yapılır. ADOS-2 ve ADI-R standart araçlardır. Erken özellikler 12–18 aylarda fark edilebilir; değerlendirme genellikle 2–3 yaşında netleşir.',
    support: [
      'Uygulamalı Davranış Analizi (ABA)',
      'Dil ve konuşma terapisi',
      'Ergoterapi (duyusal entegrasyon)',
      'PECS ve AAC iletişim sistemleri',
      'Sosyal beceri grupları',
      'Aile rehberliği ve ebeveyn eğitimi',
      'Özel eğitim ve kaynaştırma programları',
    ],
    faq: [
      FaqItem(
        'Otizm için destek seçenekleri nelerdir?',
        'Erken ve yoğun destekle bireyler bağımsızlıklarını ve yaşam kalitelerini önemli ölçüde artırabilir. ABA yaygın kullanılan kanıta dayalı yöntemlerden biridir.',
      ),
      FaqItem(
        'Ne zaman değerlendirilebilir?',
        '18–24 ay gibi erken dönemde özellikler fark edilebilir. Güvenilir değerlendirme genellikle 2–3 yaşında netleşir.',
      ),
      FaqItem(
        'Otizm kalıtsal mıdır?',
        "Genetik yatkınlık önemli bir rol oynar. İkizlerde uyum oranı %70–90'a ulaşmaktadır.",
      ),
    ],
  ),
  DiseaseInfo(
    id: 'serebral',
    name: 'Serebral Palsi',
    icon: '🌟',
    color: Color(0xFF1A6B4A),
    bg: Color(0xFFE8F5EE),
    photo: 'assets/images/serebral_palsi.png',
    desc:
        "Serebral Palsi (SP), beyin gelişimini etkileyen, erken yaşta meydana gelen beyin hasarından kaynaklanan motor fonksiyon bozukluğudur. Türkiye'de her 1000 canlı doğumda 2–3 çocukta görülür.",
    symptoms: [
      'Spastisite (kas sertliği ve anormal refleksler)',
      'Ataksi (denge ve koordinasyon güçlüğü)',
      'Diskinezi (istemsiz hareketler)',
      'Yürüme bozukluğu veya yürüyememe',
      'Konuşma güçlüğü (dizartri)',
      'Yutma güçlüğü',
      "Zihinsel ve öğrenme güçlükleri (vakaların yaklaşık %50'sinde)",
      'Epilepsi nöbetleri',
    ],
    diagnosis:
        'Uzman hekim tarafından klinik değerlendirme ve beyin MRI ile değerlendirilir. Erken özellikler ilk 6 ayda fark edilebilir. Değerlendirme çoğunlukla 12–24 ayda netleşir.',
    support: [
      'Fizyoterapi ve destek programları (Bobath, Vojta yöntemleri)',
      'Ergoterapi (günlük yaşam becerileri)',
      'Dil ve konuşma terapisi',
      'Ortez ve yardımcı cihazlar (AFO, tekerlekli sandalye)',
      'Hidroterapi ve at terapisi (hippoterapi)',
      'Botoks enjeksiyonu (spastisite yönetimi)',
      'Bakıcı ve aile eğitimi',
    ],
    faq: [
      FaqItem(
        'SP ilerleyici midir?',
        'Hayır. Beyin hasarı sabit kalır; ancak birey büyüdükçe kaslar ve eklemler etkilenebilir.',
      ),
      FaqItem(
        "SP'li çocuklar bağımsız yürüyebilir mi?",
        'SP tipine göre değişir. GMFCS Düzey 1–2’deki çocukların büyük çoğunluğu bağımsız yürür.',
      ),
      FaqItem(
        'Serebral palsi tipleri nelerdir?',
        'Dört ana tip: Spastik SP, Ataksik SP, Diskinetik SP ve Miks Tip SP.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'down',
    name: 'Down Sendromu',
    icon: '💛',
    color: Color(0xFFF4A832),
    bg: Color(0xFFFFF8ED),
    photo: 'assets/images/down_sendromu.png',
    desc:
        'Down Sendromu, 21. kromozomun fazladan bir kopyasının (trizomi 21) bulunmasından kaynaklanır. Dünyada her 700–1000 canlı doğumda bir görülür.',
    symptoms: [
      'Kas hipotonisi (düşük kas tonusu)',
      'Karakteristik yüz özellikleri',
      'Kısa boy ve geniş el-ayak yapısı',
      "Konjenital kalp defekti (vakaların yaklaşık %40–50'sinde)",
      'Zihinsel ve gelişimsel gecikmeler',
      'Tiroid sorunları ve işitme kaybı riski',
      'Erken yaşlanma eğilimi ve Alzheimer riski',
    ],
    diagnosis:
        'Prenatal: İkili/üçlü tarama, NIPT, amniyosentez, KVÖ. Doğumda klinik bulgular ve karyotip analizi kesin tanıyı sağlar.',
    support: [
      'Erken müdahale programları (0–3 yaş kritik dönem)',
      'Özel eğitim ve kaynaştırma eğitimi',
      'Konuşma ve dil terapisi',
      'Fizik tedavi (kas tonusu ve motor gelişim)',
      'Ergoterapi (ince motor beceriler)',
      'Kalp sorunları için kardiyoloji takibi',
      'Down Sendromu Araştırma Vakfı (DSRF) destek programları',
    ],
    faq: [
      FaqItem(
        'Down sendromlu bireyler ne kadar süre yaşar?',
        'Modern tıptaki gelişmeler sayesinde yaşam beklentisi 60 yılın üzerine çıkmıştır.',
      ),
      FaqItem('Okula gidebilirler mi?',
          'Evet. Kaynaştırma eğitimi ve özel eğitim programlarıyla okul eğitimi alabilirler.'),
      FaqItem(
        'Anne yaşı Down sendromu riskini etkiler mi?',
        'Evet. 35 yaş üstü annelerde risk artar; ancak vakaların büyük bölümü genç annelerde görülür.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'sma',
    name: 'SMA (Spinal Müsküler Atrofi)',
    icon: '💪',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF5F0FF),
    photo: 'assets/images/SMA_.png',
    desc:
        "Spinal Müsküler Atrofi (SMA), SMN1 genindeki mutasyon sonucu motor nöronların işlev görmemesiyle oluşan genetik bir hastalıktır. Türkiye'de yaklaşık 1500–2000 hasta bulunduğu tahmin edilmektedir.",
    symptoms: [
      'Kas güçsüzlüğü ve erimesi',
      'Solunum güçlüğü',
      'Yutma ve beslenme güçlüğü',
      'Oturma, ayakta durma ve yürümede güçlük',
      'Hipotonik bebek (floppy baby) görünümü',
      'Omurga deformiteleri (skolyoz)',
    ],
    diagnosis:
        'SMN1 gen analizi altın standarttır. EMG ve kas biyopsisi destekleyicidir. Semptom başlangıcına göre Tip 1–4 sınıflandırması yapılır.',
    support: [
      'Zolgensma (gen tedavisi)',
      'Nusinersen/Spinraza',
      'Risdiplam/Evrysdi',
      'Solunum desteği (BiPAP)',
      'Beslenme desteği',
      'Fizik tedavi, ergoterapi, ortez',
      'SMA Derneği Türkiye',
    ],
    faq: [
      FaqItem(
        'SMA için destek seçenekleri nelerdir?',
        'Zolgensma, Spinraza ve Evrysdi hastalığın seyrini ciddi biçimde değiştirebilen seçenekler arasındadır.',
      ),
      FaqItem(
        "Türkiye'de desteğe erişim nasıl?",
        'Spinraza SGK kapsamındadır. Zolgensma için ilgili kurumlara bireysel başvuru yapılabilmektedir.',
      ),
      FaqItem(
        'Gelecekte ne gibi gelişmeler bekleniyor?',
        'Miyostatin inhibitörleri, yeni nesil gen yaklaşımları ve nöroprotektif ajanlar araştırma aşamasındadır.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'dehb',
    name: 'DEHB',
    icon: '⚡',
    color: Color(0xFFE8960A),
    bg: Color(0xFFFFF3DB),
    photo: 'assets/images/DEHB.png',
    desc:
        "Dikkat Eksikliği ve Hiperaktivite Bozukluğu (DEHB), dikkat süresinin kısalığı, dürtüsellik ve hiperaktivite ile karakterize nörogelişimsel bir bozukluktur. Okul çağı çocuklarının yaklaşık %5–8'ini etkiler.",
    symptoms: [
      'Derse veya göreve odaklanamama',
      'Ayrıntılarda dikkatsiz hatalar',
      'Görevleri organize etmede güçlük',
      'Sakin oturamama',
      'Sırasını bekleyememe',
      'Düşüncesizce hareket etme',
      'Eşyaları sık kaybetme, unutkanlık',
    ],
    diagnosis:
        'Çocuk psikiyatristi veya klinisyen psikolog tarafından DSM-5 ölçütleriyle değerlendirme yapılır. En az 6 ay ve birden fazla ortamda görülen belirtiler tanı için gereklidir.',
    support: [
      'Davranış terapisi ve BDT',
      'Metilfenidat bazlı ilaçlar',
      'Atomoksetin (Strattera)',
      'Okul düzenlemeleri',
      'Aile rehberliği',
      'Sosyal beceri grupları',
      'Spor ve hareket aktiviteleri',
    ],
    faq: [
      FaqItem('DEHB ilaçsız tedavi edilir mi?',
          'Hafif vakalarda davranış terapisi yeterli olabilir.'),
      FaqItem('DEHB büyüyünce geçer mi?',
          'Hiperaktivite azalabilir ancak dikkat sorunları yetişkinlikte de sürebilir.'),
      FaqItem('DEHB zeka düzeyiyle ilişkili midir?',
          'Hayır. DEHB zekanın yüksek veya düşük olmasıyla ilgili değildir.'),
    ],
  ),
  DiseaseInfo(
    id: 'gelisim',
    name: 'Gelişim Geriliği',
    icon: '🌱',
    color: Color(0xFF5BA882),
    bg: Color(0xFFE4F0E9),
    photo: 'assets/images/geli_im_gerili_i.png',
    desc:
        "Global Gelişim Geriliği, motor, dil, bilişsel ve sosyal-duygusal alanlarda yaşa uygun gelişimin gerisinde kalma durumudur. Türkiye'de her 100 çocuktan 1–3'ünü etkiler.",
    symptoms: [
      'Motor gelişimde gecikme',
      'Dil ve konuşma ediniminde yavaşlık',
      'Sosyal etkileşim ve oyun becerilerinde güçlük',
      'Öz bakım becerilerinde gecikme',
      'Akademik öğrenme güçlükleri',
      'Dikkat ve bellek problemleri',
    ],
    diagnosis:
        'Gelişim pediatristi tarafından Denver II ile tarama yapılır. Nörolojik muayene, MRI, metabolik testler ve genetik panel uygulanabilir.',
    support: [
      'Erken müdahale programları (0–6 yaş)',
      'Fizik tedavi',
      'Dil ve konuşma terapisi',
      'Ergoterapi',
      'Özel eğitim ve BEP',
      'Beslenme desteği',
      'Aile eğitimi ve ev programları',
    ],
    faq: [
      FaqItem('Erken müdahale neden bu kadar önemli?',
          '0–6 yaş arası beyin plastisitesi en yüksek dönemdir.'),
      FaqItem('Gelişim geriliği büyüdükçe düzelir mi?',
          'Nedene göre değişir. Destek tedavileri yaşam kalitesini artırır.'),
      FaqItem(
        'Büyüme geriliği ile gelişim geriliği aynı şey midir?',
        'Hayır. Büyüme geriliği fiziksel; gelişim geriliği bilişsel ve motor alanları kapsar.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'duyu',
    name: 'Duyu Bütünleme Sorunları',
    icon: '✋',
    color: Color(0xFF9C6DB3),
    bg: Color(0xFFF5EEFB),
    photo: 'assets/images/duyu_b_t_nleme_sorunlar_.png',
    desc:
        'Duyu Bütünleme Sorunları, beynin çevreden gelen duyusal bilgileri etkin biçimde organize edip yanıt vermesindeki yetersizliği ifade eder.',
    symptoms: [
      'Giysi dikişlerine veya etiketlere aşırı tepki',
      'Gürültülü ortamlarda panik',
      'Denge kaybı ve koordinasyon güçlüğü',
      'Aşırı duyusal arayışı',
      'Yeme güçlükleri',
      'Acıya veya sıcağa alışılmadık tepkiler',
      'Kalabalık ortamlarda aşırı stres',
    ],
    diagnosis:
        "Ergoterapi uzmanı tarafından 'Duyu Profili' veya SPM değerlendirmesi yapılır.",
    support: [
      'Duyusal entegrasyon terapisi',
      'Duyusal diyet planı',
      'Ağırlıklı yelek ve battaniye',
      'Ev ve okul ortamı düzenlemeleri',
      'Proprioseptif egzersizler',
      'Sosyal öykü ve duygusal düzenleme',
    ],
    faq: [
      FaqItem(
        'Duyu bütünleme sorunları otizmle aynı şey midir?',
        'Hayır. Ayrı bir tanıdır ve otizm olmaksızın da görülebilir.',
      ),
      FaqItem(
        'Ergoterapi ne zaman işe yarar?',
        'Erken başlanan ergoterapi en iyi sonuçları verir. Genellikle 6–12 ay içinde belirgin gelişme görülür.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'iletisim',
    name: 'İletişim Bozuklukları',
    icon: '💬',
    color: Color(0xFFE07A5F),
    bg: Color(0xFFFDF0EC),
    photo: 'assets/images/ileti_im_bozukluklar_.png',
    desc:
        "İletişim Bozuklukları, konuşma sesi bozuklukları, dil bozuklukları, sosyal iletişim bozukluğu ve kekemeliği kapsayan geniş bir tanı grubudur. Çocukların yaklaşık %8–9'u konuşma veya dil desteğine ihtiyaç duyar.",
    symptoms: [
      'Geç konuşma başlangıcı',
      'Konuşma seslerinin yanlış üretimi',
      'Kekeleme veya akıcılık bozukluğu',
      'Dili anlama güçlüğü',
      'Duygu ve düşünceleri söze dökememe',
      'Sosyal bağlamda uygun iletişim kuramama',
      'Sınırlı kelime dağarcığı',
    ],
    diagnosis:
        'Dil ve konuşma terapisti tarafından standart dil değerlendirme araçları kullanılır. Odiyolojik değerlendirme ve nörolojik muayene ek tanı araçlarıdır.',
    support: [
      'Bireysel dil ve konuşma terapisi',
      'AAC — PECS, cihazlar, işaret dili',
      'Aile rehberliği ve ev programları',
      'Dil zengini çevre oluşturma',
      'Akıcılık terapisi',
      'Grup terapisi',
      'Erken müdahale dil programları',
    ],
    faq: [
      FaqItem(
        'AAC cihazı kullanmak konuşmayı engellemez mi?',
        'Araştırmalar AAC doğal konuşmayı desteklediğini göstermektedir.',
      ),
      FaqItem(
        'Çocuğum 3 yaşında konuşmuyorsa ne yapmalıyım?',
        'En kısa sürede dil ve konuşma terapistine başvurun.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'premature',
    name: 'Prematüre Bebek',
    icon: '👶',
    color: Color(0xFF0E7490),
    bg: Color(0xFFE0F2FE),
    photo: 'assets/images/geli_im_gerili_i.png',
    desc:
        'Erken doğan bebekler için 0-12 ay gelişim rehberi ve evde aktiviteler',
    symptoms: [
      'Düzeltilmiş yaş takibi',
      '0–3 ay boyun / baş kontrolü',
      '4–6 ay dönme ve oturma',
      '7–12 ay emekleme ve adımlar',
      'Evde tummy time',
    ],
    diagnosis:
        'Gelişim izlemi çocuk doktoru ve gerekirse erken müdahale ekibiyle yapılır. '
        'Bu rehber bilgilendirme amaçlıdır.',
    support: [
      'Çocuk Doktoru',
      'Fizik Tedavi',
      'Erken Müdahale',
      'SGK',
      'Sağlık raporu süreçleri',
    ],
    faq: [
      FaqItem(
        'Düzeltilmiş yaş nedir?',
        'Bebeğin beklenen doğum tarihine göre hesaplanan gelişim yaşıdır; '
        'milestones genelde buna göre okunur.',
      ),
    ],
  ),
  DiseaseInfo(
    id: 'nadir',
    name: 'Nadir Hastalıklar',
    icon: '🔬',
    color: Color(0xFF7C3AED),
    bg: Color(0xFFF0EEFF),
    photo: 'assets/images/nadir_hastal_klar.png',
    desc:
        "Dünyada 7.000'den fazla nadir hastalık tanımlanmıştır; her biri 200.000'den az kişiyi etkiler.",
    symptoms: [
      'Spina Bifida',
      'Rett Sendromu',
      'Angelman Sendromu',
      'Prader-Willi Sendromu',
      'PKU (Fenilketonüri)',
      'Fragile X Sendromu',
      'Duchenne Müsküler Distrofi',
      'Williams Sendromu',
      'CDKL5 Eksikliği',
      'Tuberous Sclerosis',
    ],
    diagnosis:
        'Tıbbi Genetik uzmanı tarafından kapsamlı genetik panel testleri ve klinik değerlendirme yapılır.',
    support: [
      'Tıbbi Genetik bölümleri',
      'nadir.org.tr',
      'Orphanet Türkiye',
      'NORD',
      'SGK Erişilemeyen İlaçlar birimi',
      'Hasta dernekleri',
    ],
    faq: [
      FaqItem(
        'Nadir hastalıkta nereye başvurmalıyım?',
        "Üniversite hastanelerinin Tıbbi Genetik bölümlerine başvurun. nadir.org.tr üzerinden uzman merkezlere ulaşabilirsiniz.",
      ),
      FaqItem(
        'SGK nadir hastalık ilaçlarını karşılar mı?',
        'Bazı ilaçlar özel onay süreciyle SGK tarafından karşılanabilir.',
      ),
    ],
  ),
];
