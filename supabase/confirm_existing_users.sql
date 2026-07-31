-- Confirm email AÇMADAN ÖNCE bir kez çalıştırın.
-- Mevcut (eski) kullanıcıları onaylı sayar → girişleri kilitlenmez.
-- Supabase Dashboard → SQL Editor

-- 1) Onaysız eski hesapları onayla
update auth.users
set
  email_confirmed_at = coalesce(email_confirmed_at, now()),
  confirmed_at = coalesce(confirmed_at, now())
where email_confirmed_at is null
  and email is not null
  and deleted_at is null;

-- 2) Kimlik kayıtlarını da onaylı işaretle (varsa)
update auth.identities
set identity_data = coalesce(identity_data, '{}'::jsonb)
  || jsonb_build_object('email_verified', true)
where provider = 'email'
  and (
    identity_data->>'email_verified' is distinct from 'true'
  );

-- Kontrol
-- select id, email, email_confirmed_at from auth.users order by created_at desc limit 30;
