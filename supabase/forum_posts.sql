-- Engelsiz Club — forum gönderileri (herkes görür)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

create table if not exists public.forum_posts (
  id bigint generated always as identity primary key,
  author text not null,
  avatar text not null default '?',
  avatar_color bigint not null default 4281568586,
  category text not null default 'Genel',
  title text not null,
  content text not null,
  likes int not null default 0,
  comments int not null default 0,
  pinned boolean not null default false,
  expert boolean not null default false,
  anon boolean not null default false,
  meslek text not null default '',
  owner_email text not null default '',
  owner_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now()
);

-- Tablo daha önce int ile oluşturulduysa genişlet (renk değeri int sınırını aşar)
alter table public.forum_posts
  alter column avatar_color type bigint;

alter table public.forum_posts
  add column if not exists meslek text not null default '';

create index if not exists forum_posts_created_at_idx
  on public.forum_posts (created_at desc);

alter table public.forum_posts enable row level security;

drop policy if exists "forum_select_authenticated" on public.forum_posts;
create policy "forum_select_authenticated"
  on public.forum_posts for select
  to authenticated
  using (true);

drop policy if exists "forum_insert_own" on public.forum_posts;
create policy "forum_insert_own"
  on public.forum_posts for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "forum_delete_own" on public.forum_posts;
create policy "forum_delete_own"
  on public.forum_posts for delete
  to authenticated
  using (owner_id = auth.uid());

notify pgrst, 'reload schema';
