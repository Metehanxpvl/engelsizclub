-- Uzman Profilleri Köşesi: 1 kutu veya tam satır (additive).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

alter table public.uzman_kosesi_profiles
  add column if not exists kart_span int not null default 1;

alter table public.expert_profiles
  add column if not exists kart_span int not null default 1;
alter table public.expert_profiles
  add column if not exists ucret_bitis timestamptz;
alter table public.expert_profiles
  add column if not exists ilk_ay_kullanildi boolean not null default false;
alter table public.expert_profiles
  add column if not exists odenen_puan int not null default 0;

create or replace function public.expert_profiles_sync_listing()
returns trigger
language plpgsql
security definer
as $$
declare
  v_etiket text := '';
  v_ust text := '';
  v_span int := 1;
begin
  if new.meslek_grubu_id is not null then
    select etiket, ust_grup into v_etiket, v_ust
    from public.meslek_gruplari
    where id = new.meslek_grubu_id;
  end if;

  v_span := case when coalesce(new.kart_span, 1) >= 2 then 2 else 1 end;

  if new.status = 'published' then
    insert into public.uzman_kosesi_profiles (
      owner_id, owner_email, full_name, meslek, il, ilce, country_code,
      deneyim_yili, dogrulandi, photo_url, ust_grup, kart_span
    )
    values (
      new.owner_id, new.owner_email, new.full_name, coalesce(v_etiket, ''),
      new.il, new.ilce, new.country_code,
      new.deneyim_yili, new.dogrulandi, new.photo_url, coalesce(v_ust, ''),
      v_span
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
      ust_grup = excluded.ust_grup,
      kart_span = excluded.kart_span;
  elsif tg_op = 'UPDATE' and old.status = 'published' and new.status <> 'published' then
    delete from public.uzman_kosesi_profiles where owner_id = new.owner_id;
  end if;
  return new;
end;
$$;

notify pgrst, 'reload schema';
