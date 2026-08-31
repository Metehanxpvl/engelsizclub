-- Bölüm yöneticileri: super admin (sakir.caykara@gmail.com) e-posta atar.
-- Atanan kişi yalnız o bölümü ekler / düzenler / siler / kapak değiştirir.
-- isAppAdmin olmaz: kullanıcılar, keşfet, ilanlar, daha fazlası menüsü vs. kapalı kalır.
--
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Additive: mevcut tablolara satır eklemez; yalnız yazma politikalarını genişletir.
--
-- Dart: canEditSection(email, SectionKey) — lib/section_editors.dart

create table if not exists public.section_editors (
  id bigint generated always as identity primary key,
  email text not null,
  section_key text not null,
  created_by text not null default '',
  created_at timestamptz not null default now(),
  constraint section_editors_email_chk
    check (
      email = lower(trim(email))
      and char_length(email) >= 3
      and position('@' in email) > 1
    ),
  constraint section_editors_key_chk
    check (section_key in ('duyurular', 'gezi', 'kampanya', 'etkinlik')),
  constraint section_editors_email_section_uq unique (email, section_key)
);

create index if not exists section_editors_email_idx
  on public.section_editors (email);

create index if not exists section_editors_section_idx
  on public.section_editors (section_key);

create or replace function public.section_editors_norm()
returns trigger
language plpgsql
as $$
begin
  new.email := lower(trim(new.email));
  new.section_key := lower(trim(new.section_key));
  return new;
end;
$$;

drop trigger if exists section_editors_norm_tg on public.section_editors;
create trigger section_editors_norm_tg
  before insert or update on public.section_editors
  for each row execute function public.section_editors_norm();

alter table public.section_editors enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.section_editors to postgres, service_role;
grant select on table public.section_editors to authenticated;
grant insert, update, delete on table public.section_editors to authenticated;

-- Super admin: tüm satırlar. Diğerleri: yalnız kendi e-postaları (yetki kontrolü).
drop policy if exists "section_editors_select" on public.section_editors;
create policy "section_editors_select"
  on public.section_editors for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
    or email = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "section_editors_insert" on public.section_editors;
create policy "section_editors_insert"
  on public.section_editors for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "section_editors_update" on public.section_editors;
create policy "section_editors_update"
  on public.section_editors for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "section_editors_delete" on public.section_editors;
create policy "section_editors_delete"
  on public.section_editors for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Super admin veya o bölümün editörü. SECURITY INVOKER: section_editors RLS
-- (kendi satırı / super admin) EXISTS kontrolünü karşılar; rastgele yazma yok.
create or replace function public.is_section_editor(p_section text)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
    or exists (
      select 1
      from public.section_editors se
      where se.email = lower(coalesce(auth.jwt() ->> 'email', ''))
        and se.section_key = p_section
    );
$$;

grant execute on function public.is_section_editor(text) to anon, authenticated;

-- ── duyurular (stories) ────────────────────────────────────────────────────
drop policy if exists "duyuru_select_auth" on public.duyurular;
create policy "duyuru_select_auth"
  on public.duyurular for select
  to authenticated
  using (
    is_active = true
    or public.is_section_editor('duyurular')
  );

drop policy if exists "duyuru_insert_admin" on public.duyurular;
create policy "duyuru_insert_admin"
  on public.duyurular for insert
  to authenticated
  with check (public.is_section_editor('duyurular'));

drop policy if exists "duyuru_update_admin" on public.duyurular;
create policy "duyuru_update_admin"
  on public.duyurular for update
  to authenticated
  using (public.is_section_editor('duyurular'))
  with check (public.is_section_editor('duyurular'));

drop policy if exists "duyuru_delete_admin" on public.duyurular;
create policy "duyuru_delete_admin"
  on public.duyurular for delete
  to authenticated
  using (public.is_section_editor('duyurular'));

-- ── gezi_rehberi ───────────────────────────────────────────────────────────
drop policy if exists "gezi_select_all" on public.gezi_rehberi;
create policy "gezi_select_all"
  on public.gezi_rehberi for select
  to anon, authenticated
  using (
    is_active = true
    or public.is_section_editor('gezi')
  );

drop policy if exists "gezi_insert_admin" on public.gezi_rehberi;
create policy "gezi_insert_admin"
  on public.gezi_rehberi for insert
  to authenticated
  with check (public.is_section_editor('gezi'));

drop policy if exists "gezi_update_admin" on public.gezi_rehberi;
create policy "gezi_update_admin"
  on public.gezi_rehberi for update
  to authenticated
  using (public.is_section_editor('gezi'))
  with check (public.is_section_editor('gezi'));

drop policy if exists "gezi_delete_admin" on public.gezi_rehberi;
create policy "gezi_delete_admin"
  on public.gezi_rehberi for delete
  to authenticated
  using (public.is_section_editor('gezi'));

-- ── kampanyalar ────────────────────────────────────────────────────────────
drop policy if exists "kampanya_select_all" on public.kampanyalar;
create policy "kampanya_select_all"
  on public.kampanyalar for select
  to anon, authenticated
  using (
    is_active = true
    or public.is_section_editor('kampanya')
  );

drop policy if exists "kampanya_insert_admin" on public.kampanyalar;
create policy "kampanya_insert_admin"
  on public.kampanyalar for insert
  to authenticated
  with check (public.is_section_editor('kampanya'));

drop policy if exists "kampanya_update_admin" on public.kampanyalar;
create policy "kampanya_update_admin"
  on public.kampanyalar for update
  to authenticated
  using (public.is_section_editor('kampanya'))
  with check (public.is_section_editor('kampanya'));

drop policy if exists "kampanya_delete_admin" on public.kampanyalar;
create policy "kampanya_delete_admin"
  on public.kampanyalar for delete
  to authenticated
  using (public.is_section_editor('kampanya'));

-- ── etkinlikler ────────────────────────────────────────────────────────────
drop policy if exists "etkinlik_select_all" on public.etkinlikler;
create policy "etkinlik_select_all"
  on public.etkinlikler for select
  to anon, authenticated
  using (
    is_active = true
    or public.is_section_editor('etkinlik')
  );

drop policy if exists "etkinlik_insert_admin" on public.etkinlikler;
create policy "etkinlik_insert_admin"
  on public.etkinlikler for insert
  to authenticated
  with check (public.is_section_editor('etkinlik'));

drop policy if exists "etkinlik_update_admin" on public.etkinlikler;
create policy "etkinlik_update_admin"
  on public.etkinlikler for update
  to authenticated
  using (public.is_section_editor('etkinlik'))
  with check (public.is_section_editor('etkinlik'));

drop policy if exists "etkinlik_delete_admin" on public.etkinlikler;
create policy "etkinlik_delete_admin"
  on public.etkinlikler for delete
  to authenticated
  using (public.is_section_editor('etkinlik'));

-- ── gezi_kampanya_tiles: yalnız o tile_key'in editörü kapağı değiştirir ────
drop policy if exists "gezi_kampanya_tiles_insert_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_insert_admin"
  on public.gezi_kampanya_tiles for insert
  to authenticated
  with check (public.is_section_editor(tile_key));

drop policy if exists "gezi_kampanya_tiles_update_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_update_admin"
  on public.gezi_kampanya_tiles for update
  to authenticated
  using (public.is_section_editor(tile_key))
  with check (public.is_section_editor(tile_key));

drop policy if exists "gezi_kampanya_tiles_delete_admin" on public.gezi_kampanya_tiles;
create policy "gezi_kampanya_tiles_delete_admin"
  on public.gezi_kampanya_tiles for delete
  to authenticated
  using (public.is_section_editor(tile_key));

notify pgrst, 'reload schema';
