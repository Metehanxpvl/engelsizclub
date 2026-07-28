-- Store ayarları (bir kez Run)
-- Demo ilanları kapat; katalog TTL 6 saat

insert into public.app_settings (key, value, description)
values
  ('show_demo_ilanlar', 'false'::jsonb, 'false = yalnız kullanıcı ilanları (Play/App Store)'),
  ('catalog_ttl_hours', '6'::jsonb, 'Katalog yeniden indirme aralığı (saat)')
on conflict (key) do update
  set value = excluded.value,
      description = excluded.description,
      updated_at = now();
