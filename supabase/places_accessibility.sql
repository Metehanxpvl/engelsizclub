-- Engelsiz Club — mekân + erişilebilirlik (Faz B)
-- Arama INSERT ETMEZ. Satır yalnız ilk değerlendirmede açılır.
-- Dashboard → SQL Editor → Run

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  google_place_id text unique,
  name text not null,
  address text not null default '',
  city text not null default '',
  ilce text not null default '',
  lat double precision not null,
  lng double precision not null,
  category text not null default '',
  source text not null default 'google',
  created_at timestamptz not null default now()
);

create unique index if not exists places_google_place_id_uidx
  on public.places (google_place_id)
  where google_place_id is not null and btrim(google_place_id) <> '';

create table if not exists public.place_accessibility_reviews (
  id uuid primary key default gen_random_uuid(),
  place_id uuid not null references public.places (id) on delete cascade,
  user_id uuid not null,
  criteria jsonb not null default '{}'::jsonb,
  note text not null default '',
  created_at timestamptz not null default now(),
  unique (user_id, place_id)
);

create index if not exists place_reviews_place_idx
  on public.place_accessibility_reviews (place_id);

alter table public.places enable row level security;
alter table public.place_accessibility_reviews enable row level security;

drop policy if exists "places_select" on public.places;
create policy "places_select"
  on public.places for select to anon, authenticated using (true);

drop policy if exists "places_insert_auth" on public.places;
create policy "places_insert_auth"
  on public.places for insert to authenticated with check (true);

drop policy if exists "place_reviews_select" on public.place_accessibility_reviews;
create policy "place_reviews_select"
  on public.place_accessibility_reviews for select
  to anon, authenticated using (true);

drop policy if exists "place_reviews_insert_own" on public.place_accessibility_reviews;
create policy "place_reviews_insert_own"
  on public.place_accessibility_reviews for insert to authenticated
  with check (user_id = auth.uid());

drop policy if exists "place_reviews_update_own" on public.place_accessibility_reviews;
create policy "place_reviews_update_own"
  on public.place_accessibility_reviews for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

grant select on public.places to anon, authenticated;
grant insert on public.places to authenticated;
grant select on public.place_accessibility_reviews to anon, authenticated;
grant insert, update on public.place_accessibility_reviews to authenticated;

notify pgrst, 'reload schema';
