-- Engelsiz Club — Play Store öncesi Supabase (SQL Editor’da sırayla çalıştır)
-- Eksik tablolar/policy’ler için güvenli (IF EXISTS / DROP IF EXISTS)

-- 1) İlan sahibi güncelleme
\i is not supported in Dashboard — paste files instead:
--    ilanlar_update_own.sql
--    bildirimler_mesaj_collapse.sql
--    user_kredi.sql (yorumlar güncel)

-- Aşağısı Dashboard’da tek seferde çalıştırılabilir:

-- İlan UPDATE (sahip: owner_id veya e-posta)
update public.ilanlar i
set owner_id = u.id
from auth.users u
where i.owner_id is null
  and lower(trim(i.owner_email)) = lower(u.email);

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Mesaj bildirimi: gönderen seç + güncelle (üst üste binmesin)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "bildirim_update_actor_mesaj" on public.bildirimler;
create policy "bildirim_update_actor_mesaj"
  on public.bildirimler for update
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Kredi kolonları
alter table public.user_profiles
  add column if not exists kredi int not null default 0;
alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

notify pgrst, 'reload schema';
