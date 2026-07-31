-- conditions: kart + detay alanları
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.conditions
  add column if not exists catalog_id text not null default '';

alter table public.conditions
  add column if not exists icon text not null default '🩺';

alter table public.conditions
  add column if not exists symptoms jsonb not null default '[]'::jsonb;

alter table public.conditions
  add column if not exists diagnosis text not null default '';

alter table public.conditions
  add column if not exists support jsonb not null default '[]'::jsonb;

alter table public.conditions
  add column if not exists faq jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
