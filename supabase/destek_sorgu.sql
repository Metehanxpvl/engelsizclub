-- Destek Sorgu katalog + kullanıcı rapor kayıtları
-- Kaynak: SGK SUT EK-3/C resmi XLS (Yür. 24.01.2026)
-- C-2: Desktop + derleme zip (SHA256 aynı)
-- C-3 / C-4 / C-5: 29.06.2026 işlenmiş güncel SUT arşivi
-- Tutarlar tablo SUT FİYATI sütunudur; KDV veya aylık çarpan eklenmez.
-- Supabase Dashboard → SQL Editor → çalıştırın

create table if not exists public.destek_sorgu_urunler (
  id text primary key,
  category text not null,
  category_sort int not null default 0,
  name text not null,
  sut_price numeric(12,2) not null,
  renew_months int not null default 60,
  sort_order int not null default 0,
  is_active boolean not null default true,
  sut_year int not null default 2026,
  updated_at timestamptz not null default now()
);

create table if not exists public.destek_sorgu_kayitlar (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  product_id text not null references public.destek_sorgu_urunler (id),
  quote_price numeric(12,2),
  sut_price numeric(12,2) not null,
  delivery_date date,
  report_end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, product_id)
);

create index if not exists destek_sorgu_urunler_cat_idx
  on public.destek_sorgu_urunler (category_sort, sort_order, id);

create index if not exists destek_sorgu_kayitlar_user_idx
  on public.destek_sorgu_kayitlar (user_id, updated_at desc);

alter table public.destek_sorgu_urunler enable row level security;
alter table public.destek_sorgu_kayitlar enable row level security;

drop policy if exists "destek_sorgu_urunler_select" on public.destek_sorgu_urunler;
create policy "destek_sorgu_urunler_select"
  on public.destek_sorgu_urunler for select
  to anon, authenticated
  using (is_active = true);

drop policy if exists "destek_sorgu_kayitlar_select_own" on public.destek_sorgu_kayitlar;
create policy "destek_sorgu_kayitlar_select_own"
  on public.destek_sorgu_kayitlar for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "destek_sorgu_kayitlar_insert_own" on public.destek_sorgu_kayitlar;
create policy "destek_sorgu_kayitlar_insert_own"
  on public.destek_sorgu_kayitlar for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "destek_sorgu_kayitlar_update_own" on public.destek_sorgu_kayitlar;
create policy "destek_sorgu_kayitlar_update_own"
  on public.destek_sorgu_kayitlar for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "destek_sorgu_kayitlar_delete_own" on public.destek_sorgu_kayitlar;
create policy "destek_sorgu_kayitlar_delete_own"
  on public.destek_sorgu_kayitlar for delete
  to authenticated
  using (user_id = auth.uid());

insert into public.destek_sorgu_urunler
  (id, category, category_sort, name, sut_price, renew_months, sort_order, sut_year)
values
  ('std-manuel', 'Tekerlekli sandalye (EK-3/C-2)', 1, 'OP1342 — STANDART MANUEL TEKERLEKLİ SANDALYE', 1848.00, 60, 1, 2026),
  ('hafif-ped', 'Tekerlekli sandalye (EK-3/C-2)', 1, 'OP1343 — HAFİF MANUEL TEKERLEKLİ SANDALYE', 4435.20, 60, 2, 2026),
  ('pediatrik', 'Tekerlekli sandalye (EK-3/C-2)', 1, 'OP1344 — PEDİATRİK TEKERLEKLİ SANDALYE', 4435.20, 60, 3, 2026),
  ('std-akulu', 'Tekerlekli sandalye (EK-3/C-2)', 1, 'OP1345 — STANDART AKÜLÜ TEKERLEKLİ SANDALYE', 12600.00, 60, 4, 2026),
  ('aktif', 'Özel hallerde karşılanan (EK-3/C-5)', 2, '100072 — AKTİF TEKERLEKLİ SANDALYE', 16934.40, 60, 1, 2026),
  ('ozellikli-akulu', 'Özel hallerde karşılanan (EK-3/C-5)', 2, '100005 — ÖZELLİKLİ AKÜLÜ TEKERLEKLİ SANDALYE', 47040.00, 60, 2, 2026),
  ('havali-yatak', 'Bakım malzemeleri (EK-3/C-2)', 3, 'OP1300 — HAVALI YATAK', 840.00, 60, 1, 2026),
  ('havali-minder', 'Bakım malzemeleri (EK-3/C-2)', 3, 'OP1301 — HAVALI MİNDER', 295.68, 60, 2, 2026),
  ('ayakta', 'Bakım malzemeleri (EK-3/C-2)', 3, 'OP1297 — AYAKTA DİK POZİSYONLAMA CİHAZI (STAND UP WHEELCHAİR) (MANUEL KALKIŞ MANUEL SÜRÜŞ)', 13104.00, 60, 3, 2026),
  ('bez-yetiskin', 'Sarf malzemeler (EK-3/C-4)', 4, 'A10049 — HASTA ALT BEZİ/KÜLOTLU HASTA ALT BEZİ', 6.31, 0, 1, 2026),
  ('bez-cocuk', 'Sarf malzemeler (EK-3/C-4)', 4, 'A10118 — ÇOCUK HASTA ALT BEZİ/ÇOCUK KÜLOTLU HASTA ALT BEZİ', 4.93, 0, 2, 2026),
  ('kafo', 'Ortez (EK-3/C-2)', 5, 'OP1545 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ (YETİŞKİN)', 5312.16, 24, 1, 2026),
  ('kafo-cocuk', 'Ortez (EK-3/C-2)', 5, 'OP1548 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ (2-18 YAŞ ARASI HASTALAR İÇİN)', 3719.52, 12, 2, 2026),
  ('afo', 'Ortez (EK-3/C-2)', 5, 'OP1066 — YÜKSEK YOĞUNLUKLU PLASTİK YÜRÜYÜŞ MOLDU (HARİCİ EKLEMLİ) (PAFO)', 934.08, 12, 3, 2026),
  ('dafo', 'Ortez (EK-3/C-2)', 5, 'OP1062 — YÜKSEK YOĞUNLUKLU PLASTİK YÜRÜYÜŞ MOLDU (SUPRA MALLEOLAR) (AFO/DAFO/SMAFO)', 554.40, 12, 4, 2026),
  ('hkafo', 'Ortez (EK-3/C-2)', 5, 'OP1546 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ BEL KEMERLİ (YETİŞKİN)', 6021.12, 24, 5, 2026),
  ('hkafo-cocuk', 'Ortez (EK-3/C-2)', 5, 'OP1549 — UZUN YÜRÜME ORTEZİ MEKANİK EKLEMLİ BEL KEMERLİ (2-18 YAŞ ARASI HASTALAR İÇİN)', 4213.44, 12, 6, 2026),
  ('korse', 'Ortez (EK-3/C-2)', 5, 'OP1274 — SKOLYOZ ORTEZLERİ (BOSTON, MİAMİ VB TİP PLASTİK TLSO)', 1313.76, 6, 7, 2026),
  ('el-atel', 'Ortez (EK-3/C-2)', 5, 'OP1122 — DİNAMİK EL-BİLEK-PARMAK SPLİNTİ', 628.32, 6, 8, 2026),
  ('trans-tibial', 'Protez (EK-3/C-2)', 6, 'OP1166 — DİZ ALTI PROTEZİ (MODÜLER)', 10735.20, 60, 1, 2026),
  ('transfemoral', 'Protez (EK-3/C-2)', 6, 'OP1189 — DİZ ÜSTÜ PROTEZİ (MEKANİK-MODÜLER)', 17307.36, 60, 2, 2026),
  ('transradial', 'Protez (EK-3/C-2)', 6, 'OP1225 — DİRSEK ALTI PROTEZİ (MEKANİK FONKSİYONEL-MODULER)', 11880.96, 60, 3, 2026),
  ('transhumeral', 'Protez (EK-3/C-2)', 6, 'OP1233 — DİRSEK ÜSTÜ PROTEZİ (MEKANİK FONKSİYONEL-MODULER)', 17895.36, 60, 4, 2026),
  ('cpap', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1011 — CPAP CİHAZI', 3265.92, 120, 1, 2026),
  ('auto-cpap', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1012 — AUTO CPAP', 6531.84, 120, 2, 2026),
  ('bpap-s', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1013 — BPAP S CİHAZI', 7920.00, 120, 3, 2026),
  ('bpap', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1014 — BPAP S/T', 9389.52, 120, 4, 2026),
  ('oksijen', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1009 — OKSİJEN KONSANTRATÖRÜ', 9391.20, 120, 5, 2026),
  ('tasinabilir-oksijen', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1071 — TAŞINABİLİR (PORTABLE) OKSİJEN KONSANTRATÖRÜ (5 KG ALTINDA, ŞARJLI VE YEDEK BATARYA İLE BİRLİKTE)', 30159.36, 120, 6, 2026),
  ('ventilator', 'Solunum cihazları (EK-3/C-3)', 7, 'DO1017 — EV TİPİ MEKANİK VENTİLATÖR (EN AZ BASINÇ DESTEKLİ VENTİLASYON (PSV) İLE BİRLİKTE VOLÜM VE/VEYA BASINÇ KONTROLLÜ VENTİLASYON (VCV, PCV) SAĞLAYAN VENTİLATÖRLER)', 63360.00, 60, 7, 2026)
on conflict (id) do update set
  category = excluded.category,
  category_sort = excluded.category_sort,
  name = excluded.name,
  sut_price = excluded.sut_price,
  renew_months = excluded.renew_months,
  sort_order = excluded.sort_order,
  is_active = true,
  sut_year = excluded.sut_year,
  updated_at = now();

notify pgrst, 'reload schema';
