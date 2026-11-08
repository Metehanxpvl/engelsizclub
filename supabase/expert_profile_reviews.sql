-- Uzman Profilleri Köşesi: yıldız + kullanıcı yorumu (yeni tablo).
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create table if not exists public.expert_profile_reviews (
  id bigint generated always as identity primary key,
  profile_id bigint not null references public.expert_profiles (id) on delete cascade,
  expert_owner_id uuid not null,
  author_id uuid not null references auth.users (id) on delete cascade,
  author_email text not null,
  author_name text not null default '',
  rating int not null,
  body text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint expert_profile_reviews_rating_chk check (rating between 1 and 5),
  constraint expert_profile_reviews_author_uk unique (profile_id, author_id)
);

create index if not exists expert_profile_reviews_profile_idx
  on public.expert_profile_reviews (profile_id, created_at desc);

create or replace function public.expert_profile_reviews_touch()
returns trigger
language plpgsql
as $$
begin
  new.author_email := lower(trim(new.author_email));
  new.author_name := trim(new.author_name);
  new.body := trim(new.body);
  new.updated_at := now();
  if new.expert_owner_id = new.author_id then
    raise exception 'Kendi profilinize yorum yazamazsınız.';
  end if;
  if length(new.body) < 3 then
    raise exception 'Yorum en az 3 karakter olmalı.';
  end if;
  return new;
end;
$$;

drop trigger if exists expert_profile_reviews_touch_tg
  on public.expert_profile_reviews;
create trigger expert_profile_reviews_touch_tg
  before insert or update on public.expert_profile_reviews
  for each row execute function public.expert_profile_reviews_touch();

alter table public.expert_profile_reviews enable row level security;

grant all on table public.expert_profile_reviews to postgres, service_role;
grant select on table public.expert_profile_reviews to anon, authenticated;
grant insert, update, delete on table public.expert_profile_reviews to authenticated;

drop policy if exists "expert_reviews_select" on public.expert_profile_reviews;
create policy "expert_reviews_select"
  on public.expert_profile_reviews for select
  to anon, authenticated
  using (true);

drop policy if exists "expert_reviews_insert_own" on public.expert_profile_reviews;
create policy "expert_reviews_insert_own"
  on public.expert_profile_reviews for insert
  to authenticated
  with check (
    author_id = auth.uid()
    and lower(author_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    and expert_owner_id <> auth.uid()
  );

drop policy if exists "expert_reviews_update_own" on public.expert_profile_reviews;
create policy "expert_reviews_update_own"
  on public.expert_profile_reviews for update
  to authenticated
  using (author_id = auth.uid())
  with check (author_id = auth.uid());

drop policy if exists "expert_reviews_delete_own" on public.expert_profile_reviews;
create policy "expert_reviews_delete_own"
  on public.expert_profile_reviews for delete
  to authenticated
  using (
    author_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
