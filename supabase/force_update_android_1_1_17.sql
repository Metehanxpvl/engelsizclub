-- Android: semver latest yalnız Play'de GERÇEKTEN yayınlanan sürüm olsun.
-- 1.1.17 henüz mağazada yokken yazılırsa uyarı erken çıkar.
-- Play In-App Update: yayınlandıktan sonra versionCode 117 görünce uyarı gelir.

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'minimumSupportedVersion', '1.0.0',
    'latestVersionAndroid', '1.1.4',
    'latestVersionIOS', '1.1.15',
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  'Android latest = Play’deki sürüm. Yeni AAB yayınlanınca In-App Update uyarıyı açar.'
)
on conflict (key) do update
set
  value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object(
    'latestVersionAndroid', '1.1.4',
    'minimumSupportedVersion', '1.0.0'
  ),
  description = excluded.description,
  updated_at = now();
