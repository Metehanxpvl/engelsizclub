-- Admin: katalog kategorisi sil (soft delete — active=false)
-- Supabase Dashboard → SQL Editor → Run

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
