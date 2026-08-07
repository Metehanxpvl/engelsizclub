-- Kullanıcı engelleme + şikayet (rapor)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.user_blocks (
  id bigint generated always as identity primary key,
  blocker_email text not null,
  blocked_email text not null,
  created_at timestamptz not null default now(),
  constraint user_blocks_emails_chk check (
    length(trim(blocker_email)) > 3
    and length(trim(blocked_email)) > 3
    and lower(blocker_email) <> lower(blocked_email)
  ),
  constraint user_blocks_unique unique (blocker_email, blocked_email)
);

create index if not exists user_blocks_blocker_idx
  on public.user_blocks (lower(blocker_email));

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (lower(blocked_email));

create table if not exists public.user_reports (
  id bigint generated always as identity primary key,
  reporter_email text not null,
  target_email text not null,
  reason text not null default '',
  context text not null default 'genel',
  detail text not null default '',
  created_at timestamptz not null default now(),
  constraint user_reports_emails_chk check (
    length(trim(reporter_email)) > 3
    and length(trim(target_email)) > 3
  )
);

create index if not exists user_reports_created_idx
  on public.user_reports (created_at desc);

create index if not exists user_reports_target_idx
  on public.user_reports (lower(target_email));

alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

-- Engeller: kendi engellerini yönet; kendisiyle ilgili engelleri okuyabilsin
-- (karşı taraf engellediyse mesaj gönderimi de engellensin)
drop policy if exists "user_blocks_select_own" on public.user_blocks;
drop policy if exists "user_blocks_select_involving_me" on public.user_blocks;
create policy "user_blocks_select_involving_me"
  on public.user_blocks for select
  to authenticated
  using (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(blocked_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own"
  on public.user_blocks for insert
  to authenticated
  with check (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own"
  on public.user_blocks for delete
  to authenticated
  using (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Şikayetler: kullanıcı kendi gönderdiğini görür; admin hepsini görür
drop policy if exists "user_reports_select_own_or_admin" on public.user_reports;
create policy "user_reports_select_own_or_admin"
  on public.user_reports for select
  to authenticated
  using (
    lower(reporter_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "user_reports_insert_own" on public.user_reports;
create policy "user_reports_insert_own"
  on public.user_reports for insert
  to authenticated
  with check (
    lower(reporter_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
