-- Engelsiz Club — yorum yanıtı + yorum beğenisi
-- Supabase SQL Editor → New query → çalıştır

-- Yanıt için parent_id
alter table public.forum_comments
  add column if not exists parent_id bigint
    references public.forum_comments (id) on delete cascade;

alter table public.forum_comments
  add column if not exists likes int not null default 0;

create index if not exists forum_comments_parent_idx
  on public.forum_comments (parent_id);

create index if not exists forum_comments_post_parent_idx
  on public.forum_comments (post_id, parent_id, created_at);

-- Yorum beğenileri
create table if not exists public.forum_comment_likes (
  id bigint generated always as identity primary key,
  comment_id bigint not null references public.forum_comments (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null default '',
  created_at timestamptz not null default now(),
  unique (comment_id, owner_id)
);

create index if not exists forum_comment_likes_comment_idx
  on public.forum_comment_likes (comment_id);

alter table public.forum_comment_likes enable row level security;

drop policy if exists "forum_comment_likes_select" on public.forum_comment_likes;
create policy "forum_comment_likes_select"
  on public.forum_comment_likes for select
  to authenticated
  using (true);

drop policy if exists "forum_comment_likes_insert" on public.forum_comment_likes;
create policy "forum_comment_likes_insert"
  on public.forum_comment_likes for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "forum_comment_likes_delete" on public.forum_comment_likes;
create policy "forum_comment_likes_delete"
  on public.forum_comment_likes for delete
  to authenticated
  using (owner_id = auth.uid());

-- Yorum beğeni sayacı güncellemesi
drop policy if exists "forum_comments_update_counts" on public.forum_comments;
create policy "forum_comments_update_counts"
  on public.forum_comments for update
  to authenticated
  using (true)
  with check (true);

notify pgrst, 'reload schema';
