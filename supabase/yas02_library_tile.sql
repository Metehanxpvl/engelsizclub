-- 0–2 Yaş Gelişim Rehberi: Daha Fazlası’ndan kaldır, Bilgi Kütüphanesi’ne taşı
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın

-- 1) Daha Fazlası menüsünde gizle (canlı DB tekrar göstermesin)
update public.daha_fazlasi_menu
set
  is_active = false,
  updated_at = now()
where lower(trim(link)) like '%0-2-yas-gelisim-rehberi%'
   or lower(trim(link)) like '%daha-fazlasi/ozel%'
   or (
     (lower(title) like '%0-2%' or lower(title) like '%0–2%')
     and (
       lower(title) like '%gelişim rehberi%'
       or lower(title) like '%gelisim rehberi%'
     )
   );

-- 2) Bilgi Kütüphanesi kutusu (conditions) — yoksa ekle
insert into public.conditions (
  title, image_url, description, catalog_id, icon,
  symptoms, diagnosis, support, faq,
  sort_order, is_active
)
select
  '0-2 Yaş Gelişim Rehberi',
  'assets/images/118547.png',
  '0–24 ay: kaba/ince motor, dil, sosyal ve bilişsel öneriler; dönem dönem ev aktiviteleri ve videolar',
  'yas02',
  '🍼',
  '["0–3 ay tummy time ve yüksek kontrast","3–6 ay dönme ve kavrama","6–9 ay oturma ve cee-e","9–12 ay ayağa kalkma","12–24 ay yürüme ve ilk sözcükler"]'::jsonb,
  'Bu rehber bilgilendirme amaçlıdır; gelişim izlemi çocuk doktoru ile yapılır.',
  '["Çocuk Doktoru","Erken Müdahale","Fizik Tedavi","Dil ve Konuşma"]'::jsonb,
  '[{"q":"Her bebek aynı hızda mı gelişir?","a":"Hayır. Her bebek kendi temposunda ilerler; öneriler baskı değil, evde nazik birer başlangıçtır."}]'::jsonb,
  coalesce((select max(sort_order) from public.conditions), 0) + 10,
  true
where not exists (
  select 1 from public.conditions
  where lower(trim(catalog_id)) = 'yas02'
     or lower(trim(title)) in (
       '0-2 yaş gelişim rehberi',
       '0–2 yaş gelişim rehberi',
       '0–2 yaş bebek ve çocuk gelişim rehberi'
     )
);

notify pgrst, 'reload schema';
