-- Engelsiz Club — sohbet mesaj silme politikaları
-- Supabase Dashboard → SQL Editor → çalıştır
-- (Tablo zaten varsa sadece bu dosyayı çalıştırmanız yeterli)

drop policy if exists "sohbet_delete_own" on public.sohbet_mesajlari;
create policy "sohbet_delete_own"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (sender_id = auth.uid());

drop policy if exists "sohbet_delete_participant" on public.sohbet_mesajlari;
create policy "sohbet_delete_participant"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
