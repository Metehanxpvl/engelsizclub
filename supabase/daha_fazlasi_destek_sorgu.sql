-- Destek Sorgu: Daha Fazlası menüsüne HTML bağlantısı.
-- Uygulama mağazası güncellemesi gerekmez; mevcut sürüm URL satırlarını açar.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın.

update public.daha_fazlasi_menu
set
  title = 'Destek Sorgu',
  subtitle = 'SUT taban fiyatı, SGK katkısı ve yenileme takvimi',
  link_type = 'url',
  link = '/destek-sorgu',
  icon = 'calculate',
  sort_order = 22,
  is_active = true,
  is_builtin = false,
  updated_at = now()
where lower(trim(title)) = 'destek sorgu'
   or lower(link) like '%destek-sorgu%'
   or lower(trim(link)) in ('destek_sorgu', 'desteksorgu', 'sut', 'sut_sorgu');

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Destek Sorgu',
  'SUT taban fiyatı, SGK katkısı ve yenileme takvimi',
  'url',
  '/destek-sorgu',
  'calculate',
  22,
  true,
  false
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(title)) = 'destek sorgu'
     or lower(link) like '%destek-sorgu%'
     or lower(trim(link)) in ('destek_sorgu', 'desteksorgu', 'sut', 'sut_sorgu')
);

notify pgrst, 'reload schema';
