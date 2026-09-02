-- Taramalar & Egzersizler & Oyun — Daha Fazlası grubu
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- (daha_fazlasi_menu tablosu yoksa önce daha_fazlasi_menu.sql)

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Taramalar & Egzersizler & Oyun',
  'Puzzle, CVI egzersizleri ve otizm tarama',
  'route',
  'taramalar',
  'apps',
  5,
  true,
  true
where exists (
  select 1 from information_schema.tables
  where table_schema = 'public' and table_name = 'daha_fazlasi_menu'
)
and not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(link)) in ('taramalar', 'taramalar_egzersizler_oyun')
);

notify pgrst, 'reload schema';
