-- Engelsiz Club — kredi bakiyelerini güncelle
-- Admin: 1000 · Diğer tüm kullanıcılar: 50
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.user_profiles
  add column if not exists kredi int not null default 50;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

-- Varsayılan yeni satırlar 50 kredi ile başlasın
alter table public.user_profiles
  alter column kredi set default 50;

-- Admin hesabı
update public.user_profiles
set
  kredi = 1000,
  kredi_welcome_gift = true,
  updated_at = now()
where lower(trim(owner_email)) = 'sakir.caykara@gmail.com';

-- Diğer tüm kullanıcılar
update public.user_profiles
set
  kredi = 50,
  kredi_welcome_gift = true,
  updated_at = now()
where lower(trim(coalesce(owner_email, ''))) <> 'sakir.caykara@gmail.com';

notify pgrst, 'reload schema';
