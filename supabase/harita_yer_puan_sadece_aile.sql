-- Yer bildirimi: yalnız aile +1 iyilik puanı. Uzman / bakıcı bakiyesi değişmez.
-- Dashboard → SQL Editor → Run. Tek fonksiyon (p_user_type dahil).
-- Idempotent.

do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as sig
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'harita_yer_bildir'
  loop
    execute 'drop function if exists ' || r.sig || ' cascade';
  end loop;
end $$;

create or replace function public.harita_yer_bildir(
  p_name text,
  p_category text,
  p_city text,
  p_ilce text default '',
  p_address text default '',
  p_phone text default '',
  p_note text default '',
  p_lat double precision default 0,
  p_lng double precision default 0,
  p_user_type text default ''
)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_meta_role text := '';
  v_jwt_role text := '';
  v_client_role text := lower(btrim(coalesce(p_user_type, '')));
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
  if v_cat not in ('Özel Eğitim', 'Fizik Tedavi', 'Medikal', 'Erişilebilirlik') then
    v_cat := 'Erişilebilirlik';
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

  select lower(btrim(coalesce(raw_user_meta_data ->> 'user_type', '')))
    into v_meta_role
    from auth.users
    where id = v_user;
  v_jwt_role := lower(btrim(coalesce(
    auth.jwt() -> 'user_metadata' ->> 'user_type',
    auth.jwt() -> 'app_metadata' ->> 'user_type',
    ''
  )));
  if v_client_role in ('bakici', 'bakıcı') then
    v_client_role := 'bakici';
  end if;
  if v_meta_role in ('bakici', 'bakıcı') then
    v_meta_role := 'bakici';
  end if;
  if v_jwt_role in ('bakici', 'bakıcı') then
    v_jwt_role := 'bakici';
  end if;

  -- Puanı uygulama yazar (yalnız aile). Bu RPC bakiyeye dokunmaz.
  v_awarded := false;

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
  text, text, text, text, text, text, text, double precision, double precision, text
) from public;
grant execute on function public.harita_yer_bildir(
  text, text, text, text, text, text, text, double precision, double precision, text
) to authenticated;

notify pgrst, 'reload schema';
