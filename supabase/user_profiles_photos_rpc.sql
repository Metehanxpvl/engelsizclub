-- Diğer kullanıcıların profil fotoğraflarını (yalnız photo) okumak için.
-- Supabase Dashboard → SQL Editor → çalıştır

create or replace function public.get_user_photos(emails text[])
returns table(owner_email text, photo_data text)
language sql
security definer
set search_path = public
stable
as $$
  select p.owner_email, p.photo_data
  from public.user_profiles p
  where lower(p.owner_email) = any (
    select lower(unnest(emails))
  )
  and p.photo_data is not null
  and length(trim(p.photo_data)) > 0;
$$;

revoke all on function public.get_user_photos(text[]) from public;
grant execute on function public.get_user_photos(text[]) to authenticated;

notify pgrst, 'reload schema';
