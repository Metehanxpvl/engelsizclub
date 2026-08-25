-- Admin: anlık aktif kullanıcı + üye listesi
-- Supabase Dashboard → SQL Editor → çalıştır
-- Yalnızca sakir.caykara@gmail.com

create or replace function public.admin_user_stats()
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
begin
  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  if v_email <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin bu verileri görebilir';
  end if;

  return json_build_object(
    'total', (select count(*)::int from auth.users),
    'online', (
      select count(*)::int from public.user_presence
      where last_seen > now() - interval '90 seconds'
    ),
    'last_24h', (
      select count(*)::int from public.user_presence
      where last_seen > now() - interval '24 hours'
    ),
    'aile', (
      select count(*)::int from auth.users
      where lower(coalesce(raw_user_meta_data ->> 'user_type', '')) = 'aile'
    ),
    'uzman', (
      select count(*)::int from auth.users
      where lower(coalesce(raw_user_meta_data ->> 'user_type', '')) = 'uzman'
    ),
    'bakici', (
      select count(*)::int from auth.users
      where lower(coalesce(raw_user_meta_data ->> 'user_type', '')) in ('bakici', 'bakıcı')
    )
  );
end;
$$;

create or replace function public.admin_list_users(
  p_q text default '',
  p_filter text default 'all',
  p_limit int default 300
)
returns table (
  owner_email text,
  display_name text,
  user_type text,
  sehir text,
  kredi int,
  last_seen timestamptz,
  created_at timestamptz,
  is_online boolean
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text;
  v_q text;
  v_filter text;
begin
  v_email := lower(coalesce(auth.jwt() ->> 'email', ''));
  if v_email <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin bu listeyi görebilir';
  end if;

  v_q := lower(trim(coalesce(p_q, '')));
  v_filter := lower(trim(coalesce(p_filter, 'all')));

  return query
  select
    lower(coalesce(au.email, up.owner_email, ''))::text as owner_email,
    coalesce(
      nullif(trim(up.profil ->> 'adSoyad'), ''),
      split_part(coalesce(au.email, up.owner_email, 'kullanici'), '@', 1)
    )::text as display_name,
    lower(coalesce(au.raw_user_meta_data ->> 'user_type', ''))::text as user_type,
    coalesce(nullif(trim(up.profil ->> 'sehir'), ''), '')::text as sehir,
    coalesce(up.kredi, 0)::int as kredi,
    pr.last_seen,
    au.created_at,
    (pr.last_seen is not null and pr.last_seen > now() - interval '90 seconds') as is_online
  from auth.users au
  left join public.user_profiles up on up.owner_id = au.id
  left join public.user_presence pr
    on lower(pr.owner_email) = lower(coalesce(au.email, up.owner_email, ''))
  where coalesce(au.email, '') <> ''
    and (
      v_q = ''
      or lower(coalesce(au.email, '')) like '%' || v_q || '%'
      or lower(coalesce(up.profil ->> 'adSoyad', '')) like '%' || v_q || '%'
      or lower(coalesce(up.profil ->> 'sehir', '')) like '%' || v_q || '%'
    )
    and (
      v_filter = 'all'
      or (v_filter = 'online' and pr.last_seen > now() - interval '90 seconds')
      or (v_filter = 'aile' and lower(coalesce(au.raw_user_meta_data ->> 'user_type', '')) = 'aile')
      or (v_filter = 'uzman' and lower(coalesce(au.raw_user_meta_data ->> 'user_type', '')) = 'uzman')
      or (
        v_filter in ('bakici', 'bakıcı')
        and lower(coalesce(au.raw_user_meta_data ->> 'user_type', '')) in ('bakici', 'bakıcı')
      )
    )
  order by
    (pr.last_seen is not null and pr.last_seen > now() - interval '90 seconds') desc,
    pr.last_seen desc nulls last,
    au.created_at desc
  limit greatest(1, least(coalesce(p_limit, 300), 500));
end;
$$;

-- Presence tablosundan: sayıyla aynı kişiler (auth join kaçsa da isim/e-posta görünür)
create or replace function public.admin_online_users()
returns table (
  owner_email text,
  display_name text,
  user_type text,
  sehir text,
  kredi int,
  last_seen timestamptz,
  created_at timestamptz,
  is_online boolean
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin bu listeyi görebilir';
  end if;

  return query
  select
    lower(pr.owner_email)::text as owner_email,
    coalesce(
      nullif(trim(up.profil ->> 'adSoyad'), ''),
      split_part(pr.owner_email, '@', 1)
    )::text as display_name,
    lower(coalesce(au.raw_user_meta_data ->> 'user_type', ''))::text as user_type,
    coalesce(nullif(trim(up.profil ->> 'sehir'), ''), '')::text as sehir,
    coalesce(up.kredi, 0)::int as kredi,
    pr.last_seen,
    au.created_at,
    true as is_online
  from public.user_presence pr
  left join public.user_profiles up
    on lower(up.owner_email) = lower(pr.owner_email)
  left join auth.users au
    on lower(au.email) = lower(pr.owner_email)
  where pr.last_seen > now() - interval '90 seconds'
  order by pr.last_seen desc;
end;
$$;

revoke all on function public.admin_user_stats() from public;
revoke all on function public.admin_list_users(text, text, int) from public;
revoke all on function public.admin_online_users() from public;
grant execute on function public.admin_user_stats() to authenticated;
grant execute on function public.admin_list_users(text, text, int) to authenticated;
grant execute on function public.admin_online_users() to authenticated;

notify pgrst, 'reload schema';
