-- Engelsiz Club — kredi ödeme bildirimleri (Armut tarzı)
-- Supabase Dashboard → SQL Editor → çalıştır
-- Onay: Table Editor'da status = 'onaylandi' yapın; uygulama krediyi yükler.

create table if not exists public.kredi_odemeleri (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null,
  paket_adet int not null check (paket_adet > 0),
  paket_fiyat text not null,
  gonderen_ad text not null,
  not_text text not null default '',
  referans_kodu text not null,
  status text not null default 'beklemede'
    check (status in ('beklemede', 'onaylandi', 'reddedildi')),
  credited boolean not null default false,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists kredi_odemeleri_owner_idx
  on public.kredi_odemeleri (owner_id, created_at desc);
create index if not exists kredi_odemeleri_status_idx
  on public.kredi_odemeleri (status) where status = 'beklemede';

alter table public.kredi_odemeleri enable row level security;

drop policy if exists "kredi_odemeleri_select_own" on public.kredi_odemeleri;
create policy "kredi_odemeleri_select_own"
  on public.kredi_odemeleri for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "kredi_odemeleri_insert_own" on public.kredi_odemeleri;
create policy "kredi_odemeleri_insert_own"
  on public.kredi_odemeleri for insert
  to authenticated
  with check (owner_id = auth.uid());

-- Kullanıcı status değiştiremez; yalnızca onaylı kayıtlarda credited işaretleyebilir.
drop policy if exists "kredi_odemeleri_claim_credit" on public.kredi_odemeleri;
create policy "kredi_odemeleri_claim_credit"
  on public.kredi_odemeleri for update
  to authenticated
  using (owner_id = auth.uid() and status = 'onaylandi' and credited = false)
  with check (owner_id = auth.uid() and status = 'onaylandi' and credited = true);

notify pgrst, 'reload schema';
