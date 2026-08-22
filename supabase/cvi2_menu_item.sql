-- CVI Egzersizleri-2 — Daha Fazlası (0-2 yaş rehberi gibi web linki)
update public.daha_fazlasi_menu
set
  link_type = 'url',
  link = '/bilgi-kutuphanesi/cvi-egzersizleri-2',
  title = 'CVI Egzersizleri-2',
  subtitle = 'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
  icon = 'eye',
  is_active = true,
  updated_at = now()
where lower(trim(link)) in ('cvi2', '/cvi2', 'route:cvi2')
   or lower(title) like '%cvi egzersizleri-2%';

insert into public.daha_fazlasi_menu (
  title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin
)
select
  'CVI Egzersizleri-2',
  'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
  'url',
  '/bilgi-kutuphanesi/cvi-egzersizleri-2',
  'eye',
  55,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where link = '/bilgi-kutuphanesi/cvi-egzersizleri-2'
);
