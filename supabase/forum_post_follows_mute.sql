-- Forum gönderi bildirimi: kapat → mute (satır silinmez)
-- Supabase SQL Editor'da çalıştırın.

alter table public.forum_post_follows
  add column if not exists notify_enabled boolean not null default true;

-- Eski yorumcuları otomatik takip et (bildirim açık)
insert into public.forum_post_follows (owner_email, post_id, notify_enabled)
select distinct lower(trim(c.owner_email)), c.post_id, true
from public.forum_comments c
where coalesce(trim(c.owner_email), '') <> ''
  and c.post_id is not null
on conflict (owner_email, post_id) do nothing;

notify pgrst, 'reload schema';
