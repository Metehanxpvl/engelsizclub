-- Kullanıcı etkinlik önerisi (admin onayı) + katılım sayacı
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- Bu dosyayı SQL Editor’de çalıştırın (idempotent; satır silmez).
-- CLI token yok — yalnızca Dashboard.
--
--   pending  → herkese açık değil (öneren + admin görür)
--   approved → Etkinlikler listesinde (il’e göre)
--   rejected → gizli; admin kısa gerekçe yazabilir
--
-- source='avm_scrape' ve status NULL → onaylı sayılır (scraper değişmez).
-- Dart: proposeEtkinlik / approveEtkinlik / toggleEtkinlikKatilim
-- Admin bildirimi (zil): ayrıca etkinlik_admin_notify.sql çalıştırın.

-- ── kolonlar ───────────────────────────────────────────────────────────────
alter table public.etkinlikler
  add column if not exists status text;

alter table public.etkinlikler
  add column if not exists created_by text not null default '';

alter table public.etkinlikler
  add column if not exists event_date text not null default '';

alter table public.etkinlikler
  add column if not exists rejection_reason text not null default '';

alter table public.etkinlikler
  add column if not exists source text;

update public.etkinlikler
set status = 'approved'
where status is null or btrim(status) = '';

alter table public.etkinlikler
  alter column status set default 'approved';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'etkinlikler_status_chk'
      and conrelid = 'public.etkinlikler'::regclass
  ) then
    alter table public.etkinlikler
      add constraint etkinlikler_status_chk
      check (status in ('pending', 'approved', 'rejected'));
  end if;
end $$;

create index if not exists etkinlikler_status_idx
  on public.etkinlikler (status, is_active, city);

-- ── katılım ────────────────────────────────────────────────────────────────
create table if not exists public.etkinlik_katilimlar (
  id bigint generated always as identity primary key,
  event_id bigint not null references public.etkinlikler (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (event_id, user_id)
);

create index if not exists etkinlik_katilimlar_event_idx
  on public.etkinlik_katilimlar (event_id);

alter table public.etkinlik_katilimlar enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.etkinlik_katilimlar to postgres, service_role;
grant select, insert, delete on table public.etkinlik_katilimlar to authenticated;

-- ── herkese açık mı? (scrape + onaylı) ─────────────────────────────────────
create or replace function public.etkinlik_is_listed(e public.etkinlikler)
returns boolean
language sql
stable
as $$
  select e.is_active = true
    and (
      e.source = 'avm_scrape'
      or coalesce(e.status, 'approved') = 'approved'
    );
$$;

-- ── RLS: etkinlikler ───────────────────────────────────────────────────────
drop policy if exists "etkinlik_select_all" on public.etkinlikler;
create policy "etkinlik_select_all"
  on public.etkinlikler for select
  to anon, authenticated
  using (
    public.etkinlik_is_listed(etkinlikler)
    or (
      status = 'pending'
      and length(coalesce(auth.jwt() ->> 'email', '')) > 0
      and lower(coalesce(created_by, '')) =
        lower(coalesce(auth.jwt() ->> 'email', ''))
    )
    or public.is_section_editor('etkinlik')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_insert_admin" on public.etkinlikler;
create policy "etkinlik_insert_admin"
  on public.etkinlikler for insert
  to authenticated
  with check (
    public.is_section_editor('etkinlik')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_insert_user_pending" on public.etkinlikler;
create policy "etkinlik_insert_user_pending"
  on public.etkinlikler for insert
  to authenticated
  with check (
    status = 'pending'
    and coalesce(source, 'user') <> 'avm_scrape'
    and length(coalesce(auth.jwt() ->> 'email', '')) > 0
    and lower(coalesce(created_by, '')) =
      lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "etkinlik_update_admin" on public.etkinlikler;
create policy "etkinlik_update_admin"
  on public.etkinlikler for update
  to authenticated
  using (
    public.is_section_editor('etkinlik')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    public.is_section_editor('etkinlik')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "etkinlik_delete_admin" on public.etkinlikler;
create policy "etkinlik_delete_admin"
  on public.etkinlikler for delete
  to authenticated
  using (
    public.is_section_editor('etkinlik')
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- ── RLS: katılım (sayım RPC’de; satır yalnız kendi) ────────────────────────
drop policy if exists "etkinlik_katilim_select_own" on public.etkinlik_katilimlar;
create policy "etkinlik_katilim_select_own"
  on public.etkinlik_katilimlar for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists "etkinlik_katilim_insert_own" on public.etkinlik_katilimlar;
create policy "etkinlik_katilim_insert_own"
  on public.etkinlik_katilimlar for insert
  to authenticated
  with check (user_id = auth.uid());

drop policy if exists "etkinlik_katilim_delete_own" on public.etkinlik_katilimlar;
create policy "etkinlik_katilim_delete_own"
  on public.etkinlik_katilimlar for delete
  to authenticated
  using (user_id = auth.uid());

-- ── herkese açık sayaç + benim katılımım ───────────────────────────────────
create or replace function public.etkinlik_katilim_ozet(p_ids bigint[])
returns table(event_id bigint, join_count bigint, joined_by_me boolean)
language sql
stable
security definer
set search_path = public
as $$
  select
    e.id as event_id,
    coalesce((
      select count(*)::bigint
      from public.etkinlik_katilimlar k
      where k.event_id = e.id
    ), 0) as join_count,
    exists (
      select 1
      from public.etkinlik_katilimlar k
      where k.event_id = e.id
        and k.user_id = auth.uid()
    ) as joined_by_me
  from public.etkinlikler e
  where e.id = any (coalesce(p_ids, '{}'::bigint[]))
    and (
      public.etkinlik_is_listed(e)
      or public.is_section_editor('etkinlik')
      or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
    );
$$;

grant execute on function public.etkinlik_katilim_ozet(bigint[])
  to anon, authenticated;

-- ── katıl / vazgeç ─────────────────────────────────────────────────────────
create or replace function public.etkinlik_toggle_katilim(p_event_id bigint)
returns table(joined boolean, join_count bigint)
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  listed boolean;
  already boolean;
begin
  if uid is null then
    raise exception 'Giriş gerekli';
  end if;

  select public.etkinlik_is_listed(e)
  into listed
  from public.etkinlikler e
  where e.id = p_event_id;

  if coalesce(listed, false) is not true then
    raise exception 'Etkinlik bulunamadı';
  end if;

  select exists (
    select 1
    from public.etkinlik_katilimlar k
    where k.event_id = p_event_id
      and k.user_id = uid
  ) into already;

  if already then
    delete from public.etkinlik_katilimlar
    where event_id = p_event_id
      and user_id = uid;
    joined := false;
  else
    insert into public.etkinlik_katilimlar (event_id, user_id)
    values (p_event_id, uid)
    on conflict (event_id, user_id) do nothing;
    joined := true;
  end if;

  select count(*)::bigint
  into join_count
  from public.etkinlik_katilimlar
  where event_id = p_event_id;

  return next;
end;
$$;

grant execute on function public.etkinlik_toggle_katilim(bigint)
  to authenticated;

notify pgrst, 'reload schema';
