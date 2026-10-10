-- Android latest = Play’de yayınlanan sürüm. Henüz olmayan 1.1.17 yazma.

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
  'Açılış uyarısı: Android latest Play yayınıyla aynı. Yeni AAB yayınlanınca In-App Update tetikler.'
)
on conflict (key) do update
set
  value = excluded.value,
  description = excluded.description,
  updated_at = now();
