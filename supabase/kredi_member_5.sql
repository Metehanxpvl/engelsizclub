-- Tüm üyeleri 5 puana çek (admin/test hesapları: kredi >= 1000 dokunulmaz)
update public.user_profiles
set
  kredi = 5,
  kredi_welcome_gift = true
where coalesce(kredi, 0) < 1000;

notify pgrst, 'reload schema';
