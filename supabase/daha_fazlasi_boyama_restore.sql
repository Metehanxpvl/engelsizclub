-- Engelsiz Boyama satırını geri ekle (eski DELETE SQL çalıştırıldıysa).
-- Silme YOK. AVM'ye dokunma.
-- Supabase Dashboard → SQL Editor → bu dosyayı yapıştırın
-- (veya: npx supabase db query -f supabase/daha_fazlasi_boyama_restore.sql --linked)

-- 1) Kalan boyama satırı varsa güncelle (link/title eşleşmesi; silme yok).
update public.daha_fazlasi_menu
set
  title = 'Engelsiz Boyama',
  subtitle = 'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  link_type = 'route',
  link = 'boyama',
  icon = '🎨',
  sort_order = 6,
  is_active = true,
  is_builtin = true,
  updated_at = now()
where lower(trim(link)) in (
     'boyama',
     '/boyama',
     'route:boyama'
   )
   or lower(link) like '%boyama.html%'
   or lower(link) like '%/boyama'
   or lower(link) like '%/boyama/%'
   or lower(link) like '%/boyama?%'
   or lower(title) like '%boyama%';

-- 2) id 13 boşsa o kimlikle geri ekle (eski satır).
insert into public.daha_fazlasi_menu
  (id, title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
overriding system value
select
  13,
  'Engelsiz Boyama',
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

-- 3) id 13 dolu ama boyama yoksa yeni satır ekle.
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Engelsiz Boyama',
  'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  'route',
  'boyama',
  '🎨',
  6,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(link)) in ('boyama', '/boyama', 'route:boyama')
     or lower(link) like '%boyama.html%'
     or lower(title) like '%boyama%'
);

select setval(
  pg_get_serial_sequence('public.daha_fazlasi_menu', 'id'),
  (select coalesce(max(id), 1) from public.daha_fazlasi_menu)
);

notify pgrst, 'reload schema';
