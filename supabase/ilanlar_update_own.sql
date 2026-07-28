-- İlan sahibi kendi ilanını güncelleyebilir
-- Supabase Dashboard → SQL Editor → çalıştır

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

notify pgrst, 'reload schema';
