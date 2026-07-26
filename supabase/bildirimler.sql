-- Engelsiz Club — uygulama içi bildirimler (teklif vb.)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.bildirimler (
  id bigint generated always as identity primary key,
  owner_email text not null,
  actor_email text not null,
  actor_name text not null default '',
  type text not null default 'teklif',
  title text not null,
  body text not null,
  ilan_id bigint,
  sohbet_key text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists bildirimler_owner_idx
  on public.bildirimler (owner_email, created_at desc);
create index if not exists bildirimler_unread_idx
  on public.bildirimler (owner_email, read)
  where read = false;

alter table public.bildirimler enable row level security;

-- Alıcı kendi bildirimlerini görür
drop policy if exists "bildirim_select_own" on public.bildirimler;
create policy "bildirim_select_own"
  on public.bildirimler for select
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen (teklif veren) başkasına bildirim oluşturabilir
drop policy if exists "bildirim_insert_actor" on public.bildirimler;
create policy "bildirim_insert_actor"
  on public.bildirimler for insert
  to authenticated
  with check (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Alıcı okundu işaretleyebilir
drop policy if exists "bildirim_update_own" on public.bildirimler;
create policy "bildirim_update_own"
  on public.bildirimler for update
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Alıcı silebilir
drop policy if exists "bildirim_delete_own" on public.bildirimler;
create policy "bildirim_delete_own"
  on public.bildirimler for delete
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
