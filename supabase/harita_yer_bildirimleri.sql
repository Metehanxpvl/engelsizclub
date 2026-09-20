-- Engelsiz Haritalar: üye yer bildirimi
-- Aile rolü: her 5 bildiride 1 iyilik puanı (user_profiles.kredi)
-- Supabase Dashboard → SQL Editor → çalıştırın (idempotent).
-- Dart: harita_yer_store.dart

create or replace function public.harita_fold_tr(p text)
returns text
language sql
immutable
as $$
  select btrim(
    regexp_replace(
      lower(translate(coalesce(p, ''), 'ÇĞİÖŞÜçğıöşüIÂâ', 'cgioosucgiosuiaa')),
      '[^a-z0-9]+',
      ' ',
      'g'
    )
  );
$$;

create table if not exists public.harita_yer_bildirimleri (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  user_email text not null default '',
  name text not null,
  name_norm text not null,
  category text not null default 'Özel Eğitim',
  city text not null,
  city_norm text not null,
  ilce text not null default '',
  address text not null default '',
  phone text not null default '',
  note text not null default '',
  lat double precision not null default 0,
  lng double precision not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, name_norm, city_norm)
);

create index if not exists harita_yer_bildirimleri_city_idx
  on public.harita_yer_bildirimleri (city_norm, created_at desc);

create index if not exists harita_yer_bildirimleri_user_idx
  on public.harita_yer_bildirimleri (user_id, created_at desc);

alter table public.harita_yer_bildirimleri enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.harita_yer_bildirimleri to postgres, service_role;
grant select on table public.harita_yer_bildirimleri to anon, authenticated;

drop policy if exists "harita_yer_select" on public.harita_yer_bildirimleri;
create policy "harita_yer_select"
  on public.harita_yer_bildirimleri for select
  to anon, authenticated
  using (true);

create or replace function public.harita_yer_bildir(
  p_name text,
  p_category text,
  p_city text,
  p_ilce text default '',
  p_address text default '',
  p_phone text default '',
  p_note text default '',
  p_lat double precision default 0,
  p_lng double precision default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_role text := lower(coalesce(
    nullif(trim(auth.jwt() -> 'user_metadata' ->> 'user_type'), ''),
    'aile'
  ));
  v_name text := btrim(coalesce(p_name, ''));
  v_city text := btrim(coalesce(p_city, ''));
  v_cat text := btrim(coalesce(p_category, ''));
  v_name_norm text;
  v_city_norm text;
  v_today int;
  v_count int;
  v_id bigint;
  v_awarded boolean := false;
  v_balance int := 0;
begin
  if v_user is null then
    raise exception 'Yer bildirmek için giriş yapın.';
  end if;
  if char_length(v_name) < 3 then
    raise exception 'Yer adı en az 3 karakter olmalı.';
  end if;
  if v_city = '' then
    raise exception 'İl seçin.';
  end if;
  if v_cat not in ('Özel Eğitim', 'Fizik Tedavi', 'Medikal') then
    v_cat := 'Özel Eğitim';
  end if;

  v_name_norm := public.harita_fold_tr(v_name);
  v_city_norm := public.harita_fold_tr(v_city);
  if v_name_norm = '' or v_city_norm = '' then
    raise exception 'Geçerli bir yer adı ve il girin.';
  end if;

  select count(*)::int into v_today
  from public.harita_yer_bildirimleri
  where user_id = v_user
    and created_at > now() - interval '1 day';
  if v_today >= 20 then
    raise exception 'Günlük yer bildirimi sınırına ulaştınız (20).';
  end if;

  insert into public.harita_yer_bildirimleri (
    user_id, user_email, name, name_norm, category,
    city, city_norm, ilce, address, phone, note, lat, lng
  ) values (
    v_user, v_email, v_name, v_name_norm, v_cat,
    v_city, v_city_norm,
    btrim(coalesce(p_ilce, '')),
    btrim(coalesce(p_address, '')),
    btrim(coalesce(p_phone, '')),
    btrim(coalesce(p_note, '')),
    coalesce(p_lat, 0),
    coalesce(p_lng, 0)
  )
  returning id into v_id;

  select count(*)::int into v_count
  from public.harita_yer_bildirimleri
  where user_id = v_user;

  if v_role = 'aile' and v_count > 0 and mod(v_count, 5) = 0 then
    insert into public.user_profiles (
      owner_id, owner_email, kredi, kredi_welcome_gift, updated_at
    ) values (
      v_user, v_email, 1, true, now()
    )
    on conflict (owner_id) do update
      set kredi = public.user_profiles.kredi + 1,
          updated_at = now();
    v_awarded := true;
  end if;

  select coalesce(kredi, 0) into v_balance
  from public.user_profiles
  where owner_id = v_user;

  return jsonb_build_object(
    'id', v_id,
    'report_count', v_count,
    'awarded', v_awarded,
    'new_balance', v_balance
  );
exception
  when unique_violation then
    raise exception 'Bu yeri zaten bildirdiniz.';
end;
$$;

revoke all on function public.harita_yer_bildir(
  text, text, text, text, text, text, text, double precision, double precision
) from public;
grant execute on function public.harita_yer_bildir(
  text, text, text, text, text, text, text, double precision, double precision
) to authenticated;

notify pgrst, 'reload schema';
