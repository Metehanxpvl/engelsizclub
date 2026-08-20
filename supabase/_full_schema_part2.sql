-- FILE: app_catalog.sql
-- =============================================================================

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

-- Güncellemede version++ otomatik.
-- SECURITY DEFINER şart: tetikleyici, admin kullanıcının yetkisiyle çalışırsa
-- app_catalog_versions RLS'i yazmayı 42501 ile reddeder ve ana tablo kaydı da
-- geri alınır.
create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
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

drop policy if exists "catalog_versions_admin_write"
  on public.app_catalog_versions;
create policy "catalog_versions_admin_write"
  on public.app_catalog_versions for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

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


-- =============================================================================
-- FILE: app_catalog_store_settings.sql
-- =============================================================================

-- Store ayarları (bir kez Run)
-- Demo ilanları kapat; katalog TTL 6 saat

insert into public.app_settings (key, value, description)
values
  ('show_demo_ilanlar', 'false'::jsonb, 'false = yalnız kullanıcı ilanları (Play/App Store)'),
  ('catalog_ttl_hours', '6'::jsonb, 'Katalog yeniden indirme aralığı (saat)')
on conflict (key) do update
  set value = excluded.value,
      description = excluded.description,
      updated_at = now();


-- =============================================================================
-- FILE: app_catalog_seed_rights.sql
-- =============================================================================

-- Engelsiz Club — app_rights seed
-- Supabase SQL Editor → New query → Run
-- Table Editor ile tek tek doldurmaya GEREK YOK

truncate table public.app_rights restart identity cascade;

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'evde-bakim',
  'Evde Bakım Maaşı',
  '₺15.775 / ay',
  'maddi',
  '🏠',
  4279921482,
  4293457390,
  50,
  18,
  true,
  'Evde bakıma muhtaç ağır engelli bireylerin yakınlarına Sosyal Hizmetler tarafından ödenen aylık destek. Güncel tutar: ₺15.775. Hane halkı gelir testi yapılır.',
  '["E-Devlet üzerinden ''Evde Bakım Hizmeti'' başvurusu yapın","Sağlık kurulundan %50+ bakıma muhtaç raporu alın","İl Sosyal Hizmetler Müdürlüğü''ne başvurun","Hane halkı gelir testi yapılır"]'::jsonb,
  'e-Devlet · İl Sosyal Hizmetler Müdürlüğü',
  1,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-maas',
  'Engelli Aylığı',
  '₺5.793 – ₺8.690 / ay',
  'maddi',
  '💳',
  4285242052,
  4293850619,
  40,
  99,
  true,
  'SGK veya Sosyal Yardımlaşma Vakfı tarafından ödenen aylık. Gelir testi uygulanır; çalışmayan engelli bireyler için geçerlidir.

',
  '["Sağlık Kurulu Raporu alın (%40+ engel oranı)","SGK veya SYDV''ye başvurun","Gelir testi ve belgeler tamamlanır","Hesaba her ay otomatik yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  2,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-yakini-ayligi',
  '18 Yaş Altı Engelli Yakını Aylığı',
  '₺5.793,30 / ay',
  'maddi',
  '👨‍👧',
  4278751666,
  4293721855,
  40,
  18,
  true,
  '18 yaşından küçük engelli yakını olan bakmakla yükümlü kişilere ödenen aylık. Güncel tutar: ₺5.793,30. Gelir testi uygulanır.',
  '["Çocuğun Sağlık Kurulu Raporunu alın (%40+)","SGK veya Sosyal Yardımlaşma Vakfı''na başvurun","Veli / vasi belgesi ve gelir belgelerini ibraz edin","Onay sonrası aylık hesaba yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  3,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yardimci-arac',
  'Yardımcı Araç-Gereç Desteği',
  'SGK karşılar',
  'maddi',
  '♿',
  4284196994,
  4293193961,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez, protez, işitme cihazı ve benzeri yardımcı araçlar SGK tarafından karşılanmaktadır.',
  '["Hekim raporu ve SGK sevki alın","SGK sözleşmeli firma veya ortez merkezine gidin","Katkı payı varsa ödenir; ücretsiz seçenekler mevcuttur"]'::jsonb,
  'SGK · Sözleşmeli medikal firmalar',
  4,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'nobet-bakim-izin',
  'Nöbet Muafiyeti & Günlük Eğitim/Bakım İzni',
  'Nöbet muafiyeti · Haftalık 8 saat eğitim',
  'izin',
  '🏢',
  4279203438,
  4293326837,
  70,
  99,
  false,
  'ENGELLİ ÇOCUĞU/YAKINI OLAN ÇALIŞANLARIN HAKLARI

',
  '["Geçerli engelli sağlık kurulu raporunu hazırlayın (ağır engelli / ÇÖZGER çok ileri–ÖKGV / tam bağımlı)","Kurumunuzun insan kaynakları / izin birimine yazılı başvuru yapın","Nöbet / gece vardiyası muafiyeti ve günlük bakım kolaylığı talep edin","Özel eğitim alınıyorsa haftalık 8 saat eğitim iznini ayrıca belirtin","TSK / EGM / hastane personeliyseniz kurumunuzun iç genelgesini ekleyin"]'::jsonb,
  'Kurum İK · Başbakanlık Genelgesi 2010/2 · EGM 2015/55 · TSK İzin Yönetmeliği',
  5,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mazeret-izin',
  'Mazeret İzni Hakkı (%70+ / Süreğen Hastalık)',
  'Yılda 10 güne kadar ücretli',
  'izin',
  '📋',
  4280640491,
  4293916415,
  70,
  18,
  false,
  'En az yüzde %70 oranında engelli ya da süreğen hastalığı olan çocukları için tüm çalışanlara; ',
  '["Çocuğun %70+ engelli veya süreğen hastalık belgesini hazırlayın","Hastalık durumunda doktor / hekim raporu alın","Kurumunuza yazılı mazeret izni talebi verin (ana veya babadan yalnızca biri)","Yıllık izin bitmiş olsa da talep edilebilir; 10 günü parçalı kullanabilirsiniz","İşçi / sözleşmeli / muvazzaf personel aynı hakkı kullanır"]'::jsonb,
  'Kurum İK · DMK md. 104 · İş Kanunu',
  6,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yari-zamanli-anne',
  'Engelli Bebekte Yarı Zamanlı Çalışma Hakkı',
  '12. aya kadar tam maaşlı yarı zamanlı',
  'izin',
  '👶',
  4292552567,
  4294832888,
  40,
  6,
  false,
  'Engelli çocuğu olan annelere yarı zamanlı çalışma hakkı

',
  '["Doğumda veya ilk 12 ay içinde engellilik tespitini belgeleyen sağlık raporunu alın","Kurum İK birimine yazılı yarı zamanlı çalışma talebi verin","Bebek 12 ayını doldurana kadar tam maaşlı yarı zamanlı çalışma uygulanır","Memur (DMK) ve işçi (İş Kanunu) anneler bu haktan yararlanır"]'::jsonb,
  'Kurum İK · Devlet Memurları Kanunu · İş Kanunu',
  7,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'otv-muafiyet',
  'ÖTV Muafiyetli Araç Alımı',
  '2026 fiyat sınırı: ₺2.873.900',
  'vergi',
  '🚗',
  4292901471,
  4294832364,
  40,
  99,
  false,
  '4 farklı grup engelli bireye ÖTV istisnası tanınmaktadır. 10 yılda bir hak kullanılabilir; araç beş yıl geçmeden ÖTV ödenmeksizin satılamaz.

',
  '["Sağlık Kurulu Raporu alın (hangi gruba girdiğinizi öğrenin)","Vergi Dairesi''ne başvurarak ÖTV istisna belgesi düzenletin","Grup 4 iseniz: geçerli B sınıfı engelli sürücü belgesi şarttır","87.03 kapsamında araçta fiyat ₺2.873.900''ı (2026) aşmamalıdır","Yetkili bayi ile sözleşme yapılır; araç engelli adına tescil edilir","5 yıl sonra ÖTV ödenmeksizin satış hakkı doğar"]'::jsonb,
  'Vergi Dairesi · Trafik Tescil · Araç Yetkili Bayii',
  8,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mtv-muafiyet',
  'MTV Muafiyeti (Araç Vergisi)',
  'Tam muafiyet veya kısmi',
  'vergi',
  '📃',
  4286331629,
  4294308095,
  40,
  99,
  false,
  '%90 ve üzeri engellilik: Kendi adına kayıtlı araçta özel tertibat şartı aranmaksızın MTV''den tam muafiyet. Tam teşekküllü devlet hastanesi sağlık kurulu raporu vergi dairesine ibraz edilir.

',
  '["%90+ ise: devlet hastanesi sağlık kurulu raporu hazırlayın","Araç tescil belgesi, engelli kimlik kartı ve raporu vergi dairesine götürün","%90 altı ise ayrıca: araç teknik belgesi, özel tertibat proje raporu ve MTV istisnası bildirim formu gerekir","Vergi dairesi muafiyet işlemini tescil eder; yıllık otomatik uygulanır"]'::jsonb,
  'Bağlı olunan Vergi Dairesi',
  9,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'park-karti',
  'Engelli Park Kartı (Mavi İşaret)',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı yalnızca üzerine araç tescil edilmiş engellilere verilir. Kullanım için Trafik Denetleme Amirliğine başvuru gerekir.

',
  '["Engelli sağlık kurulu raporu ve araç tescil belgesiyle başvurun","Trafik Denetleme Şube Amirliği veya İlçe Emniyet Müdürlüğü''ne gidin","Park kartı (mavi işaret) ücretsiz teslim edilir","Kartı araç ön camına asın; her park değişiminde görünür yerde bulundurulmalıdır"]'::jsonb,
  'Trafik Denetleme Şube/Bürü Amirliği · İlçe Emniyet Müdürlüğü',
  10,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-ehliyet',
  'Engelli Sürücü Belgesi (B Sınıfı)',
  'Ücretsiz / Normal ücret',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  '1 Ocak 2016''dan önce alınan H sınıfı engelli sürücü belgeleri 31/07/2025''e kadar geçerliydi. Bu tarihten sonra B sınıfı sürücü belgesi (engellilik kodları işlenmiş) geçerlidir.

',
  '["18 yaşını doldurun","Aile hekimine başvurarak İl Sağlık Komisyonu''na sevk alın","Komisyon raporuyla sürücü kursu ve sınavına katılın","Engellilik durumuna uygun özel tertibat kodları B sınıfı belgeye işlenir"]'::jsonb,
  'Aile Hekimi → İl Sağlık Komisyonu → Sürücü Kursu → Trafik Tescil',
  11,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kdv-indirim',
  'KDV İndirimi – Medikal & Araç',
  '%18''den %1''e',
  'vergi',
  '🛒',
  4294223922,
  4294965485,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez/protez ve engelliye özel araç tadilat hizmetlerinde KDV %1 uygulanır.',
  '["Sağlık raporu ve engel kimliği ile medikal firmaya gidin","Faturada ''engelli bireye satış'' ibaresi istenir","Araç tadilat için ÖTV muafiyet belgesi gerekir"]'::jsonb,
  'SGK sözleşmeli medikal firmalar · Yetkili servisler',
  12,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'gelir-vergisi',
  'Gelir Vergisi İndirimi',
  '₺3.000–₺6.000 / yıl',
  'vergi',
  '📊',
  4288441779,
  4294307579,
  40,
  99,
  false,
  'Engelli çalışanlara ve engelli çocuğu olan çalışan ebeveynlere yıllık gelir vergisi matrahından indirim hakkı tanınır.',
  '["İşverenin insan kaynakları birimine engel raporunu ibraz edin","Vergi dairesine de bildirim yapılması önerilir","Özel eğitim ve sağlık harcamaları da indirim kapsamına girebilir"]'::jsonb,
  'Vergi Dairesi · İşveren İK',
  13,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ozel-egitim',
  'Ücretsiz Özel Eğitim',
  'Aylık 12 saat (8+4)',
  'egitim',
  '📚',
  4288441779,
  4294307579,
  0,
  18,
  false,
  'MEB''e bağlı özel eğitim ve rehabilitasyon merkezlerinde aylık 8 saat bireysel + 4 saat grup eğitimi (toplam 12 saat) ücretsiz hizmet. RAM raporu zorunludur.',
  '["RAM''a başvurun (randevu alın)","RAM raporu ve Özel Eğitim Değerlendirme Kurulu kararı alın","MEB sözleşmeli rehabilitasyon merkezini seçin","Her yıl yenileme gerekir"]'::jsonb,
  'RAM (Rehberlik ve Araştırma Merkezi)',
  14,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ram-raporu',
  'RAM Raporu Nasıl Alınır?',
  'Ücretsiz',
  'egitim',
  '📋',
  4284196994,
  4293193961,
  0,
  18,
  false,
  'Özel eğitim hizmetlerinden yararlanmak için zorunlu değerlendirme raporu. Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır.',
  '["İlçenizdeki RAM''a randevu alın","Doktor raporu, okul belgesi, kimlik fotokopisiyle gidin","Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır","Rapor genellikle 1-3 hafta içinde hazırlanır"]'::jsonb,
  'Rehberlik ve Araştırma Merkezi (RAM)',
  15,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kaynaştirma',
  'Kaynaştırma Eğitimi Hakkı',
  'Anayasal hak',
  'egitim',
  '🏫',
  4279921482,
  4293457390,
  0,
  18,
  false,
  'Engelli çocuklar, akranlarıyla birlikte eğitim alma hakkına sahiptir. Okul, destek eğitim odası ve özel kaynaştırma programı oluşturmak zorundadır.',
  '["RAM raporuyla okul müdürlüğüne başvurun","Destek eğitim odası saatleri planlanır","BEP (Bireyselleştirilmiş Eğitim Planı) hazırlanır","İlköğretimden liseye kadar sürer"]'::jsonb,
  'İlçe Milli Eğitim Müdürlüğü · Okul Müdürlüğü',
  16,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-kimlik',
  'Engelli Kimlik Kartı',
  'Ücretsiz',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  'Pek çok ayrıcalık ve indirimlere kapı açan resmi kimlik kartı. Nüfus müdürlüğünden veya e-Devlet üzerinden alınır.',
  '["Sağlık Kurulu Raporu (%40+ engel oranı)","Nüfus Müdürlüğü''ne başvurun veya e-Devlet kullanın","Fotoğraf ve kimlik fotokopisi","1-2 hafta içinde kart teslim edilir"]'::jsonb,
  'İlçe Nüfus Müdürlüğü · e-Devlet',
  17,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ulasim',
  'Ücretsiz Toplu Taşıma',
  'Belediye kartı',
  'ulasim',
  '🚌',
  4285242052,
  4293850619,
  40,
  99,
  false,
  'Engelli kimlik kartı ile metro, otobüs, tramvayda ücretsiz veya indirimli seyahat. Refakatçi de bazı illerde indirimden yararlanır.',
  '["Engelli kimlik kartı ile belediye ulaşım müdürlüğüne başvurun","İstanbul: İETT, Ankara: EGO, İzmir: ESHOT","Ücretsiz akıllı kart verilir","Bir refakatçi de indirimden yararlanır (bazı illerde)"]'::jsonb,
  'Belediye Ulaşım Müdürlükleri',
  18,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'tcdd-thy',
  'TCDD & THY İndirimleri',
  '%50 indirim',
  'ulasim',
  '✈️',
  4292901471,
  4294832364,
  40,
  99,
  false,
  'Tren yolculuklarında %50, Türk Hava Yolları''nda engelli indirim tarifesi. Refakatçi de indirimden yararlanabilir.',
  '["TCDD: bilet alırken engelli kimliği ibraz edin","THY: thy.com''da ''Özel Yolcular'' bölümünden bilet alın","Refakatçi de indirimden yararlanabilir"]'::jsonb,
  'TCDD Bilet Gişeleri · thy.com',
  19,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'sehir-ici-park',
  'Engelli Park Kartı',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı ile engellilere ayrılmış park alanlarını kullanma hakkı tanınır. Ayrıca mavi hatlarda ücretsiz park imkânı mevcuttur.',
  '["Engelli sağlık kurulu raporu ile Belediye Trafik Müdürlüğü''ne başvurun","Engelli park kartı (maviişaret) temin edilir","Araç ön camına asılır"]'::jsonb,
  'Belediye Trafik Müdürlüğü · Emniyet Trafik Birimleri',
  20,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'emlak-vergisi',
  'Emlak Vergisi Muafiyeti',
  '200 m²''ye kadar',
  'vergi',
  '🏡',
  4288441779,
  4294307579,
  0,
  99,
  true,
  'Tek meskeni olan ve belirli gelir sınırının altındaki engelli bireyler emlak vergisinden muaf tutulur. Yıllık gelir kontrolü yapılır.',
  '["Tek meskene sahip olunması gerekir","Yıllık brüt gelir sınırı kontrol edilmeli","Engel raporu ve beyanname ile başvurun"]'::jsonb,
  'İlçe Belediyesi Gelir Müdürlüğü',
  21,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'su-faturasi',
  'Su Faturası İndirimi',
  '%50 indirim',
  'vergi',
  '💧',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli bireyin yaşadığı hanede su ve kanalizasyon faturasında %50''ye kadar indirim. İl ve belediyeye göre kota farklılık gösterebilir.',
  '["Engelli sağlık kurulu raporu ve engelli kimlik kartıyla başvurun","İkametgâh belgesi ve su abonelik sözleşmesi gerekir","İSKİ / ASKİ / İZSU gibi kuruma başvurun","Onaylı indirim bir sonraki faturadan itibaren yansıtılır"]'::jsonb,
  'Belediye Su ve Kanalizasyon İdaresi (İSKİ / ASKİ / İZSU)',
  22,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'telefon-indirimi',
  'Telefon & İnternet İndirimi',
  '%25–50 indirim',
  'vergi',
  '📱',
  4279286145,
  4293721589,
  40,
  99,
  false,
  'Engelli abonelere BTK kapsamında internet ve telefon faturalarında indirim uygulanmaktadır. Operatörden talep edilmesi gerekir.',
  '["Engelli kimlik kartı ile GSM operatörüne başvurun","Engel raporu ibraz edin","Engelli tarifesine geçiş yapılır"]'::jsonb,
  'GSM Operatör Müşteri Hizmetleri · BTK',
  23,
  true
);

update public.app_catalog_versions set version = version + 1, updated_at = now() where name = 'rights';
notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: admin_moderation.sql
-- =============================================================================

-- Engelsiz Club — admin moderasyon (silme) yetkileri
-- Supabase Dashboard → SQL Editor → New query → bu dosyanın tamamını çalıştır
-- Admin: sakir.caykara@gmail.com
--
-- ÖNEMLİ: Sadece RLS policy yetmezse (silindi görünüp yenilemede geri geliyorsa)
-- aşağıdaki SECURITY DEFINER fonksiyonlar kesin çözüm sağlar.

-- ── RLS: admin silme politikaları ──────────────────────────────────────────

-- Sohbet: admin tüm mesajları görür / siler
drop policy if exists "sohbet_select_admin" on public.sohbet_mesajlari;
create policy "sohbet_select_admin"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "sohbet_delete_admin" on public.sohbet_mesajlari;
create policy "sohbet_delete_admin"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- İlanlar: admin herhangi bir ilanı silebilir
drop policy if exists "ilanlar_delete_admin" on public.ilanlar;
create policy "ilanlar_delete_admin"
  on public.ilanlar for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum gönderileri
drop policy if exists "forum_delete_admin" on public.forum_posts;
create policy "forum_delete_admin"
  on public.forum_posts for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum yorumları
drop policy if exists "forum_comments_delete_admin" on public.forum_comments;
create policy "forum_comments_delete_admin"
  on public.forum_comments for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- ── Kesin çözüm: admin RPC (RLS’yi bypass eder, e-posta kontrolü içeride) ──

create or replace function public.admin_delete_forum_post(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_posts where id = p_id;
end;
$$;

create or replace function public.admin_delete_forum_comment(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_comments where id = p_id;
end;
$$;

revoke all on function public.admin_delete_forum_post(bigint) from public;
revoke all on function public.admin_delete_forum_comment(bigint) from public;
grant execute on function public.admin_delete_forum_post(bigint) to authenticated;
grant execute on function public.admin_delete_forum_comment(bigint) to authenticated;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: admin_top_iyilik_puani.sql
-- =============================================================================

-- Admin: iyilik puanı sıralması (en yüksekten aşağa)
-- Supabase SQL Editor'da bir kez çalıştırın.

create or replace function public.admin_top_iyilik_puani(p_limit int default 10)
returns table (
  rank int,
  owner_email text,
  display_name text,
  kredi int,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin bu listeyi görebilir';
  end if;

  return query
  select
    row_number() over (order by up.kredi desc, up.updated_at desc)::int as rank,
    up.owner_email::text,
    coalesce(
      nullif(trim(up.profil ->> 'adSoyad'), ''),
      split_part(up.owner_email, '@', 1)
    )::text as display_name,
    up.kredi::int,
    up.updated_at
  from public.user_profiles up
  where lower(trim(up.owner_email)) <> 'sakir.caykara@gmail.com'
    and coalesce(up.kredi, 0) > 0
  order by up.kredi desc, up.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
end;
$$;

revoke all on function public.admin_top_iyilik_puani(int) from public;
grant execute on function public.admin_top_iyilik_puani(int) to authenticated;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: guest_public_read.sql
-- =============================================================================

-- Misafir (anon) kullanıcılar: ilan / forum sadece okuma
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- Yazma (insert/update/delete) authenticated ile kalır.

-- İlanlar
drop policy if exists "ilanlar_select_anon" on public.ilanlar;
create policy "ilanlar_select_anon"
  on public.ilanlar for select
  to anon
  using (true);

-- Forum gönderileri
drop policy if exists "forum_select_anon" on public.forum_posts;
create policy "forum_select_anon"
  on public.forum_posts for select
  to anon
  using (true);

-- Forum yorumları
drop policy if exists "forum_comments_select_anon" on public.forum_comments;
create policy "forum_comments_select_anon"
  on public.forum_comments for select
  to anon
  using (true);

-- Duyurular / kayan story (yalnız aktif)
drop policy if exists "duyuru_select_anon" on public.duyurular;
create policy "duyuru_select_anon"
  on public.duyurular for select
  to anon
  using (is_active = true);

-- Profil fotoğrafları (avatar) — fonksiyon yoksa atlanır
do $$
begin
  grant execute on function public.get_user_photos(text[]) to anon;
exception
  when undefined_function then null;
end $$;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: google_places_proxy.sql
-- =============================================================================

-- ESKİ: Legacy Places REST proxy (nearbysearch/json).
-- Artık uygulama Places API (New) kullanıyor (places.googleapis.com/v1/...).
-- Bu SQL'i çalıştırmanıza gerek yok; Cloud Errors'ı azaltmak için
-- legacy Places API çağrılarını kapatın / anahtar kısıtlarını sadeleştirin.
--
-- Gerekirse fonksiyonu kaldırmak için:
--   drop function if exists public.google_places_proxy(jsonb);
--   drop function if exists public._uri_encode(text);

select 1;


-- =============================================================================
-- FILE: cross_platform_sync.sql
-- =============================================================================

-- Engelsiz Club — teklif veren kendi gönderdiği bildirimleri görebilsin
-- (cihazlar arası "bu ilana teklif verdim" senkronu)

drop policy if exists "bildirim_select_actor" on public.bildirimler;
create policy "bildirim_select_actor"
  on public.bildirimler for select
  to authenticated
  using (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Realtime: inbox / sohbet anlık güncellensin
do $$
begin
  alter publication supabase_realtime add table public.bildirimler;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_posts;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_comments;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: play_ready.sql
-- =============================================================================

-- Engelsiz Club — Play Store öncesi Supabase (SQL Editor’da sırayla çalıştır)
-- Eksik tablolar/policy’ler için güvenli (IF EXISTS / DROP IF EXISTS)

-- 1) İlan sahibi güncelleme
--    ilanlar_update_own.sql
--    bildirimler_mesaj_collapse.sql
--    user_kredi.sql (yorumlar güncel)

-- Aşağısı Dashboard’da tek seferde çalıştırılabilir:

-- İlan UPDATE (sahip: owner_id veya e-posta)
update public.ilanlar i
set owner_id = u.id
from auth.users u
where i.owner_id is null
  and lower(trim(i.owner_email)) = lower(u.email);

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Mesaj bildirimi: gönderen seç + güncelle (üst üste binmesin)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "bildirim_update_actor_mesaj" on public.bildirimler;
create policy "bildirim_update_actor_mesaj"
  on public.bildirimler for update
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Kredi kolonları
alter table public.user_profiles
  add column if not exists kredi int not null default 0;
alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

notify pgrst, 'reload schema';

