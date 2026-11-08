-- Yayın için yalnızca: ad soyad, meslek, il, KVKK, kısa tanıtım (≥10).
-- Eski 300-500 karakter kuralı ve ilçe / deneyim / çalışma şekli / müsaitlik
-- / engelli deneyim / mesleğe özel zorunlular kaldırılır.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

update public.meslek_alan_sablonlari
set zorunlu = false
where zorunlu = true;

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
    select alan_key, etiket, tip
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
