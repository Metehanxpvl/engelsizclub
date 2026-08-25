-- Engelsiz Club — Keşfet (Reels/Shorts) şema + RLS
-- Supabase SQL Editor’de çalıştırın (qycrkqwqrysypvqaipqn)
-- Phase 1: yalnızca onaylı videolar herkese açık. Sahte/eğlence içeriği YOK.
-- Admin: sakir.caykara@gmail.com (JWT e-posta)

create extension if not exists pgcrypto;

-- ── Kategoriler ─────────────────────────────────────────────
create table if not exists public.kesfet_categories (
  slug text primary key,
  title text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

insert into public.kesfet_categories (slug, title, sort_order) values
  ('sana-ozel', 'Sana Özel', 0),
  ('engellilik', 'Engellilik', 10),
  ('hastaliklar', 'Hastalıklar', 20),
  ('haklar', 'Haklar & Yardımlar', 30),
  ('saglik', 'Sağlık', 40),
  ('egitim', 'Eğitim', 50),
  ('aile', 'Aile', 60),
  ('erisilebilirlik', 'Erişilebilirlik', 70)
on conflict (slug) do nothing;

-- ── Anahtar kelimeler (admin düzenler; Phase 2 tarama buna bağlanır) ──
create table if not exists public.kesfet_keywords (
  id bigint generated always as identity primary key,
  phrase text not null,
  polarity text not null check (polarity in ('positive', 'negative', 'safety')),
  weight int not null default 10,
  category_hint text not null default '',
  is_weak boolean not null default false,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (phrase, polarity)
);

create index if not exists kesfet_keywords_active_idx
  on public.kesfet_keywords (is_active, polarity);

-- ── Videolar ────────────────────────────────────────────────
create table if not exists public.kesfet_videos (
  id uuid primary key default gen_random_uuid(),
  youtube_video_id text not null,
  youtube_url text not null default '',
  title text not null default '',
  description text not null default '',
  thumbnail_url text not null default '',
  channel_name text not null default '',
  channel_url text not null default '',
  category text not null default 'engellilik'
    references public.kesfet_categories (slug) on update cascade,
  tags text[] not null default '{}',
  source_url text not null default '',
  related_article_id uuid,
  related_article_slug text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'hidden')),
  relevance_score int not null default 0,
  safety_flag boolean not null default false,
  safety_note text not null default '',
  language text not null default 'tr',
  duration_seconds int,
  crawl_source text not null default 'manual',
  oembed jsonb not null default '{}'::jsonb,
  like_count int not null default 0,
  comment_count int not null default 0,
  save_count int not null default 0,
  view_count int not null default 0,
  published_at timestamptz,
  created_by_email text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (youtube_video_id)
);

create index if not exists kesfet_videos_status_cat_idx
  on public.kesfet_videos (status, category, published_at desc);
create index if not exists kesfet_videos_status_created_idx
  on public.kesfet_videos (status, created_at desc);
create index if not exists kesfet_videos_score_idx
  on public.kesfet_videos (status, relevance_score desc);

-- ── Beğeni / kaydet / izlenme / yorum / rapor ───────────────
create table if not exists public.kesfet_likes (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null default '',
  created_at timestamptz not null default now(),
  unique (video_id, owner_id)
);
create index if not exists kesfet_likes_video_idx on public.kesfet_likes (video_id);

create table if not exists public.kesfet_saves (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null default '',
  created_at timestamptz not null default now(),
  unique (video_id, owner_id)
);
create index if not exists kesfet_saves_owner_idx
  on public.kesfet_saves (owner_id, created_at desc);

create table if not exists public.kesfet_views (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  owner_id uuid references auth.users (id) on delete set null,
  owner_email text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists kesfet_views_video_idx
  on public.kesfet_views (video_id, created_at desc);

create table if not exists public.kesfet_comments (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  body text not null,
  author text not null default 'Üye',
  owner_id uuid references auth.users (id) on delete set null,
  owner_email text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists kesfet_comments_video_idx
  on public.kesfet_comments (video_id, created_at);

create table if not exists public.kesfet_reports (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  reason text not null default '',
  owner_id uuid references auth.users (id) on delete set null,
  owner_email text not null default '',
  status text not null default 'pending'
    check (status in ('pending', 'reviewed', 'dismissed')),
  moderator_note text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists kesfet_reports_status_idx
  on public.kesfet_reports (status, created_at desc);

-- Phase 2: video ↔ bilgi kütüphanesi / hastalık bağları
create table if not exists public.kesfet_video_articles (
  id bigint generated always as identity primary key,
  video_id uuid not null references public.kesfet_videos (id) on delete cascade,
  article_kind text not null default 'web'
    check (article_kind in ('info_library', 'disease', 'web')),
  article_id text not null default '',
  article_slug text not null default '',
  created_at timestamptz not null default now()
);
create index if not exists kesfet_video_articles_video_idx
  on public.kesfet_video_articles (video_id);

-- ── updated_at ──────────────────────────────────────────────
create or replace function public.kesfet_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists kesfet_videos_updated_at on public.kesfet_videos;
create trigger kesfet_videos_updated_at
  before update on public.kesfet_videos
  for each row execute function public.kesfet_set_updated_at();

drop trigger if exists kesfet_keywords_updated_at on public.kesfet_keywords;
create trigger kesfet_keywords_updated_at
  before update on public.kesfet_keywords
  for each row execute function public.kesfet_set_updated_at();

-- ── Sayaç tetikleyicileri (SECURITY DEFINER — kullanıcı videosu güncelleyemesin) ──
create or replace function public.kesfet_bump_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.kesfet_videos
      set like_count = like_count + 1 where id = new.video_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.kesfet_videos
      set like_count = greatest(like_count - 1, 0) where id = old.video_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists kesfet_likes_count_tg on public.kesfet_likes;
create trigger kesfet_likes_count_tg
  after insert or delete on public.kesfet_likes
  for each row execute function public.kesfet_bump_like_count();

create or replace function public.kesfet_bump_save_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.kesfet_videos
      set save_count = save_count + 1 where id = new.video_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.kesfet_videos
      set save_count = greatest(save_count - 1, 0) where id = old.video_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists kesfet_saves_count_tg on public.kesfet_saves;
create trigger kesfet_saves_count_tg
  after insert or delete on public.kesfet_saves
  for each row execute function public.kesfet_bump_save_count();

create or replace function public.kesfet_bump_comment_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    update public.kesfet_videos
      set comment_count = comment_count + 1 where id = new.video_id;
    return new;
  elsif tg_op = 'DELETE' then
    update public.kesfet_videos
      set comment_count = greatest(comment_count - 1, 0) where id = old.video_id;
    return old;
  end if;
  return null;
end;
$$;

drop trigger if exists kesfet_comments_count_tg on public.kesfet_comments;
create trigger kesfet_comments_count_tg
  after insert or delete on public.kesfet_comments
  for each row execute function public.kesfet_bump_comment_count();

create or replace function public.kesfet_bump_view_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.kesfet_videos
    set view_count = view_count + 1 where id = new.video_id;
  return new;
end;
$$;

drop trigger if exists kesfet_views_count_tg on public.kesfet_views;
create trigger kesfet_views_count_tg
  after insert on public.kesfet_views
  for each row execute function public.kesfet_bump_view_count();

-- ── RLS ─────────────────────────────────────────────────────
alter table public.kesfet_categories enable row level security;
alter table public.kesfet_keywords enable row level security;
alter table public.kesfet_videos enable row level security;
alter table public.kesfet_likes enable row level security;
alter table public.kesfet_saves enable row level security;
alter table public.kesfet_views enable row level security;
alter table public.kesfet_comments enable row level security;
alter table public.kesfet_reports enable row level security;
alter table public.kesfet_video_articles enable row level security;

grant usage on schema public to anon, authenticated, service_role;

grant select on table public.kesfet_categories to anon, authenticated;
grant select, insert, update, delete on table public.kesfet_categories to authenticated;

grant select on table public.kesfet_keywords to anon, authenticated;
grant select, insert, update, delete on table public.kesfet_keywords to authenticated;

grant select on table public.kesfet_videos to anon, authenticated;
grant select, insert, update, delete on table public.kesfet_videos to authenticated;

grant select, insert, delete on table public.kesfet_likes to authenticated;
grant select on table public.kesfet_likes to anon;

grant select, insert, delete on table public.kesfet_saves to authenticated;
grant select on table public.kesfet_saves to anon;

grant select, insert on table public.kesfet_views to authenticated;
grant select on table public.kesfet_views to anon;

grant select on table public.kesfet_comments to anon, authenticated;
grant insert, delete on table public.kesfet_comments to authenticated;

grant insert on table public.kesfet_reports to authenticated;
grant select, update, delete on table public.kesfet_reports to authenticated;

grant select on table public.kesfet_video_articles to anon, authenticated;
grant insert, update, delete on table public.kesfet_video_articles to authenticated;

-- Kategoriler: herkes okur; yazma admin
drop policy if exists "kesfet_categories_select" on public.kesfet_categories;
create policy "kesfet_categories_select"
  on public.kesfet_categories for select
  to anon, authenticated
  using (true);

drop policy if exists "kesfet_categories_admin_write" on public.kesfet_categories;
create policy "kesfet_categories_admin_write"
  on public.kesfet_categories for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- Anahtar kelimeler: herkes okur (skor); yazma admin
drop policy if exists "kesfet_keywords_select" on public.kesfet_keywords;
create policy "kesfet_keywords_select"
  on public.kesfet_keywords for select
  to anon, authenticated
  using (is_active = true or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "kesfet_keywords_admin_write" on public.kesfet_keywords;
create policy "kesfet_keywords_admin_write"
  on public.kesfet_keywords for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- Videolar: onaylı herkese; admin hepsi; yazma yalnız admin
drop policy if exists "kesfet_videos_select" on public.kesfet_videos;
create policy "kesfet_videos_select"
  on public.kesfet_videos for select
  to anon, authenticated
  using (
    status = 'approved'
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kesfet_videos_admin_insert" on public.kesfet_videos;
create policy "kesfet_videos_admin_insert"
  on public.kesfet_videos for insert
  to authenticated
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "kesfet_videos_admin_update" on public.kesfet_videos;
create policy "kesfet_videos_admin_update"
  on public.kesfet_videos for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "kesfet_videos_admin_delete" on public.kesfet_videos;
create policy "kesfet_videos_admin_delete"
  on public.kesfet_videos for delete
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- Beğeni
drop policy if exists "kesfet_likes_select" on public.kesfet_likes;
create policy "kesfet_likes_select"
  on public.kesfet_likes for select
  to anon, authenticated
  using (true);

drop policy if exists "kesfet_likes_insert" on public.kesfet_likes;
create policy "kesfet_likes_insert"
  on public.kesfet_likes for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "kesfet_likes_delete" on public.kesfet_likes;
create policy "kesfet_likes_delete"
  on public.kesfet_likes for delete
  to authenticated
  using (owner_id = auth.uid());

-- Kaydet
drop policy if exists "kesfet_saves_select" on public.kesfet_saves;
create policy "kesfet_saves_select"
  on public.kesfet_saves for select
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kesfet_saves_insert" on public.kesfet_saves;
create policy "kesfet_saves_insert"
  on public.kesfet_saves for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "kesfet_saves_delete" on public.kesfet_saves;
create policy "kesfet_saves_delete"
  on public.kesfet_saves for delete
  to authenticated
  using (owner_id = auth.uid());

-- İzlenme (best-effort)
drop policy if exists "kesfet_views_select" on public.kesfet_views;
create policy "kesfet_views_select"
  on public.kesfet_views for select
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kesfet_views_insert" on public.kesfet_views;
create policy "kesfet_views_insert"
  on public.kesfet_views for insert
  to authenticated
  with check (owner_id = auth.uid() or owner_id is null);

-- Yorum: onaylı videonun yorumları herkese; yazma kendi
drop policy if exists "kesfet_comments_select" on public.kesfet_comments;
create policy "kesfet_comments_select"
  on public.kesfet_comments for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.kesfet_videos v
      where v.id = video_id
        and (
          v.status = 'approved'
          or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
        )
    )
  );

drop policy if exists "kesfet_comments_insert" on public.kesfet_comments;
create policy "kesfet_comments_insert"
  on public.kesfet_comments for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "kesfet_comments_delete" on public.kesfet_comments;
create policy "kesfet_comments_delete"
  on public.kesfet_comments for delete
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Rapor: kendi yazısı; admin okur
drop policy if exists "kesfet_reports_insert" on public.kesfet_reports;
create policy "kesfet_reports_insert"
  on public.kesfet_reports for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "kesfet_reports_select" on public.kesfet_reports;
create policy "kesfet_reports_select"
  on public.kesfet_reports for select
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "kesfet_reports_admin_update" on public.kesfet_reports;
create policy "kesfet_reports_admin_update"
  on public.kesfet_reports for update
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "kesfet_video_articles_select" on public.kesfet_video_articles;
create policy "kesfet_video_articles_select"
  on public.kesfet_video_articles for select
  to anon, authenticated
  using (
    exists (
      select 1 from public.kesfet_videos v
      where v.id = video_id
        and (
          v.status = 'approved'
          or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
        )
    )
  );

drop policy if exists "kesfet_video_articles_admin" on public.kesfet_video_articles;
create policy "kesfet_video_articles_admin"
  on public.kesfet_video_articles for all
  to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

notify pgrst, 'reload schema';
