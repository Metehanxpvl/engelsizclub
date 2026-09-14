-- Admin pending_review satırlarını görebilsin (JWT email boş olsa bile).
-- SQL Editor → Run.

create or replace function public.is_engelsiz_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select lower(trim(coalesce(
    auth.jwt() ->> 'email',
    auth.jwt() -> 'user_metadata' ->> 'email',
    (select u.email::text from auth.users u where u.id = auth.uid() limit 1),
    ''
  ))) = 'sakir.caykara@gmail.com';
$$;

revoke all on function public.is_engelsiz_admin() from public;
grant execute on function public.is_engelsiz_admin() to anon, authenticated;

drop policy if exists "useful_content_select" on public.useful_content;
create policy "useful_content_select"
  on public.useful_content for select
  to anon, authenticated
  using (
    status = 'published'
    or public.is_engelsiz_admin()
  );

drop policy if exists "useful_content_insert_admin" on public.useful_content;
create policy "useful_content_insert_admin"
  on public.useful_content for insert
  to authenticated
  with check (public.is_engelsiz_admin());

drop policy if exists "useful_content_update_admin" on public.useful_content;
create policy "useful_content_update_admin"
  on public.useful_content for update
  to authenticated
  using (public.is_engelsiz_admin())
  with check (public.is_engelsiz_admin());

drop policy if exists "useful_content_delete_admin" on public.useful_content;
create policy "useful_content_delete_admin"
  on public.useful_content for delete
  to authenticated
  using (public.is_engelsiz_admin());

notify pgrst, 'reload schema';
