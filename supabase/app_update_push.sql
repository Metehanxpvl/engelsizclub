-- Otomatik sürüm push kaydı (app_settings.app_update_push).
-- Admin JWT e-postası boşsa current_user_email() ile yazabilsin.
-- Dashboard → SQL Editor → çalıştır. Idempotent.

create or replace function public.current_user_email()
returns text
language sql
stable
security definer
set search_path = public, auth
as $$
  select lower(coalesce(
    nullif(trim(auth.jwt() ->> 'email'), ''),
    (
      select lower(u.email)
      from auth.users u
      where u.id = auth.uid()
      limit 1
    ),
    ''
  ));
$$;

revoke all on function public.current_user_email() from public;
grant execute on function public.current_user_email() to authenticated;

drop policy if exists "catalog_settings_admin_write" on public.app_settings;
create policy "catalog_settings_admin_write"
  on public.app_settings for all
  to authenticated
  using (public.current_user_email() = 'sakir.caykara@gmail.com')
  with check (public.current_user_email() = 'sakir.caykara@gmail.com');

insert into public.app_settings (key, value, description)
values (
  'app_update_push',
  '{}'::jsonb,
  'Son otomatik sürüm push id. Flutter aynı id’yi tekrar göndermez.'
)
on conflict (key) do nothing;

notify pgrst, 'reload schema';
