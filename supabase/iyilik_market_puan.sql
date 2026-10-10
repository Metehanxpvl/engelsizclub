-- İyilik market puanı: yer bildirimi / ilan / forum paylaşımında +1.
-- Eski iyilik puanı (kredi) bu paylaşımlardan ARTIK artmaz.
-- Tüm kullanıcılar 0'dan başlar.
-- Dashboard → SQL Editor → çalıştır. Idempotent.

alter table public.user_profiles
  add column if not exists iyilik_market_puan int not null default 0;

update public.user_profiles
  set iyilik_market_puan = 0;

-- Eski aile kredi ödülünü kapat.
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
  -- Artık kredi yazmaz. Eski tetikleyiciler kalsa bile puan şişmez.
  select coalesce(kredi, 0) into v_balance
  from public.user_profiles
  where owner_id = p_user;
  return coalesce(v_balance, 0);
end;
$$;

create or replace function public.award_iyilik_market_puan()
returns int
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_user uuid := auth.uid();
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
  v_balance int := 0;
begin
  if v_user is null then
    raise exception 'Giriş yapın.';
  end if;

  insert into public.user_profiles (
    owner_id, owner_email, kredi_welcome_gift, iyilik_market_puan, updated_at
  ) values (
    v_user, v_email, true, 1, now()
  )
  on conflict (owner_id) do update
    set iyilik_market_puan = public.user_profiles.iyilik_market_puan + 1,
        updated_at = now();

  select coalesce(iyilik_market_puan, 0) into v_balance
  from public.user_profiles
  where owner_id = v_user;

  return v_balance;
end;
$$;

revoke all on function public.award_iyilik_market_puan() from public;
grant execute on function public.award_iyilik_market_puan() to authenticated;

notify pgrst, 'reload schema';
