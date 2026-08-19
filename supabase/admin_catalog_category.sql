-- Admin: katalog kategorisi ekle (uzmanlık / ilan / 2.el alt)
-- + app_catalog_versions RLS düzeltmesi
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını Run
--
-- Hata: new row violates row-level security policy for table "app_catalog_versions"

-- 1) Sürüm bump trigger — SECURITY DEFINER (RLS bypass)
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

-- 2) Admin app_catalog_versions yazma (yedek — trigger dışı senaryolar)
drop policy if exists "catalog_versions_admin_write" on public.app_catalog_versions;
create policy "catalog_versions_admin_write"
  on public.app_catalog_versions for all
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- 3) Kesin çözüm: admin RPC (RLS bypass)
create or replace function public.admin_upsert_app_category(
  p_id text,
  p_scope text,
  p_label text,
  p_icon text default '',
  p_sort_order int default 0,
  p_meta jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.app_categories%rowtype;
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  if coalesce(trim(p_label), '') = '' then
    raise exception 'label required';
  end if;
  if coalesce(trim(p_scope), '') = '' then
    raise exception 'scope required';
  end if;

  insert into public.app_categories (
    id, scope, label, icon, sort_order, active, meta, updated_at
  )
  values (
    trim(p_id),
    trim(p_scope),
    trim(p_label),
    coalesce(nullif(trim(p_icon), ''), '📁'),
    greatest(coalesce(p_sort_order, 0), 0),
    true,
    coalesce(p_meta, '{}'::jsonb),
    now()
  )
  on conflict (id) do update set
    scope = excluded.scope,
    label = excluded.label,
    icon = excluded.icon,
    sort_order = excluded.sort_order,
    active = true,
    meta = excluded.meta,
    updated_at = now()
  returning * into v_row;

  insert into public.app_catalog_versions (name, version, updated_at)
  values ('categories', 1, now())
  on conflict (name) do update
    set version = public.app_catalog_versions.version + 1,
        updated_at = now();

  return to_jsonb(v_row);
end;
$$;

revoke all on function public.admin_upsert_app_category(text, text, text, text, int, jsonb) from public;
grant execute on function public.admin_upsert_app_category(text, text, text, text, int, jsonb) to authenticated;

-- 4) Admin silme (soft delete)
create or replace function public.admin_delete_app_category(
  p_id text,
  p_scope text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  if coalesce(trim(p_id), '') = '' or coalesce(trim(p_scope), '') = '' then
    raise exception 'id and scope required';
  end if;

  update public.app_categories
  set active = false, updated_at = now()
  where id = trim(p_id) and scope = trim(p_scope);

  if not found then
    raise exception 'category not found';
  end if;

  insert into public.app_catalog_versions (name, version, updated_at)
  values ('categories', 1, now())
  on conflict (name) do update
    set version = public.app_catalog_versions.version + 1,
        updated_at = now();
end;
$$;

revoke all on function public.admin_delete_app_category(text, text) from public;
grant execute on function public.admin_delete_app_category(text, text) to authenticated;

notify pgrst, 'reload schema';
