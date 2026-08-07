-- Forum tags kolonu + GIN index (yoksa ekle)
-- forum_scale_taxonomy.sql çalıştıysa zaten vardır; güvenle tekrar çalışır.

alter table public.forum_posts
  add column if not exists tags text[] not null default '{}'::text[];

create index if not exists forum_posts_tags_gin_idx
  on public.forum_posts using gin (tags);

comment on column public.forum_posts.tags is
  'Hazır tıbbi alt tip + kullanıcı #etiketleri';

notify pgrst, 'reload schema';
