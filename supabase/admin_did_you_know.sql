-- Admin «Bunu biliyor musunuz?» → Güncel Duyurular kaydı.
-- Üyeler uygulamayı açınca pop-up + ana sayfa köşesinde görür.
-- Insert, mevcut duyurular_fcm tetikleyicisi ile kilit ekranı FCM yollar.
-- Dashboard SQL Editor → çalıştır.

create or replace function public.admin_send_did_you_know(p_body text)
returns jsonb
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  uid uuid;
  actor text;
  msg text;
  new_id bigint;
begin
  uid := auth.uid();
  if uid is null then
    raise exception 'Giriş gerekli.';
  end if;

  msg := btrim(coalesce(p_body, ''));
  if msg = '' then
    raise exception 'Bir mesaj yazın.';
  end if;
  if char_length(msg) > 800 then
    msg := left(msg, 800);
  end if;

  actor := lower(btrim(coalesce(auth.jwt() ->> 'email', '')));
  if actor is distinct from 'sakir.caykara@gmail.com' then
    select lower(btrim(coalesce(nullif(up.owner_email, ''), au.email, '')))
    into actor
    from public.user_profiles up
    left join auth.users au on au.id = up.owner_id
    where up.owner_id = uid
    limit 1;
  end if;
  if actor is distinct from 'sakir.caykara@gmail.com' then
    select lower(btrim(coalesce(au.email, '')))
    into actor
    from auth.users au
    where au.id = uid
    limit 1;
  end if;
  if actor is distinct from 'sakir.caykara@gmail.com'
     and uid is distinct from '61a14e10-f11b-40e7-8005-fa6c9d830a7f'::uuid then
    raise exception 'Admin gerekli.';
  end if;

  insert into public.duyurular (
    title,
    body,
    image_url,
    source_url,
    created_by,
    is_active,
    is_popup,
    publish_at
  ) values (
    'Bunu biliyor musunuz?',
    msg,
    '',
    'did_you_know',
    coalesce(nullif(actor, ''), 'sakir.caykara@gmail.com'),
    true,
    true,
    now()
  )
  returning id into new_id;

  return jsonb_build_object('ok', true, 'id', new_id);
end;
$$;

revoke all on function public.admin_send_did_you_know(text) from public;
grant execute on function public.admin_send_did_you_know(text) to authenticated;

notify pgrst, 'reload schema';
