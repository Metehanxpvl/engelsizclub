-- Duyurular: yayın başlangıç / bitiş tarihi
-- Supabase SQL Editor'da çalıştırın.

alter table public.duyurular
  add column if not exists publish_at timestamptz;

alter table public.duyurular
  add column if not exists expires_at timestamptz;

-- Eski kayıtlarda boş publish_at → oluşturulma anı (hemen yayında)
update public.duyurular
set publish_at = coalesce(publish_at, created_at)
where publish_at is null;

create index if not exists duyurular_publish_idx
  on public.duyurular (publish_at desc nulls last);

create index if not exists duyurular_expires_idx
  on public.duyurular (expires_at asc nulls last);

notify pgrst, 'reload schema';
