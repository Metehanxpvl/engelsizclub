-- Android artık Play In-App Update kullanır; min_build ile kilit YOK.
-- Play'de henüz olmayan versionCode yazmayın (sonsuz "güncelle" döngüsü).
-- iOS: App Store lookup; kapatılabilir sayfa. Bu satır yedek URL içindir.

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'android_min_build', 68,
    'android_latest_build', 68,
    'ios_min_build', 68,
    'ios_latest_build', 68,
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', '',
    'message', 'Yeni bir sürüm yayınlandı. Devam etmek için uygulamayı güncellemeniz gerekiyor.'
  ),
  'Zorunlu uygulama versionCode. Play yayını sonrası bu sayıyı yeni +koda çekin.'
)
on conflict (key) do update
set
  value = excluded.value,
  description = excluded.description,
  updated_at = now();
