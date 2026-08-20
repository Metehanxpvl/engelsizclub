-- Engelsiz Club — dinamik katalog (merkez, içerik, kategori, ayar)
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını Run
--
-- Amaç: Uygulamayı her seferinde yeniden deploy etmeden
-- içerikleri panelden / SQL'den güncellemek.
-- Flutter tarafı AppCatalogService ile çeker + yerelde TTL cache tutar.

-- ── 1) Uygulama ayarları (key → JSON) ───────────────────────────────────────
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text not null default '',
  updated_at timestamptz not null default now()
);

-- ── 2) Kategoriler (forum / haklar / merkez / uzmanlık / kart) ─────────────
create table if not exists public.app_categories (
  id text primary key,                 -- örn. 'maddi', 'izin', 'fizyoterapist'
  scope text not null,                 -- 'rights' | 'forum' | 'centers' | 'uzmanlik' | 'cards' | 'ilan'
  label text not null,
  icon text not null default '',
  color bigint,                        -- ARGB int (opsiyonel)
  sort_order int not null default 0,
  active boolean not null default true,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists app_categories_scope_idx
  on public.app_categories (scope, sort_order);

-- ── 3) CMS içerik blokları (banner, metin, FAQ, duyuru) ────────────────────
create table if not exists public.app_content (
  id text primary key,                 -- örn. 'home_hero', 'disclaimer_rights'
  scope text not null default 'general',
  title text not null default '',
  body text not null default '',
  media_url text not null default '',
  sort_order int not null default 0,
  active boolean not null default true,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists app_content_scope_idx
  on public.app_content (scope, sort_order);

-- ── 4) Haklar kataloğu ────────────────────────────────────────────────────
create table if not exists public.app_rights (
  id text primary key,
  title text not null,
  amount text not null default '',
  category text not null default 'maddi',  -- app_categories.id (scope=rights)
  icon text not null default '',
  color bigint not null default 4281568586,
  bg bigint not null default 4293980400,
  min_rate int not null default 0,
  max_age int not null default 99,
  income_limit boolean not null default false,
  description text not null default '',
  steps jsonb not null default '[]'::jsonb,   -- string[]
  where_text text not null default '',
  sort_order int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists app_rights_category_idx
  on public.app_rights (category, sort_order);

-- ── 5) Merkez kataloğu (küratör / yedek liste; Places canlı aramadan bağımsız) ─
create table if not exists public.app_centers (
  id bigint generated always as identity primary key,
  city text not null,
  ilce text not null default '',
  name text not null,
  category text not null default 'Rehabilitasyon',
  address text not null default '',
  phone text not null default '',
  hours text not null default '',
  services jsonb not null default '[]'::jsonb,
  rating double precision not null default 0,
  reviews int not null default 0,
  color bigint not null default 4281568586,
  lat double precision not null,
  lng double precision not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists app_centers_city_idx
  on public.app_centers (city, active);

create index if not exists app_centers_geo_idx
  on public.app_centers (lat, lng);

-- ── 6) Hastalık / rehber içerikleri (Ana sayfa kartları) ───────────────────
create table if not exists public.app_diseases (
  id text primary key,
  name text not null,
  icon text not null default '',
  color bigint not null default 4281568586,
  bg bigint not null default 4293980400,
  photo text not null default '',
  description text not null default '',
  symptoms jsonb not null default '[]'::jsonb,
  diagnosis text not null default '',
  support jsonb not null default '[]'::jsonb,
  faq jsonb not null default '[]'::jsonb,     -- [{q,a}, ...]
  sort_order int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ── 7) Katalog sürüm tablosu (ucuz sync — kota dostu) ─────────────────────
-- Flutter önce bunu çeker; sadece değişen paketleri indirir.
create table if not exists public.app_catalog_versions (
  name text primary key,               -- 'settings' | 'categories' | 'content' | 'rights' | 'centers' | 'diseases'
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

insert into public.app_catalog_versions (name, version)
values
  ('settings', 1),
  ('categories', 1),
  ('content', 1),
  ('rights', 1),
  ('centers', 1),
  ('diseases', 1)
on conflict (name) do nothing;

-- Güncellemede version++ otomatik
-- SECURITY DEFINER: tetikleyici app_catalog_versions'a yazarken RLS'ye takılmaz
create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text;
begin
  v_name := case tg_table_name
    when 'app_settings' then 'settings'
    when 'app_categories' then 'categories'
    when 'app_content' then 'content'
    when 'app_rights' then 'rights'
    when 'app_centers' then 'centers'
    when 'app_diseases' then 'diseases'
    else null
  end;
  if v_name is null then
    return coalesce(new, old);
  end if;
  insert into public.app_catalog_versions (name, version, updated_at)
  values (v_name, 1, now())
  on conflict (name) do update
    set version = public.app_catalog_versions.version + 1,
        updated_at = now();
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bump_settings on public.app_settings;
create trigger trg_bump_settings
  after insert or update or delete on public.app_settings
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_categories on public.app_categories;
create trigger trg_bump_categories
  after insert or update or delete on public.app_categories
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_content on public.app_content;
create trigger trg_bump_content
  after insert or update or delete on public.app_content
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_rights on public.app_rights;
create trigger trg_bump_rights
  after insert or update or delete on public.app_rights
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_centers on public.app_centers;
create trigger trg_bump_centers
  after insert or update or delete on public.app_centers
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_diseases on public.app_diseases;
create trigger trg_bump_diseases
  after insert or update or delete on public.app_diseases
  for each row execute function public.bump_catalog_version();

-- ── 8) RLS — herkes (authenticated + anon) okuyabilir; yazma sadece service role / admin ─
alter table public.app_settings enable row level security;
alter table public.app_categories enable row level security;
alter table public.app_content enable row level security;
alter table public.app_rights enable row level security;
alter table public.app_centers enable row level security;
alter table public.app_diseases enable row level security;
alter table public.app_catalog_versions enable row level security;

drop policy if exists "catalog_settings_select" on public.app_settings;
create policy "catalog_settings_select"
  on public.app_settings for select to anon, authenticated using (true);

drop policy if exists "catalog_categories_select" on public.app_categories;
create policy "catalog_categories_select"
  on public.app_categories for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_content_select" on public.app_content;
create policy "catalog_content_select"
  on public.app_content for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_rights_select" on public.app_rights;
create policy "catalog_rights_select"
  on public.app_rights for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_centers_select" on public.app_centers;
create policy "catalog_centers_select"
  on public.app_centers for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_diseases_select" on public.app_diseases;
create policy "catalog_diseases_select"
  on public.app_diseases for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_versions_select" on public.app_catalog_versions;
create policy "catalog_versions_select"
  on public.app_catalog_versions for select to anon, authenticated using (true);

drop policy if exists "catalog_versions_admin_write" on public.app_catalog_versions;
create policy "catalog_versions_admin_write"
  on public.app_catalog_versions for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- Admin yazma (sakir.caykara@gmail.com) — Dashboard Table Editor de service role kullanır
drop policy if exists "catalog_settings_admin_write" on public.app_settings;
create policy "catalog_settings_admin_write"
  on public.app_settings for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_categories_admin_write" on public.app_categories;
create policy "catalog_categories_admin_write"
  on public.app_categories for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_content_admin_write" on public.app_content;
create policy "catalog_content_admin_write"
  on public.app_content for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_rights_admin_write" on public.app_rights;
create policy "catalog_rights_admin_write"
  on public.app_rights for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_centers_admin_write" on public.app_centers;
create policy "catalog_centers_admin_write"
  on public.app_centers for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_diseases_admin_write" on public.app_diseases;
create policy "catalog_diseases_admin_write"
  on public.app_diseases for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- ── 9) Örnek ayarlar / kategoriler (isteğe bağlı seed) ─────────────────────
insert into public.app_settings (key, value, description) values
  ('places_radius_km', '40', 'Google Places arama yarıçapı (km)'),
  ('catalog_ttl_hours', '6', 'İstemci cache TTL (saat)'),
  ('maintenance_message', '""', 'Bakım duyurusu (boş = yok)')
on conflict (key) do nothing;

insert into public.app_categories (id, scope, label, icon, sort_order) values
  ('tümü', 'rights', 'Tümü', '📋', 0),
  ('maddi', 'rights', 'Maddi', '💰', 1),
  ('izin', 'rights', 'Kamu Çalışan İzin', '🏢', 2),
  ('vergi', 'rights', 'Vergi & Araç', '🚗', 3),
  ('egitim', 'rights', 'Eğitim', '📚', 4),
  ('ulasim', 'rights', 'Ulaşım', '🚌', 5),
  ('Fizyoterapist', 'uzmanlik', 'Fizyoterapist', '🏃', 1),
  ('Ergoterapist', 'uzmanlik', 'Ergoterapist', '✋', 2),
  ('Dil Konuşma Terapisti', 'uzmanlik', 'Dil Konuşma Terapisti', '💬', 3),
  ('Özel Eğitim Öğretmeni', 'uzmanlik', 'Özel Eğitim Öğretmeni', '📚', 4),
  ('Psikolog', 'uzmanlik', 'Psikolog', '🧠', 5),
  ('Tümü', 'centers', 'Tümü', '', 0),
  ('Fizik Tedavi', 'centers', 'Fizik Tedavi', '', 1),
  ('Özel Eğitim', 'centers', 'Özel Eğitim', '', 2),
  ('Dil Terapisi', 'centers', 'Dil Terapisi', '', 3),
  ('Nöroloji', 'centers', 'Nöroloji', '', 4)
on conflict (id) do nothing;

notify pgrst, 'reload schema';
