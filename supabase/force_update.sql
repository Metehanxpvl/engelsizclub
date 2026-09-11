-- Engelsiz Club — zorunlu / opsiyonel uygulama güncellemesi
-- Supabase Dashboard → SQL Editor → Run
--
-- Flutter `app_settings.force_update` okur (Firebase Remote Config YOK).
-- Semver: current < minimumSupportedVersion → zorunlu
--         min ≤ current < latestVersion*   → opsiyonel
--         current >= latest                → ekran yok
--
-- latestVersionAndroid / latestVersionIOS alanlarına mağazada GERÇEKTEN
-- yayınlanan sürümü yazın. Uydurma yüksek sürüm "Güncelle" döngüsü yapar.
-- Yeni kurulumda 1.0.0 = henüz uyarı yok (yayın sonrası Dashboard'dan yükseltin).

insert into public.app_settings (key, value, description)
values (
  'force_update',
  jsonb_build_object(
    'minimumSupportedVersion', '1.0.0',
    'latestVersionAndroid', '1.0.0',
    'latestVersionIOS', '1.0.0',
    'android_url', 'https://play.google.com/store/apps/details?id=com.sakircaykara.engelsizclub',
    'ios_url', 'https://apps.apple.com/app/id6799422264',
    'message', 'Engelsiz Club''ın yeni sürümü yayınlandı.',
    -- Eski istemciler / belgeler için (Dart semver kullanır, build kilidi yok)
    'android_min_build', 68,
    'android_latest_build', 68,
    'ios_min_build', 68,
    'ios_latest_build', 68
  ),
  'Semver güncelleme: minimumSupportedVersion + latestVersionAndroid / latestVersionIOS. Mağaza sürümüyle güncelleyin.'
)
on conflict (key) do update
set
  value = jsonb_strip_nulls(
    public.app_settings.value || jsonb_build_object(
      'minimumSupportedVersion',
        coalesce(
          nullif(btrim(public.app_settings.value ->> 'minimumSupportedVersion'), ''),
          excluded.value ->> 'minimumSupportedVersion'
        ),
      'latestVersionAndroid',
        coalesce(
          nullif(btrim(public.app_settings.value ->> 'latestVersionAndroid'), ''),
          excluded.value ->> 'latestVersionAndroid'
        ),
      'latestVersionIOS',
        coalesce(
          nullif(btrim(public.app_settings.value ->> 'latestVersionIOS'), ''),
          excluded.value ->> 'latestVersionIOS'
        ),
      'android_url',
        coalesce(
          nullif(btrim(public.app_settings.value ->> 'android_url'), ''),
          excluded.value ->> 'android_url'
        ),
      'ios_url',
        coalesce(
          nullif(btrim(public.app_settings.value ->> 'ios_url'), ''),
          excluded.value ->> 'ios_url'
        )
    )
  ),
  description = excluded.description,
  updated_at = now();

notify pgrst, 'reload schema';
