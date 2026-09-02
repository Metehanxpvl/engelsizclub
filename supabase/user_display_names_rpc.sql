-- Sohbet partnerlerinin görünen adını (yalnız display_name) okumak için.
-- user_profiles RLS yalnız kendi satırını açtığı için security definer RPC gerekir.
-- E-posta tam hali yeni bir sır olarak açılmaz; çağıran zaten sohbet e-postalarını bilir.
-- Supabase Dashboard → SQL Editor → çalıştır

create or replace function public.get_user_display_names(emails text[])
returns table(owner_email text, display_name text)
language sql
security definer
set search_path = public
stable
as $$
  with wanted as (
    select distinct lower(trim(e)) as email
    from unnest(coalesce(emails, '{}'::text[])) as e
    where e is not null
      and trim(e) <> ''
    limit 200
  )
  select
    w.email::text as owner_email,
    coalesce(
      nullif(trim(p.profil ->> 'adSoyad'), ''),
      nullif(trim(au.raw_user_meta_data ->> 'name'), ''),
      nullif(trim(au.raw_user_meta_data ->> 'full_name'), ''),
      nullif(split_part(coalesce(p.owner_email, au.email, w.email), '@', 1), '')
    )::text as display_name
  from wanted w
  left join public.user_profiles p on lower(p.owner_email) = w.email
  left join auth.users au
    on au.id = p.owner_id
    or (p.owner_id is null and lower(au.email) = w.email);
$$;

revoke all on function public.get_user_display_names(text[]) from public;
grant execute on function public.get_user_display_names(text[]) to authenticated;

notify pgrst, 'reload schema';
