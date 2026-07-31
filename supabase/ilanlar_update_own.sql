-- İlan sahibi kendi ilanını güncelleyebilir
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını çalıştır

-- Eski kayıtlarda boş kalan owner_id'yi e-postadan doldur
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

notify pgrst, 'reload schema';
