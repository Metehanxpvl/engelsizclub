-- Uzman Köşesi profilleri (Destek Veren).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Additive. Dart: lib/uzman_kosesi_profiles_store.dart
-- Herkes okur; yazma yalnız Destek Veren (uzman/bakici) veya super admin.

create or replace function public.auth_user_type()
returns text
language sql
stable
as $$
  select coalesce(
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'user_type'), ''),
    'aile'
  );
$$;

create table if not exists public.uzman_kosesi_profiles (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null,
  full_name text not null default '',
  meslek text not null default '',
  il text not null default '',
  ilce text not null default '',
  country_code text not null default 'TR',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint uzman_kosesi_profiles_owner_id_uk unique (owner_id)
);

create index if not exists uzman_kosesi_profiles_email_idx
  on public.uzman_kosesi_profiles (owner_email);

create or replace function public.uzman_kosesi_profiles_touch()
returns trigger
language plpgsql
as $$
begin
  new.owner_email := lower(trim(new.owner_email));
  new.full_name := trim(new.full_name);
  new.meslek := trim(new.meslek);
  new.il := trim(new.il);
  new.ilce := trim(new.ilce);
  new.country_code := upper(trim(new.country_code));
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists uzman_kosesi_profiles_touch_tg
  on public.uzman_kosesi_profiles;
create trigger uzman_kosesi_profiles_touch_tg
  before insert or update on public.uzman_kosesi_profiles
  for each row execute function public.uzman_kosesi_profiles_touch();

alter table public.uzman_kosesi_profiles enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.uzman_kosesi_profiles to postgres, service_role;
grant select on table public.uzman_kosesi_profiles to anon, authenticated;
grant insert, update, delete on table public.uzman_kosesi_profiles to authenticated;

drop policy if exists "uzman_kosesi_profiles_select" on public.uzman_kosesi_profiles;
create policy "uzman_kosesi_profiles_select"
  on public.uzman_kosesi_profiles for select
  to anon, authenticated
  using (true);

drop policy if exists "uzman_kosesi_profiles_insert_own" on public.uzman_kosesi_profiles;
create policy "uzman_kosesi_profiles_insert_own"
  on public.uzman_kosesi_profiles for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and public.auth_user_type() in ('uzman', 'bakici')
  );

drop policy if exists "uzman_kosesi_profiles_update_own" on public.uzman_kosesi_profiles;
create policy "uzman_kosesi_profiles_update_own"
  on public.uzman_kosesi_profiles for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "uzman_kosesi_profiles_delete_own" on public.uzman_kosesi_profiles;
create policy "uzman_kosesi_profiles_delete_own"
  on public.uzman_kosesi_profiles for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
