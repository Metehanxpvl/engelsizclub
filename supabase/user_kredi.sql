-- Engelsiz Club — kullanıcı kredisi (cihazlar arası senkron)
-- Supabase Dashboard → SQL Editor → çalıştır
-- Admin: 10000 · Üye hediye: 5 (uygulama tarafı)

alter table public.user_profiles
  add column if not exists kredi int not null default 0;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

alter table public.user_profiles
  alter column kredi set default 0;

comment on column public.user_profiles.kredi is
  'Kullanıcı kredi bakiyesi (Web/iOS/Android ortak)';
comment on column public.user_profiles.kredi_welcome_gift is
  'Hoş geldin hediyesi bir kez tanımlandı mı';

notify pgrst, 'reload schema';
