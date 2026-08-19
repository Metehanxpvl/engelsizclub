-- android_min_build = Play'de YAYINDA olan en düşük zorunlu versionCode.
-- Yüklü sürüm >= bu sayıysa kilit ÇIKMAZ.
-- Yeni AAB (ör. +69) yayına girdikten sonra bu sayıyı 69 yapın; 68'liler kilitlenir.
-- 69 yüklüyken burayı 69 yaparsanız güncel kullanıcıya kilit çıkmaz (69 < 69 false).

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
