-- İlan teklifi → uygulama içi bildirim (bildirimler type='teklif').
-- Ayrı offers / ilan_teklif tablosu yok; teklif satırı bildirimler + sohbet.
-- Kilit ekranı adı maskeli (Ş**** Ç******). FCM istemci `broadcast-push` ile gider.
-- Önce forum_ilan_social_notify.sql (mask_person_display_name / notif_public_actor_name).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- CLI token yok — yalnızca SQL Editor. Idempotent; etkinlik admin bildirimine dokunmaz.

-- ── Satırı maskele / kendi ilanına teklifi kes ───────────────
create or replace function public.trg_normalize_teklif_bildirim()
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
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;
  if new.type is distinct from 'teklif' then
    return new;
  end if;

  actor := lower(btrim(coalesce(new.actor_email, '')));
  owner := lower(btrim(coalesce(new.owner_email, '')));
  if actor = '' or owner = '' or owner = actor then
    return null;
  end if;

  name := public.notif_public_actor_name(actor, coalesce(new.actor_name, ''));
  text_line := 'İlanınıza ' || name || ' teklif verdi';

  new.actor_email := actor;
  new.owner_email := owner;
  new.actor_name := name;
  new.title := text_line;
  new.body := text_line;
  return new;
end;
$$;

drop trigger if exists bildirimler_teklif_normalize on public.bildirimler;
create trigger bildirimler_teklif_normalize
  before insert on public.bildirimler
  for each row
  when (new.type = 'teklif')
  execute function public.trg_normalize_teklif_bildirim();

-- ── Sohbet yedek: istemci teklif satırı yazamazsa ilk “teklif verdim” ──
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

  if position('teklif verdim' in lower(coalesce(new.body, ''))) = 0 then
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

drop trigger if exists sohbet_mesajlari_teklif_backup on public.sohbet_mesajlari;
create trigger sohbet_mesajlari_teklif_backup
  after insert on public.sohbet_mesajlari
  for each row
  execute function public.trg_notify_sohbet_teklif_backup();

-- Gönderen kendi teklif satırını görsün (idempotency)
drop policy if exists "bildirim_select_actor_teklif" on public.bildirimler;
create policy "bildirim_select_actor_teklif"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'teklif'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

create unique index if not exists bildirimler_teklif_unique_idx
  on public.bildirimler (
    lower(actor_email),
    lower(owner_email),
    coalesce(ilan_id, 0)
  )
  where type = 'teklif';

-- İlk “teklif verdim” mesajında mesaj zili çıkmasın (bu dosya tek başına yeter).
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

  if position('teklif verdim' in lower(coalesce(new.body, ''))) > 0 then
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

notify pgrst, 'reload schema';
