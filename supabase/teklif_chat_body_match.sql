-- Otomatik teklif sohbet metni:
-- eski: "... teklif verdim. Görüşmek isterim."
-- yeni: "Merhaba, ... ilanınızla ilgili görüşmek istiyorum."
-- Dashboard SQL Editor → Run.

create or replace function public.is_auto_teklif_chat(body text)
returns boolean
language sql
immutable
as $$
  select
    position('teklif verdim' in lower(coalesce(body, ''))) > 0
    or position('görüşmek istiyorum' in lower(coalesce(body, ''))) > 0
    or position('gorusmek istiyorum' in lower(coalesce(body, ''))) > 0;
$$;

create or replace function public.trg_notify_sohbet_teklif_backup()
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
  key text;
  listing_id bigint;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  if not public.is_auto_teklif_chat(new.body) then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.sender_email, '')));
  owner := lower(btrim(coalesce(new.receiver_email, '')));
  if actor = '' or owner = '' or owner = actor then
    return new;
  end if;

  if exists (
    select 1
    from public.bildirimler b
    where b.type = 'teklif'
      and lower(b.owner_email) = owner
      and lower(b.actor_email) = actor
      and b.created_at > now() - interval '10 minutes'
  ) then
    return new;
  end if;

  key := nullif(btrim(coalesce(new.sohbet_key, '')), '');
  listing_id := null;

  begin
    name := public.notif_public_actor_name(actor, '');
    text_line := 'İlanınıza ' || name || ' teklif verdi';

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
      name,
      'teklif',
      text_line,
      text_line,
      listing_id,
      key,
      false
    );
  exception
    when unique_violation then
      null;
    when others then
      null;
  end;
  return new;
end;
$$;

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

  if public.is_auto_teklif_chat(new.body) then
    return new;
  end if;

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
