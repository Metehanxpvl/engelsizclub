-- Üye Uzman Profilleri Köşesi profilini onaya gönderince admin bildirimi.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create or replace function public.trg_notify_admin_uzman_onay()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_email text := 'sakir.caykara@gmail.com';
  actor text;
  display text;
  meslek text;
  heading text;
  body text;
  ref text;
  yer text;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;
  if tg_op = 'UPDATE' and old.status is not distinct from 'pending' then
    return new;
  end if;

  actor := lower(trim(coalesce(new.owner_email, '')));
  if actor = '' or actor = admin_email then
    return new;
  end if;

  select nullif(trim(coalesce(g.etiket, '')), '')
    into meslek
  from public.meslek_gruplari g
  where g.id = new.meslek_grubu_id;

  display := nullif(trim(coalesce(new.full_name, '')), '');
  if display is null then
    display := split_part(actor, '@', 1);
  end if;
  heading := 'Uzman Onayları: ' || display;
  yer := nullif(trim(concat_ws(' / ', nullif(trim(new.il), ''), nullif(trim(new.ilce), ''))), '');
  body := display
    || coalesce(' (' || yer || ')', '')
    || ' '
    || coalesce(meslek, 'uzman')
    || ' profili onay bekliyor. Uzman Onayları’ndan inceleyin.';
  ref := 'uo:' || new.id::text;

  insert into public.bildirimler (
    owner_email, actor_email, actor_name, type, title, body, ilan_id, sohbet_key, read
  )
  select
    admin_email, actor, display, 'uzman_onay', heading, body, new.id, ref, false
  where not exists (
    select 1
    from public.bildirimler b
    where b.type = 'uzman_onay'
      and b.sohbet_key = ref
      and b.read = false
      and lower(b.owner_email) = admin_email
  );

  return new;
end;
$$;

drop trigger if exists expert_profiles_admin_onay_notify on public.expert_profiles;
create trigger expert_profiles_admin_onay_notify
  after insert or update of status on public.expert_profiles
  for each row
  execute function public.trg_notify_admin_uzman_onay();

notify pgrst, 'reload schema';
