-- Teklif / sohbet RLS: JWT e-postası boş olsa bile auth.users üzerinden eşle.
-- Supabase Dashboard → SQL Editor → çalıştır

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

-- Bildirim insert: e-posta eşleşmesi (rol kontrolü uygulamada).
-- JWT user_type bazen yazılamıyor; eski politika teklifi 42501 ile kesiyordu.
drop policy if exists "bildirim_insert_actor" on public.bildirimler;
create policy "bildirim_insert_actor"
  on public.bildirimler for insert
  to authenticated
  with check (
    public.current_user_email() <> ''
    and lower(actor_email) = public.current_user_email()
  );

drop policy if exists "sohbet_select_participants" on public.sohbet_mesajlari;
create policy "sohbet_select_participants"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(sender_email) = public.current_user_email()
    or lower(receiver_email) = public.current_user_email()
  );

drop policy if exists "sohbet_delete_participant" on public.sohbet_mesajlari;
create policy "sohbet_delete_participant"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(sender_email) = public.current_user_email()
    or lower(receiver_email) = public.current_user_email()
  );

drop policy if exists "sohbet_update_receiver_read" on public.sohbet_mesajlari;
create policy "sohbet_update_receiver_read"
  on public.sohbet_mesajlari for update
  to authenticated
  using (lower(receiver_email) = public.current_user_email())
  with check (lower(receiver_email) = public.current_user_email());

notify pgrst, 'reload schema';
