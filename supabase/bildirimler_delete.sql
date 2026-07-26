-- Engelsiz Club — teklif bildirimlerini silme yetkisi
-- Supabase Dashboard → SQL Editor → New query → çalıştır
-- (bildirimler.sql zaten içeriyorsa tekrar güvenle çalışır)

drop policy if exists "bildirim_delete_own" on public.bildirimler;
create policy "bildirim_delete_own"
  on public.bildirimler for delete
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
