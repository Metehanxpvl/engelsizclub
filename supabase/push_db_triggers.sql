-- Mesaj / forum / haber / ilan insert → FCM (istemci kapalı olsa da gider).
-- Dashboard → SQL Editor → çalıştır.
-- Edge: broadcast-push source=db yolu (functions deploy gerekir).

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
  -- NEW.body forum/ilan satırında yok (42703). Yalnız jsonb ile bak.
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

drop trigger if exists sohbet_mesajlari_fcm on public.sohbet_mesajlari;
create trigger sohbet_mesajlari_fcm
  after insert on public.sohbet_mesajlari
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists forum_posts_fcm on public.forum_posts;
create trigger forum_posts_fcm
  after insert on public.forum_posts
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists duyurular_fcm on public.duyurular;
create trigger duyurular_fcm
  after insert on public.duyurular
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists ilanlar_fcm on public.ilanlar;
create trigger ilanlar_fcm
  after insert on public.ilanlar
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists forum_comments_fcm on public.forum_comments;
create trigger forum_comments_fcm
  after insert on public.forum_comments
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists forum_comment_likes_fcm on public.forum_comment_likes;
create trigger forum_comment_likes_fcm
  after insert on public.forum_comment_likes
  for each row
  execute function public.trg_fcm_db();

drop trigger if exists forum_likes_fcm on public.forum_likes;
create trigger forum_likes_fcm
  after insert on public.forum_likes
  for each row
  execute function public.trg_fcm_db();

notify pgrst, 'reload schema';
