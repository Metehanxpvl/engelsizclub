-- Forum yorumu → kilit ekranı FCM (uygulama kapalıyken).
-- 1) Bu SQL'i Dashboard'da çalıştır
-- 2) Edge: npx supabase functions deploy broadcast-push --no-verify-jwt --project-ref qycrkqwqrysypvqaipqn

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

create or replace function public.trg_notify_forum_comment()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  actor text;
  name text;
  text_line text;
  parent_owner text;
  post_owner text;
  parent_id_val bigint;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.owner_email, '')));
  if actor = '' then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, coalesce(new.author, ''));
  parent_id_val := nullif(to_jsonb(new) ->> 'parent_id', '')::bigint;

  if parent_id_val is not null and parent_id_val > 0 then
    select lower(btrim(coalesce(c.owner_email, '')))
    into parent_owner
    from public.forum_comments c
    where c.id = parent_id_val;
    if parent_owner is not null and parent_owner <> '' and parent_owner <> actor then
      text_line := 'Yorumunuza cevap verildi';
      perform public.insert_social_bildirim(
        parent_owner,
        actor,
        name,
        'forum_reply',
        text_line,
        coalesce(nullif(btrim(coalesce(to_jsonb(new) ->> 'body', '')), ''), text_line),
        new.post_id,
        'c:' || new.id::text
      );
    end if;
  end if;

  select lower(btrim(coalesce(
    nullif(p.owner_email, ''),
    au.email,
    up.owner_email,
    ''
  )))
  into post_owner
  from public.forum_posts p
  left join auth.users au on au.id = p.owner_id
  left join public.user_profiles up on up.owner_id = p.owner_id
  where p.id = new.post_id
  limit 1;

  if post_owner is not null
     and post_owner <> ''
     and post_owner <> actor
     and post_owner is distinct from parent_owner then
    text_line := 'Gönderinize yorum yapıldı';
    perform public.insert_social_bildirim(
      post_owner,
      actor,
      name,
      'forum_comment',
      text_line,
      coalesce(nullif(btrim(coalesce(to_jsonb(new) ->> 'body', '')), ''), name || ' yorum yaptı'),
      new.post_id,
      'c:' || new.id::text
    );
  end if;

  return new;
end;
$$;

drop trigger if exists forum_comments_social_notify on public.forum_comments;
create trigger forum_comments_social_notify
  after insert on public.forum_comments
  for each row
  execute function public.trg_notify_forum_comment();

drop trigger if exists forum_comments_fcm on public.forum_comments;
create trigger forum_comments_fcm
  after insert on public.forum_comments
  for each row
  execute function public.trg_fcm_db();

notify pgrst, 'reload schema';
