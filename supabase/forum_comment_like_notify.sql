-- Yorum beğenisi → uygulama içi bildirim + kilit ekranı FCM.
-- Dashboard → SQL Editor → çalıştır.
-- Edge: broadcast-push (forum_comment_likes) deploy gerekir.

create extension if not exists pg_net with schema extensions;

create or replace function public.trg_fcm_db()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;
  if tg_table_name = 'sohbet_mesajlari'
     and position(
       'teklif verdim' in lower(coalesce(to_jsonb(new) ->> 'body', ''))
     ) > 0 then
    return new;
  end if;

  perform net.http_post(
    url := 'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/broadcast-push',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF',
      'apikey', 'sb_publishable_N7UfnXDF97YsuDTsFTq9zQ_lhnNtMgF'
    ),
    body := jsonb_build_object(
      'source', 'db',
      'table', tg_table_name,
      'record', to_jsonb(new)
    ),
    timeout_milliseconds := 4000
  );
  return new;
end;
$$;

create or replace function public.trg_notify_forum_comment_like()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor text;
  actor_id uuid;
  name text;
  text_line text;
  owner text;
  owner_id_val uuid;
  post_id_val bigint;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  actor_id := new.owner_id;
  actor := lower(btrim(coalesce(new.owner_email, '')));
  if actor = '' and actor_id is not null then
    select lower(btrim(coalesce(nullif(au.email, ''), up.owner_email, '')))
    into actor
    from auth.users au
    left join public.user_profiles up on up.owner_id = au.id
    where au.id = actor_id
    limit 1;
  end if;

  select
    lower(btrim(coalesce(
      nullif(c.owner_email, ''),
      au.email,
      up.owner_email,
      ''
    ))),
    c.owner_id,
    c.post_id
  into owner, owner_id_val, post_id_val
  from public.forum_comments c
  left join auth.users au on au.id = c.owner_id
  left join public.user_profiles up on up.owner_id = c.owner_id
  where c.id = new.comment_id
  limit 1;

  if owner_id_val is not null and actor_id is not null and owner_id_val = actor_id then
    return new;
  end if;
  if owner is null or owner = '' or actor is null or actor = '' or owner = actor then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, '');
  text_line := 'Yorumunuz beğenildi';
  perform public.insert_social_bildirim(
    owner,
    actor,
    name,
    'forum_like',
    text_line,
    coalesce('Yorumunuzu ' || name || ' beğendi', text_line),
    post_id_val,
    'c:' || new.comment_id::text
  );
  return new;
end;
$$;

drop trigger if exists forum_comment_likes_social_notify on public.forum_comment_likes;
create trigger forum_comment_likes_social_notify
  after insert on public.forum_comment_likes
  for each row
  execute function public.trg_notify_forum_comment_like();

drop trigger if exists forum_comment_likes_fcm on public.forum_comment_likes;
create trigger forum_comment_likes_fcm
  after insert on public.forum_comment_likes
  for each row
  execute function public.trg_fcm_db();

notify pgrst, 'reload schema';
