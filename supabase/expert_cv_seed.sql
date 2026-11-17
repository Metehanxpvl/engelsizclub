-- Idempotent meslek grupları + 3 meslek şablonu.
-- İki kez çalışınca çift kayıt oluşmaz (unique key).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

grant insert, update, delete on table public.meslek_gruplari to authenticated;
grant insert, update, delete on table public.meslek_alan_sablonlari to authenticated;

-- İlanlar > Uzman Ara meslekleri (mevcut kayıtlara dokunmaz) + eksik Bakıcı / Ev Yardımı.
insert into public.meslek_gruplari (grup_key, etiket, ust_grup, sira)
values
  ('fizyoterapist', 'Fizyoterapist', 'Sağlık Uzmanları', 10),
  ('ergoterapist', 'Ergoterapist', 'Sağlık Uzmanları', 20),
  ('dil_konusma_terapisti', 'Dil Konuşma Terapisti', 'Sağlık Uzmanları', 30),
  ('ozel_egitim_ogretmeni', 'Özel Eğitim Öğretmeni', 'Sağlık Uzmanları', 40),
  ('golge_ogretmen', 'Gölge Öğretmen', 'Sağlık Uzmanları', 50),
  ('psikolog', 'Psikolog', 'Sağlık Uzmanları', 60),
  ('bakici', 'Bakıcı', 'Bakım ve Ev Desteği', 100),
  ('ev_yardimi', 'Ev Yardımı', 'Bakım ve Ev Desteği', 110)
on conflict (grup_key) do nothing;

-- Fizyoterapist
insert into public.meslek_alan_sablonlari
  (meslek_grubu_id, alan_key, etiket, tip, secenekler, zorunlu, sira)
select g.id, v.alan_key, v.etiket, v.tip, v.secenekler::jsonb, v.zorunlu, v.sira
from public.meslek_gruplari g
cross join (values
  ('universite', 'Mezun olduğu üniversite', 'text', '[]', false, 10),
  ('mezuniyet_yili', 'Mezuniyet yılı', 'number', '[]', false, 20),
  ('derece', 'Derece', 'select', '["Lisans","Yüksek lisans"]', false, 30),
  ('calistigi_yerler', 'Çalıştığı yerler', 'multi_select', '["Hastane","Klinik","Özel"]', false, 40),
  ('uzmanlik_alanlari', 'Uzmanlık alanları', 'multi_select',
    '["Nörolojik rehabilitasyon","Pediatrik","Ortopedik","Geriatrik","Solunum","Diğer"]', false, 50),
  ('sertifikalar', 'Sertifikalar', 'multi_select',
    '["Bobath","Vojta","Manuel terapi","Kinesiotape","Diğer"]', false, 60),
  ('engel_gruplari', 'Çalıştığı hastalık/engel grupları', 'multi_select',
    '["Serebral palsi","Down sendromu","İnme","Kas hastalıkları","Diğer"]', false, 70),
  ('ev_ziyareti', 'Ev ziyareti yapıyor mu', 'boolean', '[]', false, 80),
  ('ekipman', 'Kendi ekipmanı var mı', 'boolean', '[]', false, 90),
  ('seans_suresi', 'Seans süresi', 'text', '[]', false, 100),
  ('ucret', 'Ücret bilgisi (opsiyonel)', 'text', '[]', false, 110),
  ('ucret_goster', 'Ücreti profilde göster', 'boolean', '[]', false, 120),
  ('diploma', 'Diploma / meslek belgesi', 'file', '[]', false, 130)
) as v(alan_key, etiket, tip, secenekler, zorunlu, sira)
where g.grup_key = 'fizyoterapist'
on conflict (meslek_grubu_id, alan_key) do nothing;

-- Bakıcı
insert into public.meslek_alan_sablonlari
  (meslek_grubu_id, alan_key, etiket, tip, secenekler, zorunlu, sira)
select g.id, v.alan_key, v.etiket, v.tip, v.secenekler::jsonb, v.zorunlu, v.sira
from public.meslek_gruplari g
cross join (values
  ('bakim_turu', 'Bakım türü', 'multi_select',
    '["Yaşlı","Çocuk","Engelli","Yatalak hasta"]', false, 10),
  ('mezun_bolum', 'Mezun olunan bölüm', 'text', '[]', false, 15),
  ('deneyim_aciklama', 'Hangi bireylere baktığı ve deneyim açıklaması', 'textarea', '[]', false, 20),
  ('egitim_sertifika', 'Eğitim / sertifika', 'multi_select',
    '["Hasta ve yaşlı hizmetleri kursu","İlk yardım","Bakım eğitimi"]', false, 30),
  ('yapabildikleri', 'Yapabildikleri', 'multi_select',
    '["Kaldırma/transfer","İlaç hatırlatma","Hijyen bakımı","Yemek hazırlama","Tekerlekli sandalye/yatak desteği","Diğer"]', false, 40),
  ('calisma_duzeni', 'Çalışma düzeni', 'multi_select',
    '["Gündüz","Gece","Yatılı","Saatlik"]', false, 50),
  ('tercih_sigara', 'Sigara (tercih)', 'select', '["Fark etmez","Sigara içilmeyen ev","Sigara içilebilir"]', false, 60),
  ('tercih_evcil', 'Evcil hayvan (tercih)', 'select', '["Fark etmez","Evcil hayvan olmasın","Evcil hayvan olabilir"]', false, 70),
  ('referanslar_onemli', 'Referanslar (önceki aile/işverenler)', 'textarea', '[]', false, 80),
  ('belge', 'Belge (opsiyonel)', 'file', '[]', false, 90)
) as v(alan_key, etiket, tip, secenekler, zorunlu, sira)
where g.grup_key = 'bakici'
on conflict (meslek_grubu_id, alan_key) do nothing;

-- Ev Yardımı
insert into public.meslek_alan_sablonlari
  (meslek_grubu_id, alan_key, etiket, tip, secenekler, zorunlu, sira)
select g.id, v.alan_key, v.etiket, v.tip, v.secenekler::jsonb, v.zorunlu, v.sira
from public.meslek_gruplari g
cross join (values
  ('hizmet_turu', 'Hizmet türü', 'multi_select',
    '["Ev","Ofis","Derin temizlik","Taşınma sonrası"]', false, 10),
  ('musaitlik_gun', 'Gün / saat müsaitliği', 'textarea', '[]', false, 20),
  ('calisma_sikligi', 'Çalışma sıklığı', 'select',
    '["Haftalık","Aylık","Tek seferlik"]', false, 30),
  ('kendi_malzeme', 'Kendi malzemesini getiriyor mu', 'boolean', '[]', false, 40),
  ('calistigi_yer_turleri', 'Çalıştığı yer türleri', 'textarea', '[]', false, 50),
  ('ek_hizmetler', 'Ek hizmetler', 'multi_select',
    '["Ütü","Cam silme","Yemek hazırlığı"]', false, 60),
  ('referanslar_ev', 'Referanslar', 'textarea', '[]', false, 70),
  ('belge', 'Belge (opsiyonel)', 'file', '[]', false, 80)
) as v(alan_key, etiket, tip, secenekler, zorunlu, sira)
where g.grup_key = 'ev_yardimi'
on conflict (meslek_grubu_id, alan_key) do nothing;

update public.meslek_alan_sablonlari
set zorunlu = false
where zorunlu = true;

notify pgrst, 'reload schema';
