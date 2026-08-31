-- Kampanyalar: il bazında veya tüm ülkede geçerli
-- Supabase Dashboard → SQL Editor → çalıştırın
-- Additive: mevcut satırlara dokunmaz (city NULL = tüm ülkede geçerli).
--
-- city:
--   NULL, '', 'Türkiye', 'genel'  → tüm ülkede geçerli
--   'Ankara', 'İzmir', …          → o ile özel (kCityNames)
--
-- Dart: gezi_kampanya_store.kampanyalar / KampanyaItem.city

alter table public.kampanyalar
  add column if not exists city text;

create index if not exists kampanyalar_city_idx
  on public.kampanyalar (city, is_active, sort_order, created_at desc);

notify pgrst, 'reload schema';
