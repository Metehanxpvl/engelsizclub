-- Engelsiz Club — app_catalog_versions RLS düzeltmesi
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını Run
--
-- Belirti (admin panelinden hak / kategori / içerik kaydederken):
--   PostgrestException(message: new row violates row-level security policy
--   for table "app_catalog_versions", code: 42501, details: Forbidden)
--
-- Neden: app_rights / app_categories / app_content / app_settings /
-- app_centers / app_diseases tablolarındaki trg_bump_* tetikleyicileri
-- public.bump_catalog_version() fonksiyonunu çağırıp
-- public.app_catalog_versions tablosuna yazıyor. Fonksiyon SECURITY INVOKER
-- olduğu için bu yazma isteği admin kullanıcının yetkisiyle çalışıyor;
-- app_catalog_versions tablosunda ise yalnızca SELECT politikası tanımlı.
-- Sonuç: ana tabloya yazma başarılı olsa bile tetikleyici 42501 ile patlıyor
-- ve işlem tamamen geri alınıyor.
--
-- Çözüm: sürüm sayacını SECURITY DEFINER fonksiyonla yaz (sabit search_path)
-- + app_catalog_versions için admin yazma politikası ekle.

-- ── 1) Sürüm sayacı fonksiyonu → SECURITY DEFINER ─────────────────────────
create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_name text;
begin
  v_name := case tg_table_name
    when 'app_settings' then 'settings'
    when 'app_categories' then 'categories'
    when 'app_content' then 'content'
    when 'app_rights' then 'rights'
    when 'app_centers' then 'centers'
    when 'app_diseases' then 'diseases'
    else null
  end;
  if v_name is null then
    return coalesce(new, old);
  end if;
  insert into public.app_catalog_versions (name, version, updated_at)
  values (v_name, 1, now())
  on conflict (name) do update
    set version = public.app_catalog_versions.version + 1,
        updated_at = now();
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

-- Fonksiyon, app_catalog_versions sahibinin yetkisiyle çalışmalı.
-- (Tabloyu oluşturan rol RLS'den muaf olduğu için sayaç yazılabilir.)
do $$
begin
  execute format(
    'alter function public.bump_catalog_version() owner to %I',
    (select pg_get_userbyid(relowner)
       from pg_class
      where oid = 'public.app_catalog_versions'::regclass)
  );
exception when insufficient_privilege then
  raise notice 'bump_catalog_version() sahibi degistirilemedi: %', sqlerrm;
end
$$;

-- ── 2) app_catalog_versions politikaları ──────────────────────────────────
alter table public.app_catalog_versions enable row level security;

drop policy if exists "catalog_versions_select" on public.app_catalog_versions;
create policy "catalog_versions_select"
  on public.app_catalog_versions for select to anon, authenticated using (true);

-- Admin doğrudan (panel / SQL Editor dışı) sayaç güncellemesi yapabilsin.
drop policy if exists "catalog_versions_admin_write"
  on public.app_catalog_versions;
create policy "catalog_versions_admin_write"
  on public.app_catalog_versions for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

grant select on public.app_catalog_versions to anon, authenticated;

-- ── 3) Sayaçları ileri al (istemci cache'i tazelensin) ────────────────────
insert into public.app_catalog_versions (name, version, updated_at)
values
  ('settings', 1, now()),
  ('categories', 1, now()),
  ('content', 1, now()),
  ('rights', 1, now()),
  ('centers', 1, now()),
  ('diseases', 1, now())
on conflict (name) do update
  set version = public.app_catalog_versions.version + 1,
      updated_at = now();

notify pgrst, 'reload schema';
