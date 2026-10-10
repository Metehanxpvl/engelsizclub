-- ESKİ: forum/ilan paylaşımında kredi (+2 iyilik) yazıyordu.
-- YENİ: kredi artmaz. İyilik market puanı için iyilik_market_puan.sql çalıştırın.
-- Bu dosya eski tetikleyicileri kapatır (idempotent).

drop trigger if exists forum_posts_aile_iyilik on public.forum_posts;
drop trigger if exists ilanlar_aile_iyilik on public.ilanlar;

create or replace function public.award_aile_iyilik_puani(
  p_user uuid,
  p_email text default ''
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_balance int := 0;
begin
  select coalesce(kredi, 0) into v_balance
  from public.user_profiles
  where owner_id = p_user;
  return coalesce(v_balance, 0);
end;
$$;

notify pgrst, 'reload schema';
