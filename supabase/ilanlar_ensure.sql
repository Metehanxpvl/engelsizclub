-- İlanlar tablosu + kolonlar + RLS (tek seferde, idempotent)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.ilanlar (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('uzman', 'bakici', 'ikinciel')),
  title text not null,
  city text not null,
  district text not null default '',
  note text not null default '',
  budget text not null default '',
  price text not null default '',
  original_price text not null default '',
  uzmanlik text,
  tani text,
  age text,
  frequency text,
  hours text,
  category text,
  condition text,
  brand text,
  emoji text,
  photos jsonb not null default '[]'::jsonb,
  urgent boolean not null default false,
  views int not null default 0,
  offers int not null default 0,
  poster_name text not null,
  poster_avatar text not null,
  owner_email text not null,
  owner_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.ilanlar
  add column if not exists status text not null default 'active';

alter table public.ilanlar
  add column if not exists country_code text not null default 'TR';

alter table public.ilanlar
  add column if not exists location_data jsonb not null default '{}'::jsonb;

alter table public.ilanlar drop constraint if exists ilanlar_status_check;
alter table public.ilanlar
  add constraint ilanlar_status_check
  check (status in ('active', 'sold'));

alter table public.ilanlar drop constraint if exists ilanlar_photos_max_check;
alter table public.ilanlar
  add constraint ilanlar_photos_max_check check (
    (kind in ('uzman', 'bakici') and jsonb_array_length(photos) <= 2)
    or kind = 'ikinciel'
  );

create index if not exists ilanlar_created_at_idx on public.ilanlar (created_at desc);
create index if not exists ilanlar_owner_email_idx on public.ilanlar (owner_email);
create index if not exists ilanlar_kind_idx on public.ilanlar (kind);
create index if not exists ilanlar_status_idx on public.ilanlar (status);
create index if not exists ilanlar_country_code_idx on public.ilanlar (country_code);

alter table public.ilanlar enable row level security;

drop policy if exists "ilanlar_select_authenticated" on public.ilanlar;
create policy "ilanlar_select_authenticated"
  on public.ilanlar for select
  to authenticated
  using (true);

drop policy if exists "ilanlar_select_anon" on public.ilanlar;
create policy "ilanlar_select_anon"
  on public.ilanlar for select
  to anon
  using (true);

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

drop policy if exists "ilanlar_insert_own" on public.ilanlar;
create policy "ilanlar_insert_own"
  on public.ilanlar for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and public.auth_user_type() = 'aile'
  );

drop policy if exists "ilanlar_delete_own" on public.ilanlar;
create policy "ilanlar_delete_own"
  on public.ilanlar for delete
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
