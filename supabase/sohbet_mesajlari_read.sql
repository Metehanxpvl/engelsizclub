-- Engelsiz Club — sohbet mesajı okundu / okunmadı
-- Supabase Dashboard → SQL Editor → çalıştır
-- Alıcı sohbeti açınca read_at dolar; null = henüz okunmadı.

alter table public.sohbet_mesajlari
  add column if not exists read_at timestamptz;

create index if not exists sohbet_mesajlari_unread_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc)
  where read_at is null;

-- Alıcı kendi gelen mesajlarını okundu işaretleyebilir
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
