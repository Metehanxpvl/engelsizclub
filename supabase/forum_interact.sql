-- Engelsiz Club — forum yorum + beğeni
-- Supabase SQL Editor → New query → çalıştır

-- Beğeniler
create table if not exists public.forum_likes (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.forum_posts (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null default '',
  created_at timestamptz not null default now(),
  unique (post_id, owner_id)
);

create index if not exists forum_likes_post_idx on public.forum_likes (post_id);

alter table public.forum_likes enable row level security;

drop policy if exists "forum_likes_select" on public.forum_likes;
create policy "forum_likes_select"
  on public.forum_likes for select
  to authenticated
  using (true);

drop policy if exists "forum_likes_insert" on public.forum_likes;
create policy "forum_likes_insert"
  on public.forum_likes for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "forum_likes_delete" on public.forum_likes;
create policy "forum_likes_delete"
  on public.forum_likes for delete
  to authenticated
  using (owner_id = auth.uid());

-- Yorumlar
create table if not exists public.forum_comments (
  id bigint generated always as identity primary key,
  post_id bigint not null references public.forum_posts (id) on delete cascade,
  author text not null,
  avatar text not null default '?',
  avatar_color bigint not null default 4281568586,
  body text not null,
  owner_email text not null default '',
  owner_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists forum_comments_post_idx
  on public.forum_comments (post_id, created_at);

alter table public.forum_comments enable row level security;

drop policy if exists "forum_comments_select" on public.forum_comments;
create policy "forum_comments_select"
  on public.forum_comments for select
  to authenticated
  using (true);

drop policy if exists "forum_comments_insert" on public.forum_comments;
create policy "forum_comments_insert"
  on public.forum_comments for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "forum_comments_delete" on public.forum_comments;
create policy "forum_comments_delete"
  on public.forum_comments for delete
  to authenticated
  using (owner_id = auth.uid());

-- Beğeni / yorum sayacı güncellemesi (herkes sayacı artırabilir)
drop policy if exists "forum_posts_update_counts" on public.forum_posts;
create policy "forum_posts_update_counts"
  on public.forum_posts for update
  to authenticated
  using (true)
  with check (true);

-- Gönderiye meslek (köşe yazısı) alanı
alter table public.forum_posts
  add column if not exists meslek text not null default '';

notify pgrst, 'reload schema';
