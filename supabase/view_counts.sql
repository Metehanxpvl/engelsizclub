-- Unique görüntüleme: ilan (sahip görür) + forum (kaç kişi okudu)
-- Aynı kişi bir ilanı / konuyu bir kez sayılır. Sahip / yazar sayılmaz.

alter table public.forum_posts
  add column if not exists views int not null default 0;

alter table public.ilanlar
  add column if not exists views int not null default 0;

create table if not exists public.ilan_unique_views (
  ilan_id bigint not null references public.ilanlar (id) on delete cascade,
  viewer_key text not null,
  created_at timestamptz not null default now(),
  primary key (ilan_id, viewer_key)
);

create index if not exists ilan_unique_views_ilan_idx
  on public.ilan_unique_views (ilan_id);

alter table public.ilan_unique_views enable row level security;

create table if not exists public.forum_unique_views (
  post_id bigint not null references public.forum_posts (id) on delete cascade,
  viewer_key text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, viewer_key)
);

create index if not exists forum_unique_views_post_idx
  on public.forum_unique_views (post_id);

alter table public.forum_unique_views enable row level security;

create or replace function public.record_ilan_view(
  p_id bigint,
  p_guest_key text default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  v_count int;
  v_owner_id uuid;
  v_owner_email text;
  v_email text;
begin
  if p_id is null or p_id <= 0 then
    return 0;
  end if;

  select owner_id, lower(trim(owner_email))
    into v_owner_id, v_owner_email
  from public.ilanlar
  where id = p_id;
  if not found then
    return 0;
  end if;

  v_email := lower(trim(coalesce(auth.jwt() ->> 'email', '')));

  if auth.uid() is not null then
    if v_owner_id is not null and v_owner_id = auth.uid() then
      select coalesce(views, 0) into v_count from public.ilanlar where id = p_id;
      return v_count;
    end if;
    if v_owner_email is not null
       and v_owner_email <> ''
       and v_owner_email = v_email then
      select coalesce(views, 0) into v_count from public.ilanlar where id = p_id;
      return v_count;
    end if;
    v_key := 'u:' || auth.uid()::text;
  else
    if p_guest_key is null or length(trim(p_guest_key)) < 8 then
      select coalesce(views, 0) into v_count from public.ilanlar where id = p_id;
      return v_count;
    end if;
    v_key := 'g:' || left(
      regexp_replace(trim(p_guest_key), '[^a-zA-Z0-9\-]', '', 'g'),
      64
    );
    if length(v_key) < 10 then
      select coalesce(views, 0) into v_count from public.ilanlar where id = p_id;
      return v_count;
    end if;
  end if;

  insert into public.ilan_unique_views (ilan_id, viewer_key)
  values (p_id, v_key)
  on conflict do nothing;

  select count(*)::int into v_count
  from public.ilan_unique_views
  where ilan_id = p_id;

  update public.ilanlar set views = v_count where id = p_id;
  return v_count;
end;
$$;

create or replace function public.record_forum_view(
  p_id bigint,
  p_guest_key text default null
)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_key text;
  v_count int;
  v_owner_id uuid;
  v_owner_email text;
  v_email text;
begin
  if p_id is null or p_id <= 0 then
    return 0;
  end if;

  select owner_id, lower(trim(owner_email))
    into v_owner_id, v_owner_email
  from public.forum_posts
  where id = p_id;
  if not found then
    return 0;
  end if;

  v_email := lower(trim(coalesce(auth.jwt() ->> 'email', '')));

  if auth.uid() is not null then
    if v_owner_id is not null and v_owner_id = auth.uid() then
      select coalesce(views, 0) into v_count from public.forum_posts where id = p_id;
      return v_count;
    end if;
    if v_owner_email is not null
       and v_owner_email <> ''
       and v_owner_email = v_email then
      select coalesce(views, 0) into v_count from public.forum_posts where id = p_id;
      return v_count;
    end if;
    v_key := 'u:' || auth.uid()::text;
  else
    if p_guest_key is null or length(trim(p_guest_key)) < 8 then
      select coalesce(views, 0) into v_count from public.forum_posts where id = p_id;
      return v_count;
    end if;
    v_key := 'g:' || left(
      regexp_replace(trim(p_guest_key), '[^a-zA-Z0-9\-]', '', 'g'),
      64
    );
    if length(v_key) < 10 then
      select coalesce(views, 0) into v_count from public.forum_posts where id = p_id;
      return v_count;
    end if;
  end if;

  insert into public.forum_unique_views (post_id, viewer_key)
  values (p_id, v_key)
  on conflict do nothing;

  select count(*)::int into v_count
  from public.forum_unique_views
  where post_id = p_id;

  update public.forum_posts set views = v_count where id = p_id;
  return v_count;
end;
$$;

-- Eski çağrılar da unique sayıya düşsün
create or replace function public.forum_increment_views(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.record_forum_view(p_id, null);
end;
$$;

grant execute on function public.record_ilan_view(bigint, text) to anon, authenticated;
grant execute on function public.record_forum_view(bigint, text) to anon, authenticated;
grant execute on function public.forum_increment_views(bigint) to anon, authenticated;

notify pgrst, 'reload schema';
