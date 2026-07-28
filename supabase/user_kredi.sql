-- Engelsiz Club — kullanıcı kredisi (cihazlar arası senkron)
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.user_profiles
  add column if not exists kredi int not null default 50;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

alter table public.user_profiles
  alter column kredi set default 50;

comment on column public.user_profiles.kredi is
  'Kullanıcı kredi bakiyesi (Web/iOS/Android ortak)';
comment on column public.user_profiles.kredi_welcome_gift is
  'Hoş geldin hediyesi bir kez tanımlandı mı';

notify pgrst, 'reload schema';
