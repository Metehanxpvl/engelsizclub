-- Destek Veren kaydı: JWT'de user_type gecikince RLS 'aile' sanıyordu.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

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

drop policy if exists "uzman_kosesi_profiles_insert_own" on public.uzman_kosesi_profiles;
create policy "uzman_kosesi_profiles_insert_own"
  on public.uzman_kosesi_profiles for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and (
      public.auth_user_type() in ('uzman', 'bakici')
      or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
    )
  );

-- Diploma zorunlu değil; kısa tanıtım en az 10 karakter.
update public.meslek_alan_sablonlari
set zorunlu = false
where alan_key in ('diploma', 'belge')
  and zorunlu = true;

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

notify pgrst, 'reload schema';
