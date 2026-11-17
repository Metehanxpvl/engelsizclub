-- Uzman profil görüntülenmesi (kaç kişi bakmış). Yeni tablo.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create table if not exists public.expert_profile_views (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.expert_profiles (id) on delete cascade,
  viewer_key text not null,
  viewer_id uuid,
  created_at timestamptz not null default now(),
  constraint expert_profile_views_uk unique (profile_id, viewer_key)
);

create index if not exists expert_profile_views_profile_idx
  on public.expert_profile_views (profile_id);

alter table public.expert_profile_views enable row level security;

grant all on table public.expert_profile_views to postgres, service_role;
grant insert on table public.expert_profile_views to anon, authenticated;
grant select on table public.expert_profile_views to authenticated;

drop policy if exists "expert_views_insert" on public.expert_profile_views;
create policy "expert_views_insert"
  on public.expert_profile_views for insert
  to anon, authenticated
  with check (true);

drop policy if exists "expert_views_select_owner" on public.expert_profile_views;
create policy "expert_views_select_owner"
  on public.expert_profile_views for select
  to authenticated
  using (
    exists (
      select 1
      from public.expert_profiles p
      where p.id = expert_profile_views.profile_id
        and (
          p.owner_id = auth.uid()
          or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
        )
    )
  );

create or replace function public.record_expert_profile_view(
  p_profile_id bigint,
  p_anon_key text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_uid uuid := auth.uid();
  v_email text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  v_key text;
begin
  if p_profile_id is null or p_profile_id <= 0 then
    return;
  end if;
  select owner_id into v_owner
  from public.expert_profiles
  where id = p_profile_id;
  if v_owner is null then
    return;
  end if;
  if v_uid is not null and v_uid = v_owner then
    return;
  end if;
  if v_uid is not null then
    v_key := 'uid:' || v_uid::text;
  elsif v_email <> '' then
    v_key := 'email:' || v_email;
  else
    v_key := lower(trim(coalesce(p_anon_key, '')));
    if length(v_key) < 8 or length(v_key) > 80 then
      return;
    end if;
    v_key := 'anon:' || v_key;
  end if;
  insert into public.expert_profile_views (profile_id, viewer_key, viewer_id)
  values (p_profile_id, v_key, v_uid)
  on conflict (profile_id, viewer_key) do nothing;
end;
$$;

create or replace function public.expert_profile_view_count(p_profile_id bigint)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_uid uuid := auth.uid();
  v_email text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  v_count int;
begin
  if p_profile_id is null or p_profile_id <= 0 then
    return 0;
  end if;
  select owner_id into v_owner
  from public.expert_profiles
  where id = p_profile_id;
  if v_owner is null then
    return 0;
  end if;
  if not (
    (v_uid is not null and v_uid = v_owner)
    or v_email = 'sakir.caykara@gmail.com'
  ) then
    return 0;
  end if;
  select count(*)::int into v_count
  from public.expert_profile_views
  where profile_id = p_profile_id;
  return coalesce(v_count, 0);
end;
$$;

grant execute on function public.record_expert_profile_view(bigint, text)
  to anon, authenticated;
grant execute on function public.expert_profile_view_count(bigint)
  to authenticated;

notify pgrst, 'reload schema';
