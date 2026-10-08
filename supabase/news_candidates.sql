-- Günlük gazete haberi adayları (admin onay kuyruğu).
-- SQL Editor → Run. useful_content / global_news / duyurular / collector tablolarına dokunmaz.
-- Collector asla published yazmaz; kullanıcıya otomatik yayın yok.

create or replace function public.is_engelsiz_admin()
returns boolean
language sql
stable
security definer
set search_path = public, auth
as $$
  select lower(trim(coalesce(
    auth.jwt() ->> 'email',
    auth.jwt() -> 'user_metadata' ->> 'email',
    (select u.email::text from auth.users u where u.id = auth.uid() limit 1),
    ''
  ))) = 'sakir.caykara@gmail.com';
$$;

revoke all on function public.is_engelsiz_admin() from public;
grant execute on function public.is_engelsiz_admin() to anon, authenticated;

create table if not exists public.news_candidates (
  id uuid primary key default gen_random_uuid(),
  source_name text not null,
  source_url text not null default '',
  article_url text not null,
  canonical_url text not null,
  title text not null,
  summary text not null default '',
  published_at timestamptz,
  image_url text not null default '',
  category text not null default 'Diğer',
  categories text[] not null default '{}',
  relevance_score int not null default 0
    check (relevance_score >= 0 and relevance_score <= 100),
  importance_level text not null default 'informational'
    check (importance_level in ('very_high', 'high', 'informational')),
  ai_reason text not null default '',
  affected_users text[] not null default '{}',
  content_hash text not null,
  title_fingerprint text not null default '',
  duplicate_group_id uuid,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists news_candidates_canonical_uidx
  on public.news_candidates (canonical_url)
  where btrim(canonical_url) <> '';

create unique index if not exists news_candidates_hash_uidx
  on public.news_candidates (content_hash)
  where btrim(content_hash) <> '';

create index if not exists news_candidates_status_idx
  on public.news_candidates (status, created_at desc);

create index if not exists news_candidates_published_idx
  on public.news_candidates (published_at desc);

create table if not exists public.news_scan_runs (
  id uuid primary key default gen_random_uuid(),
  started_at timestamptz not null default now(),
  finished_at timestamptz,
  ok boolean not null default false,
  stats jsonb not null default '{}'::jsonb
);

create index if not exists news_scan_runs_finished_idx
  on public.news_scan_runs (finished_at desc)
  where ok = true;

create or replace function public.news_candidates_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists news_candidates_updated_at on public.news_candidates;
create trigger news_candidates_updated_at
  before update on public.news_candidates
  for each row execute function public.news_candidates_set_updated_at();

alter table public.news_candidates enable row level security;
alter table public.news_scan_runs enable row level security;

drop policy if exists "news_candidates_select_admin" on public.news_candidates;
create policy "news_candidates_select_admin"
  on public.news_candidates for select
  to authenticated
  using (public.is_engelsiz_admin());

drop policy if exists "news_candidates_update_admin" on public.news_candidates;
create policy "news_candidates_update_admin"
  on public.news_candidates for update
  to authenticated
  using (public.is_engelsiz_admin())
  with check (public.is_engelsiz_admin());

drop policy if exists "news_scan_runs_select_admin" on public.news_scan_runs;
create policy "news_scan_runs_select_admin"
  on public.news_scan_runs for select
  to authenticated
  using (public.is_engelsiz_admin());

grant select, update on public.news_candidates to authenticated;
grant select on public.news_scan_runs to authenticated;

notify pgrst, 'reload schema';
