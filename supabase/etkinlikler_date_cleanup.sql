-- SQL Editor kopyası. Canlıda ajan ÇALIŞTIRMAZ.
-- Önce yedek alın. Asıl dosya:
--   supabase/migrations/20261030120000_etkinlik_date_fields.sql
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- UYARI: ALTER/DELETE canlı veriyi etkiler. Önce Project Settings → Database → Backups.

-- ── 1) kolonlar: events + etkinlikler ──────────────────────────────────────
alter table public.events
  add column if not exists start_date date,
  add column if not exists end_date date,
  add column if not exists start_time text,
  add column if not exists source_url text,
  add column if not exists source_type text,
  add column if not exists accessibility_tags text[] not null default '{}',
  add column if not exists date_status text,
  add column if not exists date_source text,
  add column if not exists year_inferred boolean not null default false,
  add column if not exists needs_review boolean not null default false,
  add column if not exists last_seen_at timestamptz,
  add column if not exists scraped_at timestamptz,
  add column if not exists dedupe_key text;

alter table public.etkinlikler
  add column if not exists start_date date,
  add column if not exists end_date date,
  add column if not exists start_time text,
  add column if not exists source_url text,
  add column if not exists source_type text,
  add column if not exists accessibility_tags text[] not null default '{}',
  add column if not exists date_status text,
  add column if not exists date_source text,
  add column if not exists year_inferred boolean not null default false,
  add column if not exists needs_review boolean not null default false,
  add column if not exists last_seen_at timestamptz,
  add column if not exists scraped_at timestamptz,
  add column if not exists dedupe_key text;

update public.etkinlikler
set source_type = 'kullanici'
where coalesce(source, '') = 'user'
  and coalesce(source_type, '') = '';

update public.etkinlikler
set source_type = 'avm'
where coalesce(source, '') = 'avm_scrape'
  and coalesce(source_type, '') = '';

update public.etkinlikler
set start_date = substring(event_date from '^(20[0-9]{2}-[0-9]{2}-[0-9]{2})')::date
where start_date is null
  and event_date ~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}';

update public.etkinlikler
set end_date = coalesce(end_date, start_date)
where start_date is not null
  and end_date is null;

update public.events
set start_date = substring(event_date from '^(20[0-9]{2}-[0-9]{2}-[0-9]{2})')::date
where start_date is null
  and event_date ~ '^20[0-9]{2}-[0-9]{2}-[0-9]{2}';

update public.events
set end_date = coalesce(end_date, start_date)
where start_date is not null
  and end_date is null;

update public.etkinlikler
set dedupe_key = external_id
where coalesce(dedupe_key, '') = ''
  and coalesce(external_id, '') <> '';

delete from public.etkinlikler a
using public.etkinlikler b
where a.dedupe_key is not null
  and a.dedupe_key = b.dedupe_key
  and a.id < b.id
  and coalesce(a.source, '') = 'avm_scrape'
  and coalesce(b.source, '') = 'avm_scrape';

delete from public.events a
using public.events b
where a.dedupe_key is not null
  and a.dedupe_key = b.dedupe_key
  and a.id < b.id;

create unique index if not exists etkinlikler_dedupe_key_uidx
  on public.etkinlikler (dedupe_key)
  where dedupe_key is not null;

create unique index if not exists events_dedupe_key_uidx
  on public.events (dedupe_key)
  where dedupe_key is not null;

create index if not exists etkinlikler_end_date_idx
  on public.etkinlikler (end_date);

create index if not exists etkinlikler_start_date_idx
  on public.etkinlikler (start_date);

create index if not exists etkinlikler_city_end_idx
  on public.etkinlikler (city, end_date);

create index if not exists etkinlikler_source_type_idx
  on public.etkinlikler (source_type, is_active);

create index if not exists events_end_date_idx
  on public.events (end_date);

create index if not exists events_source_type_idx
  on public.events (source_type);

create table if not exists public.events_archive (
  like public.etkinlikler including defaults
);

alter table public.events_archive
  add column if not exists archived_at timestamptz not null default now();

-- Önce say, silme:
-- select count(*) as silinecek_etkinlikler
-- from public.etkinlikler
-- where coalesce(source, '') = 'avm_scrape'
--   and coalesce(source_type, 'avm') is distinct from 'kullanici'
--   and coalesce(end_date, start_date) < (now() at time zone 'Europe/Istanbul')::date;

notify pgrst, 'reload schema';
