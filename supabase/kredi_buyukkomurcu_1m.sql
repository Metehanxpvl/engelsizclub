-- buyukkomurcuseda@gmail.com → 1.000.000 iyilik puanı
-- Supabase Dashboard → SQL Editor → Run

alter table public.user_profiles
  add column if not exists kredi int not null default 0;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

update public.user_profiles
set
  kredi = 1000000,
  kredi_welcome_gift = true,
  updated_at = now()
where lower(trim(owner_email)) = 'buyukkomurcuseda@gmail.com';

-- Profil satırı yoksa (henüz giriş yapmamışsa) bu UPDATE 0 satır etkiler.
-- O durumda kullanıcı bir kez uygulamaya giriş yapsın, sonra bu SQL'i tekrar çalıştırın.
-- Kaç satır güncellendiğini görmek için:
-- select owner_email, kredi from public.user_profiles
-- where lower(trim(owner_email)) = 'buyukkomurcuseda@gmail.com';

notify pgrst, 'reload schema';
