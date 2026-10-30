-- Etkinlik tarih/dedupe/erişilebilirlik alanları (additive, geri alınabilir)
--
-- UYARI: Canlıda çalıştırmadan önce yedek alın.
--   Dashboard → Project Settings → Database → Backups
--   veya: pg_dump -Fc --table=public.etkinlikler --table=public.events
--
-- Uygulama: Supabase SQL Editor (bu dosyanın içeriğini yapıştır) veya
--   supabase db push   (CLI bağlıysa)
-- Canlı DELETE/ALTER'ı ajan çalıştırmaz; bu dosya elle uygulanır.
--
-- Geri alma notu (en alttaki rollback bloğu yorum satırıdır).

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

-- Kullanıcı kayıtları: source='user' → source_type='kullanici' (source kolonunu yeniden adlandırma)
update public.etkinlikler
set source_type = 'kullanici'
where coalesce(source, '') = 'user'
  and coalesce(source_type, '') = '';

update public.etkinlikler
set source_type = 'avm'
where coalesce(source, '') = 'avm_scrape'
  and coalesce(source_type, '') = '';

-- ISO event_date ise start/end doldur (Türkçe parse Python'da)
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

-- Mevcut scrape satırları: dedupe_key = external_id (zaten unique)
update public.etkinlikler
set dedupe_key = external_id
where coalesce(dedupe_key, '') = ''
  and coalesce(external_id, '') <> '';

-- ── 2) mükerrerler (en yeni id kalsın) ─────────────────────────────────────
-- Önce rapor için:
--   select dedupe_key, count(*) from etkinlikler
--   where dedupe_key is not null group by 1 having count(*) > 1;

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

-- ── 3) indexler ────────────────────────────────────────────────────────────
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

-- ── 4) isteğe bağlı arşiv tablosu (silmek yerine taşımak için) ─────────────
create table if not exists public.events_archive (
  like public.etkinlikler including defaults
);

alter table public.events_archive
  add column if not exists archived_at timestamptz not null default now();

-- RLS: mevcut politikalar korunur. Yeni kolonlar nullable/default'lu;
-- anon SELECT is_active + listed kuralı aynı. Scraper service_role ile yazar.
-- Kullanıcı insert (pending + source=user) değişmez.
--
-- etkinlik_is_listed: scraper satırları is_active=true ise listelenir.
-- Geçmiş/unknown gizleme: scraper is_active=false yapar + Flutter istemci filtresi.
-- İsteğe bağlı sunucu filtresi (uygulama da dener):
--   end_date >= (now() at time zone 'Europe/Istanbul')::date
--   OR source in ('user') OR source_type = 'kullanici'

-- ── 5) TEMİZLİK — önce SAY, sonra isteğe bağlı çalıştır ────────────────────
-- Gerekçe: pg_cron bu projede varsayılan değil. Günlük GitHub Action zaten
-- çalışıyor; scraper past/unknown scraper satırlarını is_active=false yapar
-- (silmez, geri alınabilir). Kullanıcı kayıtlarına dokunulmaz.
-- 7+ gün last_seen_at görülmeyen scraper satırları da pasiflenir.
--
-- Aşağıdaki DELETE canlıda KAPALI. SQL Editor'de önce SELECT count çalıştırın.

-- select count(*) as silinecek_etkinlikler
-- from public.etkinlikler
-- where coalesce(source, '') = 'avm_scrape'
--   and coalesce(source_type, 'avm') is distinct from 'kullanici'
--   and coalesce(end_date, start_date) < (now() at time zone 'Europe/Istanbul')::date;
--
-- Arşive taşıyıp silmek için (elle, yedekten sonra):
-- insert into public.events_archive
-- select e.*, now() from public.etkinlikler e
-- where coalesce(e.source, '') = 'avm_scrape'
--   and coalesce(e.source_type, 'avm') is distinct from 'kullanici'
--   and coalesce(e.end_date, e.start_date) < (now() at time zone 'Europe/Istanbul')::date;
-- delete from public.etkinlikler e
-- where coalesce(e.source, '') = 'avm_scrape'
--   and coalesce(e.source_type, 'avm') is distinct from 'kullanici'
--   and coalesce(e.end_date, e.start_date) < (now() at time zone 'Europe/Istanbul')::date;

notify pgrst, 'reload schema';

-- ── rollback (elle) ────────────────────────────────────────────────────────
-- drop index if exists public.etkinlikler_dedupe_key_uidx;
-- drop index if exists public.events_dedupe_key_uidx;
-- drop index if exists public.etkinlikler_end_date_idx;
-- drop index if exists public.etkinlikler_start_date_idx;
-- drop index if exists public.etkinlikler_city_end_idx;
-- drop index if exists public.etkinlikler_source_type_idx;
-- drop index if exists public.events_end_date_idx;
-- drop index if exists public.events_source_type_idx;
-- alter table public.etkinlikler
--   drop column if exists start_date,
--   drop column if exists end_date,
--   drop column if exists start_time,
--   drop column if exists source_url,
--   drop column if exists source_type,
--   drop column if exists accessibility_tags,
--   drop column if exists date_status,
--   drop column if exists date_source,
--   drop column if exists year_inferred,
--   drop column if exists needs_review,
--   drop column if exists last_seen_at,
--   drop column if exists scraped_at,
--   drop column if exists dedupe_key;
-- alter table public.events
--   drop column if exists start_date, drop column if exists end_date,
--   drop column if exists start_time, drop column if exists source_url,
--   drop column if exists source_type, drop column if exists accessibility_tags,
--   drop column if exists date_status, drop column if exists date_source,
--   drop column if exists year_inferred, drop column if exists needs_review,
--   drop column if exists last_seen_at, drop column if exists scraped_at,
--   drop column if exists dedupe_key;
-- drop table if exists public.events_archive;
