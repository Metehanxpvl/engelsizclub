-- Admin: iyilik market puanı sıralaması.
-- Puan, yer bildirimi / ilan / forum paylaşımında biriken iyilik_market_puan.
-- Supabase SQL Editor'da bir kez çalıştırın. Mevcut bakiyeyi sıfırlamaz.

alter table public.user_profiles
  add column if not exists iyilik_market_puan int not null default 0;

create or replace function public.admin_top_market_puani(p_limit int default 10)
returns table (
  rank int,
  owner_email text,
  display_name text,
  iyilik_market_puan int,
  updated_at timestamptz
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
    row_number() over (order by up.iyilik_market_puan desc, up.updated_at desc)::int as rank,
    up.owner_email::text,
    coalesce(
      nullif(trim(up.profil ->> 'adSoyad'), ''),
      split_part(up.owner_email, '@', 1)
    )::text as display_name,
    up.iyilik_market_puan::int,
    up.updated_at
  from public.user_profiles up
  where lower(trim(up.owner_email)) <> 'sakir.caykara@gmail.com'
    and coalesce(up.iyilik_market_puan, 0) > 0
  order by up.iyilik_market_puan desc, up.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
end;
$$;

revoke all on function public.admin_top_market_puani(int) from public;
grant execute on function public.admin_top_market_puani(int) to authenticated;

notify pgrst, 'reload schema';
