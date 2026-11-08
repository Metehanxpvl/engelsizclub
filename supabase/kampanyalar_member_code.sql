-- Kampanya kodu: admin kodu belirler; üyeler kendi kodunu oluşturur.
-- Supabase Dashboard → SQL Editor → çalıştırın (idempotent).
-- Dart: gezi_kampanya_store.issueKampanyaMemberCode / KampanyaItem.campaignCode

alter table public.kampanyalar
  add column if not exists member_code_enabled boolean not null default false;

alter table public.kampanyalar
  add column if not exists campaign_code text not null default '';

create table if not exists public.kampanya_uye_kodlari (
  id bigint generated always as identity primary key,
  kampanya_id bigint not null references public.kampanyalar (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  code text not null,
  created_at timestamptz not null default now(),
  unique (kampanya_id, user_id)
);

create index if not exists kampanya_uye_kodlari_user_idx
  on public.kampanya_uye_kodlari (user_id, kampanya_id);

alter table public.kampanya_uye_kodlari enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.kampanya_uye_kodlari to postgres, service_role;
grant select, insert on table public.kampanya_uye_kodlari to authenticated;

drop policy if exists "kampanya_uye_kod_select_own" on public.kampanya_uye_kodlari;
create policy "kampanya_uye_kod_select_own"
  on public.kampanya_uye_kodlari for select
  to authenticated
  using (
    user_id = auth.uid()
    or public.is_section_editor('kampanya')
  );

drop policy if exists "kampanya_uye_kod_insert_own" on public.kampanya_uye_kodlari;
create policy "kampanya_uye_kod_insert_own"
  on public.kampanya_uye_kodlari for insert
  to authenticated
  with check (user_id = auth.uid());

create or replace function public.kampanya_uye_kodu_olustur(p_kampanya_id bigint)
returns table(code text, created boolean)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_enabled boolean;
  v_code text;
  v_existing text;
begin
  if v_user is null then
    raise exception 'Kampanya kodu için giriş yapın.';
  end if;

  select k.member_code_enabled, btrim(coalesce(k.campaign_code, ''))
    into v_enabled, v_code
  from public.kampanyalar k
  where k.id = p_kampanya_id
    and k.is_active = true;

  if not found or v_enabled is not true or v_code = '' then
    raise exception 'Bu kampanyada kod oluşturma kapalı.';
  end if;

  select u.code into v_existing
  from public.kampanya_uye_kodlari u
  where u.kampanya_id = p_kampanya_id
    and u.user_id = v_user;

  if v_existing is not null then
    return query select v_existing, false;
    return;
  end if;

  insert into public.kampanya_uye_kodlari (kampanya_id, user_id, code)
  values (p_kampanya_id, v_user, v_code);

  return query select v_code, true;
end;
$$;

grant execute on function public.kampanya_uye_kodu_olustur(bigint) to authenticated;

notify pgrst, 'reload schema';
