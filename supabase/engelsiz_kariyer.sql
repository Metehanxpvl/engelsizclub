-- Engelsiz Kariyer: kapak kutusu + yalnızca admin override (katalog JSON'dadır).
-- Dashboard SQL Editor → çalıştırın (additive).
-- İŞKUR ilanları public.kariyer_* tablosuna TOHUMLANMAZ.

alter table public.gezi_kampanya_tiles
  drop constraint if exists gezi_kampanya_tiles_key_chk;

alter table public.gezi_kampanya_tiles
  add constraint gezi_kampanya_tiles_key_chk
    check (tile_key in ('gezi', 'kampanya', 'etkinlik', 'kariyer'));

insert into public.gezi_kampanya_tiles (tile_key, image_url)
values ('kariyer', '')
on conflict (tile_key) do nothing;

alter table public.section_editors
  drop constraint if exists section_editors_key_chk;

alter table public.section_editors
  add constraint section_editors_key_chk
    check (section_key in ('duyurular', 'gezi', 'kampanya', 'etkinlik', 'kariyer'));

create table if not exists public.kariyer_overrides (
  job_id text primary key,
  hidden boolean not null default false,
  title text not null default '',
  city text not null default '',
  date_text text not null default '',
  apply_url text not null default '',
  custom boolean not null default false,
  updated_by text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.kariyer_overrides enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.kariyer_overrides to postgres, service_role;
grant select on table public.kariyer_overrides to anon, authenticated;
grant insert, update, delete on table public.kariyer_overrides to authenticated;

drop policy if exists "kariyer_overrides_select" on public.kariyer_overrides;
create policy "kariyer_overrides_select"
  on public.kariyer_overrides for select
  to anon, authenticated
  using (true);

drop policy if exists "kariyer_overrides_insert" on public.kariyer_overrides;
create policy "kariyer_overrides_insert"
  on public.kariyer_overrides for insert
  to authenticated
  with check (public.is_section_editor('kariyer'));

drop policy if exists "kariyer_overrides_update" on public.kariyer_overrides;
create policy "kariyer_overrides_update"
  on public.kariyer_overrides for update
  to authenticated
  using (public.is_section_editor('kariyer'))
  with check (public.is_section_editor('kariyer'));

drop policy if exists "kariyer_overrides_delete" on public.kariyer_overrides;
create policy "kariyer_overrides_delete"
  on public.kariyer_overrides for delete
  to authenticated
  using (public.is_section_editor('kariyer'));

notify pgrst, 'reload schema';
