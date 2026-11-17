-- Uzman Köşesi kurum iş ilanları. Yeni tablo; mevcut tablolara dokunmaz.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create table if not exists public.expert_kurum_is_ilanlari (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null,
  kurum_adi text not null default '',
  aranan_meslek text not null default '',
  il text not null default '',
  ilce text not null default '',
  adres text not null default '',
  photo_url text not null default '',
  aciklama text not null default '',
  calisma_sekli jsonb not null default '[]'::jsonb,
  telefon text not null default '',
  status text not null default 'published',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expert_kurum_is_ilanlari_status_chk
    check (status in ('draft', 'pending', 'published', 'rejected'))
);

create index if not exists expert_kurum_is_ilanlari_status_idx
  on public.expert_kurum_is_ilanlari (status, created_at desc);

create or replace function public.expert_kurum_is_ilanlari_touch()
returns trigger
language plpgsql
as $$
begin
  new.owner_email := lower(trim(new.owner_email));
  new.kurum_adi := trim(new.kurum_adi);
  new.aranan_meslek := trim(new.aranan_meslek);
  new.il := trim(new.il);
  new.ilce := trim(new.ilce);
  new.adres := trim(coalesce(new.adres, ''));
  new.photo_url := trim(coalesce(new.photo_url, ''));
  new.aciklama := trim(new.aciklama);
  new.telefon := trim(new.telefon);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists expert_kurum_is_ilanlari_touch_tg
  on public.expert_kurum_is_ilanlari;
create trigger expert_kurum_is_ilanlari_touch_tg
  before insert or update on public.expert_kurum_is_ilanlari
  for each row execute function public.expert_kurum_is_ilanlari_touch();

alter table public.expert_kurum_is_ilanlari enable row level security;

grant all on table public.expert_kurum_is_ilanlari to postgres, service_role;
grant select on table public.expert_kurum_is_ilanlari to anon, authenticated;
grant select, insert, update, delete on table public.expert_kurum_is_ilanlari
  to authenticated;

drop policy if exists "expert_kurum_is_select" on public.expert_kurum_is_ilanlari;
create policy "expert_kurum_is_select"
  on public.expert_kurum_is_ilanlari for select
  to anon, authenticated
  using (
    status = 'published'
    or owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "expert_kurum_is_insert" on public.expert_kurum_is_ilanlari;
create policy "expert_kurum_is_insert"
  on public.expert_kurum_is_ilanlari for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "expert_kurum_is_update" on public.expert_kurum_is_ilanlari;
create policy "expert_kurum_is_update"
  on public.expert_kurum_is_ilanlari for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "expert_kurum_is_delete" on public.expert_kurum_is_ilanlari;
create policy "expert_kurum_is_delete"
  on public.expert_kurum_is_ilanlari for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

do $$
begin
  execute 'grant usage, select on sequence public.expert_kurum_is_ilanlari_id_seq to authenticated';
exception
  when undefined_table then null;
  when undefined_object then null;
end $$;

notify pgrst, 'reload schema';
