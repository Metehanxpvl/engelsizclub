-- Pending kullanıcı etkinlik önerisi → admin uygulama içi bildirim.
-- AVM scrape (source='avm_scrape') ve onaylı/admin ekleme: bildirim yok.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
-- CLI token yok — yalnızca SQL Editor. Idempotent; satır silmez.

-- Gönderen kendi satırını görsün (idempotency; teklif politikası ile aynı fikir).
drop policy if exists "bildirim_select_actor_etkinlik_oneri" on public.bildirimler;
create policy "bildirim_select_actor_etkinlik_oneri"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'etkinlik_oneri'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Aynı öneri + aynı admin için tek satır (client + trigger çakışmasın).
create unique index if not exists bildirimler_etkinlik_oneri_unique_idx
  on public.bildirimler (lower(owner_email), sohbet_key)
  where type = 'etkinlik_oneri' and sohbet_key is not null;

create or replace function public.trg_notify_admin_etkinlik_oneri()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_email text := 'sakir.caykara@gmail.com';
  actor text;
  display text;
  heading text;
  city text;
  ref text;
begin
  if tg_op <> 'INSERT' then
    return new;
  end if;

  if coalesce(new.source, '') = 'avm_scrape' then
    return new;
  end if;

  if lower(trim(coalesce(new.status, ''))) <> 'pending' then
    return new;
  end if;

  actor := lower(trim(coalesce(new.created_by, '')));
  if actor = '' or actor = admin_email then
    return new;
  end if;

  heading := nullif(trim(coalesce(new.title, '')), '');
  if heading is null then
    heading := 'Etkinlik';
  end if;
  city := nullif(trim(coalesce(new.city, '')), '');
  display := split_part(actor, '@', 1);
  ref := 'e:' || new.id::text;

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
  )
  select
    admin_email,
    actor,
    display,
    'etkinlik_oneri',
    'Yeni etkinlik önerisi',
    case
      when city is null then heading
      else heading || ' · ' || city
    end,
    new.id,
    ref,
    false
  where not exists (
    select 1
    from public.bildirimler b
    where b.type = 'etkinlik_oneri'
      and b.sohbet_key = ref
      and lower(b.owner_email) = admin_email
  );

  return new;
end;
$$;

drop trigger if exists etkinlikler_admin_oneri_notify on public.etkinlikler;
create trigger etkinlikler_admin_oneri_notify
  after insert on public.etkinlikler
  for each row
  execute function public.trg_notify_admin_etkinlik_oneri();

notify pgrst, 'reload schema';
