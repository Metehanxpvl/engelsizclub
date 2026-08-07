-- Engelsiz Club — uluslararası konum kataloğu
-- Dil seçenekleriyle aynı ülkeler: TR, GB, DE, SA, FR
-- Supabase SQL Editor'de çalıştırın.

create table if not exists public.locations_countries (
  code text primary key,
  name_tr text not null,
  name_en text not null,
  name_native text not null default '',
  flag_emoji text not null default '',
  sort_order int not null default 0,
  active boolean not null default true
);

create table if not exists public.locations_states (
  id bigint generated always as identity primary key,
  country_code text not null references public.locations_countries (code) on delete cascade,
  code text not null default '',
  name text not null,
  sort_order int not null default 0,
  unique (country_code, name)
);

create table if not exists public.locations_cities (
  id bigint generated always as identity primary key,
  country_code text not null references public.locations_countries (code) on delete cascade,
  state_id bigint not null references public.locations_states (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  unique (state_id, name)
);

create index if not exists locations_states_country_idx
  on public.locations_states (country_code);
create index if not exists locations_cities_country_idx
  on public.locations_cities (country_code);
create index if not exists locations_cities_state_idx
  on public.locations_cities (state_id);

alter table public.locations_countries enable row level security;
alter table public.locations_states enable row level security;
alter table public.locations_cities enable row level security;

drop policy if exists "locations_countries_select" on public.locations_countries;
create policy "locations_countries_select"
  on public.locations_countries for select
  to anon, authenticated
  using (active = true);

drop policy if exists "locations_states_select" on public.locations_states;
create policy "locations_states_select"
  on public.locations_states for select
  to anon, authenticated
  using (true);

drop policy if exists "locations_cities_select" on public.locations_cities;
create policy "locations_cities_select"
  on public.locations_cities for select
  to anon, authenticated
  using (true);

-- Sadece dil seçeneklerindeki ülkeler
insert into public.locations_countries
  (code, name_tr, name_en, name_native, flag_emoji, sort_order)
values
  ('TR', 'Türkiye', 'Turkey', 'Türkiye', '🇹🇷', 1),
  ('GB', 'Birleşik Krallık', 'United Kingdom', 'United Kingdom', '🇬🇧', 2),
  ('DE', 'Almanya', 'Germany', 'Deutschland', '🇩🇪', 3),
  ('SA', 'Suudi Arabistan', 'Saudi Arabia', 'المملكة العربية السعودية', '🇸🇦', 4),
  ('FR', 'Fransa', 'France', 'France', '🇫🇷', 5)
on conflict (code) do update set
  name_tr = excluded.name_tr,
  name_en = excluded.name_en,
  name_native = excluded.name_native,
  flag_emoji = excluded.flag_emoji,
  sort_order = excluded.sort_order,
  active = true;

-- Yardımcı: state + cities ekle
create or replace function public._seed_loc_state(
  p_country text,
  p_state text,
  p_cities text[]
) returns void
language plpgsql
as $$
declare
  sid bigint;
  c text;
begin
  insert into public.locations_states (country_code, code, name)
  values (p_country, p_state, p_state)
  on conflict (country_code, name) do update set name = excluded.name
  returning id into sid;

  if sid is null then
    select id into sid from public.locations_states
    where country_code = p_country and name = p_state;
  end if;

  foreach c in array p_cities loop
    insert into public.locations_cities (country_code, state_id, name)
    values (p_country, sid, c)
    on conflict (state_id, name) do nothing;
  end loop;
end;
$$;

-- Almanya
select public._seed_loc_state('DE', 'Baden-Württemberg', array['Stuttgart','Mannheim','Karlsruhe','Freiburg','Heidelberg']);
select public._seed_loc_state('DE', 'Bayern', array['München','Nürnberg','Augsburg','Regensburg','Würzburg']);
select public._seed_loc_state('DE', 'Berlin', array['Berlin']);
select public._seed_loc_state('DE', 'Brandenburg', array['Potsdam','Cottbus','Brandenburg an der Havel']);
select public._seed_loc_state('DE', 'Bremen', array['Bremen','Bremerhaven']);
select public._seed_loc_state('DE', 'Hamburg', array['Hamburg']);
select public._seed_loc_state('DE', 'Hessen', array['Frankfurt am Main','Wiesbaden','Kassel','Darmstadt']);
select public._seed_loc_state('DE', 'Mecklenburg-Vorpommern', array['Rostock','Schwerin','Neubrandenburg']);
select public._seed_loc_state('DE', 'Niedersachsen', array['Hannover','Braunschweig','Oldenburg','Osnabrück']);
select public._seed_loc_state('DE', 'Nordrhein-Westfalen', array['Köln','Düsseldorf','Dortmund','Essen','Bonn']);
select public._seed_loc_state('DE', 'Rheinland-Pfalz', array['Mainz','Ludwigshafen','Koblenz','Trier']);
select public._seed_loc_state('DE', 'Saarland', array['Saarbrücken','Neunkirchen']);
select public._seed_loc_state('DE', 'Sachsen', array['Dresden','Leipzig','Chemnitz']);
select public._seed_loc_state('DE', 'Sachsen-Anhalt', array['Magdeburg','Halle']);
select public._seed_loc_state('DE', 'Schleswig-Holstein', array['Kiel','Lübeck','Flensburg']);
select public._seed_loc_state('DE', 'Thüringen', array['Erfurt','Jena','Gera']);

-- Birleşik Krallık
select public._seed_loc_state('GB', 'England', array['London','Manchester','Birmingham','Leeds','Liverpool','Bristol','Sheffield','Newcastle']);
select public._seed_loc_state('GB', 'Scotland', array['Edinburgh','Glasgow','Aberdeen','Dundee']);
select public._seed_loc_state('GB', 'Wales', array['Cardiff','Swansea','Newport']);
select public._seed_loc_state('GB', 'Northern Ireland', array['Belfast','Derry','Lisburn']);

-- Fransa
select public._seed_loc_state('FR', 'Île-de-France', array['Paris','Boulogne-Billancourt','Saint-Denis','Versailles']);
select public._seed_loc_state('FR', 'Auvergne-Rhône-Alpes', array['Lyon','Grenoble','Saint-Étienne','Clermont-Ferrand']);
select public._seed_loc_state('FR', 'Provence-Alpes-Côte d''Azur', array['Marseille','Nice','Toulon','Aix-en-Provence']);
select public._seed_loc_state('FR', 'Occitanie', array['Toulouse','Montpellier','Nîmes','Perpignan']);
select public._seed_loc_state('FR', 'Nouvelle-Aquitaine', array['Bordeaux','Limoges','Poitiers','La Rochelle']);
select public._seed_loc_state('FR', 'Hauts-de-France', array['Lille','Amiens','Roubaix']);
select public._seed_loc_state('FR', 'Grand Est', array['Strasbourg','Reims','Metz','Nancy']);
select public._seed_loc_state('FR', 'Pays de la Loire', array['Nantes','Angers','Le Mans']);
select public._seed_loc_state('FR', 'Bretagne', array['Rennes','Brest','Quimper']);
select public._seed_loc_state('FR', 'Normandie', array['Rouen','Caen','Le Havre']);
select public._seed_loc_state('FR', 'Bourgogne-Franche-Comté', array['Dijon','Besançon']);
select public._seed_loc_state('FR', 'Centre-Val de Loire', array['Orléans','Tours']);
select public._seed_loc_state('FR', 'Corse', array['Ajaccio','Bastia']);

-- Suudi Arabistan
select public._seed_loc_state('SA', 'Riyadh', array['Riyadh','Al Kharj','Diriyah']);
select public._seed_loc_state('SA', 'Makkah', array['Jeddah','Mecca','Taif','Rabigh']);
select public._seed_loc_state('SA', 'Madinah', array['Medina','Yanbu']);
select public._seed_loc_state('SA', 'Eastern Province', array['Dammam','Khobar','Dhahran','Al Ahsa']);
select public._seed_loc_state('SA', 'Asir', array['Abha','Khamis Mushait']);
select public._seed_loc_state('SA', 'Qassim', array['Buraidah','Unaizah']);
select public._seed_loc_state('SA', 'Tabuk', array['Tabuk']);
select public._seed_loc_state('SA', 'Hail', array['Hail']);
select public._seed_loc_state('SA', 'Northern Borders', array['Arar']);
select public._seed_loc_state('SA', 'Jazan', array['Jazan']);
select public._seed_loc_state('SA', 'Najran', array['Najran']);
select public._seed_loc_state('SA', 'Al Bahah', array['Al Bahah']);
select public._seed_loc_state('SA', 'Al Jawf', array['Sakakah']);

-- İlanlar: ülke + location_data
alter table public.ilanlar
  add column if not exists country_code text not null default 'TR';
alter table public.ilanlar
  add column if not exists location_data jsonb not null default '{}'::jsonb;

create index if not exists ilanlar_country_code_idx on public.ilanlar (country_code);

-- Eski kayıtları TR location_data ile doldur
update public.ilanlar
set
  country_code = coalesce(nullif(trim(country_code), ''), 'TR'),
  location_data = jsonb_build_object(
    'country_code', coalesce(nullif(trim(country_code), ''), 'TR'),
    'country', 'Türkiye',
    'state', city,
    'city', district
  )
where location_data = '{}'::jsonb or location_data is null;

-- Not: Türkiye il/ilçe kataloğu uygulamada kTurkishCities ile gelir.
-- İsterseniz ayrıca client seed veya ayrı bir TR SQL ile locations_states/cities doldurun.

drop function if exists public._seed_loc_state(text, text, text[]);

notify pgrst, 'reload schema';
