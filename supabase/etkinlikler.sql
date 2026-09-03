-- Etkinlikler (Kampanyalar ile aynı model: görsel + başlık + açıklama + il / tüm ülke)
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- Çalıştırma sırası (mevcut kurulum):
--   1) gezi_kampanya.sql          (zaten uygulandıysa atlayın)
--   2) gezi_kampanya_tiles.sql    (zaten uygulandıysa atlayın)
--   3) BU DOSYA: etkinlikler.sql
--
-- Additive: mevcut gezi_rehberi / kampanyalar satırlarına dokunmaz.
-- Ana sayfa kapağı: gezi_kampanya_tiles.tile_key = 'etkinlik'
-- Dart: GeziKampanyaKind.etkinlik / loadEtkinlikItems
--
-- city:
--   NULL, '', 'Türkiye', 'genel'  → tüm ülkede geçerli
--   'Ankara', 'İzmir', …          → o ile özel (kCityNames)

create table if not exists public.etkinlikler (
  id bigint generated always as identity primary key,
  title text not null default '',
  image_url text not null,
  description text not null default '',
  city text,
  sort_order int not null default 0,
  sort_index int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

-- Mevcut tablo (CREATE IF NOT EXISTS atlanır): Dart insert her zaman sort_order gönderir
alter table public.etkinlikler
  add column if not exists sort_order int not null default 0;

alter table public.etkinlikler
  add column if not exists sort_index int not null default 0;

update public.etkinlikler
set sort_order = sort_index
where coalesce(sort_order, 0) = 0 and coalesce(sort_index, 0) <> 0;

create index if not exists etkinlikler_sort_idx
  on public.etkinlikler (is_active, sort_index, created_at desc);

create index if not exists etkinlikler_city_idx
  on public.etkinlikler (city, is_active, sort_index, created_at desc);

alter table public.etkinlikler enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.etkinlikler to postgres, service_role;
grant select on table public.etkinlikler to anon, authenticated;
grant insert, update, delete on table public.etkinlikler to authenticated;

drop policy if exists "etkinlik_select_all" on public.etkinlikler;
create policy "etkinlik_select_all"
  on public.etkinlikler for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_insert_admin" on public.etkinlikler;
create policy "etkinlik_insert_admin"
  on public.etkinlikler for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_update_admin" on public.etkinlikler;
create policy "etkinlik_update_admin"
  on public.etkinlikler for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_delete_admin" on public.etkinlikler;
create policy "etkinlik_delete_admin"
  on public.etkinlikler for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Ana sayfa kutucuk: tile_key = etkinlik (mevcut gezi/kampanya kısıtını genişletir)
alter table public.gezi_kampanya_tiles
  drop constraint if exists gezi_kampanya_tiles_key_chk;

alter table public.gezi_kampanya_tiles
  add constraint gezi_kampanya_tiles_key_chk
  check (tile_key in ('gezi', 'kampanya', 'etkinlik'));

insert into public.gezi_kampanya_tiles (tile_key, image_url)
values ('etkinlik', '')
on conflict (tile_key) do nothing;

notify pgrst, 'reload schema';
