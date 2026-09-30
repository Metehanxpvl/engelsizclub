-- iOS/Android FCM token kaydı: JWT e-postası boş olsa bile auth.uid eşleşsin.
-- Supabase Dashboard → SQL Editor → çalıştır
-- Token yazılamazsa kişisel push { skipped: "no_token" } döner.

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

drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
  on public.user_push_tokens for select
  to authenticated
  using (
    owner_id = auth.uid()
    or (
      public.current_user_email() <> ''
      and lower(owner_email) = public.current_user_email()
    )
  );

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
  on public.user_push_tokens for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    or (
      public.current_user_email() <> ''
      and lower(owner_email) = public.current_user_email()
    )
  );

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
  on public.user_push_tokens for update
  to authenticated
  using (
    owner_id = auth.uid()
    or (
      public.current_user_email() <> ''
      and lower(owner_email) = public.current_user_email()
    )
  )
  with check (
    owner_id = auth.uid()
    or (
      public.current_user_email() <> ''
      and lower(owner_email) = public.current_user_email()
    )
  );

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
  on public.user_push_tokens for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or (
      public.current_user_email() <> ''
      and lower(owner_email) = public.current_user_email()
    )
  );

notify pgrst, 'reload schema';
