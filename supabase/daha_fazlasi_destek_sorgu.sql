-- Destek Sorgulama (SUT) — Daha Fazlası menü satırı
-- Mağaza: WebView https://www.engelsizclub.com/destek-sorgu.html
-- (gerçek dosya; Flutter /destek-sorgu route'una düşmesin)

update public.daha_fazlasi_menu
set
  title = 'Destek Sorgulama',
  subtitle = 'SUT taban fiyatı, SGK katkısı ve yenileme takvimi',
  link_type = 'url',
  link = 'https://www.engelsizclub.com/destek-sorgu.html',
  icon = 'calculate',
  sort_order = 22,
  is_active = true,
  is_builtin = false,
  updated_at = now()
where lower(trim(title)) in ('destek sorgu', 'destek sorgulama')
   or lower(title) like '%destek sorgu%'
   or lower(link) like '%destek-sorgu%'
   or lower(trim(link)) in ('destek_sorgu', 'desteksorgu', 'sut', 'sut_sorgu');

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Destek Sorgulama',
  'SUT taban fiyatı, SGK katkısı ve yenileme takvimi',
  'url',
  'https://www.engelsizclub.com/destek-sorgu.html',
  'calculate',
  22,
  true,
  false
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(title)) in ('destek sorgu', 'destek sorgulama')
     or lower(title) like '%destek sorgu%'
     or lower(link) like '%destek-sorgu%'
     or lower(trim(link)) in ('destek_sorgu', 'desteksorgu', 'sut', 'sut_sorgu')
);

notify pgrst, 'reload schema';
