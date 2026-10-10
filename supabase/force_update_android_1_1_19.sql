-- YALNIZ Play Console'da 1.1.19 (versionCode 201019) yayına girdikten sonra çalıştır.
-- Erken çalışırsa kullanıcı Play'de henüz olmayan sürüme yönlenir.
-- minimumSupportedVersion dokunulmaz: mağaza gelmeden uygulama kilitlenmesin.
-- Play In-App Update zaten versionCode yükseltince Google Play kartını açar;
-- bu SQL semver latest'i de 1.1.19 yapar (In-App Update çalışmayan cihaz yedeği).

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'minimumSupportedVersion', '1.0.0',
    'latestVersionAndroid', '1.1.19',
    'latestVersionIOS', '1.1.16',
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  'Android latest = Play 1.1.19. In-App Update + semver Google Play’e yönlendirir.'
)
on conflict (key) do update
set
  value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object(
    'latestVersionAndroid', '1.1.19',
    'minimumSupportedVersion', '1.0.0'
  ),
  description = excluded.description,
  updated_at = now();
