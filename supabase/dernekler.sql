-- Ana sayfa Dernekler kutucukları (Bilgi Kütüphanesi üstü)
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Additive. Dart: lib/dernekler_store.dart
-- Herkes okur; yazma yalnız admin.

create table if not exists public.dernekler (
  id bigint generated always as identity primary key,
  title text not null,
  image_url text not null default '',
  website_url text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists dernekler_sort_idx
  on public.dernekler (is_active, sort_order, id);

alter table public.dernekler enable row level security;

grant all on table public.dernekler to postgres, service_role;
grant select on table public.dernekler to anon, authenticated;
grant insert, update, delete on table public.dernekler to authenticated;

drop policy if exists "dernekler_select" on public.dernekler;
create policy "dernekler_select"
  on public.dernekler for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "dernekler_insert_admin" on public.dernekler;
create policy "dernekler_insert_admin"
  on public.dernekler for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "dernekler_update_admin" on public.dernekler;
create policy "dernekler_update_admin"
  on public.dernekler for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "dernekler_delete_admin" on public.dernekler;
create policy "dernekler_delete_admin"
  on public.dernekler for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

insert into public.dernekler (title, image_url, website_url, sort_order, created_by)
select v.title, '', v.website_url, v.sort_order, 'seed'
from (values
  ('SERÇEV', 'https://www.sercev.org.tr/', 10),
  ('Down Sendromlular Derneği', 'https://www.downturkiye.org/', 20)
) as v(title, website_url, sort_order)
where not exists (select 1 from public.dernekler limit 1);

notify pgrst, 'reload schema';
