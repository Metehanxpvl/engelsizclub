-- Küresel haber JSON kataloğunun admin override'ı (status / başlık / özet).
-- Ham haberler web/engelsiz-haberler.json içinde kalır; tablo şişmez.
-- SQL Editor → Run.

create table if not exists public.global_news_overrides (
  news_id text primary key,
  status text not null default 'pending_review'
    check (status in ('pending_review', 'published', 'rejected')),
  title text,
  summary text,
  image_url text,
  reviewed_at timestamptz,
  reviewed_by uuid,
  updated_at timestamptz not null default now()
);

alter table public.global_news_overrides enable row level security;

drop policy if exists "global_news_overrides_select" on public.global_news_overrides;
create policy "global_news_overrides_select"
  on public.global_news_overrides for select
  to anon, authenticated
  using (true);

drop policy if exists "global_news_overrides_write" on public.global_news_overrides;
create policy "global_news_overrides_write"
  on public.global_news_overrides for all
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

grant select on public.global_news_overrides to anon, authenticated;
grant insert, update, delete on public.global_news_overrides to authenticated;

notify pgrst, 'reload schema';
