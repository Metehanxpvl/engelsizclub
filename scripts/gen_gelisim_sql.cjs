const fs = require('fs');
const path = require('path');

const GROUPS = [
  ['kaba-motor', 'Kaba Motor'],
  ['ince-motor', 'İnce Motor'],
  ['dil', 'Dil ve İletişim'],
  ['bilissel', 'Bilişsel'],
  ['sosyal', 'Sosyal-Duygusal'],
  ['duyusal', 'Duyusal'],
  ['ozbakim', 'Öz Bakım'],
];
const AGES = [
  ['0-12ay', '0–12 ay'],
  ['1-2yas', '1–2 yaş'],
  ['2-3yas', '2–3 yaş'],
  ['3-4yas', '3–4 yaş'],
  ['4-6yas', '4–6 yaş'],
];
const LEVELS = [
  ['kolay', 'Kolay'],
  ['orta', 'Orta'],
  ['zor', 'Zor'],
];

const IDEAS = {
  'kaba-motor': [
    ['Top Yuvarlama', 'Yumuşak topu ileri geri yuvarlayın.', 'Boş koridor yeterlidir.'],
    ['Minder Parkuru', 'Minder/yastıktan kısa engel parkuru.', 'Yumuşak zemin kullanın.'],
    ['Ayı Yürüyüşü', 'Kısa mesafede ayı yürüyüşü.', 'Belini zorlamayın.'],
    ['Zıpla-Dur', 'Müzikle zıpla, dur.', 'Yumuşak zıplama.'],
    ['Tünelden Geç', 'Battaniye tünelinden emekleyin.', 'Gözetimde yapın.'],
    ['Balon Takibi', 'Balonu düşürmeden takip.', 'Aşırı şişirmeyin.'],
    ['Adım Taşları', 'Bantla adım taşları çizin.', 'Kaymaz zemin.'],
    ['Çember İçinde', 'Çemberde gir-çık adımları.', 'Çemberi sabitleyin.'],
    ['İleri Geri Koşu', 'Kısa ileri-geri koşu.', 'Yavaş tempo.'],
    ['Tek Ayak Denge', 'Destekle tek ayak duruş.', 'Duvar desteği.'],
    ['Top At-Tut', 'Yakından yumuşak top at-tut.', 'Yüze atmayın.'],
    ['Hayvan Taklidi', 'Kurbağa/yengeç/fil yürüyüşü.', 'Baskısız oynayın.'],
    ['Otur-Kalk', 'Yastıkta kontrollü otur-kalk.', 'Bel desteği.'],
    ['İp Üstü Yürüme', 'Yere yapışık ip üzerinde yürüme.', 'Yanında olun.'],
    ['Dans Durakları', 'Müzik açık dans, kapalı don.', 'Kısa şarkı.'],
    ['Merdiven Adımı', 'Kontrollü basamak (uygun yaş).', 'Korkuluk kullanın.'],
    ['Arabayı İt', 'Oyuncak arabayı itin.', 'Dar alanda dikkat.'],
  ],
  'ince-motor': [
    ['Boncuk Dizme', 'Kalın ipe büyük boncuk dizin.', 'Yutma riskine dikkat.'],
    ['Hamur Sıkma', 'Hamur sıkma/yuvarlama/ezme.', 'Yutturmayın.'],
    ['Sticker', 'Büyük çıkartma yapıştırma.', 'Planlama destekler.'],
    ['Maşa Aktar', 'Maşayla pamuk aktarma.', 'Çocuk maşası.'],
    ['Çizgi Takibi', 'Kalın çizgiyi kalemle izleyin.', 'Kısa oturum.'],
    ['Kağıt Yırtma', 'Şerit şerit kağıt yırtma.', 'Kolay kağıt.'],
    ['Kapak Aç-Kapa', 'Kavanoz kapakları.', 'Keskin kenar olmasın.'],
    ['Mandal Asma', 'Mandal asma pratiği.', 'Parmak gücü.'],
    ['Makasla Kes', 'Kalın çizgide kesme.', 'Çocuk makası.'],
    ['Düğme İlkleme', 'Büyük düğme ilikleme.', 'Gevşek düğme.'],
    ['Pipet Boncuk', 'Pipet parçasına iplik.', 'Kısa parçalar.'],
    ['Boya Damlatma', 'Pipetle boya damlatma.', 'Önlük takın.'],
    ['Büyük Puzzle', '4–12 parça puzzle.', 'Yaşa göre.'],
    ['Kilit Açma', 'Basit kilit/anahtar.', 'Küçük parça dikkat.'],
    ['Kaşık Aktarma', 'Kaşıkla fasulye aktarma.', 'Dökülmeye hazır.'],
    ['Parmak Boyası', 'Parmakla daire/çizgi.', 'Yenilebilir boya.'],
    ['Lego Ayır', 'Renk/boyut ayırma.', 'Küçük parça dikkat.'],
  ],
  dil: [
    ['Resimli Kitap', '"Ne görüyorsun?" ile kitap.', 'Aceele etmeyin.'],
    ['Günlük Anlatım', 'Rutinleri sesli anlatın.', 'Kısa cümle.'],
    ['Kukla Konuşması', 'Peluş ile diyalog.', 'Sıra alma.'],
    ['Ses Avı', 'Evde 5 ses bulun.', 'Sakin ortam.'],
    ['İsim Kartları', 'Nesne kartı isimleme.', 'Az kart.'],
    ['Şarkı Tekrarı', 'Kısa şarkı tekrarı.', 'Yavaş tempo.'],
    ['Ben Gördüm', 'Pencereden gördüklerini söyleyin.', 'Soru-cevap.'],
    ['Hikaye Zinciri', 'Sırayla cümle ekleyin.', 'Yetişkin model.'],
    ['Duygu Sözcükleri', 'Mutlu/üzgün/kızgın adlandırın.', 'Ayna kullanın.'],
    ['Talimat Oyunu', '1–2 adımlı yönerge.', 'Başarıyı kutlayın.'],
    ['Zıt Kavramlar', 'Büyük-küçük örnekleri.', 'Somut nesne.'],
    ['Telefon Oyunu', 'Oyuncak telefon diyaloğu.', 'Sıra verin.'],
    ['Hayvan Sesleri', 'Hayvan sesi taklidi.', 'Baskısız.'],
    ['Alışveriş Listesi', '3–4 ürün ezberle-topla.', 'Görsel destek.'],
    ['Ritim Söyle', 'Hece ritmiyle kelime.', 'El çırpın.'],
    ['Soru Kartı', 'Kim/ne/nerede.', 'Tek soru.'],
    ['Teşekkür Pratiği', 'Lütfen/teşekkür modeli.', 'Model olun.'],
  ],
  bilissel: [
    ['Renk Sıralama', '2 renge ayırma.', 'Önce 2 renk.'],
    ['Desen Tekrarı', 'Kırmızı-mavi desen.', 'Görsel ipucu.'],
    ['Hazine Avı', '3 ipucuyla nesne bul.', 'Kolay ipucu.'],
    ['Eşleştir Kart', 'Aynı resmi eşleştir.', 'Az kart.'],
    ['Ölç-Dök', 'Kaplara su dökme.', 'Gözetim.'],
    ['Sayı Sayma', '1–5 sayma.', 'Parmakla gösterin.'],
    ['Ne Eksik?', '3 nesneden biri gizle.', 'Kısa bekleme.'],
    ['Boyut Kulesi', 'Büyükten küçüğe kule.', 'Yeniden deneyin.'],
    ['Zaman Sırası', 'Sabah rutini 3 kart.', 'Foto kullanın.'],
    ['Şekil Avı', 'Daire/kare bul.', '1 şekil.'],
    ['Hafıza Tepsisi', '4 nesneden biri kaldır.', 'İsimleyin.'],
    ['Neden-Sonuç', 'Somut neden-sonuç.', 'Deney yapın.'],
    ['Labirent', 'Kalın labirent izle.', 'Parmakla önce.'],
    ['Kategori Kutusu', 'Yiyecek/oyuncak ayır.', '2 kategori.'],
    ['Harita Oyunu', 'Basit haritada X bul.', 'Ok yönü.'],
    ['Tahmin Et', 'Kutu sallayıp tahmin.', 'İpucu verin.'],
    ['Blok Köprü', 'İki kuleye köprü.', 'Stabil zemin.'],
  ],
  sosyal: [
    ['Duygu Mimikleri', 'Duygu canlandır-tahmin.', 'Ayna.'],
    ['Sıra Alma', 'Zamanlayıcıyla sıra.', 'Kısa süre.'],
    ['Aile Çizimi', 'Birlikte aile resmi.', 'Herkes eklesin.'],
    ['Duygu Kitabı', 'Yüz foto kitabığı.', 'İsim yazın.'],
    ['Doktor Oyunu', 'Doktor-hasta rolü.', 'Nazik dokunuş.'],
    ['Teşekkür Notu', 'Teşekkür kartı.', 'Çizim yeter.'],
    ['Yardım Eli', 'Masayı birlikte topla.', 'Küçük görev.'],
    ['Paylaşım', 'İki tabak paylaşımı.', 'Senin-benim dili.'],
    ['Selamlaşma', 'Sabah selam rutini.', 'Seçenek sunun.'],
    ['Özür Cümlesi', 'Yumuşak özür modeli.', 'Zorlamayın.'],
    ['Grup Dansı', 'Aynı hareket tekrarı.', 'Herkes lider.'],
    ['Duygu Termometresi', 'Nasıl hissediyorum?', 'Renk skalası.'],
    ['Misafir Oyunu', 'Oyuncaklara ikram.', 'Nezaket.'],
    ['Alkış Kutlaması', 'Küçük başarı alkışı.', 'Somut övgü.'],
    ['Birlikte Nefes', '3 derin nefes.', 'Yavaş sayın.'],
    ['Foto Hikaye', 'Eski foto anlatımı.', 'Kısa tutun.'],
    ['Empati Oyunu', 'Üzgün arkadaş senaryosu.', 'Seçenek sunun.'],
  ],
  duyusal: [
    ['Duyusal Kutu', 'Kutuda saklı nesne.', 'Yutma riski.'],
    ['Doku Yürüyüşü', 'Farklı zeminler.', 'Keskin cisim yok.'],
    ['Su Oyunu', 'Dökme/süzme.', 'Havlu hazır.'],
    ['Koku İstasyonu', 'Kokuları ayırt et.', 'Alerji kontrol.'],
    ['Ses Şişeleri', 'Şişe sesi eşleştir.', 'Kapak bantlayın.'],
    ['Işık-Karanlık', 'El feneri gölge.', 'Gözü yormayın.'],
    ['Sıcak-Soğuk', 'Ilık/soğuk dokunuş.', 'Aşırı sıcak yok.'],
    ['Köpük Oyun', 'Sabun köpüğü.', 'Göze kaçmasın.'],
    ['Kokulu Hamur', 'Kokulu hamur şekil.', 'Yenmeyen malzeme.'],
    ['Fırça Dokunuşu', 'Yumuşak fırça tarama.', 'Tempo çocukta.'],
    ['Rüzgar Oyunu', 'Üfleyerek kağıt uçur.', 'Yüze üflemeyin.'],
    ['Ağır Yorgan', 'Kısa dinlenme.', 'Nefes rahat.'],
    ['Titreşim', 'Kısa titreşim deneyimi.', 'İsteğe bağlı.'],
    ['Renkli Su', 'Renk karıştırma.', 'Önlük.'],
    ['Kum Tepsisi', 'Kinetik kum izi.', 'Masa koruyucu.'],
    ['Müzik Dinle', 'Yavaş müzikle sallanma.', 'Ses düşük.'],
    ['Tat Tahmini', 'Güvenli tat tahmini.', 'Alerjen yoksa.'],
  ],
  ozbakim: [
    ['El Yıkama Şarkısı', '20 sn el yıkama.', 'Köpürtün.'],
    ['Diş Fırçalama', 'Aynada birlikte fırçala.', 'Model olun.'],
    ['Çorap Giydirme', 'Oturarak çorap.', 'Geniş ağız.'],
    ['Düğme Pratik', 'Ceket düğmesi.', 'Büyük düğme.'],
    ['Ayakkabı', 'Cırtlı ayakkabı pratik.', 'Önce cırt.'],
    ['Masa Kurma', 'Tabak-bardak yerleştir.', 'Kırılmaz set.'],
    ['Oyuncak Topla', 'Kutulara yerleştir.', 'Şarkıyla.'],
    ['Su Dökme', 'Sürahiden bardak.', 'Az miktar.'],
    ['Peçete Katlama', 'Basit katlama.', 'Köşe hizala.'],
    ['Saç Taraması', 'Yumuşak tarak.', 'Nazik hareket.'],
    ['Mont Askı', 'Askıya mont as.', 'Alçak askı.'],
    ['Meyve Yıkama', 'Meyve yıkama yardımı.', 'Kaymaz basamak.'],
    ['Macun Sıkma', 'Bezelye kadar macun.', 'Birlikte ölçün.'],
    ['Uyku Rutini', 'Pijama-kitap-ışık kartları.', 'Aynı sıra.'],
    ['Tuvalet Adımları', 'Görsel adım kartları.', 'Baskısız.'],
    ['Çanta Hazırlama', '3 eşya çantaya.', 'Liste kullanın.'],
    ['Ayakkabı Çiftleme', 'Çiftleyip rafa koy.', 'Renk ipucu.'],
  ],
};

function esc(s) {
  return String(s).replace(/'/g, "''");
}

const list = [];
for (const [gkey, gname] of GROUPS) {
  IDEAS[gkey].forEach((row, idx) => {
    const age = AGES[idx % AGES.length];
    const lvl = LEVELS[idx % LEVELS.length];
    list.push({
      title: row[0],
      description: row[1],
      tip: row[2],
      grup: gkey,
      grup_ad: gname,
      yas: age[0],
      yas_ad: age[1],
      zorluk: lvl[0],
      zorluk_ad: lvl[1],
      youtube_url: '',
      kaynak: '',
      sort_order: list.length + 1,
    });
  });
}
while (list.length < 120) {
  const b = list[list.length % 119];
  list.push({
    ...b,
    title: `${b.title} · Ek pratik`,
    description: `${b.description} Bu turda süreyi biraz uzatın.`,
    sort_order: list.length + 1,
  });
}
list.splice(120);
list.forEach((a, i) => {
  a.sort_order = i + 1;
});

const values = list
  .map(
    (a, i) =>
      `  (${i + 1}, '${esc(a.title)}', '${esc(a.description)}', '${esc(a.tip)}', '${esc(a.grup)}', '${esc(a.grup_ad)}', '${esc(a.yas)}', '${esc(a.yas_ad)}', '${esc(a.zorluk)}', '${esc(a.zorluk_ad)}', '', '', ${a.sort_order}, true)`,
  )
  .join(',\n');

const sql = `-- Gelişim Etkinlikleri (YouTube + kaynak)
-- Supabase SQL Editor'de çalıştırın

create table if not exists public.gelisim_etkinlikleri (
  id bigint primary key,
  title text not null,
  description text not null default '',
  tip text not null default '',
  grup text not null,
  grup_ad text not null,
  yas text not null,
  yas_ad text not null,
  zorluk text not null,
  zorluk_ad text not null,
  youtube_url text not null default '',
  kaynak text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists gelisim_etkinlikleri_sort_idx
  on public.gelisim_etkinlikleri (sort_order asc, id asc);

alter table public.gelisim_etkinlikleri enable row level security;

drop policy if exists "gelisim_select_anon" on public.gelisim_etkinlikleri;
create policy "gelisim_select_anon"
  on public.gelisim_etkinlikleri for select
  to anon
  using (is_active = true);

drop policy if exists "gelisim_select_auth" on public.gelisim_etkinlikleri;
create policy "gelisim_select_auth"
  on public.gelisim_etkinlikleri for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gelisim_insert_admin" on public.gelisim_etkinlikleri;
create policy "gelisim_insert_admin"
  on public.gelisim_etkinlikleri for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gelisim_update_admin" on public.gelisim_etkinlikleri;
create policy "gelisim_update_admin"
  on public.gelisim_etkinlikleri for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gelisim_delete_admin" on public.gelisim_etkinlikleri;
create policy "gelisim_delete_admin"
  on public.gelisim_etkinlikleri for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Seed (yalnız tablo boşsa)
insert into public.gelisim_etkinlikleri
  (id, title, description, tip, grup, grup_ad, yas, yas_ad, zorluk, zorluk_ad, youtube_url, kaynak, sort_order, is_active)
select * from (values
${values}
) as v(id, title, description, tip, grup, grup_ad, yas, yas_ad, zorluk, zorluk_ad, youtube_url, kaynak, sort_order, is_active)
where not exists (select 1 from public.gelisim_etkinlikleri limit 1);

notify pgrst, 'reload schema';
`;

fs.writeFileSync(
  path.join('c:/engelsizclub/supabase/gelisim_etkinlikleri.sql'),
  sql,
  'utf8',
);
console.log('wrote SQL', list.length);
