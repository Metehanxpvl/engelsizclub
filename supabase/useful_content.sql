-- Fırsat / Destek / Hak toplama (yalnız yeni tablolar).
-- SQL Editor → Run. Mevcut events / kariyer / profiles / push tablolarına dokunmaz.
-- Durumlar: pending_review | published | rejected | expired
-- Yayın: yalnızca admin onayından sonra. Collector asla published yazmaz.

create table if not exists public.content_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text not null,
  method text not null default 'rss'
    check (method in ('rss', 'sitemap', 'api', 'scrape')),
  is_active boolean not null default false,
  fetch_interval_hours int not null default 24
    check (fetch_interval_hours >= 1),
  last_fetched_at timestamptz,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists content_sources_url_uidx
  on public.content_sources (url);

create table if not exists public.useful_content (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references public.content_sources (id) on delete set null,
  title text not null,
  summary text not null default '',
  body text not null default '',
  category text not null default 'diger',
  city text not null default '',
  source_name text not null default '',
  source_url text not null default '',
  image_url text not null default '',
  external_id text,
  content_hash text not null,
  status text not null default 'pending_review'
    check (status in ('pending_review', 'published', 'rejected', 'expired')),
  deadline_at timestamptz,
  expires_at timestamptz,
  ai_notes text not null default '',
  reviewed_by uuid,
  reviewed_at timestamptz,
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists useful_content_source_url_uidx
  on public.useful_content (source_url)
  where source_url is not null and btrim(source_url) <> '';

create unique index if not exists useful_content_hash_uidx
  on public.useful_content (content_hash)
  where content_hash is not null and btrim(content_hash) <> '';

create unique index if not exists useful_content_external_id_uidx
  on public.useful_content (external_id)
  where external_id is not null and btrim(external_id) <> '';

create index if not exists useful_content_status_idx
  on public.useful_content (status, created_at desc);

create index if not exists useful_content_published_idx
  on public.useful_content (created_at desc)
  where status = 'published';

create index if not exists useful_content_category_idx
  on public.useful_content (category, created_at desc)
  where status = 'published';

create or replace function public.useful_content_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists content_sources_updated_at on public.content_sources;
create trigger content_sources_updated_at
  before update on public.content_sources
  for each row execute function public.useful_content_set_updated_at();

drop trigger if exists useful_content_updated_at on public.useful_content;
create trigger useful_content_updated_at
  before update on public.useful_content
  for each row execute function public.useful_content_set_updated_at();

alter table public.content_sources enable row level security;
alter table public.useful_content enable row level security;

-- Kullanıcı: yalnız published. Admin: tüm durumlar.
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

drop policy if exists "useful_content_select" on public.useful_content;
create policy "useful_content_select"
  on public.useful_content for select
  to anon, authenticated
  using (
    status = 'published'
    or public.is_engelsiz_admin()
  );

drop policy if exists "useful_content_insert_admin" on public.useful_content;
create policy "useful_content_insert_admin"
  on public.useful_content for insert
  to authenticated
  with check (public.is_engelsiz_admin());

drop policy if exists "useful_content_update_admin" on public.useful_content;
create policy "useful_content_update_admin"
  on public.useful_content for update
  to authenticated
  using (public.is_engelsiz_admin())
  with check (public.is_engelsiz_admin());

drop policy if exists "useful_content_delete_admin" on public.useful_content;
create policy "useful_content_delete_admin"
  on public.useful_content for delete
  to authenticated
  using (public.is_engelsiz_admin());

-- Kaynak listesi yalnızca admin.
drop policy if exists "content_sources_select_admin" on public.content_sources;
create policy "content_sources_select_admin"
  on public.content_sources for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "content_sources_insert_admin" on public.content_sources;
create policy "content_sources_insert_admin"
  on public.content_sources for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "content_sources_update_admin" on public.content_sources;
create policy "content_sources_update_admin"
  on public.content_sources for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "content_sources_delete_admin" on public.content_sources;
create policy "content_sources_delete_admin"
  on public.content_sources for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

grant select on table public.useful_content to anon, authenticated;
grant insert, update, delete on table public.useful_content to authenticated;
grant all on table public.useful_content to postgres, service_role;

grant select, insert, update, delete on table public.content_sources to authenticated;
grant all on table public.content_sources to postgres, service_role;

-- Resmi RSS / sitemap adayları. v1 collector yalnız rss+sitemap çeker.
-- is_active=false: sahiplik/robots doğrulanmadan tarama yapılmaz.
insert into public.content_sources (name, url, method, is_active, fetch_interval_hours, notes)
select * from (values
  (
    'MEB duyurular RSS',
    'https://www.meb.gov.tr/rss.php',
    'rss',
    false,
    24,
    'Resmi MEB RSS. Aktif etmeden önce akışın erişilebilir olduğunu doğrulayın.'
  ),
  (
    'Resmi Gazete RSS',
    'https://www.resmigazete.gov.tr/reg/rss.aspx',
    'rss',
    false,
    24,
    'Resmi Gazete. Aktif etmeden RSS adresini doğrulayın.'
  ),
  (
    'Aile ve Sosyal Hizmetler Bakanlığı sitemap',
    'https://www.aile.gov.tr/sitemap.xml',
    'sitemap',
    false,
    168,
    'Bakanlık sitemap. v1 HTML sayfa çekmez; yalnız XML/RSS izler.'
  ),
  (
    'İŞKUR haber RSS',
    'https://www.iskur.gov.tr/rss',
    'rss',
    false,
    168,
    'İŞKUR. Adres değişmiş olabilir; aktif etmeden doğrulayın.'
  ),
  (
    'İBB haber RSS',
    'https://www.ibb.istanbul/rss',
    'rss',
    false,
    168,
    'Belediye resmi RSS adayı. Düşük sıklık.'
  ),
  (
    'Ankara BB RSS',
    'https://www.ankara.bel.tr/rss',
    'rss',
    false,
    168,
    'Belediye resmi RSS adayı. Düşük sıklık.'
  )
) as v(name, url, method, is_active, fetch_interval_hours, notes)
where not exists (
  select 1 from public.content_sources s where s.url = v.url
);

notify pgrst, 'reload schema';
