-- Forum: kullanıcının beğenileri owner_id ile sorgulanıyor; index yalnızca okuma hızı için.
create index if not exists forum_likes_owner_idx on public.forum_likes (owner_id);
