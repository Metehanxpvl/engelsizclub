-- Gelişim Etkinlikleri (YouTube + kaynak)
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
  (1, 'Top Yuvarlama', 'Yumuşak topu ileri geri yuvarlayın.', 'Boş koridor yeterlidir.', 'kaba-motor', 'Kaba Motor', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 1, true),
  (2, 'Minder Parkuru', 'Minder/yastıktan kısa engel parkuru.', 'Yumuşak zemin kullanın.', 'kaba-motor', 'Kaba Motor', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 2, true),
  (3, 'Ayı Yürüyüşü', 'Kısa mesafede ayı yürüyüşü.', 'Belini zorlamayın.', 'kaba-motor', 'Kaba Motor', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 3, true),
  (4, 'Zıpla-Dur', 'Müzikle zıpla, dur.', 'Yumuşak zıplama.', 'kaba-motor', 'Kaba Motor', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 4, true),
  (5, 'Tünelden Geç', 'Battaniye tünelinden emekleyin.', 'Gözetimde yapın.', 'kaba-motor', 'Kaba Motor', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 5, true),
  (6, 'Balon Takibi', 'Balonu düşürmeden takip.', 'Aşırı şişirmeyin.', 'kaba-motor', 'Kaba Motor', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 6, true),
  (7, 'Adım Taşları', 'Bantla adım taşları çizin.', 'Kaymaz zemin.', 'kaba-motor', 'Kaba Motor', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 7, true),
  (8, 'Çember İçinde', 'Çemberde gir-çık adımları.', 'Çemberi sabitleyin.', 'kaba-motor', 'Kaba Motor', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 8, true),
  (9, 'İleri Geri Koşu', 'Kısa ileri-geri koşu.', 'Yavaş tempo.', 'kaba-motor', 'Kaba Motor', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 9, true),
  (10, 'Tek Ayak Denge', 'Destekle tek ayak duruş.', 'Duvar desteği.', 'kaba-motor', 'Kaba Motor', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 10, true),
  (11, 'Top At-Tut', 'Yakından yumuşak top at-tut.', 'Yüze atmayın.', 'kaba-motor', 'Kaba Motor', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 11, true),
  (12, 'Hayvan Taklidi', 'Kurbağa/yengeç/fil yürüyüşü.', 'Baskısız oynayın.', 'kaba-motor', 'Kaba Motor', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 12, true),
  (13, 'Otur-Kalk', 'Yastıkta kontrollü otur-kalk.', 'Bel desteği.', 'kaba-motor', 'Kaba Motor', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 13, true),
  (14, 'İp Üstü Yürüme', 'Yere yapışık ip üzerinde yürüme.', 'Yanında olun.', 'kaba-motor', 'Kaba Motor', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 14, true),
  (15, 'Dans Durakları', 'Müzik açık dans, kapalı don.', 'Kısa şarkı.', 'kaba-motor', 'Kaba Motor', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 15, true),
  (16, 'Merdiven Adımı', 'Kontrollü basamak (uygun yaş).', 'Korkuluk kullanın.', 'kaba-motor', 'Kaba Motor', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 16, true),
  (17, 'Arabayı İt', 'Oyuncak arabayı itin.', 'Dar alanda dikkat.', 'kaba-motor', 'Kaba Motor', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 17, true),
  (18, 'Boncuk Dizme', 'Kalın ipe büyük boncuk dizin.', 'Yutma riskine dikkat.', 'ince-motor', 'İnce Motor', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 18, true),
  (19, 'Hamur Sıkma', 'Hamur sıkma/yuvarlama/ezme.', 'Yutturmayın.', 'ince-motor', 'İnce Motor', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 19, true),
  (20, 'Sticker', 'Büyük çıkartma yapıştırma.', 'Planlama destekler.', 'ince-motor', 'İnce Motor', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 20, true),
  (21, 'Maşa Aktar', 'Maşayla pamuk aktarma.', 'Çocuk maşası.', 'ince-motor', 'İnce Motor', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 21, true),
  (22, 'Çizgi Takibi', 'Kalın çizgiyi kalemle izleyin.', 'Kısa oturum.', 'ince-motor', 'İnce Motor', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 22, true),
  (23, 'Kağıt Yırtma', 'Şerit şerit kağıt yırtma.', 'Kolay kağıt.', 'ince-motor', 'İnce Motor', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 23, true),
  (24, 'Kapak Aç-Kapa', 'Kavanoz kapakları.', 'Keskin kenar olmasın.', 'ince-motor', 'İnce Motor', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 24, true),
  (25, 'Mandal Asma', 'Mandal asma pratiği.', 'Parmak gücü.', 'ince-motor', 'İnce Motor', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 25, true),
  (26, 'Makasla Kes', 'Kalın çizgide kesme.', 'Çocuk makası.', 'ince-motor', 'İnce Motor', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 26, true),
  (27, 'Düğme İlkleme', 'Büyük düğme ilikleme.', 'Gevşek düğme.', 'ince-motor', 'İnce Motor', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 27, true),
  (28, 'Pipet Boncuk', 'Pipet parçasına iplik.', 'Kısa parçalar.', 'ince-motor', 'İnce Motor', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 28, true),
  (29, 'Boya Damlatma', 'Pipetle boya damlatma.', 'Önlük takın.', 'ince-motor', 'İnce Motor', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 29, true),
  (30, 'Büyük Puzzle', '4–12 parça puzzle.', 'Yaşa göre.', 'ince-motor', 'İnce Motor', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 30, true),
  (31, 'Kilit Açma', 'Basit kilit/anahtar.', 'Küçük parça dikkat.', 'ince-motor', 'İnce Motor', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 31, true),
  (32, 'Kaşık Aktarma', 'Kaşıkla fasulye aktarma.', 'Dökülmeye hazır.', 'ince-motor', 'İnce Motor', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 32, true),
  (33, 'Parmak Boyası', 'Parmakla daire/çizgi.', 'Yenilebilir boya.', 'ince-motor', 'İnce Motor', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 33, true),
  (34, 'Lego Ayır', 'Renk/boyut ayırma.', 'Küçük parça dikkat.', 'ince-motor', 'İnce Motor', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 34, true),
  (35, 'Resimli Kitap', '"Ne görüyorsun?" ile kitap.', 'Aceele etmeyin.', 'dil', 'Dil ve İletişim', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 35, true),
  (36, 'Günlük Anlatım', 'Rutinleri sesli anlatın.', 'Kısa cümle.', 'dil', 'Dil ve İletişim', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 36, true),
  (37, 'Kukla Konuşması', 'Peluş ile diyalog.', 'Sıra alma.', 'dil', 'Dil ve İletişim', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 37, true),
  (38, 'Ses Avı', 'Evde 5 ses bulun.', 'Sakin ortam.', 'dil', 'Dil ve İletişim', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 38, true),
  (39, 'İsim Kartları', 'Nesne kartı isimleme.', 'Az kart.', 'dil', 'Dil ve İletişim', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 39, true),
  (40, 'Şarkı Tekrarı', 'Kısa şarkı tekrarı.', 'Yavaş tempo.', 'dil', 'Dil ve İletişim', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 40, true),
  (41, 'Ben Gördüm', 'Pencereden gördüklerini söyleyin.', 'Soru-cevap.', 'dil', 'Dil ve İletişim', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 41, true),
  (42, 'Hikaye Zinciri', 'Sırayla cümle ekleyin.', 'Yetişkin model.', 'dil', 'Dil ve İletişim', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 42, true),
  (43, 'Duygu Sözcükleri', 'Mutlu/üzgün/kızgın adlandırın.', 'Ayna kullanın.', 'dil', 'Dil ve İletişim', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 43, true),
  (44, 'Talimat Oyunu', '1–2 adımlı yönerge.', 'Başarıyı kutlayın.', 'dil', 'Dil ve İletişim', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 44, true),
  (45, 'Zıt Kavramlar', 'Büyük-küçük örnekleri.', 'Somut nesne.', 'dil', 'Dil ve İletişim', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 45, true),
  (46, 'Telefon Oyunu', 'Oyuncak telefon diyaloğu.', 'Sıra verin.', 'dil', 'Dil ve İletişim', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 46, true),
  (47, 'Hayvan Sesleri', 'Hayvan sesi taklidi.', 'Baskısız.', 'dil', 'Dil ve İletişim', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 47, true),
  (48, 'Alışveriş Listesi', '3–4 ürün ezberle-topla.', 'Görsel destek.', 'dil', 'Dil ve İletişim', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 48, true),
  (49, 'Ritim Söyle', 'Hece ritmiyle kelime.', 'El çırpın.', 'dil', 'Dil ve İletişim', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 49, true),
  (50, 'Soru Kartı', 'Kim/ne/nerede.', 'Tek soru.', 'dil', 'Dil ve İletişim', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 50, true),
  (51, 'Teşekkür Pratiği', 'Lütfen/teşekkür modeli.', 'Model olun.', 'dil', 'Dil ve İletişim', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 51, true),
  (52, 'Renk Sıralama', '2 renge ayırma.', 'Önce 2 renk.', 'bilissel', 'Bilişsel', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 52, true),
  (53, 'Desen Tekrarı', 'Kırmızı-mavi desen.', 'Görsel ipucu.', 'bilissel', 'Bilişsel', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 53, true),
  (54, 'Hazine Avı', '3 ipucuyla nesne bul.', 'Kolay ipucu.', 'bilissel', 'Bilişsel', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 54, true),
  (55, 'Eşleştir Kart', 'Aynı resmi eşleştir.', 'Az kart.', 'bilissel', 'Bilişsel', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 55, true),
  (56, 'Ölç-Dök', 'Kaplara su dökme.', 'Gözetim.', 'bilissel', 'Bilişsel', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 56, true),
  (57, 'Sayı Sayma', '1–5 sayma.', 'Parmakla gösterin.', 'bilissel', 'Bilişsel', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 57, true),
  (58, 'Ne Eksik?', '3 nesneden biri gizle.', 'Kısa bekleme.', 'bilissel', 'Bilişsel', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 58, true),
  (59, 'Boyut Kulesi', 'Büyükten küçüğe kule.', 'Yeniden deneyin.', 'bilissel', 'Bilişsel', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 59, true),
  (60, 'Zaman Sırası', 'Sabah rutini 3 kart.', 'Foto kullanın.', 'bilissel', 'Bilişsel', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 60, true),
  (61, 'Şekil Avı', 'Daire/kare bul.', '1 şekil.', 'bilissel', 'Bilişsel', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 61, true),
  (62, 'Hafıza Tepsisi', '4 nesneden biri kaldır.', 'İsimleyin.', 'bilissel', 'Bilişsel', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 62, true),
  (63, 'Neden-Sonuç', 'Somut neden-sonuç.', 'Deney yapın.', 'bilissel', 'Bilişsel', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 63, true),
  (64, 'Labirent', 'Kalın labirent izle.', 'Parmakla önce.', 'bilissel', 'Bilişsel', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 64, true),
  (65, 'Kategori Kutusu', 'Yiyecek/oyuncak ayır.', '2 kategori.', 'bilissel', 'Bilişsel', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 65, true),
  (66, 'Harita Oyunu', 'Basit haritada X bul.', 'Ok yönü.', 'bilissel', 'Bilişsel', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 66, true),
  (67, 'Tahmin Et', 'Kutu sallayıp tahmin.', 'İpucu verin.', 'bilissel', 'Bilişsel', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 67, true),
  (68, 'Blok Köprü', 'İki kuleye köprü.', 'Stabil zemin.', 'bilissel', 'Bilişsel', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 68, true),
  (69, 'Duygu Mimikleri', 'Duygu canlandır-tahmin.', 'Ayna.', 'sosyal', 'Sosyal-Duygusal', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 69, true),
  (70, 'Sıra Alma', 'Zamanlayıcıyla sıra.', 'Kısa süre.', 'sosyal', 'Sosyal-Duygusal', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 70, true),
  (71, 'Aile Çizimi', 'Birlikte aile resmi.', 'Herkes eklesin.', 'sosyal', 'Sosyal-Duygusal', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 71, true),
  (72, 'Duygu Kitabı', 'Yüz foto kitabığı.', 'İsim yazın.', 'sosyal', 'Sosyal-Duygusal', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 72, true),
  (73, 'Doktor Oyunu', 'Doktor-hasta rolü.', 'Nazik dokunuş.', 'sosyal', 'Sosyal-Duygusal', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 73, true),
  (74, 'Teşekkür Notu', 'Teşekkür kartı.', 'Çizim yeter.', 'sosyal', 'Sosyal-Duygusal', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 74, true),
  (75, 'Yardım Eli', 'Masayı birlikte topla.', 'Küçük görev.', 'sosyal', 'Sosyal-Duygusal', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 75, true),
  (76, 'Paylaşım', 'İki tabak paylaşımı.', 'Senin-benim dili.', 'sosyal', 'Sosyal-Duygusal', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 76, true),
  (77, 'Selamlaşma', 'Sabah selam rutini.', 'Seçenek sunun.', 'sosyal', 'Sosyal-Duygusal', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 77, true),
  (78, 'Özür Cümlesi', 'Yumuşak özür modeli.', 'Zorlamayın.', 'sosyal', 'Sosyal-Duygusal', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 78, true),
  (79, 'Grup Dansı', 'Aynı hareket tekrarı.', 'Herkes lider.', 'sosyal', 'Sosyal-Duygusal', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 79, true),
  (80, 'Duygu Termometresi', 'Nasıl hissediyorum?', 'Renk skalası.', 'sosyal', 'Sosyal-Duygusal', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 80, true),
  (81, 'Misafir Oyunu', 'Oyuncaklara ikram.', 'Nezaket.', 'sosyal', 'Sosyal-Duygusal', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 81, true),
  (82, 'Alkış Kutlaması', 'Küçük başarı alkışı.', 'Somut övgü.', 'sosyal', 'Sosyal-Duygusal', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 82, true),
  (83, 'Birlikte Nefes', '3 derin nefes.', 'Yavaş sayın.', 'sosyal', 'Sosyal-Duygusal', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 83, true),
  (84, 'Foto Hikaye', 'Eski foto anlatımı.', 'Kısa tutun.', 'sosyal', 'Sosyal-Duygusal', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 84, true),
  (85, 'Empati Oyunu', 'Üzgün arkadaş senaryosu.', 'Seçenek sunun.', 'sosyal', 'Sosyal-Duygusal', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 85, true),
  (86, 'Duyusal Kutu', 'Kutuda saklı nesne.', 'Yutma riski.', 'duyusal', 'Duyusal', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 86, true),
  (87, 'Doku Yürüyüşü', 'Farklı zeminler.', 'Keskin cisim yok.', 'duyusal', 'Duyusal', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 87, true),
  (88, 'Su Oyunu', 'Dökme/süzme.', 'Havlu hazır.', 'duyusal', 'Duyusal', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 88, true),
  (89, 'Koku İstasyonu', 'Kokuları ayırt et.', 'Alerji kontrol.', 'duyusal', 'Duyusal', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 89, true),
  (90, 'Ses Şişeleri', 'Şişe sesi eşleştir.', 'Kapak bantlayın.', 'duyusal', 'Duyusal', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 90, true),
  (91, 'Işık-Karanlık', 'El feneri gölge.', 'Gözü yormayın.', 'duyusal', 'Duyusal', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 91, true),
  (92, 'Sıcak-Soğuk', 'Ilık/soğuk dokunuş.', 'Aşırı sıcak yok.', 'duyusal', 'Duyusal', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 92, true),
  (93, 'Köpük Oyun', 'Sabun köpüğü.', 'Göze kaçmasın.', 'duyusal', 'Duyusal', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 93, true),
  (94, 'Kokulu Hamur', 'Kokulu hamur şekil.', 'Yenmeyen malzeme.', 'duyusal', 'Duyusal', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 94, true),
  (95, 'Fırça Dokunuşu', 'Yumuşak fırça tarama.', 'Tempo çocukta.', 'duyusal', 'Duyusal', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 95, true),
  (96, 'Rüzgar Oyunu', 'Üfleyerek kağıt uçur.', 'Yüze üflemeyin.', 'duyusal', 'Duyusal', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 96, true),
  (97, 'Ağır Yorgan', 'Kısa dinlenme.', 'Nefes rahat.', 'duyusal', 'Duyusal', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 97, true),
  (98, 'Titreşim', 'Kısa titreşim deneyimi.', 'İsteğe bağlı.', 'duyusal', 'Duyusal', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 98, true),
  (99, 'Renkli Su', 'Renk karıştırma.', 'Önlük.', 'duyusal', 'Duyusal', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 99, true),
  (100, 'Kum Tepsisi', 'Kinetik kum izi.', 'Masa koruyucu.', 'duyusal', 'Duyusal', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 100, true),
  (101, 'Müzik Dinle', 'Yavaş müzikle sallanma.', 'Ses düşük.', 'duyusal', 'Duyusal', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 101, true),
  (102, 'Tat Tahmini', 'Güvenli tat tahmini.', 'Alerjen yoksa.', 'duyusal', 'Duyusal', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 102, true),
  (103, 'El Yıkama Şarkısı', '20 sn el yıkama.', 'Köpürtün.', 'ozbakim', 'Öz Bakım', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 103, true),
  (104, 'Diş Fırçalama', 'Aynada birlikte fırçala.', 'Model olun.', 'ozbakim', 'Öz Bakım', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 104, true),
  (105, 'Çorap Giydirme', 'Oturarak çorap.', 'Geniş ağız.', 'ozbakim', 'Öz Bakım', '2-3yas', '2–3 yaş', 'zor', 'Zor', '', '', 105, true),
  (106, 'Düğme Pratik', 'Ceket düğmesi.', 'Büyük düğme.', 'ozbakim', 'Öz Bakım', '3-4yas', '3–4 yaş', 'kolay', 'Kolay', '', '', 106, true),
  (107, 'Ayakkabı', 'Cırtlı ayakkabı pratik.', 'Önce cırt.', 'ozbakim', 'Öz Bakım', '4-6yas', '4–6 yaş', 'orta', 'Orta', '', '', 107, true),
  (108, 'Masa Kurma', 'Tabak-bardak yerleştir.', 'Kırılmaz set.', 'ozbakim', 'Öz Bakım', '0-12ay', '0–12 ay', 'zor', 'Zor', '', '', 108, true),
  (109, 'Oyuncak Topla', 'Kutulara yerleştir.', 'Şarkıyla.', 'ozbakim', 'Öz Bakım', '1-2yas', '1–2 yaş', 'kolay', 'Kolay', '', '', 109, true),
  (110, 'Su Dökme', 'Sürahiden bardak.', 'Az miktar.', 'ozbakim', 'Öz Bakım', '2-3yas', '2–3 yaş', 'orta', 'Orta', '', '', 110, true),
  (111, 'Peçete Katlama', 'Basit katlama.', 'Köşe hizala.', 'ozbakim', 'Öz Bakım', '3-4yas', '3–4 yaş', 'zor', 'Zor', '', '', 111, true),
  (112, 'Saç Taraması', 'Yumuşak tarak.', 'Nazik hareket.', 'ozbakim', 'Öz Bakım', '4-6yas', '4–6 yaş', 'kolay', 'Kolay', '', '', 112, true),
  (113, 'Mont Askı', 'Askıya mont as.', 'Alçak askı.', 'ozbakim', 'Öz Bakım', '0-12ay', '0–12 ay', 'orta', 'Orta', '', '', 113, true),
  (114, 'Meyve Yıkama', 'Meyve yıkama yardımı.', 'Kaymaz basamak.', 'ozbakim', 'Öz Bakım', '1-2yas', '1–2 yaş', 'zor', 'Zor', '', '', 114, true),
  (115, 'Macun Sıkma', 'Bezelye kadar macun.', 'Birlikte ölçün.', 'ozbakim', 'Öz Bakım', '2-3yas', '2–3 yaş', 'kolay', 'Kolay', '', '', 115, true),
  (116, 'Uyku Rutini', 'Pijama-kitap-ışık kartları.', 'Aynı sıra.', 'ozbakim', 'Öz Bakım', '3-4yas', '3–4 yaş', 'orta', 'Orta', '', '', 116, true),
  (117, 'Tuvalet Adımları', 'Görsel adım kartları.', 'Baskısız.', 'ozbakim', 'Öz Bakım', '4-6yas', '4–6 yaş', 'zor', 'Zor', '', '', 117, true),
  (118, 'Çanta Hazırlama', '3 eşya çantaya.', 'Liste kullanın.', 'ozbakim', 'Öz Bakım', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 118, true),
  (119, 'Ayakkabı Çiftleme', 'Çiftleyip rafa koy.', 'Renk ipucu.', 'ozbakim', 'Öz Bakım', '1-2yas', '1–2 yaş', 'orta', 'Orta', '', '', 119, true),
  (120, 'Top Yuvarlama · Ek pratik', 'Yumuşak topu ileri geri yuvarlayın. Bu turda süreyi biraz uzatın.', 'Boş koridor yeterlidir.', 'kaba-motor', 'Kaba Motor', '0-12ay', '0–12 ay', 'kolay', 'Kolay', '', '', 120, true)
) as v(id, title, description, tip, grup, grup_ad, yas, yas_ad, zorluk, zorluk_ad, youtube_url, kaynak, sort_order, is_active)
where not exists (select 1 from public.gelisim_etkinlikleri limit 1);

notify pgrst, 'reload schema';
