-- Katalog kategorisi eklerken bump trigger'ının RLS'ye takılmaması
-- Hata: new row violates row-level security policy for table "app_catalog_versions"
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını çalıştır

create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
security definer
set search_path = public
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

notify pgrst, 'reload schema';
