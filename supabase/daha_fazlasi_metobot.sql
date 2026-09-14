-- MetoBot menü satırı. SQL Editor → Run. Mevcut satırları değiştirmez.

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'MetoBot',
  'Yardımcı asistan',
  'route',
  'metobot',
  'smart_toy',
  12,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(link)) in ('metobot', '/metobot', 'route:metobot')
     or lower(trim(title)) = 'metobot'
);

notify pgrst, 'reload schema';
