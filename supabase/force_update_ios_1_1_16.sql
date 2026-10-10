-- iOS App Store 1.1.16 yayınlandı. Eski 1.1.15 latest olduğu için uyarı çıkmıyordu.
-- Dashboard → SQL Editor → çalıştır. Android latest değişmez (Play 1.1.4).

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'minimumSupportedVersion', '1.0.0',
    'latestVersionAndroid', '1.1.4',
    'latestVersionIOS', '1.1.16',
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  'iOS latest = App Store 1.1.16. Android latest = Play yayını (1.1.4).'
)
on conflict (key) do update
set
  value = coalesce(app_settings.value, '{}'::jsonb) || jsonb_build_object(
    'latestVersionIOS', '1.1.16',
    'ios_url', 'https://apps.apple.com/tr/app/engelsiz-club/id6799422264'
  ),
  description = excluded.description,
  updated_at = now();
