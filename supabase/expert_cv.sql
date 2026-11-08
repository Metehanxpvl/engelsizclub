-- Uzman Köşesi dinamik CV (bölüm 10). Additive.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- Mevcut uzman_kosesi_profiles kolonlarına dokunmaz; yalnız yeni kolon ekler.
-- Dart: lib/uzman_kosesi/

create or replace function public.auth_user_type()
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_meta text := '';
  v_jwt text := '';
  v_role text := '';
begin
  if auth.uid() is not null then
    select lower(btrim(coalesce(raw_user_meta_data ->> 'user_type', '')))
    into v_meta
    from auth.users
    where id = auth.uid();
  end if;
  v_jwt := lower(btrim(coalesce(
    auth.jwt() -> 'user_metadata' ->> 'user_type',
    auth.jwt() -> 'app_metadata' ->> 'user_type',
    ''
  )));
  v_role := coalesce(nullif(v_meta, ''), nullif(v_jwt, ''), '');
  if v_role in ('bakici', 'bakıcı') then
    return 'bakici';
  end if;
  if v_role = 'uzman' then
    return 'uzman';
  end if;
  return 'aile';
end;
$$;

revoke all on function public.auth_user_type() from public;
grant execute on function public.auth_user_type() to anon, authenticated;

create table if not exists public.meslek_gruplari (
  id bigint generated always as identity primary key,
  grup_key text not null,
  etiket text not null,
  ust_grup text not null,
  sira int not null default 0,
  aktif boolean not null default true,
  constraint meslek_gruplari_key_uk unique (grup_key),
  constraint meslek_gruplari_ust_chk
    check (ust_grup in ('Sağlık Uzmanları', 'Bakım ve Ev Desteği'))
);

create table if not exists public.meslek_alan_sablonlari (
  id bigint generated always as identity primary key,
  meslek_grubu_id bigint not null references public.meslek_gruplari (id) on delete cascade,
  alan_key text not null,
  etiket text not null,
  tip text not null,
  secenekler jsonb not null default '[]'::jsonb,
  zorunlu boolean not null default false,
  sira int not null default 0,
  aktif boolean not null default true,
  constraint meslek_alan_sablonlari_tip_chk
    check (tip in ('text', 'textarea', 'number', 'select', 'multi_select', 'boolean', 'file')),
  constraint meslek_alan_sablonlari_uk unique (meslek_grubu_id, alan_key)
);

create index if not exists meslek_alan_sablonlari_grup_idx
  on public.meslek_alan_sablonlari (meslek_grubu_id, sira);

create table if not exists public.expert_profiles (
  id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null,
  full_name text not null default '',
  photo_url text not null default '',
  meslek_grubu_id bigint references public.meslek_gruplari (id),
  il text not null default '',
  ilce text not null default '',
  country_code text not null default 'TR',
  deneyim_yili int,
  kisa_tanitim text not null default '',
  calisma_sekli jsonb not null default '[]'::jsonb,
  musaitlik jsonb not null default '[]'::jsonb,
  diller jsonb not null default '[]'::jsonb,
  isaret_dili boolean not null default false,
  engelli_deneyimi boolean,
  engelli_deneyim_aciklama text not null default '',
  referanslar text not null default '',
  iletisim_tercihi text not null default 'app_message',
  telefon_izin boolean not null default false,
  eposta_izin boolean not null default false,
  meslek_detaylari jsonb not null default '{}'::jsonb,
  kvkk_onay boolean not null default false,
  kvkk_onay_at timestamptz,
  status text not null default 'draft',
  reject_reason text not null default '',
  dogrulandi boolean not null default false,
  published_at timestamptz,
  next_charge_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expert_profiles_owner_uk unique (owner_id),
  constraint expert_profiles_status_chk
    check (status in ('draft', 'pending', 'published', 'rejected', 'expired')),
  constraint expert_profiles_iletisim_chk
    check (iletisim_tercihi in ('app_message', 'phone', 'email'))
);

create index if not exists expert_profiles_status_idx
  on public.expert_profiles (status, created_at desc);
create index if not exists expert_profiles_meslek_idx
  on public.expert_profiles (meslek_grubu_id);

-- Belge URL'leri public JSON'da tutulmaz; yalnız bu tablo + RLS (sahip/admin).
create table if not exists public.expert_profile_files (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.expert_profiles (id) on delete cascade,
  owner_id uuid not null,
  alan_key text not null,
  file_url text not null,
  created_at timestamptz not null default now(),
  constraint expert_profile_files_uk unique (profile_id, alan_key)
);

alter table public.uzman_kosesi_profiles
  add column if not exists deneyim_yili int;
alter table public.uzman_kosesi_profiles
  add column if not exists dogrulandi boolean not null default false;
alter table public.uzman_kosesi_profiles
  add column if not exists photo_url text not null default '';
alter table public.uzman_kosesi_profiles
  add column if not exists ust_grup text not null default '';

create or replace function public.expert_profiles_touch()
returns trigger
language plpgsql
as $$
begin
  new.owner_email := lower(trim(new.owner_email));
  new.full_name := trim(new.full_name);
  new.il := trim(new.il);
  new.ilce := trim(new.ilce);
  new.country_code := upper(trim(coalesce(new.country_code, 'TR')));
  new.kisa_tanitim := trim(new.kisa_tanitim);
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists expert_profiles_touch_tg on public.expert_profiles;
create trigger expert_profiles_touch_tg
  before insert or update on public.expert_profiles
  for each row execute function public.expert_profiles_touch();

-- Yayınlanan CV'yi mevcut liste tablosuna yansıt (mevcut kolonlara dokunmadan).
create or replace function public.expert_profiles_sync_listing()
returns trigger
language plpgsql
security definer
as $$
declare
  v_etiket text := '';
  v_ust text := '';
begin
  if new.meslek_grubu_id is not null then
    select etiket, ust_grup into v_etiket, v_ust
    from public.meslek_gruplari
    where id = new.meslek_grubu_id;
  end if;

  if new.status = 'published' then
    insert into public.uzman_kosesi_profiles (
      owner_id, owner_email, full_name, meslek, il, ilce, country_code,
      deneyim_yili, dogrulandi, photo_url, ust_grup
    )
    values (
      new.owner_id, new.owner_email, new.full_name, coalesce(v_etiket, ''),
      new.il, new.ilce, new.country_code,
      new.deneyim_yili, new.dogrulandi, new.photo_url, coalesce(v_ust, '')
    )
    on conflict (owner_id) do update set
      owner_email = excluded.owner_email,
      full_name = excluded.full_name,
      meslek = excluded.meslek,
      il = excluded.il,
      ilce = excluded.ilce,
      country_code = excluded.country_code,
      deneyim_yili = excluded.deneyim_yili,
      dogrulandi = excluded.dogrulandi,
      photo_url = excluded.photo_url,
      ust_grup = excluded.ust_grup;
  elsif tg_op = 'UPDATE' and old.status = 'published' and new.status <> 'published' then
    delete from public.uzman_kosesi_profiles where owner_id = new.owner_id;
  end if;
  return new;
end;
$$;

drop trigger if exists expert_profiles_sync_listing_tg on public.expert_profiles;
create trigger expert_profiles_sync_listing_tg
  after insert or update on public.expert_profiles
  for each row execute function public.expert_profiles_sync_listing();

-- Yayınla/beklemede: zorunlu ortak alanlar + şablon zorunluları.
create or replace function public.expert_profiles_validate()
returns trigger
language plpgsql
as $$
declare
  r record;
  v jsonb;
  v_len int;
begin
  if new.status not in ('pending', 'published') then
    return new;
  end if;
  if not coalesce(new.kvkk_onay, false) then
    raise exception 'KVKK onayı zorunludur.';
  end if;
  if length(trim(new.full_name)) < 2 then
    raise exception 'Ad soyad gerekli.';
  end if;
  if new.meslek_grubu_id is null then
    raise exception 'Meslek grubu seçin.';
  end if;
  if length(trim(new.il)) < 1 then
    raise exception 'İl seçin.';
  end if;
  v_len := length(trim(new.kisa_tanitim));
  if v_len < 10 then
    raise exception 'Kısa tanıtım en az 10 karakter olmalı.';
  end if;

  for r in
    select alan_key, etiket, tip, zorunlu
    from public.meslek_alan_sablonlari
    where meslek_grubu_id = new.meslek_grubu_id
      and aktif = true
  loop
    v := new.meslek_detaylari -> r.alan_key;
    if r.tip in ('text', 'textarea') and v is not null and v <> 'null'::jsonb then
      v_len := length(trim(both '"' from coalesce(v::text, '')));
      if r.tip = 'textarea' and v_len > 2000 then
        raise exception '% en fazla 2000 karakter.', r.etiket;
      elsif r.tip = 'text' and v_len > 200 then
        raise exception '% en fazla 200 karakter.', r.etiket;
      end if;
    end if;
  end loop;
  return new;
end;
$$;

drop trigger if exists expert_profiles_validate_tg on public.expert_profiles;
create trigger expert_profiles_validate_tg
  before insert or update on public.expert_profiles
  for each row execute function public.expert_profiles_validate();

alter table public.meslek_gruplari enable row level security;
alter table public.meslek_alan_sablonlari enable row level security;
alter table public.expert_profiles enable row level security;
alter table public.expert_profile_files enable row level security;

grant all on table public.meslek_gruplari to postgres, service_role;
grant all on table public.meslek_alan_sablonlari to postgres, service_role;
grant all on table public.expert_profiles to postgres, service_role;
grant all on table public.expert_profile_files to postgres, service_role;

grant select on table public.meslek_gruplari to anon, authenticated;
grant select on table public.meslek_alan_sablonlari to anon, authenticated;
grant select, insert, update, delete on table public.expert_profiles to authenticated;
grant select on table public.expert_profiles to anon;
grant select, insert, update, delete on table public.expert_profile_files to authenticated;

drop policy if exists "meslek_gruplari_select" on public.meslek_gruplari;
create policy "meslek_gruplari_select"
  on public.meslek_gruplari for select
  to anon, authenticated
  using (true);

drop policy if exists "meslek_gruplari_admin_write" on public.meslek_gruplari;
create policy "meslek_gruplari_admin_write"
  on public.meslek_gruplari for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "meslek_alan_sablonlari_select" on public.meslek_alan_sablonlari;
create policy "meslek_alan_sablonlari_select"
  on public.meslek_alan_sablonlari for select
  to anon, authenticated
  using (true);

drop policy if exists "meslek_alan_sablonlari_admin_write" on public.meslek_alan_sablonlari;
create policy "meslek_alan_sablonlari_admin_write"
  on public.meslek_alan_sablonlari for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "expert_profiles_select" on public.expert_profiles;
create policy "expert_profiles_select"
  on public.expert_profiles for select
  to anon, authenticated
  using (
    status = 'published'
    or owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "expert_profiles_insert_own" on public.expert_profiles;
create policy "expert_profiles_insert_own"
  on public.expert_profiles for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and (
      public.auth_user_type() in ('uzman', 'bakici')
      or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
    )
  );

drop policy if exists "expert_profiles_update_own" on public.expert_profiles;
create policy "expert_profiles_update_own"
  on public.expert_profiles for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "expert_profile_files_select" on public.expert_profile_files;
create policy "expert_profile_files_select"
  on public.expert_profile_files for select
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "expert_profile_files_write" on public.expert_profile_files;
create policy "expert_profile_files_write"
  on public.expert_profile_files for all
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Admin onay
create or replace function public.admin_review_expert_profile(
  p_id bigint,
  p_approve boolean,
  p_reason text default '',
  p_dogrulandi boolean default false
)
returns void
language plpgsql
security definer
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yetkisiz';
  end if;
  if p_approve then
    update public.expert_profiles
    set status = 'published',
        reject_reason = '',
        dogrulandi = dogrulandi or coalesce(p_dogrulandi, false),
        published_at = coalesce(published_at, now()),
        next_charge_at = coalesce(next_charge_at, now() + interval '30 days')
    where id = p_id;
  else
    if length(trim(coalesce(p_reason, ''))) < 3 then
      raise exception 'Red sebebi zorunlu.';
    end if;
    update public.expert_profiles
    set status = 'rejected',
        reject_reason = trim(p_reason)
    where id = p_id;
  end if;
end;
$$;

grant execute on function public.admin_review_expert_profile(bigint, boolean, text, boolean)
  to authenticated;

do $$
declare
  seq text;
begin
  foreach seq in array array[
    'meslek_gruplari_id_seq',
    'meslek_alan_sablonlari_id_seq',
    'expert_profiles_id_seq',
    'expert_profile_files_id_seq'
  ]
  loop
    begin
      execute format('grant usage, select on sequence public.%I to authenticated', seq);
    exception
      when undefined_table then null;
      when undefined_object then null;
    end;
  end loop;
end $$;

notify pgrst, 'reload schema';
