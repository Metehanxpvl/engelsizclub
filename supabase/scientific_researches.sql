-- Bilimsel araştırma toplayıcı (yalnız yeni tablolar).
-- SQL Editor → Run. Mevcut events / kariyer / useful_content / profiles / push tablolarına dokunmaz.
--
-- Durumlar: pending_review | published | rejected
-- Yayın: yalnızca admin onayından sonra. Collector asla published yazmaz.
-- FCM / bildirim yok. service_role Flutter’da kullanılmaz.
-- Tıbbi içerik tedavi vaadi değildir; hayvan çalışması insan tedavisi değildir.
-- Collector yalnız HIGH_VALUE ve POTENTIAL_VALUE satırlarını pending_review olarak ekler;
-- IRRELEVANT insert edilmez.

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

create table if not exists public.scientific_sources (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  url text not null,
  method text not null default 'api'
    check (method in ('api', 'rss')),
  query text not null default '',
  notes text not null default '',
  is_active boolean not null default false,
  fetch_interval_hours int not null default 6
    check (fetch_interval_hours >= 1),
  last_fetched_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists scientific_sources_url_uidx
  on public.scientific_sources (url);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'scientific_sources_url_key'
      and conrelid = 'public.scientific_sources'::regclass
  ) then
    alter table public.scientific_sources
      add constraint scientific_sources_url_key unique using index scientific_sources_url_uidx;
  end if;
exception
  when duplicate_object then null;
end $$;

create table if not exists public.scientific_researches (
  id uuid primary key default gen_random_uuid(),
  source_id uuid references public.scientific_sources (id) on delete set null,
  title text not null,
  original_title text not null default '',
  summary text not null default '',
  why_important text not null default '',
  limitations text not null default '',
  conditions text[] not null default '{}',
  categories text[] not null default '{}',
  study_type text,
  evidence_level text,
  study_phase text,
  human_or_animal text,
  pediatric_relevance text,
  relevance_score int
    check (relevance_score is null or (relevance_score >= 0 and relevance_score <= 100)),
  scientific_importance_score int
    check (scientific_importance_score is null or (scientific_importance_score >= 0 and scientific_importance_score <= 100)),
  treatment_potential_score int
    check (treatment_potential_score is null or (treatment_potential_score >= 0 and treatment_potential_score <= 100)),
  clinical_readiness_score int
    check (clinical_readiness_score is null or (clinical_readiness_score >= 0 and clinical_readiness_score <= 100)),
  treatment_potential text not null
    check (treatment_potential in ('HIGH_VALUE', 'POTENTIAL_VALUE', 'IRRELEVANT')),
  recruitment_status text,
  publication_date date,
  country text,
  journal text,
  doi text,
  pmid text,
  nct_id text,
  source_name text not null default '',
  source_url text not null default '',
  external_id text,
  content_hash text not null,
  status text not null default 'pending_review'
    check (status in ('pending_review', 'published', 'rejected')),
  ai_notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists scientific_researches_pmid_uidx
  on public.scientific_researches (pmid)
  where pmid is not null and btrim(pmid) <> '';

create unique index if not exists scientific_researches_nct_id_uidx
  on public.scientific_researches (nct_id)
  where nct_id is not null and btrim(nct_id) <> '';

create unique index if not exists scientific_researches_doi_uidx
  on public.scientific_researches (doi)
  where doi is not null and btrim(doi) <> '';

create unique index if not exists scientific_researches_source_url_uidx
  on public.scientific_researches (source_url)
  where source_url is not null and btrim(source_url) <> '';

create unique index if not exists scientific_researches_hash_uidx
  on public.scientific_researches (content_hash)
  where content_hash is not null and btrim(content_hash) <> '';

create index if not exists scientific_researches_status_idx
  on public.scientific_researches (status, created_at desc);

create index if not exists scientific_researches_published_idx
  on public.scientific_researches (created_at desc)
  where status = 'published';

create or replace function public.scientific_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists scientific_sources_updated_at on public.scientific_sources;
create trigger scientific_sources_updated_at
  before update on public.scientific_sources
  for each row execute function public.scientific_set_updated_at();

drop trigger if exists scientific_researches_updated_at on public.scientific_researches;
create trigger scientific_researches_updated_at
  before update on public.scientific_researches
  for each row execute function public.scientific_set_updated_at();

alter table public.scientific_sources enable row level security;
alter table public.scientific_researches enable row level security;

-- Kullanıcı: yalnız published. Admin: tüm durumlar + kaynaklar.
drop policy if exists "scientific_researches_select" on public.scientific_researches;
create policy "scientific_researches_select"
  on public.scientific_researches for select
  to anon, authenticated
  using (
    status = 'published'
    or public.is_engelsiz_admin()
  );

drop policy if exists "scientific_researches_insert_admin" on public.scientific_researches;
create policy "scientific_researches_insert_admin"
  on public.scientific_researches for insert
  to authenticated
  with check (public.is_engelsiz_admin());

drop policy if exists "scientific_researches_update_admin" on public.scientific_researches;
create policy "scientific_researches_update_admin"
  on public.scientific_researches for update
  to authenticated
  using (public.is_engelsiz_admin())
  with check (public.is_engelsiz_admin());

drop policy if exists "scientific_researches_delete_admin" on public.scientific_researches;
create policy "scientific_researches_delete_admin"
  on public.scientific_researches for delete
  to authenticated
  using (public.is_engelsiz_admin());

drop policy if exists "scientific_sources_select_admin" on public.scientific_sources;
create policy "scientific_sources_select_admin"
  on public.scientific_sources for select
  to authenticated
  using (public.is_engelsiz_admin());

drop policy if exists "scientific_sources_insert_admin" on public.scientific_sources;
create policy "scientific_sources_insert_admin"
  on public.scientific_sources for insert
  to authenticated
  with check (public.is_engelsiz_admin());

drop policy if exists "scientific_sources_update_admin" on public.scientific_sources;
create policy "scientific_sources_update_admin"
  on public.scientific_sources for update
  to authenticated
  using (public.is_engelsiz_admin())
  with check (public.is_engelsiz_admin());

drop policy if exists "scientific_sources_delete_admin" on public.scientific_sources;
create policy "scientific_sources_delete_admin"
  on public.scientific_sources for delete
  to authenticated
  using (public.is_engelsiz_admin());

grant select on table public.scientific_researches to anon, authenticated;
grant insert, update, delete on table public.scientific_researches to authenticated;
grant all on table public.scientific_researches to postgres, service_role;

grant select, insert, update, delete on table public.scientific_sources to authenticated;
grant all on table public.scientific_sources to postgres, service_role;

-- Resmi API kaynakları. Collector PDF/tam metin çekmez; blog kazımaz.
-- Cochrane RSS isteğe bağlı (karmaşık/abonelik); şimdilik eklenmedi — conditions.json ile genişletilir.
-- ON CONFLICT: SQL tekrar Run edilirse PubMed/CT yeniden is_active=true olur (boş/pasif tablo 0 kâğıt üretir).
insert into public.scientific_sources (name, url, method, query, is_active, fetch_interval_hours, notes)
values
  (
    'PubMed',
    'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/',
    'api',
    'cerebral palsy OR periventricular leukomalacia OR hypoxic ischemic encephalopathy',
    true,
    6,
    'NCBI E-utilities (esearch+efetch). NCBI_API_KEY isteğe bağlı. Sorgu listesi collectors/science/conditions.json. Collector pending_review yazar; yayınlamaz. Kaynak satırı yoksa collector conditions.json fallback kullanır.'
  ),
  (
    'ClinicalTrials.gov',
    'https://clinicaltrials.gov/api/v2/studies',
    'api',
    'cerebral palsy',
    true,
    6,
    'ClinicalTrials.gov API v2. RECRUITING vb. overallStatus korunur. Collector pending_review yazar; FCM yok.'
  ),
  (
    'FDA',
    'https://api.fda.gov/drug/drugsfda.json',
    'api',
    '',
    true,
    6,
    'openFDA Drugs@FDA (https://api.fda.gov/drug/drugsfda.json) + etiket endikasyonu. Onaylı / geçici onay / NDA-BLA inceleme (API’de varsa). Koşul eşlemesi collectors/science/conditions.json. Collector pending_review yazar; yayın/FCM yok. Satır source_url Drugs@FDA sayfasıdır.'
  ),
  (
    'Cochrane Library CDSR',
    'https://www.cochranelibrary.com/cdsr/reviews',
    'rss',
    '',
    false,
    24,
    'İsteğe bağlı. Resmi RSS basit ve kararlı değilse kapalı bırakın. Blog kazımayın.'
  )
on conflict (url) do update set
  name = excluded.name,
  method = excluded.method,
  query = excluded.query,
  is_active = excluded.is_active,
  fetch_interval_hours = excluded.fetch_interval_hours,
  notes = excluded.notes;

-- Eski kurulumda is_active=false kaldıysa API kaynaklarını aç.
update public.scientific_sources
set is_active = true, method = 'api'
where url in (
  'https://eutils.ncbi.nlm.nih.gov/entrez/eutils/',
  'https://clinicaltrials.gov/api/v2/studies',
  'https://api.fda.gov/drug/drugsfda.json'
);

notify pgrst, 'reload schema';
