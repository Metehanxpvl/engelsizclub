-- Teklif spam önleme: aynı kişi aynı ilana yalnızca 1 teklif bildirimi
-- Supabase Dashboard → SQL Editor → çalıştır

-- Gönderen kendi teklif satırını görebilsin (idempotency kontrolü)
drop policy if exists "bildirim_select_actor_teklif" on public.bildirimler;
create policy "bildirim_select_actor_teklif"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'teklif'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Varsa mükerrer teklif satırlarını temizle (en eski kalsın)
delete from public.bildirimler a
using public.bildirimler b
where a.type = 'teklif'
  and b.type = 'teklif'
  and a.id > b.id
  and lower(a.actor_email) = lower(b.actor_email)
  and lower(a.owner_email) = lower(b.owner_email)
  and coalesce(a.ilan_id, 0) = coalesce(b.ilan_id, 0);

create unique index if not exists bildirimler_teklif_unique_idx
  on public.bildirimler (
    lower(actor_email),
    lower(owner_email),
    coalesce(ilan_id, 0)
  )
  where type = 'teklif';

notify pgrst, 'reload schema';
