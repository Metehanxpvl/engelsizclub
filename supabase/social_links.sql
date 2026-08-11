-- Ana sayfa sosyal / mağaza linkleri
-- Supabase SQL Editor → Run

insert into public.app_settings (key, value, description)
values (
  'social_links',
  jsonb_build_object(
    'instagram', 'https://www.instagram.com/engelsizclub',
    'facebook', 'https://www.facebook.com/share/1QAzdknz5M/',
    'app_store', '',
    'play_store', ''
  ),
  'Ana sayfa altı Instagram / Facebook / App Store / Google Play linkleri'
)
on conflict (key) do update
  set description = excluded.description,
      updated_at = now();

notify pgrst, 'reload schema';
