-- Engelsiz Club — sohbet iletildi / okundu (WhatsApp tarzı tik)
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını Run
--
-- sent: satır var (id)
-- delivered_at: karşı taraf cihazında gördü (gelen kutu / sohbet açık)
-- read_at: karşı taraf sohbeti açtı

alter table public.sohbet_mesajlari
  add column if not exists delivered_at timestamptz;

create index if not exists sohbet_mesajlari_undelivered_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc)
  where delivered_at is null;

-- Alıcı hem iletildi hem okundu yazabilir (mevcut politika)
drop policy if exists "sohbet_update_receiver_read" on public.sohbet_mesajlari;
create policy "sohbet_update_receiver_read"
  on public.sohbet_mesajlari for update
  to authenticated
  using (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';
