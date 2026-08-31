-- Ana sayfa kutucuk kapakları: Gezi Rehberi | Kampanyalar | Etkinlikler
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Tümünü yapıştırıp Run (additive; IF NOT EXISTS; mevcut gezi/kampanya tablolarına dokunmaz)
-- Dart: gezi_kampanya_tiles / tile_key = gezi | kampanya | etkinlik
-- Mevcut kurulumda etkinlik tablosu + kapak: etkinlikler.sql
-- Herkes okur; yazma yalnız admin.

create table if not exists public.gezi_kampanya_tiles (
  tile_key text primary key,
  image_url text not null default '',
  updated_by text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.gezi_kampanya_tiles
  drop constraint if exists gezi_kampanya_tiles_key_chk;

alter table public.gezi_kampanya_tiles
  add constraint gezi_kampanya_tiles_key_chk
    check (tile_key in ('gezi', 'kampanya', 'etkinlik'));

insert into public.gezi_kampanya_tiles (tile_key, image_url)
values ('gezi', ''), ('kampanya', ''), ('etkinlik', '')
on conflict (tile_key) do nothing;

alter table public.gezi_kampanya_tiles enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.gezi_kampanya_tiles to postgres, service_role;
grant select on table public.gezi_kampanya_tiles to anon, authenticated;
grant insert, update, delete on table public.gezi_kampanya_tiles to authenticated;

drop policy if exists "gezi_kampanya_tiles_select" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_select"
  on public.gezi_kampanya_tiles for select
  to anon, authenticated
  using (true);

drop policy if exists "gezi_kampanya_tiles_insert_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_insert_admin"
  on public.gezi_kampanya_tiles for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gezi_kampanya_tiles_update_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_update_admin"
  on public.gezi_kampanya_tiles for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "gezi_kampanya_tiles_delete_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_delete_admin"
  on public.gezi_kampanya_tiles for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
