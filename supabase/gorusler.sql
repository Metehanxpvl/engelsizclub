-- Engelsiz Club — dilek / şikayet / öneri
-- Supabase Dashboard → SQL Editor → Run

create table if not exists public.gorusler (
  id bigint generated always as identity primary key,
  user_email text not null,
  user_name text not null default '',
  type text not null default 'dilek',  -- dilek | sikayet | oneri | diger
  subject text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists gorusler_created_idx
  on public.gorusler (created_at desc);

create index if not exists gorusler_user_idx
  on public.gorusler (user_email, created_at desc);

alter table public.gorusler enable row level security;

-- Kullanıcı kendi görüşünü ekler
drop policy if exists "gorus_insert_own" on public.gorusler;
create policy "gorus_insert_own"
  on public.gorusler for insert
  to authenticated
  with check (
    lower(user_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Kullanıcı kendi kayıtlarını görür
drop policy if exists "gorus_select_own" on public.gorusler;
create policy "gorus_select_own"
  on public.gorusler for select
  to authenticated
  using (
    lower(user_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Admin tüm görüşleri görür
drop policy if exists "gorus_select_admin" on public.gorusler;
create policy "gorus_select_admin"
  on public.gorusler for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
