-- Misafir (anon): aktif duyuru / story okuma
-- Supabase Dashboard → SQL Editor → çalıştırın
-- (guest_public_read.sql içinde de var; yalnız duyuru için bu dosya yeterli)

drop policy if exists "duyuru_select_anon" on public.duyurular;
create policy "duyuru_select_anon"
  on public.duyurular for select
  to anon
  using (is_active = true);

notify pgrst, 'reload schema';
