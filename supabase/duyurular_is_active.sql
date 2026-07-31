-- Story / duyurular: is_active (pasif story gizlensin)
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.duyurular
  add column if not exists is_active boolean not null default true;

create index if not exists duyurular_active_created_idx
  on public.duyurular (is_active, created_at desc);

-- Normal kullanıcılar yalnız aktifleri görür (select policy güncellemesi)
drop policy if exists "duyuru_select_auth" on public.duyurular;
create policy "duyuru_select_auth"
  on public.duyurular for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
