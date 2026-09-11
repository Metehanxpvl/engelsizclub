-- Engelsiz Club — zorunlu / opsiyonel uygulama güncellemesi
-- Supabase Dashboard → SQL Editor → Run (RLS + seed)
--
-- Flutter `app_settings.force_update` okur (Firebase Remote Config YOK).
-- Semver: current < minimumSupportedVersion → zorunlu
--         min ≤ current < latestVersion*   → opsiyonel
--         current >= latest                → ekran yok (1.1.8 yüklü testçi görmez)
-- Web (engelsizclub.com) ekranı GÖSTERMEZ — yalnız iOS/Android mağaza.
--
-- Seed 1.0.0 = henüz uyarı yok. Mağaza sürümü yayınlandıktan sonra Table Editor'dan
-- `value` JSON'unu güncelleyin. Bu dosyayı tekrar çalıştırmak mevcut latest'ı EZMEZ.
--
-- Table Editor → app_settings → key = force_update → value örneği:
--   a) 1.1.8 altı opsiyonel:  min 1.0.0, latest* 1.1.8
--   b) 1.1.8 altı zorunlu:    min 1.1.8, latest* 1.1.8
-- Sahte yüksek latest "Güncelle" döngüsü yapar; yalnız gerçek mağaza sürümü yazın.

alter table if exists public.app_settings enable row level security;

drop policy if exists "catalog_settings_select" on public.app_settings;
create policy "catalog_settings_select"
  on public.app_settings for select to anon, authenticated using (true);

grant select on public.app_settings to anon, authenticated;

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
