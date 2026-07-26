-- Engelsiz Club — app_rights seed
-- Supabase SQL Editor → New query → Run
-- Table Editor ile tek tek doldurmaya GEREK YOK

truncate table public.app_rights restart identity cascade;

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'evde-bakim',
  'Evde Bakım Maaşı',
  '₺15.775 / ay',
  'maddi',
  '🏠',
  4279921482,
  4293457390,
  50,
  18,
  true,
  'Evde bakıma muhtaç ağır engelli bireylerin yakınlarına Sosyal Hizmetler tarafından ödenen aylık destek. Güncel tutar: ₺15.775. Hane halkı gelir testi yapılır.',
  '["E-Devlet üzerinden ''Evde Bakım Hizmeti'' başvurusu yapın","Sağlık kurulundan %50+ bakıma muhtaç raporu alın","İl Sosyal Hizmetler Müdürlüğü''ne başvurun","Hane halkı gelir testi yapılır"]'::jsonb,
  'e-Devlet · İl Sosyal Hizmetler Müdürlüğü',
  1,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-maas',
  'Engelli Aylığı',
  '₺5.793 – ₺8.690 / ay',
  'maddi',
  '💳',
  4285242052,
  4293850619,
  40,
  99,
  true,
  'SGK veya Sosyal Yardımlaşma Vakfı tarafından ödenen aylık. Gelir testi uygulanır; çalışmayan engelli bireyler için geçerlidir.

',
  '["Sağlık Kurulu Raporu alın (%40+ engel oranı)","SGK veya SYDV''ye başvurun","Gelir testi ve belgeler tamamlanır","Hesaba her ay otomatik yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  2,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-yakini-ayligi',
  '18 Yaş Altı Engelli Yakını Aylığı',
  '₺5.793,30 / ay',
  'maddi',
  '👨‍👧',
  4278751666,
  4293721855,
  40,
  18,
  true,
  '18 yaşından küçük engelli yakını olan bakmakla yükümlü kişilere ödenen aylık. Güncel tutar: ₺5.793,30. Gelir testi uygulanır.',
  '["Çocuğun Sağlık Kurulu Raporunu alın (%40+)","SGK veya Sosyal Yardımlaşma Vakfı''na başvurun","Veli / vasi belgesi ve gelir belgelerini ibraz edin","Onay sonrası aylık hesaba yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  3,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yardimci-arac',
  'Yardımcı Araç-Gereç Desteği',
  'SGK karşılar',
  'maddi',
  '♿',
  4284196994,
  4293193961,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez, protez, işitme cihazı ve benzeri yardımcı araçlar SGK tarafından karşılanmaktadır.',
  '["Hekim raporu ve SGK sevki alın","SGK sözleşmeli firma veya ortez merkezine gidin","Katkı payı varsa ödenir; ücretsiz seçenekler mevcuttur"]'::jsonb,
  'SGK · Sözleşmeli medikal firmalar',
  4,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'nobet-bakim-izin',
  'Nöbet Muafiyeti & Günlük Eğitim/Bakım İzni',
  'Nöbet muafiyeti · Haftalık 8 saat eğitim',
  'izin',
  '🏢',
  4279203438,
  4293326837,
  70,
  99,
  false,
  'ENGELLİ ÇOCUĞU/YAKINI OLAN ÇALIŞANLARIN HAKLARI

',
  '["Geçerli engelli sağlık kurulu raporunu hazırlayın (ağır engelli / ÇÖZGER çok ileri–ÖKGV / tam bağımlı)","Kurumunuzun insan kaynakları / izin birimine yazılı başvuru yapın","Nöbet / gece vardiyası muafiyeti ve günlük bakım kolaylığı talep edin","Özel eğitim alınıyorsa haftalık 8 saat eğitim iznini ayrıca belirtin","TSK / EGM / hastane personeliyseniz kurumunuzun iç genelgesini ekleyin"]'::jsonb,
  'Kurum İK · Başbakanlık Genelgesi 2010/2 · EGM 2015/55 · TSK İzin Yönetmeliği',
  5,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mazeret-izin',
  'Mazeret İzni Hakkı (%70+ / Süreğen Hastalık)',
  'Yılda 10 güne kadar ücretli',
  'izin',
  '📋',
  4280640491,
  4293916415,
  70,
  18,
  false,
  'En az yüzde %70 oranında engelli ya da süreğen hastalığı olan çocukları için tüm çalışanlara; ',
  '["Çocuğun %70+ engelli veya süreğen hastalık belgesini hazırlayın","Hastalık durumunda doktor / hekim raporu alın","Kurumunuza yazılı mazeret izni talebi verin (ana veya babadan yalnızca biri)","Yıllık izin bitmiş olsa da talep edilebilir; 10 günü parçalı kullanabilirsiniz","İşçi / sözleşmeli / muvazzaf personel aynı hakkı kullanır"]'::jsonb,
  'Kurum İK · DMK md. 104 · İş Kanunu',
  6,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yari-zamanli-anne',
  'Engelli Bebekte Yarı Zamanlı Çalışma Hakkı',
  '12. aya kadar tam maaşlı yarı zamanlı',
  'izin',
  '👶',
  4292552567,
  4294832888,
  40,
  6,
  false,
  'Engelli çocuğu olan annelere yarı zamanlı çalışma hakkı

',
  '["Doğumda veya ilk 12 ay içinde engellilik tespitini belgeleyen sağlık raporunu alın","Kurum İK birimine yazılı yarı zamanlı çalışma talebi verin","Bebek 12 ayını doldurana kadar tam maaşlı yarı zamanlı çalışma uygulanır","Memur (DMK) ve işçi (İş Kanunu) anneler bu haktan yararlanır"]'::jsonb,
  'Kurum İK · Devlet Memurları Kanunu · İş Kanunu',
  7,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'otv-muafiyet',
  'ÖTV Muafiyetli Araç Alımı',
  '2026 fiyat sınırı: ₺2.873.900',
  'vergi',
  '🚗',
  4292901471,
  4294832364,
  40,
  99,
  false,
  '4 farklı grup engelli bireye ÖTV istisnası tanınmaktadır. 10 yılda bir hak kullanılabilir; araç beş yıl geçmeden ÖTV ödenmeksizin satılamaz.

',
  '["Sağlık Kurulu Raporu alın (hangi gruba girdiğinizi öğrenin)","Vergi Dairesi''ne başvurarak ÖTV istisna belgesi düzenletin","Grup 4 iseniz: geçerli B sınıfı engelli sürücü belgesi şarttır","87.03 kapsamında araçta fiyat ₺2.873.900''ı (2026) aşmamalıdır","Yetkili bayi ile sözleşme yapılır; araç engelli adına tescil edilir","5 yıl sonra ÖTV ödenmeksizin satış hakkı doğar"]'::jsonb,
  'Vergi Dairesi · Trafik Tescil · Araç Yetkili Bayii',
  8,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mtv-muafiyet',
  'MTV Muafiyeti (Araç Vergisi)',
  'Tam muafiyet veya kısmi',
  'vergi',
  '📃',
  4286331629,
  4294308095,
  40,
  99,
  false,
  '%90 ve üzeri engellilik: Kendi adına kayıtlı araçta özel tertibat şartı aranmaksızın MTV''den tam muafiyet. Tam teşekküllü devlet hastanesi sağlık kurulu raporu vergi dairesine ibraz edilir.

',
  '["%90+ ise: devlet hastanesi sağlık kurulu raporu hazırlayın","Araç tescil belgesi, engelli kimlik kartı ve raporu vergi dairesine götürün","%90 altı ise ayrıca: araç teknik belgesi, özel tertibat proje raporu ve MTV istisnası bildirim formu gerekir","Vergi dairesi muafiyet işlemini tescil eder; yıllık otomatik uygulanır"]'::jsonb,
  'Bağlı olunan Vergi Dairesi',
  9,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'park-karti',
  'Engelli Park Kartı (Mavi İşaret)',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı yalnızca üzerine araç tescil edilmiş engellilere verilir. Kullanım için Trafik Denetleme Amirliğine başvuru gerekir.

',
  '["Engelli sağlık kurulu raporu ve araç tescil belgesiyle başvurun","Trafik Denetleme Şube Amirliği veya İlçe Emniyet Müdürlüğü''ne gidin","Park kartı (mavi işaret) ücretsiz teslim edilir","Kartı araç ön camına asın; her park değişiminde görünür yerde bulundurulmalıdır"]'::jsonb,
  'Trafik Denetleme Şube/Bürü Amirliği · İlçe Emniyet Müdürlüğü',
  10,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-ehliyet',
  'Engelli Sürücü Belgesi (B Sınıfı)',
  'Ücretsiz / Normal ücret',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  '1 Ocak 2016''dan önce alınan H sınıfı engelli sürücü belgeleri 31/07/2025''e kadar geçerliydi. Bu tarihten sonra B sınıfı sürücü belgesi (engellilik kodları işlenmiş) geçerlidir.

',
  '["18 yaşını doldurun","Aile hekimine başvurarak İl Sağlık Komisyonu''na sevk alın","Komisyon raporuyla sürücü kursu ve sınavına katılın","Engellilik durumuna uygun özel tertibat kodları B sınıfı belgeye işlenir"]'::jsonb,
  'Aile Hekimi → İl Sağlık Komisyonu → Sürücü Kursu → Trafik Tescil',
  11,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kdv-indirim',
  'KDV İndirimi – Medikal & Araç',
  '%18''den %1''e',
  'vergi',
  '🛒',
  4294223922,
  4294965485,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez/protez ve engelliye özel araç tadilat hizmetlerinde KDV %1 uygulanır.',
  '["Sağlık raporu ve engel kimliği ile medikal firmaya gidin","Faturada ''engelli bireye satış'' ibaresi istenir","Araç tadilat için ÖTV muafiyet belgesi gerekir"]'::jsonb,
  'SGK sözleşmeli medikal firmalar · Yetkili servisler',
  12,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'gelir-vergisi',
  'Gelir Vergisi İndirimi',
  '₺3.000–₺6.000 / yıl',
  'vergi',
  '📊',
  4288441779,
  4294307579,
  40,
  99,
  false,
  'Engelli çalışanlara ve engelli çocuğu olan çalışan ebeveynlere yıllık gelir vergisi matrahından indirim hakkı tanınır.',
  '["İşverenin insan kaynakları birimine engel raporunu ibraz edin","Vergi dairesine de bildirim yapılması önerilir","Özel eğitim ve sağlık harcamaları da indirim kapsamına girebilir"]'::jsonb,
  'Vergi Dairesi · İşveren İK',
  13,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ozel-egitim',
  'Ücretsiz Özel Eğitim',
  'Haftada 8 saat',
  'egitim',
  '📚',
  4288441779,
  4294307579,
  0,
  18,
  false,
  'MEB''e bağlı özel eğitim ve rehabilitasyon merkezlerinde haftada 8 saate kadar ücretsiz hizmet. RAM raporu zorunludur.',
  '["RAM''a başvurun (randevu alın)","RAM raporu ve Özel Eğitim Değerlendirme Kurulu kararı alın","MEB sözleşmeli rehabilitasyon merkezini seçin","Her yıl yenileme gerekir"]'::jsonb,
  'RAM (Rehberlik ve Araştırma Merkezi)',
  14,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ram-raporu',
  'RAM Raporu Nasıl Alınır?',
  'Ücretsiz',
  'egitim',
  '📋',
  4284196994,
  4293193961,
  0,
  18,
  false,
  'Özel eğitim hizmetlerinden yararlanmak için zorunlu değerlendirme raporu. Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır.',
  '["İlçenizdeki RAM''a randevu alın","Doktor raporu, okul belgesi, kimlik fotokopisiyle gidin","Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır","Rapor genellikle 1-3 hafta içinde hazırlanır"]'::jsonb,
  'Rehberlik ve Araştırma Merkezi (RAM)',
  15,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kaynaştirma',
  'Kaynaştırma Eğitimi Hakkı',
  'Anayasal hak',
  'egitim',
  '🏫',
  4279921482,
  4293457390,
  0,
  18,
  false,
  'Engelli çocuklar, akranlarıyla birlikte eğitim alma hakkına sahiptir. Okul, destek eğitim odası ve özel kaynaştırma programı oluşturmak zorundadır.',
  '["RAM raporuyla okul müdürlüğüne başvurun","Destek eğitim odası saatleri planlanır","BEP (Bireyselleştirilmiş Eğitim Planı) hazırlanır","İlköğretimden liseye kadar sürer"]'::jsonb,
  'İlçe Milli Eğitim Müdürlüğü · Okul Müdürlüğü',
  16,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-kimlik',
  'Engelli Kimlik Kartı',
  'Ücretsiz',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  'Pek çok ayrıcalık ve indirimlere kapı açan resmi kimlik kartı. Nüfus müdürlüğünden veya e-Devlet üzerinden alınır.',
  '["Sağlık Kurulu Raporu (%40+ engel oranı)","Nüfus Müdürlüğü''ne başvurun veya e-Devlet kullanın","Fotoğraf ve kimlik fotokopisi","1-2 hafta içinde kart teslim edilir"]'::jsonb,
  'İlçe Nüfus Müdürlüğü · e-Devlet',
  17,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ulasim',
  'Ücretsiz Toplu Taşıma',
  'Belediye kartı',
  'ulasim',
  '🚌',
  4285242052,
  4293850619,
  40,
  99,
  false,
  'Engelli kimlik kartı ile metro, otobüs, tramvayda ücretsiz veya indirimli seyahat. Refakatçi de bazı illerde indirimden yararlanır.',
  '["Engelli kimlik kartı ile belediye ulaşım müdürlüğüne başvurun","İstanbul: İETT, Ankara: EGO, İzmir: ESHOT","Ücretsiz akıllı kart verilir","Bir refakatçi de indirimden yararlanır (bazı illerde)"]'::jsonb,
  'Belediye Ulaşım Müdürlükleri',
  18,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'tcdd-thy',
  'TCDD & THY İndirimleri',
  '%50 indirim',
  'ulasim',
  '✈️',
  4292901471,
  4294832364,
  40,
  99,
  false,
  'Tren yolculuklarında %50, Türk Hava Yolları''nda engelli indirim tarifesi. Refakatçi de indirimden yararlanabilir.',
  '["TCDD: bilet alırken engelli kimliği ibraz edin","THY: thy.com''da ''Özel Yolcular'' bölümünden bilet alın","Refakatçi de indirimden yararlanabilir"]'::jsonb,
  'TCDD Bilet Gişeleri · thy.com',
  19,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'sehir-ici-park',
  'Engelli Park Kartı',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı ile engellilere ayrılmış park alanlarını kullanma hakkı tanınır. Ayrıca mavi hatlarda ücretsiz park imkânı mevcuttur.',
  '["Engelli sağlık kurulu raporu ile Belediye Trafik Müdürlüğü''ne başvurun","Engelli park kartı (maviişaret) temin edilir","Araç ön camına asılır"]'::jsonb,
  'Belediye Trafik Müdürlüğü · Emniyet Trafik Birimleri',
  20,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'emlak-vergisi',
  'Emlak Vergisi Muafiyeti',
  '200 m²''ye kadar',
  'vergi',
  '🏡',
  4288441779,
  4294307579,
  0,
  99,
  true,
  'Tek meskeni olan ve belirli gelir sınırının altındaki engelli bireyler emlak vergisinden muaf tutulur. Yıllık gelir kontrolü yapılır.',
  '["Tek meskene sahip olunması gerekir","Yıllık brüt gelir sınırı kontrol edilmeli","Engel raporu ve beyanname ile başvurun"]'::jsonb,
  'İlçe Belediyesi Gelir Müdürlüğü',
  21,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'su-faturasi',
  'Su Faturası İndirimi',
  '%50 indirim',
  'vergi',
  '💧',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli bireyin yaşadığı hanede su ve kanalizasyon faturasında %50''ye kadar indirim. İl ve belediyeye göre kota farklılık gösterebilir.',
  '["Engelli sağlık kurulu raporu ve engelli kimlik kartıyla başvurun","İkametgâh belgesi ve su abonelik sözleşmesi gerekir","İSKİ / ASKİ / İZSU gibi kuruma başvurun","Onaylı indirim bir sonraki faturadan itibaren yansıtılır"]'::jsonb,
  'Belediye Su ve Kanalizasyon İdaresi (İSKİ / ASKİ / İZSU)',
  22,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'telefon-indirimi',
  'Telefon & İnternet İndirimi',
  '%25–50 indirim',
  'vergi',
  '📱',
  4279286145,
  4293721589,
  40,
  99,
  false,
  'Engelli abonelere BTK kapsamında internet ve telefon faturalarında indirim uygulanmaktadır. Operatörden talep edilmesi gerekir.',
  '["Engelli kimlik kartı ile GSM operatörüne başvurun","Engel raporu ibraz edin","Engelli tarifesine geçiş yapılır"]'::jsonb,
  'GSM Operatör Müşteri Hizmetleri · BTK',
  23,
  true
);

update public.app_catalog_versions set version = version + 1, updated_at = now() where name = 'rights';
notify pgrst, 'reload schema';