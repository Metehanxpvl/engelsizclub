-- 1) Table Editor'de görünmezse önce bunu çalıştır (Success)
-- 2) Sonra alttaki KONTROL sorgusunu çalıştır

create extension if not exists pgcrypto;

create table if not exists public.info_library_contents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  youtube_url text not null default '',
  source text not null default '',
  category text not null default 'genel',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'info_library_contents'
      and column_name = 'source'
  ) then
    alter table public.info_library_contents
      add column source text not null default '';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'info_library_contents'
      and column_name = 'youtube_url'
  ) then
    alter table public.info_library_contents
      add column youtube_url text not null default '';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'info_library_contents'
      and column_name = 'description'
  ) then
    alter table public.info_library_contents
      add column description text not null default '';
  end if;
end $$;

create index if not exists info_library_category_sort_idx
  on public.info_library_contents (category, is_active, sort_order, created_at desc);

alter table public.info_library_contents enable row level security;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on table public.info_library_contents to postgres, service_role;
grant select on table public.info_library_contents to anon, authenticated;
grant insert, update, delete on table public.info_library_contents to authenticated;

drop policy if exists "info_library_select_public" on public.info_library_contents;
create policy "info_library_select_public"
  on public.info_library_contents for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_insert_admin" on public.info_library_contents;
create policy "info_library_insert_admin"
  on public.info_library_contents for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_update_admin" on public.info_library_contents;
create policy "info_library_update_admin"
  on public.info_library_contents for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_delete_admin" on public.info_library_contents;
create policy "info_library_delete_admin"
  on public.info_library_contents for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- API şemasını yenile (çok önemli)
notify pgrst, 'reload schema';

-- KONTROL: Results'ta satır gelmeli (source dahil)
select column_name, data_type
from information_schema.columns
where table_schema = 'public'
  and table_name = 'info_library_contents'
order by ordinal_position;
