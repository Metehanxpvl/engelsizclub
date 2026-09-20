-- Evde eğitim sorgu — Daha Fazlası menü satırı
-- Mağaza: WebView https://www.engelsizclub.com/evde-egitim.html
-- (gerçek dosya; Flutter /evde-egitim route'una düşmesin)

update public.daha_fazlasi_menu
set
  title = 'Evde eğitim sorgu',
  subtitle = 'Şartları adım adım görün — ad ve T.C. sorulmaz',
  link_type = 'url',
  link = 'https://www.engelsizclub.com/evde-egitim.html',
  icon = 'family',
  sort_order = 23,
  is_active = true,
  is_builtin = false,
  updated_at = now()
where lower(trim(title)) in ('evde eğitim', 'evde egitim', 'evde eğitim sorgu', 'evde egitim sorgu')
   or lower(title) like '%evde eğitim%'
   or lower(title) like '%evde egitim%'
   or lower(link) like '%evde-egitim%'
   or lower(trim(link)) in ('evde_egitim', 'evdeegitim', 'home_education');

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Evde eğitim sorgu',
  'Şartları adım adım görün — ad ve T.C. sorulmaz',
  'url',
  'https://www.engelsizclub.com/evde-egitim.html',
  'family',
  23,
  true,
  false
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(title)) in ('evde eğitim', 'evde egitim', 'evde eğitim sorgu', 'evde egitim sorgu')
     or lower(title) like '%evde eğitim%'
     or lower(title) like '%evde egitim%'
     or lower(link) like '%evde-egitim%'
     or lower(trim(link)) in ('evde_egitim', 'evdeegitim', 'home_education')
);

notify pgrst, 'reload schema';
