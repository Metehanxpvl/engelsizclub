-- Kampanya kategorileri (sağlık, restoran, giyim, eğitim, marka iş birlikleri)
-- Admin yeni kategori ekler: app_categories.scope = 'kampanya'
-- Dart: kKampanyaCategories / addKampanyaCategory / KampanyaItem.category

alter table public.kampanyalar
  add column if not exists category text not null default '';

create index if not exists kampanyalar_category_idx
  on public.kampanyalar (category, is_active, sort_order, created_at desc);

notify pgrst, 'reload schema';
