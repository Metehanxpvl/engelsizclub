-- Engelsiz Club — kredi bakiyelerini güncelle
-- Admin: 10000 · Uzman/Bakıcı hediyesi uygulamada 25 · Aile başlangıç: 1 (uygulama)
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.user_profiles
  add column if not exists kredi int not null default 0;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

alter table public.user_profiles
  alter column kredi set default 0;

-- Admin hesabı → 10000
update public.user_profiles
set
  kredi = 10000,
  kredi_welcome_gift = true,
  updated_at = now()
where lower(trim(owner_email)) = 'sakir.caykara@gmail.com';

notify pgrst, 'reload schema';
