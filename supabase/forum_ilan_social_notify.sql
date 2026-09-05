-- Forum yanıt / beğeni + ilan sohbeti → uygulama içi bildirim (bildirimler).
-- Fix 42702: notif_public_actor_name used PL/pgSQL var "email" vs auth.users.email.
-- Kilit ekranı adı maskeli (Ş**** Ç******). FCM istemci `broadcast-push` ile gider.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- CLI token yok — yalnızca SQL Editor. Idempotent; etkinlik admin bildirimine dokunmaz.

-- ── Maskeli kamu adı ─────────────────────────────────────────
create or replace function public.mask_person_display_name(raw text)
returns text
language plpgsql
immutable
as $$
declare
  word text;
  parts text[];
  out_parts text[] := '{}';
  first_ch text;
  rest_len int;
begin
  if raw is null or btrim(raw) = '' then
    return 'Üye';
  end if;
  if position('@' in raw) > 0 or position('↔' in raw) > 0 then
    return 'Üye';
  end if;
  parts := regexp_split_to_array(btrim(raw), '\s+');
  foreach word in array parts loop
    if word is null or word = '' then
      continue;
    end if;
    first_ch := upper(left(word, 1));
    rest_len := greatest(char_length(word) - 1, 0);
    out_parts := out_parts || (first_ch || repeat('*', rest_len));
  end loop;
  if coalesce(array_length(out_parts, 1), 0) = 0 then
    return 'Üye';
  end if;
  return array_to_string(out_parts, ' ');
end;
$$;

create or replace function public.notif_public_actor_name(
  actor_email text,
  preferred text default ''
)
returns text
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_email text;
  pref text;
  resolved text;
begin
  pref := btrim(coalesce(preferred, ''));
  if lower(pref) = 'anonim' then
    return 'Anonim';
  end if;
  if pref <> '' and position('@' in pref) = 0 and position('↔' in pref) = 0 then
    return public.mask_person_display_name(pref);
  end if;

  -- v_email (not "email"): PL/pgSQL var + auth.users.email = 42702 ambiguous.
  v_email := lower(btrim(coalesce(actor_email, '')));
  if v_email = '' then
    return 'Üye';
  end if;

  select coalesce(
    nullif(btrim(p.profil ->> 'adSoyad'), ''),
    nullif(btrim(au.raw_user_meta_data ->> 'name'), ''),
    nullif(btrim(au.raw_user_meta_data ->> 'full_name'), '')
  )
  into resolved
  from public.user_profiles p
  left join auth.users au
    on au.id = p.owner_id
    or lower(au.email) = v_email
  where lower(p.owner_email) = v_email
  limit 1;

  if resolved is null then
    select coalesce(
      nullif(btrim(au.raw_user_meta_data ->> 'name'), ''),
      nullif(btrim(au.raw_user_meta_data ->> 'full_name'), '')
    )
    into resolved
    from auth.users au
    where lower(au.email) = v_email
    limit 1;
  end if;

  if resolved is null or btrim(resolved) = '' or position('@' in resolved) > 0 then
    return 'Üye';
  end if;
  return public.mask_person_display_name(resolved);
end;
$$;

revoke all on function public.notif_public_actor_name(text, text) from public;
grant execute on function public.notif_public_actor_name(text, text) to authenticated;

create or replace function public.insert_social_bildirim(
  p_owner text,
  p_actor text,
  p_actor_name text,
  p_type text,
  p_title text,
  p_body text,
  p_ilan_id bigint,
  p_sohbet_key text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  owner text;
  actor text;
begin
  owner := lower(btrim(coalesce(p_owner, '')));
  actor := lower(btrim(coalesce(p_actor, '')));
  if owner = '' or actor = '' or owner = actor then
    return;
  end if;

  if p_type = 'mesaj' then
    update public.bildirimler
    set
      actor_name = p_actor_name,
      title = p_title,
      body = p_body,
      ilan_id = coalesce(p_ilan_id, ilan_id),
      sohbet_key = coalesce(p_sohbet_key, sohbet_key),
      read = false,
      created_at = now()
    where type = 'mesaj'
      and lower(owner_email) = owner
      and lower(actor_email) = actor
      and read = false;

    if found then
      return;
    end if;
  elsif p_type = 'forum_like' then
    if exists (
      select 1
      from public.bildirimler b
      where b.type = 'forum_like'
        and lower(b.owner_email) = owner
        and lower(b.actor_email) = actor
        and coalesce(b.sohbet_key, '') = coalesce(p_sohbet_key, '')
        and coalesce(b.ilan_id, 0) = coalesce(p_ilan_id, 0)
    ) then
      return;
    end if;
  elsif p_sohbet_key is not null then
    if exists (
      select 1
      from public.bildirimler b
      where b.type = p_type
        and lower(b.owner_email) = owner
        and b.sohbet_key = p_sohbet_key
    ) then
      return;
    end if;
  end if;

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
    owner,
    actor,
    p_actor_name,
    p_type,
    p_title,
    p_body,
    p_ilan_id,
    p_sohbet_key,
    false
  );
end;
$$;

-- ── Forum yorum / yanıt ──────────────────────────────────────
create or replace function public.trg_notify_forum_comment()
returns trigger
language plpgsql
security definer
set search_path = public
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
  text_line := 'Mesajınıza ' || name || ' cevap verdi';
  parent_id_val := nullif(to_jsonb(new) ->> 'parent_id', '')::bigint;

  if parent_id_val is not null and parent_id_val > 0 then
    select lower(btrim(coalesce(c.owner_email, '')))
    into parent_owner
    from public.forum_comments c
    where c.id = parent_id_val;
    if parent_owner is not null and parent_owner <> '' and parent_owner <> actor then
      perform public.insert_social_bildirim(
        parent_owner,
        actor,
        name,
        'forum_reply',
        text_line,
        text_line,
        new.post_id,
        'c:' || new.id::text
      );
    end if;
  end if;

  select lower(btrim(coalesce(p.owner_email, '')))
  into post_owner
  from public.forum_posts p
  where p.id = new.post_id;

  if post_owner is not null
     and post_owner <> ''
     and post_owner <> actor
     and post_owner is distinct from parent_owner then
    perform public.insert_social_bildirim(
      post_owner,
      actor,
      name,
      'forum_comment',
      text_line,
      text_line,
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

-- ── Yorum beğenisi ───────────────────────────────────────────
create or replace function public.trg_notify_forum_comment_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  name text;
  text_line text;
  owner text;
  post_id_val bigint;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.owner_email, '')));
  if actor = '' then
    return new;
  end if;

  select
    lower(btrim(coalesce(c.owner_email, ''))),
    c.post_id
  into owner, post_id_val
  from public.forum_comments c
  where c.id = new.comment_id;

  if owner is null or owner = '' or owner = actor then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, '');
  text_line := 'Yorumunuzu ' || name || ' beğendi';
  perform public.insert_social_bildirim(
    owner,
    actor,
    name,
    'forum_like',
    text_line,
    text_line,
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

-- ── Gönderi beğenisi ─────────────────────────────────────────
create or replace function public.trg_notify_forum_post_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  name text;
  text_line text;
  owner text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.owner_email, '')));
  if actor = '' then
    return new;
  end if;

  select lower(btrim(coalesce(p.owner_email, '')))
  into owner
  from public.forum_posts p
  where p.id = new.post_id;

  if owner is null or owner = '' or owner = actor then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, '');
  text_line := 'Yorumunuzu ' || name || ' beğendi';
  perform public.insert_social_bildirim(
    owner,
    actor,
    name,
    'forum_like',
    text_line,
    text_line,
    new.post_id,
    null
  );
  return new;
end;
$$;

drop trigger if exists forum_likes_social_notify on public.forum_likes;
create trigger forum_likes_social_notify
  after insert on public.forum_likes
  for each row
  execute function public.trg_notify_forum_post_like();

-- ── İlan sohbeti ─────────────────────────────────────────────
create or replace function public.trg_notify_sohbet_mesaj()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  actor text;
  owner text;
  name text;
  text_line text;
  preview text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.sender_email, '')));
  owner := lower(btrim(coalesce(new.receiver_email, '')));
  if actor = '' or owner = '' or owner = actor then
    return new;
  end if;

  -- İlk teklif mesajı → ilan_teklif_notify (çift zil olmasın).
  if position('teklif verdim' in lower(coalesce(new.body, ''))) > 0 then
    return new;
  end if;

  -- Aynı anda giden teklif bildirimiyle çift zil olmasın.
  if exists (
    select 1
    from public.bildirimler b
    where b.type = 'teklif'
      and lower(b.owner_email) = owner
      and lower(b.actor_email) = actor
      and b.created_at > now() - interval '2 minutes'
  ) then
    return new;
  end if;

  name := public.notif_public_actor_name(actor, '');
  text_line := 'Mesajınıza ' || name || ' cevap verdi';
  preview := btrim(coalesce(new.body, ''));
  if char_length(preview) > 90 then
    preview := left(preview, 90) || '…';
  end if;
  if preview = '' then
    preview := text_line;
  end if;

  perform public.insert_social_bildirim(
    owner,
    actor,
    name,
    'mesaj',
    text_line,
    preview,
    null,
    nullif(btrim(coalesce(new.sohbet_key, '')), '')
  );
  return new;
end;
$$;

drop trigger if exists sohbet_mesajlari_social_notify on public.sohbet_mesajlari;
create trigger sohbet_mesajlari_social_notify
  after insert on public.sohbet_mesajlari
  for each row
  execute function public.trg_notify_sohbet_mesaj();

-- Çift satır (istemci + tetikleyici)
do $$
begin
  create unique index if not exists bildirimler_forum_reply_unique_idx
    on public.bildirimler (lower(owner_email), sohbet_key)
    where type = 'forum_reply' and sohbet_key is not null;
exception
  when others then null;
end $$;

do $$
begin
  create unique index if not exists bildirimler_forum_comment_unique_idx
    on public.bildirimler (lower(owner_email), sohbet_key)
    where type = 'forum_comment' and sohbet_key is not null;
exception
  when others then null;
end $$;

do $$
begin
  create unique index if not exists bildirimler_forum_like_unique_idx
    on public.bildirimler (
      lower(owner_email),
      lower(actor_email),
      coalesce(sohbet_key, ''),
      coalesce(ilan_id, 0)
    )
    where type = 'forum_like';
exception
  when others then null;
end $$;

notify pgrst, 'reload schema';
