-- Mesaj bildirimleri: gönderen güncelleyebilsin / kendi satırını görebilsin
-- (aynı kişiden üst üste bildirim olmasın diye upsert için)
-- Supabase Dashboard → SQL Editor → çalıştır

-- Gönderen, oluşturduğu mesaj bildirimlerini seçebilir (güncellemek için)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen, okunmamış mesaj bildirimini güncelleyebilir (son mesaj + saat)
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

notify pgrst, 'reload schema';
