-- Optional index for the İlanlar feed:
--   SELECT … FROM ilanlar ORDER BY created_at DESC
--
-- Production `ilanlar` has no `status` or `satildi` column
-- (see supabase/ilanlar.sql). Sold listings are DELETE'd, so every
-- remaining row is active. Do not create an index on `status`.
-- Safe / idempotent. Supabase Dashboard → SQL Editor → run once.

create index if not exists ilanlar_created_at_idx
  on public.ilanlar (created_at desc);

drop index if exists public.ilanlar_status_created_at_idx;
