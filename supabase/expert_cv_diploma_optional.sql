-- Diploma zorunlu değil; kısa tanıtım en az 10 karakter.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

update public.meslek_alan_sablonlari
set zorunlu = false
where alan_key in ('diploma', 'belge')
  and zorunlu = true;

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
