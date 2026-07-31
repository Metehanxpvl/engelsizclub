-- Forum konu takibi (bildirim için)
create table if not exists public.forum_topic_follows (
  id bigint generated always as identity primary key,
  owner_email text not null,
  category text not null,
  created_at timestamptz not null default now(),
  unique (owner_email, category)
);

create index if not exists forum_topic_follows_cat_idx
  on public.forum_topic_follows (category);

alter table public.forum_topic_follows enable row level security;

drop policy if exists "forum_follow_select_own" on public.forum_topic_follows;
create policy "forum_follow_select_own"
  on public.forum_topic_follows for select
  to authenticated
  using (true);

drop policy if exists "forum_follow_insert_own" on public.forum_topic_follows;
create policy "forum_follow_insert_own"
  on public.forum_topic_follows for insert
  to authenticated
  with check (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "forum_follow_delete_own" on public.forum_topic_follows;
create policy "forum_follow_delete_own"
  on public.forum_topic_follows for delete
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "forum_follow_update_own" on public.forum_topic_follows;
create policy "forum_follow_update_own"
  on public.forum_topic_follows for update
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));
