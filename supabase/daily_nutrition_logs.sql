-- Günlük vitamin & mineral karnesi kayıtları
-- Supabase Dashboard → SQL Editor → çalıştırın (idempotent).
-- RLS: kullanıcı yalnızca kendi satırlarını görür / yazar.

create table if not exists public.daily_nutrition_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,
  raw_input text not null default '',
  nutrients_result jsonb not null default '{}'::jsonb,
  analysis_version text not null default '1',
  nutrition_profile text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, log_date)
);

alter table public.daily_nutrition_logs
  add column if not exists nutrition_profile text;

create index if not exists daily_nutrition_logs_user_date_idx
  on public.daily_nutrition_logs (user_id, log_date desc);

alter table public.daily_nutrition_logs enable row level security;

drop policy if exists "daily_nutrition_select_own" on public.daily_nutrition_logs;
create policy "daily_nutrition_select_own"
  on public.daily_nutrition_logs for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "daily_nutrition_insert_own" on public.daily_nutrition_logs;
create policy "daily_nutrition_insert_own"
  on public.daily_nutrition_logs for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "daily_nutrition_update_own" on public.daily_nutrition_logs;
create policy "daily_nutrition_update_own"
  on public.daily_nutrition_logs for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "daily_nutrition_delete_own" on public.daily_nutrition_logs;
create policy "daily_nutrition_delete_own"
  on public.daily_nutrition_logs for delete
  to authenticated
  using (user_id = auth.uid());

grant select, insert, update, delete on table public.daily_nutrition_logs
  to authenticated;

notify pgrst, 'reload schema';
