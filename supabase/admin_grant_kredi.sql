-- Admin: istediği üyeye puan / iyilik puanı yükler veya bakiyeyi ayarlar.
-- Supabase Dashboard → SQL Editor → çalıştırın (idempotent).
-- Dart: lib/widgets/admin_users_panel.dart
-- Yalnızca sakir.caykara@gmail.com

create or replace function public.admin_grant_kredi(
  p_email text,
  p_amount int,
  p_mode text default 'add'
)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_email text;
  v_mode text;
  v_amount int;
  v_user uuid;
  v_role text;
  v_name text;
  v_old int := 0;
  v_new int := 0;
  v_delta int := 0;
  v_birim text;
  v_title text;
  v_body text;
begin
  if v_admin <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin puan yükleyebilir';
  end if;

  v_email := lower(trim(coalesce(p_email, '')));
  if v_email = '' or position('@' in v_email) = 0 then
    raise exception 'Geçerli bir üye e-postası girin';
  end if;

  v_mode := lower(trim(coalesce(p_mode, 'add')));
  if v_mode not in ('add', 'set') then
    raise exception 'Geçersiz işlem';
  end if;

  v_amount := coalesce(p_amount, 0);
  if v_amount < 0 or v_amount > 99999999 then
    raise exception 'Puan 0 ile 99.999.999 arasında olmalı';
  end if;
  if v_mode = 'add' and v_amount = 0 then
    raise exception 'Yüklenecek puanı girin';
  end if;

  select au.id,
         lower(coalesce(au.email, v_email)),
         lower(coalesce(au.raw_user_meta_data ->> 'user_type', 'aile'))
    into v_user, v_email, v_role
  from auth.users au
  where lower(trim(au.email)) = v_email
  limit 1;

  if v_user is null then
    raise exception 'Üye bulunamadı: %', v_email;
  end if;

  select coalesce(up.kredi, 0),
         coalesce(
           nullif(trim(up.profil ->> 'adSoyad'), ''),
           split_part(v_email, '@', 1)
         )
    into v_old, v_name
  from public.user_profiles up
  where up.owner_id = v_user;

  if not found then
    v_old := 0;
    v_name := split_part(v_email, '@', 1);
  end if;

  if v_mode = 'set' then
    v_new := v_amount;
  else
    v_new := least(99999999, v_old + v_amount);
  end if;
  v_delta := v_new - v_old;

  insert into public.user_profiles (
    owner_id, owner_email, kredi, kredi_welcome_gift, updated_at
  ) values (
    v_user, v_email, v_new, true, now()
  )
  on conflict (owner_id) do update
    set kredi = excluded.kredi,
        kredi_welcome_gift = true,
        owner_email = excluded.owner_email,
        updated_at = now();

  if v_role = 'aile' then
    v_birim := 'iyilik puanı';
  else
    v_birim := 'puan';
  end if;

  if v_delta <> 0 and v_email <> v_admin then
    if v_mode = 'set' then
      v_title := 'Puan güncellendi';
      v_body := format(
        'Bakiyeniz %s %s olarak ayarlandı.',
        v_new,
        v_birim
      );
    else
      v_title := format('Puan yüklendi: +%s %s', v_delta, v_birim);
      v_body := format(
        E'Hesabınıza +%s %s yüklendi.\nYeni bakiye: %s',
        v_delta,
        v_birim,
        v_new
      );
    end if;

    insert into public.bildirimler (
      owner_email, actor_email, actor_name, type, title, body, read
    ) values (
      v_email,
      v_admin,
      'Engelsiz Club',
      'kredi',
      v_title,
      v_body,
      false
    );
  end if;

  return json_build_object(
    'owner_email', v_email,
    'display_name', v_name,
    'user_type', v_role,
    'old_kredi', v_old,
    'new_kredi', v_new,
    'delta', v_delta,
    'mode', v_mode
  );
end;
$$;

revoke all on function public.admin_grant_kredi(text, int, text) from public;
grant execute on function public.admin_grant_kredi(text, int, text) to authenticated;

notify pgrst, 'reload schema';
