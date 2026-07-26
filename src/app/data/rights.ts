export const allRights = [
  { id: "evde-bakim", title: "Evde Bakım Maaşı", amount: "≈ ₺12.000 / ay", category: "maddi", icon: "🏠", color: "#1a6b4a", bg: "#e8f5ee", minRate: 50, maxAge: 18, incomeLimit: true, desc: "Evde bakıma muhtaç ağır engelli bireylerin yakınlarına Sosyal Hizmetler tarafından ödenen aylık destek. Hane halkı gelir testi yapılır.", steps: ["E-Devlet üzerinden 'Evde Bakım Hizmeti' başvurusu yapın", "Sağlık kurulundan %50+ bakıma muhtaç raporu alın", "İl Sosyal Hizmetler Müdürlüğü'ne başvurun", "Hane halkı gelir testi yapılır"], where: "e-Devlet · İl Sosyal Hizmetler Müdürlüğü" },
  { id: "engelli-maas", title: "Engelli Aylığı", amount: "₺4.000 – ₺8.000 / ay", category: "maddi", icon: "💳", color: "#6b9ac4", bg: "#eef5fb", minRate: 40, maxAge: 99, incomeLimit: true, desc: "SGK veya Sosyal Yardımlaşma Vakfı tarafından ödenen aylık. Gelir testi uygulanır; çalışmayan engelli bireyler için geçerlidir.", steps: ["Sağlık Kurulu Raporu alın (%40+ engel oranı)", "SGK veya SYDV'ye başvurun", "18 yaş altı için veli belgesi gerekir", "Hesaba her ay otomatik yatırılır"], where: "SGK · Sosyal Yardımlaşma Vakfı" },
  { id: "yardimci-arac", title: "Yardımcı Araç-Gereç Desteği", amount: "SGK karşılar", category: "maddi", icon: "♿", color: "#5ba882", bg: "#e4f0e9", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Tekerlekli sandalye, yürüteç, ortez, protez, işitme cihazı ve benzeri yardımcı araçlar SGK tarafından karşılanmaktadır.", steps: ["Hekim raporu ve SGK sevki alın", "SGK sözleşmeli firma veya ortez merkezine gidin", "Katkı payı varsa ödenir; ücretsiz seçenekler mevcuttur"], where: "SGK · Sözleşmeli medikal firmalar" },
  { id: "otv-muafiyet", title: "ÖTV Muafiyetli Araç Alımı", amount: "2026 fiyat sınırı: ₺2.873.900", category: "vergi", icon: "🚗", color: "#e07a5f", bg: "#fdf0ec", minRate: 40, maxAge: 99, incomeLimit: false,
    desc: "4 farklı grup engelli bireye ÖTV istisnası tanınmaktadır. 10 yılda bir hak kullanılabilir; araç beş yıl geçmeden ÖTV ödenmeksizin satılamaz.\n\n" +
      "Grup 1 — %90+ engellilik: Özel tertibat şartı aranmaz, bizzat kullanma zorunluluğu yoktur.\n" +
      "Grup 2 — 18 yaş altı, ÇÖZGER'de 'ÖKGV' ibaresi bulunanlar: Aynı muafiyetten yararlanabilir.\n" +
      "Grup 3 — %40+ ortopedik engellilik nedeniyle sürücü belgesi alamayanlar: İlk iktisapta ÖTV istisnası.\n" +
      "Grup 4 — Özel tertibatlı araç bizzat kullananlar (%90 altı): Sağlık raporunda 'sadece hareket ettirici aksamda özel tertibatlı taşıt kullanması gerekir' ibaresi ve geçerli engelli sürücü belgesi zorunludur.\n\n" +
      "Araç sınırları: 87.03 (binek/SUV — ₺2.873.900), 87.04 (van/kamyonet — ≤2800 cm³), 87.11 (motosiklet). Yerli katkı oranı en az %40 olmalıdır.\n\n" +
      "Deprem, sel, yangın, heyelan veya kaza nedeniyle araç kullanılamaz hale gelirse 10 yıl dolmadan yeni araçta yeniden ÖTV istisnası uygulanır.",
    steps: [
      "Sağlık Kurulu Raporu alın (hangi gruba girdiğinizi öğrenin)",
      "Vergi Dairesi'ne başvurarak ÖTV istisna belgesi düzenletin",
      "Grup 4 iseniz: geçerli B sınıfı engelli sürücü belgesi şarttır",
      "87.03 kapsamında araçta fiyat ₺2.873.900'ı (2026) aşmamalıdır",
      "Yetkili bayi ile sözleşme yapılır; araç engelli adına tescil edilir",
      "5 yıl sonra ÖTV ödenmeksizin satış hakkı doğar"
    ],
    where: "Vergi Dairesi · Trafik Tescil · Araç Yetkili Bayii"
  },
  { id: "mtv-muafiyet", title: "MTV Muafiyeti (Araç Vergisi)", amount: "Tam muafiyet veya kısmi", category: "vergi", icon: "📃", color: "#7c3aed", bg: "#f5f0ff", minRate: 40, maxAge: 99, incomeLimit: false,
    desc: "%90 ve üzeri engellilik: Kendi adına kayıtlı araçta özel tertibat şartı aranmaksızın MTV'den tam muafiyet. Tam teşekküllü devlet hastanesi sağlık kurulu raporu vergi dairesine ibraz edilir.\n\n" +
      "%90 altı engellilik: Yalnızca özel tertibatlı araçlarda MTV muafiyeti geçerlidir. Teknik belge, proje raporu ve MTV istisnası bildirim formu istenir.",
    steps: [
      "%90+ ise: devlet hastanesi sağlık kurulu raporu hazırlayın",
      "Araç tescil belgesi, engelli kimlik kartı ve raporu vergi dairesine götürün",
      "%90 altı ise ayrıca: araç teknik belgesi, özel tertibat proje raporu ve MTV istisnası bildirim formu gerekir",
      "Vergi dairesi muafiyet işlemini tescil eder; yıllık otomatik uygulanır"
    ],
    where: "Bağlı olunan Vergi Dairesi"
  },
  { id: "park-karti", title: "Engelli Park Kartı (Mavi İşaret)", amount: "Ücretsiz", category: "ulasim", icon: "🅿️", color: "#3b82f6", bg: "#eff6ff", minRate: 40, maxAge: 99, incomeLimit: false,
    desc: "Engelli park kartı yalnızca üzerine araç tescil edilmiş engellilere verilir. Kullanım için Trafik Denetleme Amirliğine başvuru gerekir.\n\n" +
      "Her 20 park yerinden biri engelliler için ayrılmak zorundadır (Otopark Yönetmeliği). Engelli park yerine izinsiz park eden engelli olmayanlara iki kat para cezası uygulanır (2918 sayılı Kanun, md. 61).",
    steps: [
      "Engelli sağlık kurulu raporu ve araç tescil belgesiyle başvurun",
      "Trafik Denetleme Şube Amirliği veya İlçe Emniyet Müdürlüğü'ne gidin",
      "Park kartı (mavi işaret) ücretsiz teslim edilir",
      "Kartı araç ön camına asın; her park değişiminde görünür yerde bulundurulmalıdır"
    ],
    where: "Trafik Denetleme Şube/Bürü Amirliği · İlçe Emniyet Müdürlüğü"
  },
  { id: "engelli-ehliyet", title: "Engelli Sürücü Belgesi (B Sınıfı)", amount: "Ücretsiz / Normal ücret", category: "ulasim", icon: "🪪", color: "#1a6b4a", bg: "#e8f5ee", minRate: 40, maxAge: 99, incomeLimit: false,
    desc: "1 Ocak 2016'dan önce alınan H sınıfı engelli sürücü belgeleri 31/07/2025'e kadar geçerliydi. Bu tarihten sonra B sınıfı sürücü belgesi (engellilik kodları işlenmiş) geçerlidir.\n\n" +
      "B sınıfı engelli ehliyeti için 18 yaşını doldurmuş olmak ve aile hekimine başvurmak gerekir; aile hekimi İl Sağlık Komisyonu'na sevk eder.",
    steps: [
      "18 yaşını doldurun",
      "Aile hekimine başvurarak İl Sağlık Komisyonu'na sevk alın",
      "Komisyon raporuyla sürücü kursu ve sınavına katılın",
      "Engellilik durumuna uygun özel tertibat kodları B sınıfı belgeye işlenir"
    ],
    where: "Aile Hekimi → İl Sağlık Komisyonu → Sürücü Kursu → Trafik Tescil"
  },
  { id: "kdv-indirim", title: "KDV İndirimi – Medikal & Araç", amount: "%18'den %1'e", category: "vergi", icon: "🛒", color: "#f4a832", bg: "#fff8ed", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Tekerlekli sandalye, yürüteç, ortez/protez ve engelliye özel araç tadilat hizmetlerinde KDV %1 uygulanır.", steps: ["Sağlık raporu ve engel kimliği ile medikal firmaya gidin", "Faturada 'engelli bireye satış' ibaresi istenir", "Araç tadilat için ÖTV muafiyet belgesi gerekir"], where: "SGK sözleşmeli medikal firmalar · Yetkili servisler" },
  { id: "gelir-vergisi", title: "Gelir Vergisi İndirimi", amount: "₺3.000–₺6.000 / yıl", category: "vergi", icon: "📊", color: "#9c6db3", bg: "#f5eefb", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Engelli çalışanlara ve engelli çocuğu olan çalışan ebeveynlere yıllık gelir vergisi matrahından indirim hakkı tanınır.", steps: ["İşverenin insan kaynakları birimine engel raporunu ibraz edin", "Vergi dairesine de bildirim yapılması önerilir", "Özel eğitim ve sağlık harcamaları da indirim kapsamına girebilir"], where: "Vergi Dairesi · İşveren İK" },
  { id: "ozel-egitim", title: "Ücretsiz Özel Eğitim", amount: "Haftada 8 saat", category: "egitim", icon: "📚", color: "#9c6db3", bg: "#f5eefb", minRate: 0, maxAge: 18, incomeLimit: false, desc: "MEB'e bağlı özel eğitim ve rehabilitasyon merkezlerinde haftada 8 saate kadar ücretsiz hizmet. RAM raporu zorunludur.", steps: ["RAM'a başvurun (randevu alın)", "RAM raporu ve Özel Eğitim Değerlendirme Kurulu kararı alın", "MEB sözleşmeli rehabilitasyon merkezini seçin", "Her yıl yenileme gerekir"], where: "RAM (Rehberlik ve Araştırma Merkezi)" },
  { id: "ram-raporu", title: "RAM Raporu Nasıl Alınır?", amount: "Ücretsiz", category: "egitim", icon: "📋", color: "#5ba882", bg: "#e4f0e9", minRate: 0, maxAge: 18, incomeLimit: false, desc: "Özel eğitim hizmetlerinden yararlanmak için zorunlu değerlendirme raporu. Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır.", steps: ["İlçenizdeki RAM'a randevu alın", "Doktor raporu, okul belgesi, kimlik fotokopisiyle gidin", "Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır", "Rapor genellikle 1-3 hafta içinde hazırlanır"], where: "Rehberlik ve Araştırma Merkezi (RAM)" },
  { id: "kaynaştirma", title: "Kaynaştırma Eğitimi Hakkı", amount: "Anayasal hak", category: "egitim", icon: "🏫", color: "#1a6b4a", bg: "#e8f5ee", minRate: 0, maxAge: 18, incomeLimit: false, desc: "Engelli çocuklar, akranlarıyla birlikte eğitim alma hakkına sahiptir. Okul, destek eğitim odası ve özel kaynaştırma programı oluşturmak zorundadır.", steps: ["RAM raporuyla okul müdürlüğüne başvurun", "Destek eğitim odası saatleri planlanır", "BEP (Bireyselleştirilmiş Eğitim Planı) hazırlanır", "İlköğretimden liseye kadar sürer"], where: "İlçe Milli Eğitim Müdürlüğü · Okul Müdürlüğü" },
  { id: "engelli-kimlik", title: "Engelli Kimlik Kartı", amount: "Ücretsiz", category: "ulasim", icon: "🪪", color: "#1a6b4a", bg: "#e8f5ee", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Pek çok ayrıcalık ve indirimlere kapı açan resmi kimlik kartı. Nüfus müdürlüğünden veya e-Devlet üzerinden alınır.", steps: ["Sağlık Kurulu Raporu (%40+ engel oranı)", "Nüfus Müdürlüğü'ne başvurun veya e-Devlet kullanın", "Fotoğraf ve kimlik fotokopisi", "1-2 hafta içinde kart teslim edilir"], where: "İlçe Nüfus Müdürlüğü · e-Devlet" },
  { id: "ulasim", title: "Ücretsiz Toplu Taşıma", amount: "Belediye kartı", category: "ulasim", icon: "🚌", color: "#6b9ac4", bg: "#eef5fb", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Engelli kimlik kartı ile metro, otobüs, tramvayda ücretsiz veya indirimli seyahat. Refakatçi de bazı illerde indirimden yararlanır.", steps: ["Engelli kimlik kartı ile belediye ulaşım müdürlüğüne başvurun", "İstanbul: İETT, Ankara: EGO, İzmir: ESHOT", "Ücretsiz akıllı kart verilir", "Bir refakatçi de indirimden yararlanır (bazı illerde)"], where: "Belediye Ulaşım Müdürlükleri" },
  { id: "tcdd-thy", title: "TCDD & THY İndirimleri", amount: "%50 indirim", category: "ulasim", icon: "✈️", color: "#e07a5f", bg: "#fdf0ec", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Tren yolculuklarında %50, Türk Hava Yolları'nda engelli indirim tarifesi. Refakatçi de indirimden yararlanabilir.", steps: ["TCDD: bilet alırken engelli kimliği ibraz edin", "THY: thy.com'da 'Özel Yolcular' bölümünden bilet alın", "Refakatçi de indirimden yararlanabilir"], where: "TCDD Bilet Gişeleri · thy.com" },
  { id: "sehir-ici-park", title: "Engelli Park Kartı", amount: "Ücretsiz", category: "ulasim", icon: "🅿️", color: "#3b82f6", bg: "#eff6ff", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Engelli park kartı ile engellilere ayrılmış park alanlarını kullanma hakkı tanınır. Ayrıca mavi hatlarda ücretsiz park imkânı mevcuttur.", steps: ["Engelli sağlık kurulu raporu ile Belediye Trafik Müdürlüğü'ne başvurun", "Engelli park kartı (maviişaret) temin edilir", "Araç ön camına asılır"], where: "Belediye Trafik Müdürlüğü · Emniyet Trafik Birimleri" },
  { id: "emlak-vergisi", title: "Emlak Vergisi Muafiyeti", amount: "200 m²'ye kadar", category: "vergi", icon: "🏡", color: "#9c6db3", bg: "#f5eefb", minRate: 0, maxAge: 99, incomeLimit: true, desc: "Tek meskeni olan ve belirli gelir sınırının altındaki engelli bireyler emlak vergisinden muaf tutulur. Yıllık gelir kontrolü yapılır.", steps: ["Tek meskene sahip olunması gerekir", "Yıllık brüt gelir sınırı kontrol edilmeli", "Engel raporu ve beyanname ile başvurun"], where: "İlçe Belediyesi Gelir Müdürlüğü" },
  { id: "su-faturasi", title: "Su Faturası İndirimi", amount: "%50 indirim", category: "vergi", icon: "💧", color: "#3b82f6", bg: "#eff6ff", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Engelli bireyin yaşadığı hanede su ve kanalizasyon faturasında %50'ye kadar indirim. İl ve belediyeye göre kota farklılık gösterebilir.", steps: ["Engelli sağlık kurulu raporu ve engelli kimlik kartıyla başvurun", "İkametgâh belgesi ve su abonelik sözleşmesi gerekir", "İSKİ / ASKİ / İZSU gibi kuruma başvurun", "Onaylı indirim bir sonraki faturadan itibaren yansıtılır"], where: "Belediye Su ve Kanalizasyon İdaresi (İSKİ / ASKİ / İZSU)" },
  { id: "telefon-indirimi", title: "Telefon & İnternet İndirimi", amount: "%25–50 indirim", category: "vergi", icon: "📱", color: "#10b981", bg: "#ecfdf5", minRate: 40, maxAge: 99, incomeLimit: false, desc: "Engelli abonelere BTK kapsamında internet ve telefon faturalarında indirim uygulanmaktadır. Operatörden talep edilmesi gerekir.", steps: ["Engelli kimlik kartı ile GSM operatörüne başvurun", "Engel raporu ibraz edin", "Engelli tarifesine geçiş yapılır"], where: "GSM Operatör Müşteri Hizmetleri · BTK" },
];

export const COZGER_GRUPLARI = [
  { range: "%20–39", label: "Özel Gereksinim Vardır", kisa: "ÖGV", color: "#6b9ac4", bg: "#eef5fb" },
  { range: "%40–49", label: "Hafif Düzeyde Özel Gereksinim Vardır", kisa: "Hafif", color: "#5ba882", bg: "#e8f5ee" },
  { range: "%50–59", label: "Orta Düzeyde Özel Gereksinim Vardır", kisa: "Orta", color: "#e8a020", bg: "#fef3e2" },
  { range: "%60–69", label: "İleri Düzeyde Özel Gereksinim Vardır", kisa: "İleri", color: "#e07a5f", bg: "#fdf0ec" },
  { range: "%70–79", label: "Çok İleri Düzeyde Özel Gereksinim Vardır", kisa: "Çok İleri", color: "#c0392b", bg: "#fde8e8", agir: true },
  { range: "%80–89", label: "Belirgin Düzeyde Özel Gereksinim Vardır", kisa: "BÖGV", color: "#8e44ad", bg: "#f5eefb", agir: true },
  { range: "%90–100", label: "Özel Koşul Gereksinimi Vardır", kisa: "ÖKGV", color: "#1a6b4a", bg: "#e8f5ee", agir: true },
];
