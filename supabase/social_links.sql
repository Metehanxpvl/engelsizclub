-- Ana sayfa Instagram / Facebook linkleri.
-- app_store / play_store paylaşılan config'te BOŞ kalır:
-- 1.1.8 Android "URL doluysa rozet göster" der; boş olunca gizler.
-- Web ve native mağaza rozeti yok.

insert into public.app_settings (key, value, description)
values (
  'social_links',
  jsonb_build_object(
    'instagram', 'https://www.instagram.com/engelsizclub',
    'facebook', 'https://www.facebook.com/share/1QAzdknz5M/',
    'app_store', '',
    'play_store', ''
  ),
  'Ana sayfa Instagram / Facebook linkleri (mağaza URL yok)'
)
on conflict (key) do update
  set value = jsonb_set(
        jsonb_set(
          coalesce(public.app_settings.value, '{}'::jsonb),
          '{app_store}',
          '""'::jsonb
        ),
        '{play_store}',
        '""'::jsonb
      ),
      description = excluded.description,
      updated_at = now();

notify pgrst, 'reload schema';
