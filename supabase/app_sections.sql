-- Ana sayfa bölüm kartları (kapak + görünen ad).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Additive. Dart: lib/app_sections_store.dart
-- Herkes okur; yazma yalnız super admin.

create table if not exists public.app_sections (
  section_key text primary key,
  title text not null default '',
  cover_image_url text not null default '',
  updated_by text not null default '',
  updated_at timestamptz not null default now(),
  constraint app_sections_key_chk
    check (
      section_key = lower(trim(section_key))
      and char_length(section_key) >= 3
    )
);

create or replace function public.app_sections_norm()
returns trigger
language plpgsql
as $$
begin
  new.section_key := lower(trim(new.section_key));
  new.title := trim(new.title);
  new.cover_image_url := trim(new.cover_image_url);
  new.updated_by := lower(trim(new.updated_by));
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists app_sections_norm_tg on public.app_sections;
create trigger app_sections_norm_tg
  before insert or update on public.app_sections
  for each row execute function public.app_sections_norm();

insert into public.app_sections (section_key, title, cover_image_url)
values ('uzman_kosesi', 'Uzman Profilleri Köşesi', '')
on conflict (section_key) do update
set title = excluded.title
where public.app_sections.title in ('Uzman Köşesi', '');

alter table public.app_sections enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.app_sections to postgres, service_role;
grant select on table public.app_sections to anon, authenticated;
grant insert, update, delete on table public.app_sections to authenticated;

drop policy if exists "app_sections_select" on public.app_sections;
create policy "app_sections_select"
  on public.app_sections for select
  to anon, authenticated
  using (true);

drop policy if exists "app_sections_insert_admin" on public.app_sections;
create policy "app_sections_insert_admin"
  on public.app_sections for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "app_sections_update_admin" on public.app_sections;
create policy "app_sections_update_admin"
  on public.app_sections for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "app_sections_delete_admin" on public.app_sections;
create policy "app_sections_delete_admin"
  on public.app_sections for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
