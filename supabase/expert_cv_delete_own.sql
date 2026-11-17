-- Sahip kendi Uzman Profilleri Köşesi ilanını silebilsin.
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

drop policy if exists "expert_profiles_delete_own" on public.expert_profiles;
create policy "expert_profiles_delete_own"
  on public.expert_profiles for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

create or replace function public.expert_profiles_delete_listing()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.uzman_kosesi_profiles where owner_id = old.owner_id;
  return old;
end;
$$;

drop trigger if exists expert_profiles_delete_listing_tg on public.expert_profiles;
create trigger expert_profiles_delete_listing_tg
  after delete on public.expert_profiles
  for each row execute function public.expert_profiles_delete_listing();

create or replace function public.delete_own_expert_profile()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'Giriş yapın.';
  end if;
  delete from public.expert_profiles where owner_id = uid;
  delete from public.uzman_kosesi_profiles where owner_id = uid;
end;
$$;

revoke all on function public.delete_own_expert_profile() from public;
grant execute on function public.delete_own_expert_profile() to authenticated;

notify pgrst, 'reload schema';
