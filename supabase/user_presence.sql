-- Engelsiz Club — sohbet çevrimiçi durumu (last_seen)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

create table if not exists public.user_presence (
  owner_email text primary key,
  owner_id uuid references auth.users (id) on delete cascade,
  last_seen timestamptz not null default now()
);

create index if not exists user_presence_last_seen_idx
  on public.user_presence (last_seen desc);

alter table public.user_presence enable row level security;

-- Giriş yapan herkes başkalarının çevrimiçi durumunu görebilir
drop policy if exists "user_presence_select_authenticated" on public.user_presence;
create policy "user_presence_select_authenticated"
  on public.user_presence for select
  to authenticated
  using (true);

-- Sadece kendi satırını yazabilir / güncelleyebilir
drop policy if exists "user_presence_upsert_own" on public.user_presence;
create policy "user_presence_upsert_own"
  on public.user_presence for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_presence_update_own" on public.user_presence;
create policy "user_presence_update_own"
  on public.user_presence for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

notify pgrst, 'reload schema';
