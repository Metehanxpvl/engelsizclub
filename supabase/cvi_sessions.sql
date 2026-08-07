-- CVI görsel egzersiz oturum özeti
-- Supabase SQL Editor → Run
-- Uygulama yalnızca oturum bitince TEK insert yapar.

create table if not exists public.cvi_sessions (
  id bigint generated always as identity primary key,
  owner_id uuid references auth.users (id) on delete set null,
  owner_email text not null default '',
  config_version text not null default '',
  total_steps int not null default 20,
  correct_count int not null default 0,
  percentage double precision not null default 0,
  avg_reaction_ms int not null default 0,
  step_results jsonb not null default '[]'::jsonb,
  clutter_tolerance jsonb not null default '{}'::jsonb,
  color_preference jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists cvi_sessions_owner_idx
  on public.cvi_sessions (owner_id, created_at desc);

create index if not exists cvi_sessions_email_idx
  on public.cvi_sessions (lower(owner_email), created_at desc);

alter table public.cvi_sessions enable row level security;

drop policy if exists "cvi_sessions_select_own" on public.cvi_sessions;
create policy "cvi_sessions_select_own"
  on public.cvi_sessions for select
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "cvi_sessions_insert_own" on public.cvi_sessions;
create policy "cvi_sessions_insert_own"
  on public.cvi_sessions for insert
  to authenticated
  with check (owner_id = auth.uid());

notify pgrst, 'reload schema';
