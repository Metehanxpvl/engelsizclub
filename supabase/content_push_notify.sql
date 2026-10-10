-- Tüm içerik insert → kilit ekranı FCM (uygulama kapalıyken).
-- Dashboard → SQL Editor → çalıştır.
-- Edge: broadcast-push deploy gerekir (forum_likes, etkinlikler, gezi, kariyer, gelişim).

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
    timeout_milliseconds := 8000
  );
  return new;
end;
$$;

-- Etkinlik: onaylı insert + pending→approved. Scrape otomatik gitmez.
create or replace function public.trg_fcm_etkinlik()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  rec jsonb;
  status_new text;
  status_old text;
  listed_new boolean;
  listed_old boolean;
begin
  rec := to_jsonb(new);
  if coalesce(rec ->> 'is_active', 'true') = 'false' then
    return new;
  end if;
  if coalesce(rec ->> 'source', '') = 'avm_scrape' then
    return new;
  end if;
  status_new := lower(btrim(coalesce(nullif(rec ->> 'status', ''), 'approved')));
  listed_new := status_new not in ('pending', 'rejected');
  if not listed_new then
    return new;
  end if;
  if tg_op = 'UPDATE' then
    status_old := lower(btrim(coalesce(nullif(to_jsonb(old) ->> 'status', ''), 'approved')));
    listed_old := coalesce(to_jsonb(old) ->> 'is_active', 'true') <> 'false'
      and coalesce(to_jsonb(old) ->> 'source', '') <> 'avm_scrape'
      and status_old not in ('pending', 'rejected');
    if listed_old then
      return new;
    end if;
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
      'table', 'etkinlikler',
      'record', rec
    ),
    timeout_milliseconds := 4000
  );
  return new;
end;
$$;

drop trigger if exists sohbet_mesajlari_fcm on public.sohbet_mesajlari;
create trigger sohbet_mesajlari_fcm
  after insert on public.sohbet_mesajlari
  for each row execute function public.trg_fcm_db();

drop trigger if exists forum_posts_fcm on public.forum_posts;
create trigger forum_posts_fcm
  after insert on public.forum_posts
  for each row execute function public.trg_fcm_db();

drop trigger if exists duyurular_fcm on public.duyurular;
create trigger duyurular_fcm
  after insert on public.duyurular
  for each row execute function public.trg_fcm_db();

drop trigger if exists ilanlar_fcm on public.ilanlar;
create trigger ilanlar_fcm
  after insert on public.ilanlar
  for each row execute function public.trg_fcm_db();

drop trigger if exists forum_comments_fcm on public.forum_comments;
create trigger forum_comments_fcm
  after insert on public.forum_comments
  for each row execute function public.trg_fcm_db();

drop trigger if exists forum_comment_likes_fcm on public.forum_comment_likes;
create trigger forum_comment_likes_fcm
  after insert on public.forum_comment_likes
  for each row execute function public.trg_fcm_db();

drop trigger if exists forum_likes_fcm on public.forum_likes;
create trigger forum_likes_fcm
  after insert on public.forum_likes
  for each row execute function public.trg_fcm_db();

drop trigger if exists etkinlikler_fcm on public.etkinlikler;
drop trigger if exists etkinlikler_fcm_ins on public.etkinlikler;
drop trigger if exists etkinlikler_fcm_upd on public.etkinlikler;
create trigger etkinlikler_fcm_ins
  after insert on public.etkinlikler
  for each row execute function public.trg_fcm_etkinlik();
create trigger etkinlikler_fcm_upd
  after update of status, is_active on public.etkinlikler
  for each row execute function public.trg_fcm_etkinlik();

drop trigger if exists gezi_rehberi_fcm on public.gezi_rehberi;
create trigger gezi_rehberi_fcm
  after insert on public.gezi_rehberi
  for each row execute function public.trg_fcm_db();

drop trigger if exists kampanyalar_fcm on public.kampanyalar;
create trigger kampanyalar_fcm
  after insert on public.kampanyalar
  for each row execute function public.trg_fcm_db();

do $$
begin
  if to_regclass('public.gelisim_etkinlikleri') is not null then
    drop trigger if exists gelisim_etkinlikleri_fcm on public.gelisim_etkinlikleri;
    create trigger gelisim_etkinlikleri_fcm
      after insert on public.gelisim_etkinlikleri
      for each row execute function public.trg_fcm_db();
  end if;
  if to_regclass('public.kariyer_overrides') is not null then
    drop trigger if exists kariyer_overrides_fcm on public.kariyer_overrides;
    create trigger kariyer_overrides_fcm
      after insert on public.kariyer_overrides
      for each row execute function public.trg_fcm_db();
  end if;
end $$;

create or replace function public.trg_notify_forum_post_like()
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
      nullif(p.owner_email, ''),
      au.email,
      up.owner_email,
      ''
    ))),
    p.owner_id
  into owner, owner_id_val
  from public.forum_posts p
  left join auth.users au on au.id = p.owner_id
  left join public.user_profiles up on up.owner_id = p.owner_id
  where p.id = new.post_id
  limit 1;

  if owner_id_val is not null and actor_id is not null and owner_id_val = actor_id then
    return new;
  end if;
  if owner is null or owner = '' or actor is null or actor = '' or owner = actor then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, '');
  text_line := 'Gönderiniz beğenildi';
  perform public.insert_social_bildirim(
    owner,
    actor,
    name,
    'forum_like',
    text_line,
    coalesce('Gönderinizi ' || name || ' beğendi', text_line),
    new.post_id,
    null
  );
  return new;
end;
$$;

drop trigger if exists forum_likes_social_notify on public.forum_likes;
create trigger forum_likes_social_notify
  after insert on public.forum_likes
  for each row execute function public.trg_notify_forum_post_like();

notify pgrst, 'reload schema';
