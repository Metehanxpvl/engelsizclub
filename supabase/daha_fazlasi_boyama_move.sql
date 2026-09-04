-- Engelsiz Boyama: üst Daha Fazlası satırını KORU / aktif tut.
-- DO NOT DELETE id 13 (or any boyama row).
-- Schema'da parent_id yok; Taramalar grubu Flutter'da hardcoded
-- (lib/data/more_menu_data.dart). Boyama artık grup içinde değil —
-- üst listede 🎨 engelsiz Boyama olarak görünür (route: boyama → BoyamaPage).
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- (veya: npx supabase db query -f supabase/daha_fazlasi_boyama_move.sql --linked)

update public.daha_fazlasi_menu
set
  title = 'engelsiz Boyama',
  subtitle = 'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  link_type = 'route',
  link = 'boyama',
  icon = '🎨',
  sort_order = 6,
  is_active = true,
  is_builtin = true,
  updated_at = now()
where id = 13
   or lower(trim(link)) in (
     'boyama',
     '/boyama',
     'route:boyama'
   )
   or lower(link) like '%boyama.html%'
   or lower(link) like '%/boyama'
   or lower(link) like '%/boyama/%'
   or lower(link) like '%/boyama?%'
   or lower(title) like '%boyama%';

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'engelsiz Boyama',
  'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  'route',
  'boyama',
  '🎨',
  6,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where id = 13
     or lower(trim(link)) in ('boyama', '/boyama', 'route:boyama')
     or lower(link) like '%boyama.html%'
     or lower(title) like '%boyama%'
);

notify pgrst, 'reload schema';
