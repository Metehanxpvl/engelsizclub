-- Forum gönderi takibi (Facebook tarzı "gönderi hakkında bildirim al")
-- Supabase Dashboard → SQL Editor → çalıştırın

create table if not exists public.forum_post_follows (
  id bigint generated always as identity primary key,
  owner_email text not null,
  post_id bigint not null references public.forum_posts (id) on delete cascade,
  notify_enabled boolean not null default true,
  created_at timestamptz not null default now(),
  unique (owner_email, post_id)
);

create index if not exists forum_post_follows_post_idx
  on public.forum_post_follows (post_id);

create index if not exists forum_post_follows_owner_idx
  on public.forum_post_follows (owner_email);

alter table public.forum_post_follows enable row level security;

-- Takipçileri okumak: yorum yazan kullanıcı bildirim gönderebilsin
drop policy if exists "forum_post_follow_select" on public.forum_post_follows;
create policy "forum_post_follow_select"
  on public.forum_post_follows for select
  to authenticated
  using (true);

drop policy if exists "forum_post_follow_insert_own" on public.forum_post_follows;
create policy "forum_post_follow_insert_own"
  on public.forum_post_follows for insert
  to authenticated
  with check (lower(owner_email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "forum_post_follow_delete_own" on public.forum_post_follows;
create policy "forum_post_follow_delete_own"
  on public.forum_post_follows for delete
  to authenticated
  using (lower(owner_email) = lower(auth.jwt() ->> 'email'));

notify pgrst, 'reload schema';
