-- Evde Eğitim: Daha Fazlası menüsüne HTML bağlantısı.
-- Uygulama mağazası güncellemesi gerekmez; mevcut sürüm URL satırlarını açar.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın.

update public.daha_fazlasi_menu
set
  title = 'Evde Eğitim',
  subtitle = 'Şartları adım adım görün — ad ve T.C. sorulmaz',
  link_type = 'url',
  link = '/evde-egitim',
  icon = 'family',
  sort_order = 23,
  is_active = true,
  is_builtin = false,
  updated_at = now()
where lower(trim(title)) = 'evde eğitim'
   or lower(link) like '%evde-egitim%'
   or lower(trim(link)) in ('evde_egitim', 'evdeegitim', 'home_education');

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Evde Eğitim',
  'Şartları adım adım görün — ad ve T.C. sorulmaz',
  'url',
  '/evde-egitim',
  'family',
  23,
  true,
  false
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(title)) = 'evde eğitim'
     or lower(link) like '%evde-egitim%'
     or lower(trim(link)) in ('evde_egitim', 'evdeegitim', 'home_education')
);

notify pgrst, 'reload schema';
