-- Güncel Duyurular & Haberler (Instagram story tarzı)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.duyurular (
  id bigint generated always as identity primary key,
  title text not null,
  body text not null default '',
  image_url text not null default '',
  source_url text,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists duyurular_created_idx
  on public.duyurular (created_at desc);

alter table public.duyurular enable row level security;

-- Herkes okuyabilir (girişli)
drop policy if exists "duyuru_select_auth" on public.duyurular;
create policy "duyuru_select_auth"
  on public.duyurular for select
  to authenticated
  using (true);

-- Yalnız admin ekler
drop policy if exists "duyuru_insert_admin" on public.duyurular;
create policy "duyuru_insert_admin"
  on public.duyurular for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Yalnız admin siler / günceller
drop policy if exists "duyuru_update_admin" on public.duyurular;
create policy "duyuru_update_admin"
  on public.duyurular for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "duyuru_delete_admin" on public.duyurular;
create policy "duyuru_delete_admin"
  on public.duyurular for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
