-- YALNIZ App Store’da 1.1.19 (CFBundleVersion 202610101320) yayına girdikten sonra çalıştır.
-- Erken çalışırsa kullanıcı mağazada henüz olmayan sürüme yönlenir.
-- Android latest / minimumSupportedVersion dokunulmaz.
-- Yayın sonrası: iOS kullanıcıları App Store güncelleme kartını görür (Güncelle → App Store).

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'minimumSupportedVersion', '1.0.0',
    'latestVersionAndroid', '1.1.4',
    'latestVersionIOS', '1.1.19',
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  'iOS latest = App Store 1.1.19. Android latest değişmez.'
)
on conflict (key) do update
set
  value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object(
    'latestVersionIOS', '1.1.19',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  description = excluded.description,
  updated_at = now();
