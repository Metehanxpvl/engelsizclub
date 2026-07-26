-- Engelsiz Club — kullanıcı profili, foto, favoriler, bildirim tercihleri
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.user_profiles (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  owner_email text not null,
  photo_data text,
  profil jsonb not null default '{}'::jsonb,
  cocuk jsonb not null default '{}'::jsonb,
  favorites jsonb not null default '[]'::jsonb,
  notifications jsonb not null default '{
    "ilanlar": true,
    "mesajlar": true,
    "duyurular": true
  }'::jsonb,
  kredi int not null default 0,
  kredi_welcome_gift boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists user_profiles_email_idx
  on public.user_profiles (owner_email);

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles_select_own" on public.user_profiles;
create policy "user_profiles_select_own"
  on public.user_profiles for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "user_profiles_insert_own" on public.user_profiles;
create policy "user_profiles_insert_own"
  on public.user_profiles for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "user_profiles_update_own" on public.user_profiles;
create policy "user_profiles_update_own"
  on public.user_profiles for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "user_profiles_delete_own" on public.user_profiles;
create policy "user_profiles_delete_own"
  on public.user_profiles for delete
  to authenticated
  using (owner_id = auth.uid());

notify pgrst, 'reload schema';

-- Mevcut tablolara kredi kolonları (yoksa ekle)
alter table public.user_profiles
  add column if not exists kredi int not null default 0;
alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;
