-- Hastalıklar & Durumlar (ana sayfa kartları)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.conditions (
  id bigint generated always as identity primary key,
  title text not null,
  image_url text not null default '',
  description text not null default '',
  catalog_id text not null default '',
  icon text not null default '🩺',
  symptoms jsonb not null default '[]'::jsonb,
  diagnosis text not null default '',
  support jsonb not null default '[]'::jsonb,
  faq jsonb not null default '[]'::jsonb,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists conditions_active_sort_idx
  on public.conditions (is_active, sort_order, created_at desc);

alter table public.conditions enable row level security;

-- Girişli kullanıcılar aktif kayıtları görür; admin hepsini
drop policy if exists "conditions_select_auth" on public.conditions;
create policy "conditions_select_auth"
  on public.conditions for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_insert_admin" on public.conditions;
create policy "conditions_insert_admin"
  on public.conditions for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_update_admin" on public.conditions;
create policy "conditions_update_admin"
  on public.conditions for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_delete_admin" on public.conditions;
create policy "conditions_delete_admin"
  on public.conditions for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Mevcut tabloya detay kolonları
alter table public.conditions
  add column if not exists catalog_id text not null default '';
alter table public.conditions
  add column if not exists icon text not null default '🩺';
alter table public.conditions
  add column if not exists symptoms jsonb not null default '[]'::jsonb;
alter table public.conditions
  add column if not exists diagnosis text not null default '';
alter table public.conditions
  add column if not exists support jsonb not null default '[]'::jsonb;
alter table public.conditions
  add column if not exists faq jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
