-- Aile: forum konusu ve ilan paylaşımında +2 iyilik puanı (user_profiles.kredi)
-- Uzman / bakıcı puanı bu paylaşımlardan ARTMAZ.
-- Supabase Dashboard → SQL Editor → çalıştırın (idempotent).
-- Dart: kredi_store.syncCloudKredi / forumShareSnack / ilanShareSnack

-- Rol: auth.users metadata (JWT boş olsa bile uzman/bakıcı aile sayılmaz).
create or replace function public.member_user_type(p_user uuid)
returns text
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  v_meta text := '';
  v_jwt text := '';
  v_role text := '';
begin
  if p_user is not null then
    select lower(btrim(coalesce(raw_user_meta_data ->> 'user_type', '')))
    into v_meta
    from auth.users
    where id = p_user;
  end if;
  v_jwt := lower(btrim(coalesce(
    auth.jwt() -> 'user_metadata' ->> 'user_type',
    ''
  )));
  v_role := coalesce(nullif(v_meta, ''), nullif(v_jwt, ''), '');
  if v_role in ('bakici', 'bakıcı') then
    return 'bakici';
  end if;
  if v_role = 'uzman' then
    return 'uzman';
  end if;
  if v_role = 'aile' then
    return 'aile';
  end if;
  return 'aile';
end;
$$;

revoke all on function public.member_user_type(uuid) from public;

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
  v_role text := public.member_user_type(p_user);
  v_email text := lower(coalesce(
    nullif(trim(p_email), ''),
    nullif(trim(auth.jwt() ->> 'email'), ''),
    ''
  ));
  v_balance int := 0;
begin
  if p_user is null or auth.uid() is null or p_user <> auth.uid() then
    return 0;
  end if;
  if v_role <> 'aile' then
    return 0;
  end if;

  insert into public.user_profiles (
    owner_id, owner_email, kredi, kredi_welcome_gift, updated_at
  ) values (
    p_user, v_email, 2, true, now()
  )
  on conflict (owner_id) do update
    set kredi = public.user_profiles.kredi + 2,
        updated_at = now();

  select coalesce(kredi, 0) into v_balance
  from public.user_profiles
  where owner_id = p_user;

  return v_balance;
end;
$$;

revoke all on function public.award_aile_iyilik_puani(uuid, text) from public;

create or replace function public.trg_award_aile_iyilik_forum()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.award_aile_iyilik_puani(NEW.owner_id, NEW.owner_email);
  return NEW;
end;
$$;

drop trigger if exists forum_posts_aile_iyilik on public.forum_posts;
create trigger forum_posts_aile_iyilik
  after insert on public.forum_posts
  for each row
  execute function public.trg_award_aile_iyilik_forum();

create or replace function public.trg_award_aile_iyilik_ilan()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.award_aile_iyilik_puani(NEW.owner_id, NEW.owner_email);
  return NEW;
end;
$$;

drop trigger if exists ilanlar_aile_iyilik on public.ilanlar;
create trigger ilanlar_aile_iyilik
  after insert on public.ilanlar
  for each row
  execute function public.trg_award_aile_iyilik_ilan();

notify pgrst, 'reload schema';
