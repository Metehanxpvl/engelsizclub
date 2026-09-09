-- Evde Eğitim: aile başvuru taslağı + EK-2 aylık çizelge
-- Kaynak özeti (tam metin kopyalanmaz):
--   MEB Evde Eğitim Hizmetleri Kılavuzu 2025 (ORG M)
--   Özel Eğitim Hizmetleri Yönetmeliği (RG 07.07.2018 / 30471)
--   2.6.2023 RG 32209: Evde Sağlık Hizmeti Sunumu (Sağlık Bakanlığı) — eğitim değildir
-- TC: tam numara saklanmaz; tc_kimlik_no = son 4 hane, tc_kimlik_hash = SHA-256
-- Supabase Dashboard → SQL Editor → çalıştırın

create table if not exists public.evde_egitim_basvurulari (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  hizmet_turu text not null
    check (hizmet_turu in ('evde_egitim_meb', 'evde_destek_kurum')),
  ogrenci_adi_soyadi text,
  -- Son 4 hane; tam TC yazılmaz
  tc_kimlik_no text,
  tc_kimlik_hash text,
  kiminle_oturuyor text,
  oturdugu_ev_kira_mi boolean,
  kendi_odasi_var_mi boolean,
  isinma_turu text,
  dilekce_url text,
  saglik_kurulu_raporu_url text,
  egitsel_degerlendirme_formu_url text,
  egitim_turu text
    check (egitim_turu is null or egitim_turu in ('yuz_yuze', 'uzaktan_canli')),
  -- ilkogretim / ortaogretim_ozel: min 10; ortaogretim: min 16 (Kılavuz 2025 md. 16)
  kademe text
    check (kademe is null or kademe in ('ilkogretim', 'ortaogretim_ozel', 'ortaogretim')),
  haftalik_ders_saati int,
  durum text not null default 'taslak'
    check (durum in ('taslak', 'beklemede', 'ram_incelemede', 'kurul_onaylandi')),
  ek1_veli_sozlesmesi_onaylandi boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint evde_egitim_haftalik_saat_chk check (
    haftalik_ders_saati is null
    or (
      kademe in ('ilkogretim', 'ortaogretim_ozel')
      and haftalik_ders_saati >= 10
    )
    or (
      kademe = 'ortaogretim'
      and haftalik_ders_saati >= 16
    )
  ),
  constraint evde_egitim_tc_son4_chk check (
    tc_kimlik_no is null or tc_kimlik_no ~ '^[0-9]{4}$'
  )
);

create table if not exists public.evde_egitim_aylik_cizelge (
  id uuid primary key default gen_random_uuid(),
  basvuru_id uuid not null
    references public.evde_egitim_basvurulari (id) on delete cascade,
  ders_tarihi date not null,
  ders_adi text,
  islenen_kazanim text,
  ogretmen_id uuid,
  veli_onay_kodu text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists evde_egitim_basvurulari_user_idx
  on public.evde_egitim_basvurulari (user_id, updated_at desc);

create index if not exists evde_egitim_aylik_cizelge_basvuru_idx
  on public.evde_egitim_aylik_cizelge (basvuru_id, ders_tarihi desc);

alter table public.evde_egitim_basvurulari enable row level security;
alter table public.evde_egitim_aylik_cizelge enable row level security;

drop policy if exists "evde_egitim_basvurulari_select_own" on public.evde_egitim_basvurulari;
create policy "evde_egitim_basvurulari_select_own"
  on public.evde_egitim_basvurulari for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "evde_egitim_basvurulari_insert_own" on public.evde_egitim_basvurulari;
create policy "evde_egitim_basvurulari_insert_own"
  on public.evde_egitim_basvurulari for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "evde_egitim_basvurulari_update_own" on public.evde_egitim_basvurulari;
create policy "evde_egitim_basvurulari_update_own"
  on public.evde_egitim_basvurulari for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "evde_egitim_cizelge_select_own" on public.evde_egitim_aylik_cizelge;
create policy "evde_egitim_cizelge_select_own"
  on public.evde_egitim_aylik_cizelge for select
  to authenticated
  using (
    exists (
      select 1 from public.evde_egitim_basvurulari b
      where b.id = evde_egitim_aylik_cizelge.basvuru_id
        and b.user_id = auth.uid()
    )
  );

drop policy if exists "evde_egitim_cizelge_insert_own" on public.evde_egitim_aylik_cizelge;
create policy "evde_egitim_cizelge_insert_own"
  on public.evde_egitim_aylik_cizelge for insert
  to authenticated
  with check (
    exists (
      select 1 from public.evde_egitim_basvurulari b
      where b.id = evde_egitim_aylik_cizelge.basvuru_id
        and b.user_id = auth.uid()
    )
  );

drop policy if exists "evde_egitim_cizelge_update_own" on public.evde_egitim_aylik_cizelge;
create policy "evde_egitim_cizelge_update_own"
  on public.evde_egitim_aylik_cizelge for update
  to authenticated
  using (
    exists (
      select 1 from public.evde_egitim_basvurulari b
      where b.id = evde_egitim_aylik_cizelge.basvuru_id
        and b.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.evde_egitim_basvurulari b
      where b.id = evde_egitim_aylik_cizelge.basvuru_id
        and b.user_id = auth.uid()
    )
  );

grant select, insert, update on table public.evde_egitim_basvurulari to authenticated;
grant select, insert, update on table public.evde_egitim_aylik_cizelge to authenticated;

notify pgrst, 'reload schema';
