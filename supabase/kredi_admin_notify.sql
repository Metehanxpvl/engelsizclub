-- Her puan (kredi) artışında admin'e uygulama içi bildirim.
-- Supabase SQL Editor → çalıştırın.

create or replace function public.trg_notify_admin_kredi_yukleme()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  delta int;
  admin_email text := 'sakir.caykara@gmail.com';
  display text;
  actor text;
begin
  if tg_op = 'INSERT' then
    delta := coalesce(new.kredi, 0);
  else
    delta := coalesce(new.kredi, 0) - coalesce(old.kredi, 0);
  end if;

  if delta <= 0 then
    return new;
  end if;

  actor := lower(trim(coalesce(new.owner_email, '')));
  if actor = '' or actor = admin_email then
    return new;
  end if;

  display := coalesce(
    nullif(trim(new.profil ->> 'adSoyad'), ''),
    split_part(actor, '@', 1)
  );

  insert into public.bildirimler (
    owner_email,
    actor_email,
    actor_name,
    type,
    title,
    body,
    ilan_id,
    sohbet_key,
    read
  ) values (
    admin_email,
    actor,
    display,
    'kredi',
    format('Puan yükleme: +%s puan', delta),
    format(
      E'%s (%s)\n+%s puan yüklendi\nYeni bakiye: %s',
      display,
      actor,
      delta,
      coalesce(new.kredi, 0)
    ),
    null,
    null,
    false
  );

  return new;
end;
$$;

drop trigger if exists user_profiles_kredi_notify on public.user_profiles;
create trigger user_profiles_kredi_notify
  after insert or update of kredi
  on public.user_profiles
  for each row
  execute function public.trg_notify_admin_kredi_yukleme();

notify pgrst, 'reload schema';
