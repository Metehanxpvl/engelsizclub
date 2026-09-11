-- OS tray push: bildirimler INSERT → notify-push Edge Function (FCM).
-- Uygulama içi zil (bildirimler satırı) aynı kalır; FCM cihazdan bağımsızdır.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- Secrets (git'e yazmayın):
--   supabase secrets set NOTIFY_PUSH_SECRET="uzun-rastgele"
--   supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account",...}'
--   (yedek) supabase secrets set FCM_SERVER_KEY="AAAA..."
--   supabase functions deploy notify-push --no-verify-jwt
--   supabase functions deploy broadcast-push
--
-- Vault (pg_net tetikleyici için — service role SQL'e gömmeyin):
--   select vault.create_secret('AYNI_NOTIFY_PUSH_SECRET', 'notify_push_secret');
--
-- Alternatif: Dashboard → Database → Webhooks → bildirimler INSERT (ve mesaj collapse için UPDATE)
--   URL: https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/notify-push
--   HTTP Header Authorization: Bearer <NOTIFY_PUSH_SECRET>
-- Webhook + bu tetikleyiciyi birlikte açmayın (push_dedupe / push_dispatch tekiller).

create extension if not exists pg_net;

create table if not exists public.push_dispatch (
  bildirim_id bigint primary key references public.bildirimler(id) on delete cascade,
  event text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.push_dedupe (
  dedupe_key text primary key,
  created_at timestamptz not null default now()
);

alter table public.push_dispatch enable row level security;
alter table public.push_dedupe enable row level security;

-- Servis rolü RLS'i bypass eder; istemci yazamaz.

create or replace function public.enqueue_bildirim_os_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_url text := 'https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/notify-push';
  v_secret text;
  v_type text;
  v_ref text;
  v_dedupe text;
  v_owner text;
  v_actor text;
begin
  v_type := btrim(coalesce(new.type, ''));
  if v_type not in (
    'forum_like',
    'forum_follow',
    'forum_comment',
    'forum_reply',
    'mesaj'
  ) then
    return new;
  end if;
  if tg_op = 'UPDATE' and v_type <> 'mesaj' then
    return new;
  end if;
  if tg_op = 'UPDATE'
     and new.body is not distinct from old.body
     and new.created_at is not distinct from old.created_at then
    return new;
  end if;
  v_owner := lower(btrim(coalesce(new.owner_email, '')));
  v_actor := lower(btrim(coalesce(new.actor_email, '')));
  if v_owner = v_actor then
    return new;
  end if;
  v_ref := nullif(btrim(coalesce(new.sohbet_key, '')), '');
  if v_ref is null then
    v_ref := 'i:' || coalesce(new.ilan_id, 0)::text;
  end if;
  if tg_op = 'UPDATE' then
    v_dedupe := 'upd:' || v_type || ':' || v_owner || ':' || v_actor || ':' ||
      v_ref || ':' || floor(extract(epoch from new.created_at))::bigint;
  else
    v_dedupe := 'ins:' || v_type || ':' || v_owner || ':' || v_actor || ':' ||
      v_ref;
  end if;

  begin
    select ds.decrypted_secret
    into v_secret
    from vault.decrypted_secrets ds
    where ds.name = 'notify_push_secret'
    limit 1;
  exception
    when others then
      v_secret := null;
  end;

  if v_secret is null or btrim(v_secret) = '' then
    raise warning 'notify_push_secret vault yok; OS push atlandı (in-app zil durur)';
    return new;
  end if;

  begin
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || btrim(v_secret)
      ),
      body := jsonb_build_object(
        'id', new.id,
        'type', tg_op,
        'table', 'bildirimler',
        'dedupeKey', v_dedupe,
        'record', to_jsonb(new)
      ),
      timeout_milliseconds := 5000
    );
  exception
    when others then
      raise warning 'enqueue_bildirim_os_push: %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists bildirimler_os_push on public.bildirimler;
create trigger bildirimler_os_push
  after insert on public.bildirimler
  for each row
  execute function public.enqueue_bildirim_os_push();

drop trigger if exists bildirimler_os_push_upd on public.bildirimler;
create trigger bildirimler_os_push_upd
  after update of body, created_at, title on public.bildirimler
  for each row
  execute function public.enqueue_bildirim_os_push();

notify pgrst, 'reload schema';
