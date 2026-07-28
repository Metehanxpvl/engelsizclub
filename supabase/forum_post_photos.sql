-- Forum gönderilerine fotoğraf (en fazla 2, uygulama tarafında sınırlı)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

alter table public.forum_posts
  add column if not exists photos jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';
