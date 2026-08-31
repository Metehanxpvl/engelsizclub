-- Gezi Rehberi (81 il görselleri) + Kampanyalar
-- Supabase Dashboard → SQL Editor → çalıştırın
-- Misafir (anon) aktif kayıtları okur; yazma yalnız admin.
-- Ana sayfa kutucuk kapakları: gezi_kampanya_tiles.sql

create table if not exists public.gezi_rehberi (
  id bigint generated always as identity primary key,
  city_name text not null,
  city_slug text not null,
  title text not null default '',
  image_url text not null,
  description text not null default '',
  sort_order int not null default 0,
  sort_index int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists gezi_rehberi_city_idx
  on public.gezi_rehberi (city_slug, is_active, sort_order, id);

-- Mevcut kurulum: title + il içi 1. 2. 3. için gezi_rehberi_title.sql

create index if not exists gezi_rehberi_created_idx
  on public.gezi_rehberi (created_at desc);

create table if not exists public.kampanyalar (
  id bigint generated always as identity primary key,
  title text not null default '',
  image_url text not null,
  description text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists kampanyalar_sort_idx
  on public.kampanyalar (is_active, sort_order, created_at desc);

alter table public.gezi_rehberi enable row level security;
alter table public.kampanyalar enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.gezi_rehberi to postgres, service_role;
grant all on table public.kampanyalar to postgres, service_role;
grant select on table public.gezi_rehberi to anon, authenticated;
grant select on table public.kampanyalar to anon, authenticated;
grant insert, update, delete on table public.gezi_rehberi to authenticated;
grant insert, update, delete on table public.kampanyalar to authenticated;

-- Gezi: herkes aktifleri okur; admin pasifleri de görür
drop policy if exists "gezi_select_all" on public.gezi_rehberi;
create policy "gezi_select_all"
  on public.gezi_rehberi for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gezi_insert_admin" on public.gezi_rehberi;
create policy "gezi_insert_admin"
  on public.gezi_rehberi for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gezi_update_admin" on public.gezi_rehberi;
create policy "gezi_update_admin"
  on public.gezi_rehberi for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gezi_delete_admin" on public.gezi_rehberi;
create policy "gezi_delete_admin"
  on public.gezi_rehberi for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Kampanya: aynı RLS
drop policy if exists "kampanya_select_all" on public.kampanyalar;
create policy "kampanya_select_all"
  on public.kampanyalar for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kampanya_insert_admin" on public.kampanyalar;
create policy "kampanya_insert_admin"
  on public.kampanyalar for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kampanya_update_admin" on public.kampanyalar;
create policy "kampanya_update_admin"
  on public.kampanyalar for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kampanya_delete_admin" on public.kampanyalar;
create policy "kampanya_delete_admin"
  on public.kampanyalar for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
