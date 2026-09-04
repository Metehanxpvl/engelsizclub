-- AVM çocuk / aile etkinlikleri (scraper → events → etkinlikler)
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- İlk kurulum:
--   1) Bu dosyayı SQL Editor’de çalıştırın (additive; mevcut satırları silmez)
--   2) GitHub secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, GEMINI_API_KEY
--   3) GitHub → Actions → "Scrape AVM family events" (scrape_events.yml)
--      → Run workflow
-- Catalog sync (sync-catalog) etkinlik listesini DOLDURMAZ — ayrı workflow.
--
-- Bu dosya additive’dir: mevcut etkinlikler satırlarını silmez.
-- Dart hâlâ public.etkinlikler okur. Scraper önce events’e yazar, sonra
-- source='avm_scrape' + external_id ile etkinlikler’e senkronlar.
--
-- Kullanıcı düzenlemesi: user_edited=true → scraper üzerine yazmaz.
-- Kullanıcı silmesi: mevcut admin UI DELETE. Trigger, silinen AVM
-- external_id’yi deleted_avm_events’e kaydeder; scraper geri getirmez.
-- is_active=false satırlarda scraper is_active’i tekrar true yapmaz.
--
-- Workflow: .github/workflows/scrape_events.yml (günlük 05:00 UTC, yalnızca main)

-- ── ham AVM kayıtları ──────────────────────────────────────────────────────
create table if not exists public.events (
  id bigint generated always as identity primary key,
  city text not null,
  avm_name text not null,
  event_name text not null,
  event_date text not null,
  description text not null default '',
  image_url text default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Scraper AVM kapak görselini de yazar (mevcut tablolar için additive).
-- Ayrıca bkz. supabase/events_image_url.sql
alter table public.events
  add column if not exists image_url text default '';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'events_city_avm_name_date_uq'
      and conrelid = 'public.events'::regclass
  ) then
    alter table public.events
      add constraint events_city_avm_name_date_uq
      unique (city, avm_name, event_name, event_date);
  end if;
end $$;

create index if not exists events_city_idx
  on public.events (city, avm_name);

create or replace function public.events_touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  new.city := trim(new.city);
  new.avm_name := trim(new.avm_name);
  new.event_name := trim(new.event_name);
  new.event_date := trim(new.event_date);
  new.description := coalesce(new.description, '');
  return new;
end;
$$;

drop trigger if exists events_touch_updated_at_tg on public.events;
create trigger events_touch_updated_at_tg
  before insert or update on public.events
  for each row execute function public.events_touch_updated_at();

alter table public.events enable row level security;

grant all on table public.events to postgres, service_role;

-- ── silinen scrape kimlikleri (admin DELETE sonrası dirilmesin) ───────────
create table if not exists public.deleted_avm_events (
  external_id text primary key,
  deleted_at timestamptz not null default now()
);

alter table public.deleted_avm_events enable row level security;

grant all on table public.deleted_avm_events to postgres, service_role;

-- ── etkinlikler: scrape senkron kolonları ────────────────────────────────
alter table public.etkinlikler
  add column if not exists source text;

alter table public.etkinlikler
  add column if not exists external_id text;

alter table public.etkinlikler
  add column if not exists avm_name text not null default '';

alter table public.etkinlikler
  add column if not exists user_edited boolean not null default false;

alter table public.etkinlikler
  alter column image_url set default '';

alter table public.etkinlikler
  alter column image_url drop not null;

create unique index if not exists etkinlikler_external_id_uidx
  on public.etkinlikler (external_id);

create index if not exists etkinlikler_source_idx
  on public.etkinlikler (source, is_active);

create index if not exists etkinlikler_avm_idx
  on public.etkinlikler (city, avm_name);

-- Admin UI içeriği değiştirince scraper bir daha ezmesin.
-- service_role (GitHub scraper) işaretlemez. Sıra (sort_*) içerik sayılmaz.
create or replace function public.etkinlikler_mark_user_edited()
returns trigger
language plpgsql
as $$
declare
  jwt_role text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.user_edited then
    new.user_edited := true;
    return new;
  end if;

  jwt_role := coalesce(auth.role(), auth.jwt() ->> 'role', '');
  if jwt_role = 'service_role' then
    return new;
  end if;

  if new.title is distinct from old.title
     or new.description is distinct from old.description
     or new.city is distinct from old.city
     or new.image_url is distinct from old.image_url
     or new.avm_name is distinct from old.avm_name
     or new.is_active is distinct from old.is_active then
    new.user_edited := true;
  end if;

  return new;
end;
$$;

drop trigger if exists etkinlikler_mark_user_edited_tg on public.etkinlikler;
create trigger etkinlikler_mark_user_edited_tg
  before update on public.etkinlikler
  for each row execute function public.etkinlikler_mark_user_edited();

-- Admin silince scrape kimliği kara listeye.
create or replace function public.etkinlikler_remember_deleted_avm()
returns trigger
language plpgsql
as $$
begin
  if old.source = 'avm_scrape' and coalesce(old.external_id, '') <> '' then
    insert into public.deleted_avm_events (external_id)
    values (old.external_id)
    on conflict (external_id) do nothing;
  end if;
  return old;
end;
$$;

drop trigger if exists etkinlikler_remember_deleted_avm_tg on public.etkinlikler;
create trigger etkinlikler_remember_deleted_avm_tg
  before delete on public.etkinlikler
  for each row execute function public.etkinlikler_remember_deleted_avm();

notify pgrst, 'reload schema';
