-- yazaresul@gmail.com → iyilik puanı ve diğer puan bakiyesi 0
-- Supabase Dashboard → SQL Editor → Run

update public.user_profiles
set
  kredi = 0,
  kredi_welcome_gift = true,
  updated_at = now()
where lower(trim(owner_email)) = 'yazaresul@gmail.com'
   or owner_id in (
     select id from auth.users
     where lower(trim(email)) = 'yazaresul@gmail.com'
   );

-- Onaylanmış ama henüz hesaba işlenmemiş paketleri kilitle (tekrar çekilemesin)
update public.kredi_odemeleri
set
  credited = true,
  reviewed_at = coalesce(reviewed_at, now())
where lower(trim(owner_email)) = 'yazaresul@gmail.com'
  and status = 'onaylandi'
  and credited = false;

select owner_email, kredi, kredi_welcome_gift, updated_at
from public.user_profiles
where lower(trim(owner_email)) = 'yazaresul@gmail.com';
