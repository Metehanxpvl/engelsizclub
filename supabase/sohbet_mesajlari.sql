-- Engelsiz Club — gerçek sohbet mesajları
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.sohbet_mesajlari (
  id bigint generated always as identity primary key,
  sohbet_key text not null,
  sender_email text not null,
  sender_id uuid references auth.users (id) on delete set null,
  receiver_email text not null,
  body text not null,
  created_at timestamptz not null default now()
);

create index if not exists sohbet_mesajlari_key_idx
  on public.sohbet_mesajlari (sohbet_key, created_at);
create index if not exists sohbet_mesajlari_receiver_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc);

alter table public.sohbet_mesajlari enable row level security;

drop policy if exists "sohbet_select_participants" on public.sohbet_mesajlari;
create policy "sohbet_select_participants"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "sohbet_insert_own" on public.sohbet_mesajlari;
create policy "sohbet_insert_own"
  on public.sohbet_mesajlari for insert
  to authenticated
  with check (sender_id = auth.uid());

-- Kendi gönderdiğiniz mesajı silin
drop policy if exists "sohbet_delete_own" on public.sohbet_mesajlari;
create policy "sohbet_delete_own"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (sender_id = auth.uid());

-- Katılımcı olduğunuz sohbetteki tüm mesajları silin (sohbeti temizle)
drop policy if exists "sohbet_delete_participant" on public.sohbet_mesajlari;
create policy "sohbet_delete_participant"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Realtime (yoksa hata vermemesi için)
do $$
begin
  alter publication supabase_realtime add table public.sohbet_mesajlari;
exception
  when duplicate_object then null;
  when others then null;
end $$;

notify pgrst, 'reload schema';
