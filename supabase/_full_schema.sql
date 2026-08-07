-- Engelsiz Club — combined schema for project ifwcrmehzipguncrnsxp
-- Generated from supabase/_migrate_order.txt
-- Run in Supabase SQL Editor (may need to split if editor size limit hits)


-- =============================================================================
-- FILE: user_profiles.sql
-- =============================================================================

-- Engelsiz Club — kullanıcı profili, foto, favoriler, bildirim tercihleri
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.user_profiles (
  owner_id uuid primary key references auth.users (id) on delete cascade,
  owner_email text not null,
  photo_data text,
  profil jsonb not null default '{}'::jsonb,
  cocuk jsonb not null default '{}'::jsonb,
  favorites jsonb not null default '[]'::jsonb,
  notifications jsonb not null default '{
    "ilanlar": true,
    "mesajlar": true,
    "duyurular": true
  }'::jsonb,
  kredi int not null default 0,
  kredi_welcome_gift boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists user_profiles_email_idx
  on public.user_profiles (owner_email);

alter table public.user_profiles enable row level security;

drop policy if exists "user_profiles_select_own" on public.user_profiles;
create policy "user_profiles_select_own"
  on public.user_profiles for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "user_profiles_insert_own" on public.user_profiles;
create policy "user_profiles_insert_own"
  on public.user_profiles for insert
  to authenticated
  with check (owner_id = auth.uid());

drop policy if exists "user_profiles_update_own" on public.user_profiles;
create policy "user_profiles_update_own"
  on public.user_profiles for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "user_profiles_delete_own" on public.user_profiles;
create policy "user_profiles_delete_own"
  on public.user_profiles for delete
  to authenticated
  using (owner_id = auth.uid());

notify pgrst, 'reload schema';

-- Mevcut tablolara kredi kolonları (yoksa ekle)
alter table public.user_profiles
  add column if not exists kredi int not null default 0;
alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;


-- =============================================================================
-- FILE: user_kredi.sql
-- =============================================================================

-- Engelsiz Club — kullanıcı kredisi (cihazlar arası senkron)
-- Supabase Dashboard → SQL Editor → çalıştır
-- Admin: 10000 · Uzman/Bakıcı hediye: 25 · Aile başlangıç: 1 (uygulama tarafı)

alter table public.user_profiles
  add column if not exists kredi int not null default 0;

alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

alter table public.user_profiles
  alter column kredi set default 0;

comment on column public.user_profiles.kredi is
  'Kullanıcı kredi bakiyesi (Web/iOS/Android ortak)';
comment on column public.user_profiles.kredi_welcome_gift is
  'Hoş geldin hediyesi bir kez tanımlandı mı';

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: user_presence.sql
-- =============================================================================

-- Engelsiz Club — sohbet çevrimiçi durumu (last_seen)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

create table if not exists public.user_presence (
  owner_email text primary key,
  owner_id uuid references auth.users (id) on delete cascade,
  last_seen timestamptz not null default now()
);

create index if not exists user_presence_last_seen_idx
  on public.user_presence (last_seen desc);

alter table public.user_presence enable row level security;

-- Giriş yapan herkes başkalarının çevrimiçi durumunu görebilir
drop policy if exists "user_presence_select_authenticated" on public.user_presence;
create policy "user_presence_select_authenticated"
  on public.user_presence for select
  to authenticated
  using (true);

-- Sadece kendi satırını yazabilir / güncelleyebilir
drop policy if exists "user_presence_upsert_own" on public.user_presence;
create policy "user_presence_upsert_own"
  on public.user_presence for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_presence_update_own" on public.user_presence;
create policy "user_presence_update_own"
  on public.user_presence for update
  to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: user_profiles_photos_rpc.sql
-- =============================================================================

-- Diğer kullanıcıların profil fotoğraflarını (yalnız photo) okumak için.
-- Supabase Dashboard → SQL Editor → çalıştır

create or replace function public.get_user_photos(emails text[])
returns table(owner_email text, photo_data text)
language sql
security definer
set search_path = public
stable
as $$
  select p.owner_email, p.photo_data
  from public.user_profiles p
  where lower(p.owner_email) = any (
    select lower(unnest(emails))
  )
  and p.photo_data is not null
  and length(trim(p.photo_data)) > 0;
$$;

revoke all on function public.get_user_photos(text[]) from public;
grant execute on function public.get_user_photos(text[]) to authenticated;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: user_blocks_reports.sql
-- =============================================================================

-- Kullanıcı engelleme + şikayet (rapor)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.user_blocks (
  id bigint generated always as identity primary key,
  blocker_email text not null,
  blocked_email text not null,
  created_at timestamptz not null default now(),
  constraint user_blocks_emails_chk check (
    length(trim(blocker_email)) > 3
    and length(trim(blocked_email)) > 3
    and lower(blocker_email) <> lower(blocked_email)
  ),
  constraint user_blocks_unique unique (blocker_email, blocked_email)
);

create index if not exists user_blocks_blocker_idx
  on public.user_blocks (lower(blocker_email));

create index if not exists user_blocks_blocked_idx
  on public.user_blocks (lower(blocked_email));

create table if not exists public.user_reports (
  id bigint generated always as identity primary key,
  reporter_email text not null,
  target_email text not null,
  reason text not null default '',
  context text not null default 'genel',
  detail text not null default '',
  created_at timestamptz not null default now(),
  constraint user_reports_emails_chk check (
    length(trim(reporter_email)) > 3
    and length(trim(target_email)) > 3
  )
);

create index if not exists user_reports_created_idx
  on public.user_reports (created_at desc);

create index if not exists user_reports_target_idx
  on public.user_reports (lower(target_email));

alter table public.user_blocks enable row level security;
alter table public.user_reports enable row level security;

-- Engeller: kendi engellerini yönet; kendisiyle ilgili engelleri okuyabilsin
-- (karşı taraf engellediyse mesaj gönderimi de engellensin)
drop policy if exists "user_blocks_select_own" on public.user_blocks;
drop policy if exists "user_blocks_select_involving_me" on public.user_blocks;
create policy "user_blocks_select_involving_me"
  on public.user_blocks for select
  to authenticated
  using (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(blocked_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_blocks_insert_own" on public.user_blocks;
create policy "user_blocks_insert_own"
  on public.user_blocks for insert
  to authenticated
  with check (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "user_blocks_delete_own" on public.user_blocks;
create policy "user_blocks_delete_own"
  on public.user_blocks for delete
  to authenticated
  using (
    lower(blocker_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Şikayetler: kullanıcı kendi gönderdiğini görür; admin hepsini görür
drop policy if exists "user_reports_select_own_or_admin" on public.user_reports;
create policy "user_reports_select_own_or_admin"
  on public.user_reports for select
  to authenticated
  using (
    lower(reporter_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "user_reports_insert_own" on public.user_reports;
create policy "user_reports_insert_own"
  on public.user_reports for insert
  to authenticated
  with check (
    lower(reporter_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: ilanlar.sql
-- =============================================================================

-- Engelsiz Club — ortak ilan tablosu
-- Supabase Dashboard → SQL Editor → New query → çalıştır

create table if not exists public.ilanlar (
  id bigint generated always as identity primary key,
  kind text not null check (kind in ('uzman', 'bakici', 'ikinciel')),
  title text not null,
  city text not null,
  district text not null default '',
  note text not null default '',
  budget text not null default '',
  price text not null default '',
  original_price text not null default '',
  uzmanlik text,
  tani text,
  age text,
  frequency text,
  hours text,
  category text,
  condition text,
  brand text,
  emoji text,
  photos jsonb not null default '[]'::jsonb,
  urgent boolean not null default false,
  views int not null default 0,
  offers int not null default 0,
  poster_name text not null,
  poster_avatar text not null,
  owner_email text not null,
  owner_id uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  -- Uzman / bakıcı ilanlarında en fazla 2 fotoğraf
  constraint ilanlar_photos_max_check check (
    (kind in ('uzman', 'bakici') and jsonb_array_length(photos) <= 2)
    or kind = 'ikinciel'
  )
);

create index if not exists ilanlar_created_at_idx on public.ilanlar (created_at desc);
create index if not exists ilanlar_owner_email_idx on public.ilanlar (owner_email);
create index if not exists ilanlar_kind_idx on public.ilanlar (kind);

alter table public.ilanlar enable row level security;

-- Giriş yapmış herkes tüm ilanları görebilir
drop policy if exists "ilanlar_select_authenticated" on public.ilanlar;
create policy "ilanlar_select_authenticated"
  on public.ilanlar for select
  to authenticated
  using (true);

-- Kendi oturumuyla ilan ekleyebilir (e-posta JWT'de yoksa da çalışır)
drop policy if exists "ilanlar_insert_own" on public.ilanlar;
create policy "ilanlar_insert_own"
  on public.ilanlar for insert
  to authenticated
  with check (owner_id = auth.uid());

-- Sadece kendi ilanını silebilir
drop policy if exists "ilanlar_delete_own" on public.ilanlar;
create policy "ilanlar_delete_own"
  on public.ilanlar for delete
  to authenticated
  using (owner_id = auth.uid());

-- Sadece kendi ilanını güncelleyebilir (owner_id veya e-posta)
drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';

-- Mevcut tablolar için (tablo zaten varsa yukarıdaki CREATE atlanır):
-- Uzman / bakıcı ilanlarında en fazla 2 fotoğraf kısıtı
alter table public.ilanlar drop constraint if exists ilanlar_photos_max_check;
alter table public.ilanlar
  add constraint ilanlar_photos_max_check check (
    (kind in ('uzman', 'bakici') and jsonb_array_length(photos) <= 2)
    or kind = 'ikinciel'
  );


-- =============================================================================
-- FILE: ilanlar_status.sql
-- =============================================================================

-- İlan satıldı / yayından kaldır durumu
alter table public.ilanlar
  add column if not exists status text not null default 'active';

alter table public.ilanlar
  drop constraint if exists ilanlar_status_check;

alter table public.ilanlar
  add constraint ilanlar_status_check
  check (status in ('active', 'sold'));

create index if not exists ilanlar_status_idx on public.ilanlar (status);


-- =============================================================================
-- FILE: ilanlar_update_own.sql
-- =============================================================================

-- İlan sahibi kendi ilanını güncelleyebilir
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını çalıştır

-- Eski kayıtlarda boş kalan owner_id'yi e-postadan doldur
update public.ilanlar i
set owner_id = u.id
from auth.users u
where i.owner_id is null
  and lower(trim(i.owner_email)) = lower(u.email);

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: ilan_photos_storage.sql
-- =============================================================================

-- İlan fotoğrafları için Supabase Storage bucket (R2 yedeği / alternatif)
-- Supabase SQL Editor'da çalıştırın.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'ilan-photos',
  'ilan-photos',
  true,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- Herkes okuyabilir (ilan kartlarında URL)
drop policy if exists "ilan_photos_public_read" on storage.objects;
create policy "ilan_photos_public_read"
  on storage.objects for select
  to anon, authenticated
  using (bucket_id = 'ilan-photos');

-- Sadece giriş yapmış kullanıcı kendi klasörüne yükler: {user_id}/...
drop policy if exists "ilan_photos_auth_insert" on storage.objects;
create policy "ilan_photos_auth_insert"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "ilan_photos_auth_update" on storage.objects;
create policy "ilan_photos_auth_update"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "ilan_photos_auth_delete" on storage.objects;
create policy "ilan_photos_auth_delete"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'ilan-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );


-- =============================================================================
-- FILE: forum_posts.sql
-- =============================================================================

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
  photos jsonb not null default '[]'::jsonb,
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


-- =============================================================================
-- FILE: forum_post_photos.sql
-- =============================================================================

-- Forum gönderilerine fotoğraf (en fazla 2, uygulama tarafında sınırlı)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

alter table public.forum_posts
  add column if not exists photos jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: forum_interact.sql
-- =============================================================================

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


-- =============================================================================
-- FILE: forum_comment_replies_likes.sql
-- =============================================================================

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


-- =============================================================================
-- FILE: forum_post_follows.sql
-- =============================================================================

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


-- =============================================================================
-- FILE: forum_post_follows_mute.sql
-- =============================================================================

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


-- =============================================================================
-- FILE: forum_topic_follows.sql
-- =============================================================================

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


-- =============================================================================
-- FILE: forum_scale_taxonomy.sql
-- =============================================================================

-- Forum ölçekleme: dinam hastalık / alt kategori + konu filtre alanları
-- Supabase SQL Editor'da çalıştırın.
-- Not: Firestore değil; mevcut Postgres `forum_posts` genişletilir.

-- 1) Ana hastalıklar (dinamik)
create table if not exists public.forum_diseases (
  id text primary key,
  label text not null,
  short_label text not null default '',
  icon text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

-- 2) Alt kategoriler
create table if not exists public.forum_sub_categories (
  id text primary key,
  disease_id text not null references public.forum_diseases (id) on delete cascade,
  label text not null,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists forum_sub_cat_disease_idx
  on public.forum_sub_categories (disease_id, sort_order);

-- 3) Konu alanları (forum_posts)
alter table public.forum_posts
  add column if not exists disease_id text references public.forum_diseases (id) on delete set null;

alter table public.forum_posts
  add column if not exists sub_category_id text references public.forum_sub_categories (id) on delete set null;

alter table public.forum_posts
  add column if not exists age_group text not null default '';

alter table public.forum_posts
  add column if not exists tags text[] not null default '{}';

alter table public.forum_posts
  add column if not exists views int not null default 0;

alter table public.forum_posts
  add column if not exists is_resolved boolean not null default false;

-- Performans indeksleri (100k+)
create index if not exists forum_posts_disease_created_idx
  on public.forum_posts (disease_id, created_at desc);

create index if not exists forum_posts_subcat_created_idx
  on public.forum_posts (sub_category_id, created_at desc);

create index if not exists forum_posts_age_created_idx
  on public.forum_posts (age_group, created_at desc);

create index if not exists forum_posts_resolved_created_idx
  on public.forum_posts (is_resolved, created_at desc);

create index if not exists forum_posts_comments_created_idx
  on public.forum_posts (comments desc, created_at desc);

create index if not exists forum_posts_likes_created_idx
  on public.forum_posts (likes desc, created_at desc);

create index if not exists forum_posts_tags_gin_idx
  on public.forum_posts using gin (tags);

-- RLS: herkes okuyabilir (authenticated + mevcut guest politikalarına uyum)
alter table public.forum_diseases enable row level security;
alter table public.forum_sub_categories enable row level security;

drop policy if exists "forum_diseases_select" on public.forum_diseases;
create policy "forum_diseases_select"
  on public.forum_diseases for select
  to anon, authenticated
  using (is_active = true);

drop policy if exists "forum_sub_categories_select" on public.forum_sub_categories;
create policy "forum_sub_categories_select"
  on public.forum_sub_categories for select
  to anon, authenticated
  using (is_active = true);

-- Seed ana hastalıklar
insert into public.forum_diseases (id, label, short_label, sort_order) values
  ('serebral-palsi', 'Serebral Palsi', 'Serebral Palsi', 1),
  ('otizm', 'Otizm Spektrum Bozukluğu', 'Otizm', 2),
  ('down-sendromu', 'Down Sendromu', 'Down Sendromu', 3),
  ('sma', 'SMA (Spinal Müsküler Atrofi)', 'SMA', 4),
  ('dehb', 'DEHB', 'DEHB', 5),
  ('gelisim-geriligi', 'Gelişim Geriliği', 'Gelişim Geriliği', 6),
  ('duyu-butunleme', 'Duyu Bütünleme Sorunları', 'Duyu Bütünleme', 7),
  ('iletisim-bozukluklari', 'İletişim Bozuklukları', 'İletişim Bozuklukları', 8),
  ('nadir-hastaliklar', 'Nadir Hastalıklar', 'Nadir Hastalıklar', 9),
  ('genel', 'Genel Konular', 'Genel', 100)
on conflict (id) do update set
  label = excluded.label,
  short_label = excluded.short_label,
  sort_order = excluded.sort_order,
  is_active = true;

-- Seed alt kategoriler (örnek set — yönetilebilir)
insert into public.forum_sub_categories (id, disease_id, label, sort_order) values
  ('otizm-egitim', 'otizm', 'Eğitim & Terapi', 1),
  ('otizm-gunluk', 'otizm', 'Günlük Yaşam', 2),
  ('otizm-aile', 'otizm', 'Aile Destek', 3),
  ('sp-fizyo', 'serebral-palsi', 'Fizyoterapi', 1),
  ('sp-ortez', 'serebral-palsi', 'Ortez / Cihaz', 2),
  ('sp-aile', 'serebral-palsi', 'Aile Destek', 3),
  ('down-egitim', 'down-sendromu', 'Eğitim', 1),
  ('down-saglik', 'down-sendromu', 'Sağlık', 2),
  ('sma-tedavi', 'sma', 'Tedavi & İlaç', 1),
  ('sma-bakim', 'sma', 'Bakım', 2),
  ('dehb-okul', 'dehb', 'Okul', 1),
  ('dehb-davranis', 'dehb', 'Davranış', 2),
  ('genel-soru', 'genel', 'Soru-Cevap', 1),
  ('genel-deneyim', 'genel', 'Deneyim Paylaşımı', 2)
on conflict (id) do update set
  label = excluded.label,
  sort_order = excluded.sort_order,
  is_active = true;

-- Eski category metninden disease_id doldur (best-effort)
update public.forum_posts p
set disease_id = d.id
from public.forum_diseases d
where p.disease_id is null
  and (
    lower(p.category) = lower(d.short_label)
    or lower(p.category) = lower(d.label)
    or lower(p.category) like '%' || lower(d.short_label) || '%'
  );

update public.forum_posts
set disease_id = 'genel'
where disease_id is null
  and (
    lower(category) like '%genel%'
    or category = ''
    or category is null
  );

notify pgrst, 'reload schema';

-- Görüntülenme sayacı (atomik)
create or replace function public.forum_increment_views(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.forum_posts
  set views = coalesce(views, 0) + 1
  where id = p_id;
end;
$$;

grant execute on function public.forum_increment_views(bigint) to anon, authenticated;


-- =============================================================================
-- FILE: forum_tags_ensure.sql
-- =============================================================================

-- Forum tags kolonu + GIN index (yoksa ekle)
-- forum_scale_taxonomy.sql çalıştıysa zaten vardır; güvenle tekrar çalışır.

alter table public.forum_posts
  add column if not exists tags text[] not null default '{}'::text[];

create index if not exists forum_posts_tags_gin_idx
  on public.forum_posts using gin (tags);

comment on column public.forum_posts.tags is
  'Hazır tıbbi alt tip + kullanıcı #etiketleri';

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: bildirimler.sql
-- =============================================================================

-- Engelsiz Club — uygulama içi bildirimler (teklif vb.)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.bildirimler (
  id bigint generated always as identity primary key,
  owner_email text not null,
  actor_email text not null,
  actor_name text not null default '',
  type text not null default 'teklif',
  title text not null,
  body text not null,
  ilan_id bigint,
  sohbet_key text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists bildirimler_owner_idx
  on public.bildirimler (owner_email, created_at desc);
create index if not exists bildirimler_unread_idx
  on public.bildirimler (owner_email, read)
  where read = false;

alter table public.bildirimler enable row level security;

-- Alıcı kendi bildirimlerini görür
drop policy if exists "bildirim_select_own" on public.bildirimler;
create policy "bildirim_select_own"
  on public.bildirimler for select
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen (teklif veren) başkasına bildirim oluşturabilir
drop policy if exists "bildirim_insert_actor" on public.bildirimler;
create policy "bildirim_insert_actor"
  on public.bildirimler for insert
  to authenticated
  with check (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Alıcı okundu işaretleyebilir
drop policy if exists "bildirim_update_own" on public.bildirimler;
create policy "bildirim_update_own"
  on public.bildirimler for update
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Alıcı silebilir
drop policy if exists "bildirim_delete_own" on public.bildirimler;
create policy "bildirim_delete_own"
  on public.bildirimler for delete
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen mesaj bildirimini seçebilir (upsert için)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen mesaj bildirimini güncelleyebilir (aynı kişiden tek satır)
drop policy if exists "bildirim_update_actor_mesaj" on public.bildirimler;
create policy "bildirim_update_actor_mesaj"
  on public.bildirimler for update
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: bildirimler_delete.sql
-- =============================================================================

-- Engelsiz Club — teklif bildirimlerini silme yetkisi
-- Supabase Dashboard → SQL Editor → New query → çalıştır
-- (bildirimler.sql zaten içeriyorsa tekrar güvenle çalışır)

drop policy if exists "bildirim_delete_own" on public.bildirimler;
create policy "bildirim_delete_own"
  on public.bildirimler for delete
  to authenticated
  using (
    lower(owner_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: bildirimler_mesaj_collapse.sql
-- =============================================================================

-- Mesaj bildirimleri: gönderen güncelleyebilsin / kendi satırını görebilsin
-- (aynı kişiden üst üste bildirim olmasın diye upsert için)
-- Supabase Dashboard → SQL Editor → çalıştır

-- Gönderen, oluşturduğu mesaj bildirimlerini seçebilir (güncellemek için)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Gönderen, okunmamış mesaj bildirimini güncelleyebilir (son mesaj + saat)
drop policy if exists "bildirim_update_actor_mesaj" on public.bildirimler;
create policy "bildirim_update_actor_mesaj"
  on public.bildirimler for update
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: bildirimler_teklif_unique.sql
-- =============================================================================

-- Teklif spam önleme: aynı kişi aynı ilana yalnızca 1 teklif bildirimi
-- Supabase Dashboard → SQL Editor → çalıştır

-- Gönderen kendi teklif satırını görebilsin (idempotency kontrolü)
drop policy if exists "bildirim_select_actor_teklif" on public.bildirimler;
create policy "bildirim_select_actor_teklif"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'teklif'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Varsa mükerrer teklif satırlarını temizle (en eski kalsın)
delete from public.bildirimler a
using public.bildirimler b
where a.type = 'teklif'
  and b.type = 'teklif'
  and a.id > b.id
  and lower(a.actor_email) = lower(b.actor_email)
  and lower(a.owner_email) = lower(b.owner_email)
  and coalesce(a.ilan_id, 0) = coalesce(b.ilan_id, 0);

create unique index if not exists bildirimler_teklif_unique_idx
  on public.bildirimler (
    lower(actor_email),
    lower(owner_email),
    coalesce(ilan_id, 0)
  )
  where type = 'teklif';

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: kredi_admin_notify.sql
-- =============================================================================

-- Her puan (kredi) artışında admin'e uygulama içi bildirim.
-- Supabase SQL Editor → çalıştırın.

create or replace function public.trg_notify_admin_kredi_yukleme()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  delta int;
  admin_email text := 'sakir.caykara@gmail.com';
  display text;
  actor text;
begin
  if tg_op = 'INSERT' then
    delta := coalesce(new.kredi, 0);
  else
    delta := coalesce(new.kredi, 0) - coalesce(old.kredi, 0);
  end if;

  if delta <= 0 then
    return new;
  end if;

  actor := lower(trim(coalesce(new.owner_email, '')));
  if actor = '' or actor = admin_email then
    return new;
  end if;

  display := coalesce(
    nullif(trim(new.profil ->> 'adSoyad'), ''),
    split_part(actor, '@', 1)
  );

  insert into public.bildirimler (
    owner_email,
    actor_email,
    actor_name,
    type,
    title,
    body,
    ilan_id,
    sohbet_key,
    read
  ) values (
    admin_email,
    actor,
    display,
    'kredi',
    format('Puan yükleme: +%s puan', delta),
    format(
      E'%s (%s)\n+%s puan yüklendi\nYeni bakiye: %s',
      display,
      actor,
      delta,
      coalesce(new.kredi, 0)
    ),
    null,
    null,
    false
  );

  return new;
end;
$$;

drop trigger if exists user_profiles_kredi_notify on public.user_profiles;
create trigger user_profiles_kredi_notify
  after insert or update of kredi
  on public.user_profiles
  for each row
  execute function public.trg_notify_admin_kredi_yukleme();

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: kredi_odemeleri.sql
-- =============================================================================

-- Engelsiz Club — kredi ödeme bildirimleri (Armut tarzı)
-- Supabase Dashboard → SQL Editor → çalıştır
-- Onay: Table Editor'da status = 'onaylandi' yapın; uygulama krediyi yükler.

create table if not exists public.kredi_odemeleri (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  owner_email text not null,
  paket_adet int not null check (paket_adet > 0),
  paket_fiyat text not null,
  gonderen_ad text not null,
  not_text text not null default '',
  referans_kodu text not null,
  status text not null default 'beklemede'
    check (status in ('beklemede', 'onaylandi', 'reddedildi')),
  credited boolean not null default false,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists kredi_odemeleri_owner_idx
  on public.kredi_odemeleri (owner_id, created_at desc);
create index if not exists kredi_odemeleri_status_idx
  on public.kredi_odemeleri (status) where status = 'beklemede';

alter table public.kredi_odemeleri enable row level security;

drop policy if exists "kredi_odemeleri_select_own" on public.kredi_odemeleri;
create policy "kredi_odemeleri_select_own"
  on public.kredi_odemeleri for select
  to authenticated
  using (owner_id = auth.uid());

drop policy if exists "kredi_odemeleri_insert_own" on public.kredi_odemeleri;
create policy "kredi_odemeleri_insert_own"
  on public.kredi_odemeleri for insert
  to authenticated
  with check (owner_id = auth.uid());

-- Kullanıcı status değiştiremez; yalnızca onaylı kayıtlarda credited işaretleyebilir.
drop policy if exists "kredi_odemeleri_claim_credit" on public.kredi_odemeleri;
create policy "kredi_odemeleri_claim_credit"
  on public.kredi_odemeleri for update
  to authenticated
  using (owner_id = auth.uid() and status = 'onaylandi' and credited = false)
  with check (owner_id = auth.uid() and status = 'onaylandi' and credited = true);

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: sohbet_mesajlari.sql
-- =============================================================================

-- Engelsiz Club — gerçek sohbet mesajları
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.sohbet_mesajlari (
  id bigint generated always as identity primary key,
  sohbet_key text not null,
  sender_email text not null,
  sender_id uuid references auth.users (id) on delete set null,
  receiver_email text not null,
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz
);

-- Mevcut tablolara kolon ekle
alter table public.sohbet_mesajlari
  add column if not exists read_at timestamptz;

create index if not exists sohbet_mesajlari_key_idx
  on public.sohbet_mesajlari (sohbet_key, created_at);
create index if not exists sohbet_mesajlari_receiver_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc);
create index if not exists sohbet_mesajlari_unread_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc)
  where read_at is null;

alter table public.sohbet_mesajlari enable row level security;

drop policy if exists "sohbet_select_participants" on public.sohbet_mesajlari;
create policy "sohbet_select_participants"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "sohbet_insert_own" on public.sohbet_mesajlari;
create policy "sohbet_insert_own"
  on public.sohbet_mesajlari for insert
  to authenticated
  with check (sender_id = auth.uid());

-- Kendi gönderdiğiniz mesajı silin
drop policy if exists "sohbet_delete_own" on public.sohbet_mesajlari;
create policy "sohbet_delete_own"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (sender_id = auth.uid());

-- Katılımcı olduğunuz sohbetteki tüm mesajları silin (sohbeti temizle)
drop policy if exists "sohbet_delete_participant" on public.sohbet_mesajlari;
create policy "sohbet_delete_participant"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Alıcı gelen mesajı okundu işaretleyebilir
drop policy if exists "sohbet_update_receiver_read" on public.sohbet_mesajlari;
create policy "sohbet_update_receiver_read"
  on public.sohbet_mesajlari for update
  to authenticated
  using (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Realtime (yoksa hata vermemesi için)
do $$
begin
  alter publication supabase_realtime add table public.sohbet_mesajlari;
exception
  when duplicate_object then null;
  when others then null;
end $$;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: sohbet_mesajlari_read.sql
-- =============================================================================

-- Engelsiz Club — sohbet mesajı okundu / okunmadı
-- Supabase Dashboard → SQL Editor → çalıştır
-- Alıcı sohbeti açınca read_at dolar; null = henüz okunmadı.

alter table public.sohbet_mesajlari
  add column if not exists read_at timestamptz;

create index if not exists sohbet_mesajlari_unread_idx
  on public.sohbet_mesajlari (receiver_email, created_at desc)
  where read_at is null;

-- Alıcı kendi gelen mesajlarını okundu işaretleyebilir
drop policy if exists "sohbet_update_receiver_read" on public.sohbet_mesajlari;
create policy "sohbet_update_receiver_read"
  on public.sohbet_mesajlari for update
  to authenticated
  using (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: sohbet_mesajlari_delete.sql
-- =============================================================================

-- Engelsiz Club — sohbet mesaj silme politikaları
-- Supabase Dashboard → SQL Editor → çalıştır
-- (Tablo zaten varsa sadece bu dosyayı çalıştırmanız yeterli)

drop policy if exists "sohbet_delete_own" on public.sohbet_mesajlari;
create policy "sohbet_delete_own"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (sender_id = auth.uid());

drop policy if exists "sohbet_delete_participant" on public.sohbet_mesajlari;
create policy "sohbet_delete_participant"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(sender_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    or lower(receiver_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: duyurular.sql
-- =============================================================================

-- Güncel Duyurular & Haberler (Instagram story tarzı)
-- Supabase Dashboard → SQL Editor → çalıştır
--
-- Instagram story/gönderi kaydı (DB yükü yok):
--   image_url = 'instagram:embed'   -- kısa işaretçi, medya YOK
--   source_url = 'https://www.instagram.com/reel/...'  -- yalnız metin link
-- Video/dosya Supabase'e yazılmaz; oynatma istemcide Instagram üzerinden yapılır.

create table if not exists public.duyurular (
  id bigint generated always as identity primary key,
  title text not null,
  body text not null default '',
  image_url text not null default '',
  source_url text,
  created_by text not null default '',
  is_active boolean not null default true,
  is_popup boolean not null default false,
  publish_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists duyurular_created_idx
  on public.duyurular (created_at desc);

alter table public.duyurular enable row level security;

-- Herkes okuyabilir (girişli)
drop policy if exists "duyuru_select_auth" on public.duyurular;
create policy "duyuru_select_auth"
  on public.duyurular for select
  to authenticated
  using (true);

-- Yalnız admin ekler
drop policy if exists "duyuru_insert_admin" on public.duyurular;
create policy "duyuru_insert_admin"
  on public.duyurular for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Yalnız admin siler / günceller
drop policy if exists "duyuru_update_admin" on public.duyurular;
create policy "duyuru_update_admin"
  on public.duyurular for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "duyuru_delete_admin" on public.duyurular;
create policy "duyuru_delete_admin"
  on public.duyurular for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: duyurular_is_active.sql
-- =============================================================================

-- Story / duyurular: is_active (pasif story gizlensin)
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.duyurular
  add column if not exists is_active boolean not null default true;

create index if not exists duyurular_active_created_idx
  on public.duyurular (is_active, created_at desc);

-- Normal kullanıcılar yalnız aktifleri görür (select policy güncellemesi)
drop policy if exists "duyuru_select_auth" on public.duyurular;
create policy "duyuru_select_auth"
  on public.duyurular for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: duyurular_is_popup.sql
-- =============================================================================

-- Duyurular: pop-up haber vs yatay liste (Güncel Haber)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

alter table public.duyurular
  add column if not exists is_popup boolean not null default false;

create index if not exists duyurular_popup_active_created_idx
  on public.duyurular (is_popup, is_active, created_at desc);

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: duyurular_schedule.sql
-- =============================================================================

-- Duyurular: yayın başlangıç / bitiş tarihi
-- Supabase SQL Editor'da çalıştırın.

alter table public.duyurular
  add column if not exists publish_at timestamptz;

alter table public.duyurular
  add column if not exists expires_at timestamptz;

-- Eski kayıtlarda boş publish_at → oluşturulma anı (hemen yayında)
update public.duyurular
set publish_at = coalesce(publish_at, created_at)
where publish_at is null;

create index if not exists duyurular_publish_idx
  on public.duyurular (publish_at desc nulls last);

create index if not exists duyurular_expires_idx
  on public.duyurular (expires_at asc nulls last);

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: duyurular_guest_read.sql
-- =============================================================================

-- Misafir (anon): aktif duyuru / story okuma
-- Supabase Dashboard → SQL Editor → çalıştırın
-- (guest_public_read.sql içinde de var; yalnız duyuru için bu dosya yeterli)

drop policy if exists "duyuru_select_anon" on public.duyurular;
create policy "duyuru_select_anon"
  on public.duyurular for select
  to anon
  using (is_active = true);

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: conditions.sql
-- =============================================================================

-- Hastalıklar & Durumlar (ana sayfa kartları)
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.conditions (
  id bigint generated always as identity primary key,
  title text not null,
  image_url text not null default '',
  description text not null default '',
  catalog_id text not null default '',
  icon text not null default '🩺',
  symptoms jsonb not null default '[]'::jsonb,
  diagnosis text not null default '',
  support jsonb not null default '[]'::jsonb,
  faq jsonb not null default '[]'::jsonb,
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists conditions_active_sort_idx
  on public.conditions (is_active, sort_order, created_at desc);

alter table public.conditions enable row level security;

-- Girişli kullanıcılar aktif kayıtları görür; admin hepsini
drop policy if exists "conditions_select_auth" on public.conditions;
create policy "conditions_select_auth"
  on public.conditions for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_insert_admin" on public.conditions;
create policy "conditions_insert_admin"
  on public.conditions for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_update_admin" on public.conditions;
create policy "conditions_update_admin"
  on public.conditions for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "conditions_delete_admin" on public.conditions;
create policy "conditions_delete_admin"
  on public.conditions for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Mevcut tabloya detay kolonları
alter table public.conditions
  add column if not exists catalog_id text not null default '';
alter table public.conditions
  add column if not exists icon text not null default '🩺';
alter table public.conditions
  add column if not exists symptoms jsonb not null default '[]'::jsonb;
alter table public.conditions
  add column if not exists diagnosis text not null default '';
alter table public.conditions
  add column if not exists support jsonb not null default '[]'::jsonb;
alter table public.conditions
  add column if not exists faq jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: conditions_detail.sql
-- =============================================================================

-- conditions: kart + detay alanları
-- Supabase Dashboard → SQL Editor → çalıştır

alter table public.conditions
  add column if not exists catalog_id text not null default '';

alter table public.conditions
  add column if not exists icon text not null default '🩺';

alter table public.conditions
  add column if not exists symptoms jsonb not null default '[]'::jsonb;

alter table public.conditions
  add column if not exists diagnosis text not null default '';

alter table public.conditions
  add column if not exists support jsonb not null default '[]'::jsonb;

alter table public.conditions
  add column if not exists faq jsonb not null default '[]'::jsonb;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: nadir_hastaliklar.sql
-- =============================================================================

-- Nadir hastalıklar detay içerikleri
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.nadir_hastaliklar (
  id text primary key,
  name text not null,
  icon text not null default '',
  short_desc text not null default '',
  definition text not null default '',
  effects text not null default '',
  sort_order int not null default 0,
  updated_at timestamptz not null default now()
);

create index if not exists nadir_hastaliklar_sort_idx
  on public.nadir_hastaliklar (sort_order);

alter table public.nadir_hastaliklar enable row level security;

drop policy if exists "nadir_select_auth" on public.nadir_hastaliklar;
create policy "nadir_select_auth"
  on public.nadir_hastaliklar for select
  to authenticated
  using (true);

drop policy if exists "nadir_write_admin" on public.nadir_hastaliklar;
create policy "nadir_write_admin"
  on public.nadir_hastaliklar for all
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Varsayılan kayıtları ekle (yoksa); mevcut satırları bozmaz
insert into public.nadir_hastaliklar
  (id, name, icon, short_desc, definition, effects, sort_order)
values
  (
    'spina_bifida',
    'Spina Bifida',
    '🧠',
    'Omurilik ve omurga gelişim bozukluğu.',
    'Omurganın ve omuriliğin anne karnındaki gelişim sürecinde (gebeliğin ilk haftalarında) tam olarak kapanmaması sonucu ortaya çıkan konjenital (doğuştan) bir nöral tüp defektidir.',
    'Omuriliğin dışarıya kesecik şeklinde çıkmasına veya açık kalmasına neden olabilir. Etkilenen bölgeye bağlı olarak bacaklarda kısmi veya tam felç, idrar ve dışkı kontrolü sorunları gibi fiziksel engellerle seyredebilir.',
    0
  ),
  (
    'rett',
    'Rett Sendromu',
    '🌸',
    'Ağırlıklı olarak kız çocuklarında görülen nörolojik gelişim bozukluğu.',
    'Genellikle MECP2 genindeki mutasyonlardan kaynaklanan, nadir görülen ve ilerleyici nörogelişimsel bir bozukluktur. Ağırlıklı olarak kız çocuklarını etkiler.',
    'Bebek ilk aylarında normal bir gelişim gösterdikten sonra; el becerilerini (amaçlı el hareketlerini) kaybeder, konuşma yeteneği geriler, yürüme bozuklukları ve karakteristik el ovuşturma/bükme hareketleri başlar.',
    1
  ),
  (
    'angelman',
    'Angelman Sendromu',
    '😊',
    'Mutluluk davranışı ve gelişim geriliğiyle karakterize genetik hastalık.',
    '15 numaralı kromozomdaki genetik bir bozukluktan (genellikle anneden gelen kopyanın eksikliği veya işlevsizliği) kaynaklanan nörogelişimsel bir sendromdur.',
    'Şiddetli zihinsel yetersizlik, konuşma yokluğu veya ciddi derecede kısıtlı konuşma, denge ve yürüme bozuklukları (ataksik/marazi yürüyüş) görülür. En belirgin özelliklerinden biri, sık gülme, neşeli görünüm, el çırpma gibi davranışlar ve aşırı heyecan halidir.',
    2
  ),
  (
    'prader_willi',
    'Prader-Willi Sendromu',
    '🧬',
    'Hipotoni, obezite eğilimi ve gelişim geriliğiyle seyreden genetik durum.',
    '15 numaralı kromozomun babadan gelen kısmındaki bir eksiklikten kaynaklanan karmaşık bir genetik hastalıktır.',
    'Bebeklik döneminde derin kas gevşekliği (hipotoni) ve beslenme güçlükleri ile başlar. Çocukluk dönemine geçişle birlikte doyum noktası olmama (sürekli açlık hissi - hiperfaji) durumu baş gösterir; bu da kontrol edilmezse aşırı obeziteye ve buna bağlı metabolik sorunlara yol açabilir.',
    3
  ),
  (
    'pku',
    'PKU (Fenilketonüri)',
    '🔴',
    'Fenilalanin metabolizmasındaki enzim eksikliğinden kaynaklanan metabolik hastalık.',
    'Karaciğerde fenilalanin amino asidini parçalayan enzimin eksikliği veya çalışmaması nedeniyle ortaya çıkan kalıtsal bir metabolik hastalıktır.',
    'Vücutta biriken fenilalanin ve türevleri beyin dokusuna zarar vererek tedavi edilmediği takdirde kalıcı zihinsel geriliğe yol açar. Doğan her bebeğe rutin olarak topuk kanı testi ile taranır ve ömür boyu düşük fenilalaninli diyetle kontrol altında tutulur.',
    4
  ),
  (
    'fragile_x',
    'Fragile X (Kırılgan X Sendromu)',
    '🔬',
    'En yaygın kalıtsal zihinsel engel nedeni olan genetik bozukluk.',
    'X kromozomu üzerinde bulunan FMR1 genindeki mutasyon sonucu gelişen, en sık rastlanan kalıtsal zihinsel engel nedenlerinden biridir.',
    'Öğrenme güçlükleri, dikkat eksikliği, hiperaktivite, sosyal kaygı ve otizm benzeri davranışsal özellikler görülebilir. Erkeklerde genellikle kızlara kıyasla daha ağır tablolara yol açar.',
    5
  ),
  (
    'tuberous',
    'Tuberous Sclerosis (Tüberoskleroz)',
    '🔵',
    'Beyin, cilt ve organlarda iyi huylu tümörlere yol açan genetik hastalık.',
    'Vücudun farklı organlarında (özellikle beyin, böbrek, kalp, akciğer ve cilt) iyi huylu tümörlerin (hamartom) oluşmasına neden olan genetik bir hastalıktır.',
    'Beyindeki lezyonlara bağlı olarak epilepsi (nöbetler), öğrenme güçlükleri veya otizm spektrum bozuklukları görülebilir. Ciltte karakteristik lekeler ve kabarıklıklar eşlik edebilir.',
    6
  ),
  (
    'dmd',
    'Duchenne Müsküler Distrofi (DMD)',
    '💪',
    'Kas gücünün ilerleyici kaybıyla seyreden genetik kas hastalığı.',
    'Kasların yapısını koruyan distrofin proteininin eksikliğinden kaynaklanan, X kromozomuna bağlı geçiş gösteren ilerleyici bir genetik kas hastalığıdır. Genellikle erkek çocuklarında görülür.',
    'Çocukluk çağında yürüme zorlukları, sık düşme ve merdiven çıkmada güçlükle başlar. Zamanla tüm iskelet kaslarını ve solunum/kalp kaslarını zayıflatarak hastanın tekerlekli sandalyeye bağımlı hale gelmesine yol açar.',
    7
  ),
  (
    'williams',
    'Williams Sendromu',
    '🎵',
    'Sosyal kişilik, müzikal yetenek ve kardiyovasküler sorunlarla karakterize durum.',
    '7 numaralı kromozomun belirli bir bölgesindeki genlerin eksilmesi (mikrodelesyon) sonucu oluşan nadir bir genetik sendromdur.',
    'Hastalar genellikle aşırı sosyal, dışa dönük, empatik ve müzik kulağı gelişmiş kişilik yapılarıyla bilinirler. Buna karşın yüz hatlarında belirgin özellikler (elf benzeri yüz), böbrek anomalileri ve ilerleyici kardiyovasküler (kalp-damar) sorunlar barındırabilir.',
    8
  ),
  (
    'cdkl5',
    'CDKL5 Eksikliği',
    '⚡',
    'Erken başlangıçlı nöbetler ve ciddi gelişimsel gecikmeye yol açan genetik bozukluk.',
    'X kromozomu üzerindeki CDKL5 geninin mutasyonu veya eksikliğinden kaynaklanan, erken çocukluk döneminde ortaya çıkan ağır bir genetik nörolojik bozukluktur.',
    'Yaşamın ilk aylarından itibaren başlayan, kontrol edilmesi zor ve dirençli epilepsi nöbetleri (erken başlangıçlı nöbetler), ağır motor ve zihinsel gelişim gerilikleri, konuşma yokluğu ve ellerde tekrarlayan stereotipik hareketlerle karakterizedir.',
    9
  )
on conflict (id) do nothing;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: gorusler.sql
-- =============================================================================

-- Engelsiz Club — dilek / şikayet / öneri
-- Supabase Dashboard → SQL Editor → Run

create table if not exists public.gorusler (
  id bigint generated always as identity primary key,
  user_email text not null,
  user_name text not null default '',
  type text not null default 'dilek',  -- dilek | sikayet | oneri | diger
  subject text not null,
  message text not null,
  created_at timestamptz not null default now()
);

create index if not exists gorusler_created_idx
  on public.gorusler (created_at desc);

create index if not exists gorusler_user_idx
  on public.gorusler (user_email, created_at desc);

alter table public.gorusler enable row level security;

-- Kullanıcı kendi görüşünü ekler
drop policy if exists "gorus_insert_own" on public.gorusler;
create policy "gorus_insert_own"
  on public.gorusler for insert
  to authenticated
  with check (
    lower(user_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Kullanıcı kendi kayıtlarını görür
drop policy if exists "gorus_select_own" on public.gorusler;
create policy "gorus_select_own"
  on public.gorusler for select
  to authenticated
  using (
    lower(user_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Admin tüm görüşleri görür
drop policy if exists "gorus_select_admin" on public.gorusler;
create policy "gorus_select_admin"
  on public.gorusler for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: home_hero_slides.sql
-- =============================================================================

-- Ana sayfa geçiş (hero) görselleri
-- Supabase SQL Editor → çalıştır

create table if not exists public.home_hero_slides (
  id bigint generated always as identity primary key,
  image_url text not null,
  alt_text text not null default '',
  sort_order int not null default 0,
  is_active boolean not null default true,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

create index if not exists home_hero_slides_sort_idx
  on public.home_hero_slides (is_active, sort_order, id);

alter table public.home_hero_slides enable row level security;

drop policy if exists "home_hero_select_all" on public.home_hero_slides;
create policy "home_hero_select_all"
  on public.home_hero_slides for select
  to anon, authenticated
  using (is_active = true or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "home_hero_insert_admin" on public.home_hero_slides;
create policy "home_hero_insert_admin"
  on public.home_hero_slides for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "home_hero_update_admin" on public.home_hero_slides;
create policy "home_hero_update_admin"
  on public.home_hero_slides for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "home_hero_delete_admin" on public.home_hero_slides;
create policy "home_hero_delete_admin"
  on public.home_hero_slides for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Varsayılan 3 slide (asset yolu — uygulama paketinden okunur)
insert into public.home_hero_slides (image_url, alt_text, sort_order)
select v.image_url, v.alt_text, v.sort_order
from (values
  ('asset:assets/images/118547.png', 'Terapist ve özel gereksinimli çocuk yürüyüş terapisinde', 1),
  ('asset:assets/images/118587-1.png', 'Gökkuşağı altında mutlu iki çocuk', 2),
  ('asset:assets/images/118600.png', 'Anne ve yeni doğan bebeği hastanede', 3)
) as v(image_url, alt_text, sort_order)
where not exists (select 1 from public.home_hero_slides limit 1);

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: app_catalog.sql
-- =============================================================================

-- Engelsiz Club — dinamik katalog (merkez, içerik, kategori, ayar)
-- Supabase Dashboard → SQL Editor → bu dosyanın tamamını Run
--
-- Amaç: Uygulamayı her seferinde yeniden deploy etmeden
-- içerikleri panelden / SQL'den güncellemek.
-- Flutter tarafı AppCatalogService ile çeker + yerelde TTL cache tutar.

-- ── 1) Uygulama ayarları (key → JSON) ───────────────────────────────────────
create table if not exists public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text not null default '',
  updated_at timestamptz not null default now()
);

-- ── 2) Kategoriler (forum / haklar / merkez / uzmanlık / kart) ─────────────
create table if not exists public.app_categories (
  id text primary key,                 -- örn. 'maddi', 'izin', 'fizyoterapist'
  scope text not null,                 -- 'rights' | 'forum' | 'centers' | 'uzmanlik' | 'cards' | 'ilan'
  label text not null,
  icon text not null default '',
  color bigint,                        -- ARGB int (opsiyonel)
  sort_order int not null default 0,
  active boolean not null default true,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists app_categories_scope_idx
  on public.app_categories (scope, sort_order);

-- ── 3) CMS içerik blokları (banner, metin, FAQ, duyuru) ────────────────────
create table if not exists public.app_content (
  id text primary key,                 -- örn. 'home_hero', 'disclaimer_rights'
  scope text not null default 'general',
  title text not null default '',
  body text not null default '',
  media_url text not null default '',
  sort_order int not null default 0,
  active boolean not null default true,
  meta jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create index if not exists app_content_scope_idx
  on public.app_content (scope, sort_order);

-- ── 4) Haklar kataloğu ────────────────────────────────────────────────────
create table if not exists public.app_rights (
  id text primary key,
  title text not null,
  amount text not null default '',
  category text not null default 'maddi',  -- app_categories.id (scope=rights)
  icon text not null default '',
  color bigint not null default 4281568586,
  bg bigint not null default 4293980400,
  min_rate int not null default 0,
  max_age int not null default 99,
  income_limit boolean not null default false,
  description text not null default '',
  steps jsonb not null default '[]'::jsonb,   -- string[]
  where_text text not null default '',
  sort_order int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists app_rights_category_idx
  on public.app_rights (category, sort_order);

-- ── 5) Merkez kataloğu (küratör / yedek liste; Places canlı aramadan bağımsız) ─
create table if not exists public.app_centers (
  id bigint generated always as identity primary key,
  city text not null,
  ilce text not null default '',
  name text not null,
  category text not null default 'Rehabilitasyon',
  address text not null default '',
  phone text not null default '',
  hours text not null default '',
  services jsonb not null default '[]'::jsonb,
  rating double precision not null default 0,
  reviews int not null default 0,
  color bigint not null default 4281568586,
  lat double precision not null,
  lng double precision not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create index if not exists app_centers_city_idx
  on public.app_centers (city, active);

create index if not exists app_centers_geo_idx
  on public.app_centers (lat, lng);

-- ── 6) Hastalık / rehber içerikleri (Ana sayfa kartları) ───────────────────
create table if not exists public.app_diseases (
  id text primary key,
  name text not null,
  icon text not null default '',
  color bigint not null default 4281568586,
  bg bigint not null default 4293980400,
  photo text not null default '',
  description text not null default '',
  symptoms jsonb not null default '[]'::jsonb,
  diagnosis text not null default '',
  support jsonb not null default '[]'::jsonb,
  faq jsonb not null default '[]'::jsonb,     -- [{q,a}, ...]
  sort_order int not null default 0,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

-- ── 7) Katalog sürüm tablosu (ucuz sync — kota dostu) ─────────────────────
-- Flutter önce bunu çeker; sadece değişen paketleri indirir.
create table if not exists public.app_catalog_versions (
  name text primary key,               -- 'settings' | 'categories' | 'content' | 'rights' | 'centers' | 'diseases'
  version bigint not null default 1,
  updated_at timestamptz not null default now()
);

insert into public.app_catalog_versions (name, version)
values
  ('settings', 1),
  ('categories', 1),
  ('content', 1),
  ('rights', 1),
  ('centers', 1),
  ('diseases', 1)
on conflict (name) do nothing;

-- Güncellemede version++ otomatik
create or replace function public.bump_catalog_version()
returns trigger
language plpgsql
as $$
declare
  v_name text;
begin
  v_name := case tg_table_name
    when 'app_settings' then 'settings'
    when 'app_categories' then 'categories'
    when 'app_content' then 'content'
    when 'app_rights' then 'rights'
    when 'app_centers' then 'centers'
    when 'app_diseases' then 'diseases'
    else null
  end;
  if v_name is null then
    return coalesce(new, old);
  end if;
  insert into public.app_catalog_versions (name, version, updated_at)
  values (v_name, 1, now())
  on conflict (name) do update
    set version = public.app_catalog_versions.version + 1,
        updated_at = now();
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bump_settings on public.app_settings;
create trigger trg_bump_settings
  after insert or update or delete on public.app_settings
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_categories on public.app_categories;
create trigger trg_bump_categories
  after insert or update or delete on public.app_categories
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_content on public.app_content;
create trigger trg_bump_content
  after insert or update or delete on public.app_content
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_rights on public.app_rights;
create trigger trg_bump_rights
  after insert or update or delete on public.app_rights
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_centers on public.app_centers;
create trigger trg_bump_centers
  after insert or update or delete on public.app_centers
  for each row execute function public.bump_catalog_version();

drop trigger if exists trg_bump_diseases on public.app_diseases;
create trigger trg_bump_diseases
  after insert or update or delete on public.app_diseases
  for each row execute function public.bump_catalog_version();

-- ── 8) RLS — herkes (authenticated + anon) okuyabilir; yazma sadece service role / admin ─
alter table public.app_settings enable row level security;
alter table public.app_categories enable row level security;
alter table public.app_content enable row level security;
alter table public.app_rights enable row level security;
alter table public.app_centers enable row level security;
alter table public.app_diseases enable row level security;
alter table public.app_catalog_versions enable row level security;

drop policy if exists "catalog_settings_select" on public.app_settings;
create policy "catalog_settings_select"
  on public.app_settings for select to anon, authenticated using (true);

drop policy if exists "catalog_categories_select" on public.app_categories;
create policy "catalog_categories_select"
  on public.app_categories for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_content_select" on public.app_content;
create policy "catalog_content_select"
  on public.app_content for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_rights_select" on public.app_rights;
create policy "catalog_rights_select"
  on public.app_rights for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_centers_select" on public.app_centers;
create policy "catalog_centers_select"
  on public.app_centers for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_diseases_select" on public.app_diseases;
create policy "catalog_diseases_select"
  on public.app_diseases for select to anon, authenticated
  using (active = true);

drop policy if exists "catalog_versions_select" on public.app_catalog_versions;
create policy "catalog_versions_select"
  on public.app_catalog_versions for select to anon, authenticated using (true);

-- Admin yazma (sakir.caykara@gmail.com) — Dashboard Table Editor de service role kullanır
drop policy if exists "catalog_settings_admin_write" on public.app_settings;
create policy "catalog_settings_admin_write"
  on public.app_settings for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_categories_admin_write" on public.app_categories;
create policy "catalog_categories_admin_write"
  on public.app_categories for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_content_admin_write" on public.app_content;
create policy "catalog_content_admin_write"
  on public.app_content for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_rights_admin_write" on public.app_rights;
create policy "catalog_rights_admin_write"
  on public.app_rights for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_centers_admin_write" on public.app_centers;
create policy "catalog_centers_admin_write"
  on public.app_centers for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

drop policy if exists "catalog_diseases_admin_write" on public.app_diseases;
create policy "catalog_diseases_admin_write"
  on public.app_diseases for all to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com')
  with check (lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com');

-- ── 9) Örnek ayarlar / kategoriler (isteğe bağlı seed) ─────────────────────
insert into public.app_settings (key, value, description) values
  ('places_radius_km', '40', 'Google Places arama yarıçapı (km)'),
  ('catalog_ttl_hours', '6', 'İstemci cache TTL (saat)'),
  ('maintenance_message', '""', 'Bakım duyurusu (boş = yok)')
on conflict (key) do nothing;

insert into public.app_categories (id, scope, label, icon, sort_order) values
  ('tümü', 'rights', 'Tümü', '📋', 0),
  ('maddi', 'rights', 'Maddi', '💰', 1),
  ('izin', 'rights', 'Kamu Çalışan İzin', '🏢', 2),
  ('vergi', 'rights', 'Vergi & Araç', '🚗', 3),
  ('egitim', 'rights', 'Eğitim', '📚', 4),
  ('ulasim', 'rights', 'Ulaşım', '🚌', 5),
  ('Fizyoterapist', 'uzmanlik', 'Fizyoterapist', '🏃', 1),
  ('Ergoterapist', 'uzmanlik', 'Ergoterapist', '✋', 2),
  ('Dil Konuşma Terapisti', 'uzmanlik', 'Dil Konuşma Terapisti', '💬', 3),
  ('Özel Eğitim Öğretmeni', 'uzmanlik', 'Özel Eğitim Öğretmeni', '📚', 4),
  ('Psikolog', 'uzmanlik', 'Psikolog', '🧠', 5),
  ('Tümü', 'centers', 'Tümü', '', 0),
  ('Fizik Tedavi', 'centers', 'Fizik Tedavi', '', 1),
  ('Özel Eğitim', 'centers', 'Özel Eğitim', '', 2),
  ('Dil Terapisi', 'centers', 'Dil Terapisi', '', 3),
  ('Nöroloji', 'centers', 'Nöroloji', '', 4)
on conflict (id) do nothing;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: app_catalog_store_settings.sql
-- =============================================================================

-- Store ayarları (bir kez Run)
-- Demo ilanları kapat; katalog TTL 6 saat

insert into public.app_settings (key, value, description)
values
  ('show_demo_ilanlar', 'false'::jsonb, 'false = yalnız kullanıcı ilanları (Play/App Store)'),
  ('catalog_ttl_hours', '6'::jsonb, 'Katalog yeniden indirme aralığı (saat)')
on conflict (key) do update
  set value = excluded.value,
      description = excluded.description,
      updated_at = now();


-- =============================================================================
-- FILE: app_catalog_seed_rights.sql
-- =============================================================================

-- Engelsiz Club — app_rights seed
-- Supabase SQL Editor → New query → Run
-- Table Editor ile tek tek doldurmaya GEREK YOK

truncate table public.app_rights restart identity cascade;

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'evde-bakim',
  'Evde Bakım Maaşı',
  '₺15.775 / ay',
  'maddi',
  '🏠',
  4279921482,
  4293457390,
  50,
  18,
  true,
  'Evde bakıma muhtaç ağır engelli bireylerin yakınlarına Sosyal Hizmetler tarafından ödenen aylık destek. Güncel tutar: ₺15.775. Hane halkı gelir testi yapılır.',
  '["E-Devlet üzerinden ''Evde Bakım Hizmeti'' başvurusu yapın","Sağlık kurulundan %50+ bakıma muhtaç raporu alın","İl Sosyal Hizmetler Müdürlüğü''ne başvurun","Hane halkı gelir testi yapılır"]'::jsonb,
  'e-Devlet · İl Sosyal Hizmetler Müdürlüğü',
  1,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-maas',
  'Engelli Aylığı',
  '₺5.793 – ₺8.690 / ay',
  'maddi',
  '💳',
  4285242052,
  4293850619,
  40,
  99,
  true,
  'SGK veya Sosyal Yardımlaşma Vakfı tarafından ödenen aylık. Gelir testi uygulanır; çalışmayan engelli bireyler için geçerlidir.

',
  '["Sağlık Kurulu Raporu alın (%40+ engel oranı)","SGK veya SYDV''ye başvurun","Gelir testi ve belgeler tamamlanır","Hesaba her ay otomatik yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  2,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-yakini-ayligi',
  '18 Yaş Altı Engelli Yakını Aylığı',
  '₺5.793,30 / ay',
  'maddi',
  '👨‍👧',
  4278751666,
  4293721855,
  40,
  18,
  true,
  '18 yaşından küçük engelli yakını olan bakmakla yükümlü kişilere ödenen aylık. Güncel tutar: ₺5.793,30. Gelir testi uygulanır.',
  '["Çocuğun Sağlık Kurulu Raporunu alın (%40+)","SGK veya Sosyal Yardımlaşma Vakfı''na başvurun","Veli / vasi belgesi ve gelir belgelerini ibraz edin","Onay sonrası aylık hesaba yatırılır"]'::jsonb,
  'SGK · Sosyal Yardımlaşma Vakfı',
  3,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yardimci-arac',
  'Yardımcı Araç-Gereç Desteği',
  'SGK karşılar',
  'maddi',
  '♿',
  4284196994,
  4293193961,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez, protez, işitme cihazı ve benzeri yardımcı araçlar SGK tarafından karşılanmaktadır.',
  '["Hekim raporu ve SGK sevki alın","SGK sözleşmeli firma veya ortez merkezine gidin","Katkı payı varsa ödenir; ücretsiz seçenekler mevcuttur"]'::jsonb,
  'SGK · Sözleşmeli medikal firmalar',
  4,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'nobet-bakim-izin',
  'Nöbet Muafiyeti & Günlük Eğitim/Bakım İzni',
  'Nöbet muafiyeti · Haftalık 8 saat eğitim',
  'izin',
  '🏢',
  4279203438,
  4293326837,
  70,
  99,
  false,
  'ENGELLİ ÇOCUĞU/YAKINI OLAN ÇALIŞANLARIN HAKLARI

',
  '["Geçerli engelli sağlık kurulu raporunu hazırlayın (ağır engelli / ÇÖZGER çok ileri–ÖKGV / tam bağımlı)","Kurumunuzun insan kaynakları / izin birimine yazılı başvuru yapın","Nöbet / gece vardiyası muafiyeti ve günlük bakım kolaylığı talep edin","Özel eğitim alınıyorsa haftalık 8 saat eğitim iznini ayrıca belirtin","TSK / EGM / hastane personeliyseniz kurumunuzun iç genelgesini ekleyin"]'::jsonb,
  'Kurum İK · Başbakanlık Genelgesi 2010/2 · EGM 2015/55 · TSK İzin Yönetmeliği',
  5,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mazeret-izin',
  'Mazeret İzni Hakkı (%70+ / Süreğen Hastalık)',
  'Yılda 10 güne kadar ücretli',
  'izin',
  '📋',
  4280640491,
  4293916415,
  70,
  18,
  false,
  'En az yüzde %70 oranında engelli ya da süreğen hastalığı olan çocukları için tüm çalışanlara; ',
  '["Çocuğun %70+ engelli veya süreğen hastalık belgesini hazırlayın","Hastalık durumunda doktor / hekim raporu alın","Kurumunuza yazılı mazeret izni talebi verin (ana veya babadan yalnızca biri)","Yıllık izin bitmiş olsa da talep edilebilir; 10 günü parçalı kullanabilirsiniz","İşçi / sözleşmeli / muvazzaf personel aynı hakkı kullanır"]'::jsonb,
  'Kurum İK · DMK md. 104 · İş Kanunu',
  6,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'yari-zamanli-anne',
  'Engelli Bebekte Yarı Zamanlı Çalışma Hakkı',
  '12. aya kadar tam maaşlı yarı zamanlı',
  'izin',
  '👶',
  4292552567,
  4294832888,
  40,
  6,
  false,
  'Engelli çocuğu olan annelere yarı zamanlı çalışma hakkı

',
  '["Doğumda veya ilk 12 ay içinde engellilik tespitini belgeleyen sağlık raporunu alın","Kurum İK birimine yazılı yarı zamanlı çalışma talebi verin","Bebek 12 ayını doldurana kadar tam maaşlı yarı zamanlı çalışma uygulanır","Memur (DMK) ve işçi (İş Kanunu) anneler bu haktan yararlanır"]'::jsonb,
  'Kurum İK · Devlet Memurları Kanunu · İş Kanunu',
  7,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'otv-muafiyet',
  'ÖTV Muafiyetli Araç Alımı',
  '2026 fiyat sınırı: ₺2.873.900',
  'vergi',
  '🚗',
  4292901471,
  4294832364,
  40,
  99,
  false,
  '4 farklı grup engelli bireye ÖTV istisnası tanınmaktadır. 10 yılda bir hak kullanılabilir; araç beş yıl geçmeden ÖTV ödenmeksizin satılamaz.

',
  '["Sağlık Kurulu Raporu alın (hangi gruba girdiğinizi öğrenin)","Vergi Dairesi''ne başvurarak ÖTV istisna belgesi düzenletin","Grup 4 iseniz: geçerli B sınıfı engelli sürücü belgesi şarttır","87.03 kapsamında araçta fiyat ₺2.873.900''ı (2026) aşmamalıdır","Yetkili bayi ile sözleşme yapılır; araç engelli adına tescil edilir","5 yıl sonra ÖTV ödenmeksizin satış hakkı doğar"]'::jsonb,
  'Vergi Dairesi · Trafik Tescil · Araç Yetkili Bayii',
  8,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'mtv-muafiyet',
  'MTV Muafiyeti (Araç Vergisi)',
  'Tam muafiyet veya kısmi',
  'vergi',
  '📃',
  4286331629,
  4294308095,
  40,
  99,
  false,
  '%90 ve üzeri engellilik: Kendi adına kayıtlı araçta özel tertibat şartı aranmaksızın MTV''den tam muafiyet. Tam teşekküllü devlet hastanesi sağlık kurulu raporu vergi dairesine ibraz edilir.

',
  '["%90+ ise: devlet hastanesi sağlık kurulu raporu hazırlayın","Araç tescil belgesi, engelli kimlik kartı ve raporu vergi dairesine götürün","%90 altı ise ayrıca: araç teknik belgesi, özel tertibat proje raporu ve MTV istisnası bildirim formu gerekir","Vergi dairesi muafiyet işlemini tescil eder; yıllık otomatik uygulanır"]'::jsonb,
  'Bağlı olunan Vergi Dairesi',
  9,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'park-karti',
  'Engelli Park Kartı (Mavi İşaret)',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı yalnızca üzerine araç tescil edilmiş engellilere verilir. Kullanım için Trafik Denetleme Amirliğine başvuru gerekir.

',
  '["Engelli sağlık kurulu raporu ve araç tescil belgesiyle başvurun","Trafik Denetleme Şube Amirliği veya İlçe Emniyet Müdürlüğü''ne gidin","Park kartı (mavi işaret) ücretsiz teslim edilir","Kartı araç ön camına asın; her park değişiminde görünür yerde bulundurulmalıdır"]'::jsonb,
  'Trafik Denetleme Şube/Bürü Amirliği · İlçe Emniyet Müdürlüğü',
  10,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-ehliyet',
  'Engelli Sürücü Belgesi (B Sınıfı)',
  'Ücretsiz / Normal ücret',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  '1 Ocak 2016''dan önce alınan H sınıfı engelli sürücü belgeleri 31/07/2025''e kadar geçerliydi. Bu tarihten sonra B sınıfı sürücü belgesi (engellilik kodları işlenmiş) geçerlidir.

',
  '["18 yaşını doldurun","Aile hekimine başvurarak İl Sağlık Komisyonu''na sevk alın","Komisyon raporuyla sürücü kursu ve sınavına katılın","Engellilik durumuna uygun özel tertibat kodları B sınıfı belgeye işlenir"]'::jsonb,
  'Aile Hekimi → İl Sağlık Komisyonu → Sürücü Kursu → Trafik Tescil',
  11,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kdv-indirim',
  'KDV İndirimi – Medikal & Araç',
  '%18''den %1''e',
  'vergi',
  '🛒',
  4294223922,
  4294965485,
  40,
  99,
  false,
  'Tekerlekli sandalye, yürüteç, ortez/protez ve engelliye özel araç tadilat hizmetlerinde KDV %1 uygulanır.',
  '["Sağlık raporu ve engel kimliği ile medikal firmaya gidin","Faturada ''engelli bireye satış'' ibaresi istenir","Araç tadilat için ÖTV muafiyet belgesi gerekir"]'::jsonb,
  'SGK sözleşmeli medikal firmalar · Yetkili servisler',
  12,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'gelir-vergisi',
  'Gelir Vergisi İndirimi',
  '₺3.000–₺6.000 / yıl',
  'vergi',
  '📊',
  4288441779,
  4294307579,
  40,
  99,
  false,
  'Engelli çalışanlara ve engelli çocuğu olan çalışan ebeveynlere yıllık gelir vergisi matrahından indirim hakkı tanınır.',
  '["İşverenin insan kaynakları birimine engel raporunu ibraz edin","Vergi dairesine de bildirim yapılması önerilir","Özel eğitim ve sağlık harcamaları da indirim kapsamına girebilir"]'::jsonb,
  'Vergi Dairesi · İşveren İK',
  13,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ozel-egitim',
  'Ücretsiz Özel Eğitim',
  'Haftada 8 saat',
  'egitim',
  '📚',
  4288441779,
  4294307579,
  0,
  18,
  false,
  'MEB''e bağlı özel eğitim ve rehabilitasyon merkezlerinde haftada 8 saate kadar ücretsiz hizmet. RAM raporu zorunludur.',
  '["RAM''a başvurun (randevu alın)","RAM raporu ve Özel Eğitim Değerlendirme Kurulu kararı alın","MEB sözleşmeli rehabilitasyon merkezini seçin","Her yıl yenileme gerekir"]'::jsonb,
  'RAM (Rehberlik ve Araştırma Merkezi)',
  14,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ram-raporu',
  'RAM Raporu Nasıl Alınır?',
  'Ücretsiz',
  'egitim',
  '📋',
  4284196994,
  4293193961,
  0,
  18,
  false,
  'Özel eğitim hizmetlerinden yararlanmak için zorunlu değerlendirme raporu. Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır.',
  '["İlçenizdeki RAM''a randevu alın","Doktor raporu, okul belgesi, kimlik fotokopisiyle gidin","Psikolog ve özel eğitim uzmanı değerlendirmesi yapılır","Rapor genellikle 1-3 hafta içinde hazırlanır"]'::jsonb,
  'Rehberlik ve Araştırma Merkezi (RAM)',
  15,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'kaynaştirma',
  'Kaynaştırma Eğitimi Hakkı',
  'Anayasal hak',
  'egitim',
  '🏫',
  4279921482,
  4293457390,
  0,
  18,
  false,
  'Engelli çocuklar, akranlarıyla birlikte eğitim alma hakkına sahiptir. Okul, destek eğitim odası ve özel kaynaştırma programı oluşturmak zorundadır.',
  '["RAM raporuyla okul müdürlüğüne başvurun","Destek eğitim odası saatleri planlanır","BEP (Bireyselleştirilmiş Eğitim Planı) hazırlanır","İlköğretimden liseye kadar sürer"]'::jsonb,
  'İlçe Milli Eğitim Müdürlüğü · Okul Müdürlüğü',
  16,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'engelli-kimlik',
  'Engelli Kimlik Kartı',
  'Ücretsiz',
  'ulasim',
  '🪪',
  4279921482,
  4293457390,
  40,
  99,
  false,
  'Pek çok ayrıcalık ve indirimlere kapı açan resmi kimlik kartı. Nüfus müdürlüğünden veya e-Devlet üzerinden alınır.',
  '["Sağlık Kurulu Raporu (%40+ engel oranı)","Nüfus Müdürlüğü''ne başvurun veya e-Devlet kullanın","Fotoğraf ve kimlik fotokopisi","1-2 hafta içinde kart teslim edilir"]'::jsonb,
  'İlçe Nüfus Müdürlüğü · e-Devlet',
  17,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'ulasim',
  'Ücretsiz Toplu Taşıma',
  'Belediye kartı',
  'ulasim',
  '🚌',
  4285242052,
  4293850619,
  40,
  99,
  false,
  'Engelli kimlik kartı ile metro, otobüs, tramvayda ücretsiz veya indirimli seyahat. Refakatçi de bazı illerde indirimden yararlanır.',
  '["Engelli kimlik kartı ile belediye ulaşım müdürlüğüne başvurun","İstanbul: İETT, Ankara: EGO, İzmir: ESHOT","Ücretsiz akıllı kart verilir","Bir refakatçi de indirimden yararlanır (bazı illerde)"]'::jsonb,
  'Belediye Ulaşım Müdürlükleri',
  18,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'tcdd-thy',
  'TCDD & THY İndirimleri',
  '%50 indirim',
  'ulasim',
  '✈️',
  4292901471,
  4294832364,
  40,
  99,
  false,
  'Tren yolculuklarında %50, Türk Hava Yolları''nda engelli indirim tarifesi. Refakatçi de indirimden yararlanabilir.',
  '["TCDD: bilet alırken engelli kimliği ibraz edin","THY: thy.com''da ''Özel Yolcular'' bölümünden bilet alın","Refakatçi de indirimden yararlanabilir"]'::jsonb,
  'TCDD Bilet Gişeleri · thy.com',
  19,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'sehir-ici-park',
  'Engelli Park Kartı',
  'Ücretsiz',
  'ulasim',
  '🅿️',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli park kartı ile engellilere ayrılmış park alanlarını kullanma hakkı tanınır. Ayrıca mavi hatlarda ücretsiz park imkânı mevcuttur.',
  '["Engelli sağlık kurulu raporu ile Belediye Trafik Müdürlüğü''ne başvurun","Engelli park kartı (maviişaret) temin edilir","Araç ön camına asılır"]'::jsonb,
  'Belediye Trafik Müdürlüğü · Emniyet Trafik Birimleri',
  20,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'emlak-vergisi',
  'Emlak Vergisi Muafiyeti',
  '200 m²''ye kadar',
  'vergi',
  '🏡',
  4288441779,
  4294307579,
  0,
  99,
  true,
  'Tek meskeni olan ve belirli gelir sınırının altındaki engelli bireyler emlak vergisinden muaf tutulur. Yıllık gelir kontrolü yapılır.',
  '["Tek meskene sahip olunması gerekir","Yıllık brüt gelir sınırı kontrol edilmeli","Engel raporu ve beyanname ile başvurun"]'::jsonb,
  'İlçe Belediyesi Gelir Müdürlüğü',
  21,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'su-faturasi',
  'Su Faturası İndirimi',
  '%50 indirim',
  'vergi',
  '💧',
  4282090230,
  4293916415,
  40,
  99,
  false,
  'Engelli bireyin yaşadığı hanede su ve kanalizasyon faturasında %50''ye kadar indirim. İl ve belediyeye göre kota farklılık gösterebilir.',
  '["Engelli sağlık kurulu raporu ve engelli kimlik kartıyla başvurun","İkametgâh belgesi ve su abonelik sözleşmesi gerekir","İSKİ / ASKİ / İZSU gibi kuruma başvurun","Onaylı indirim bir sonraki faturadan itibaren yansıtılır"]'::jsonb,
  'Belediye Su ve Kanalizasyon İdaresi (İSKİ / ASKİ / İZSU)',
  22,
  true
);

insert into public.app_rights (
  id, title, amount, category, icon, color, bg, min_rate, max_age,
  income_limit, description, steps, where_text, sort_order, active
) values (
  'telefon-indirimi',
  'Telefon & İnternet İndirimi',
  '%25–50 indirim',
  'vergi',
  '📱',
  4279286145,
  4293721589,
  40,
  99,
  false,
  'Engelli abonelere BTK kapsamında internet ve telefon faturalarında indirim uygulanmaktadır. Operatörden talep edilmesi gerekir.',
  '["Engelli kimlik kartı ile GSM operatörüne başvurun","Engel raporu ibraz edin","Engelli tarifesine geçiş yapılır"]'::jsonb,
  'GSM Operatör Müşteri Hizmetleri · BTK',
  23,
  true
);

update public.app_catalog_versions set version = version + 1, updated_at = now() where name = 'rights';
notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: admin_moderation.sql
-- =============================================================================

-- Engelsiz Club — admin moderasyon (silme) yetkileri
-- Supabase Dashboard → SQL Editor → New query → bu dosyanın tamamını çalıştır
-- Admin: sakir.caykara@gmail.com
--
-- ÖNEMLİ: Sadece RLS policy yetmezse (silindi görünüp yenilemede geri geliyorsa)
-- aşağıdaki SECURITY DEFINER fonksiyonlar kesin çözüm sağlar.

-- ── RLS: admin silme politikaları ──────────────────────────────────────────

-- Sohbet: admin tüm mesajları görür / siler
drop policy if exists "sohbet_select_admin" on public.sohbet_mesajlari;
create policy "sohbet_select_admin"
  on public.sohbet_mesajlari for select
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "sohbet_delete_admin" on public.sohbet_mesajlari;
create policy "sohbet_delete_admin"
  on public.sohbet_mesajlari for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- İlanlar: admin herhangi bir ilanı silebilir
drop policy if exists "ilanlar_delete_admin" on public.ilanlar;
create policy "ilanlar_delete_admin"
  on public.ilanlar for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum gönderileri
drop policy if exists "forum_delete_admin" on public.forum_posts;
create policy "forum_delete_admin"
  on public.forum_posts for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Forum yorumları
drop policy if exists "forum_comments_delete_admin" on public.forum_comments;
create policy "forum_comments_delete_admin"
  on public.forum_comments for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- ── Kesin çözüm: admin RPC (RLS’yi bypass eder, e-posta kontrolü içeride) ──

create or replace function public.admin_delete_forum_post(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_posts where id = p_id;
end;
$$;

create or replace function public.admin_delete_forum_comment(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'not allowed';
  end if;
  delete from public.forum_comments where id = p_id;
end;
$$;

revoke all on function public.admin_delete_forum_post(bigint) from public;
revoke all on function public.admin_delete_forum_comment(bigint) from public;
grant execute on function public.admin_delete_forum_post(bigint) to authenticated;
grant execute on function public.admin_delete_forum_comment(bigint) to authenticated;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: admin_top_iyilik_puani.sql
-- =============================================================================

-- Admin: iyilik puanı sıralması (en yüksekten aşağa)
-- Supabase SQL Editor'da bir kez çalıştırın.

create or replace function public.admin_top_iyilik_puani(p_limit int default 10)
returns table (
  rank int,
  owner_email text,
  display_name text,
  kredi int,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if lower(coalesce(auth.jwt() ->> 'email', '')) <> 'sakir.caykara@gmail.com' then
    raise exception 'Yalnızca admin bu listeyi görebilir';
  end if;

  return query
  select
    row_number() over (order by up.kredi desc, up.updated_at desc)::int as rank,
    up.owner_email::text,
    coalesce(
      nullif(trim(up.profil ->> 'adSoyad'), ''),
      split_part(up.owner_email, '@', 1)
    )::text as display_name,
    up.kredi::int,
    up.updated_at
  from public.user_profiles up
  where lower(trim(up.owner_email)) <> 'sakir.caykara@gmail.com'
    and coalesce(up.kredi, 0) > 0
  order by up.kredi desc, up.updated_at desc
  limit greatest(1, least(coalesce(p_limit, 10), 50));
end;
$$;

revoke all on function public.admin_top_iyilik_puani(int) from public;
grant execute on function public.admin_top_iyilik_puani(int) to authenticated;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: guest_public_read.sql
-- =============================================================================

-- Misafir (anon) kullanıcılar: ilan / forum sadece okuma
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- Yazma (insert/update/delete) authenticated ile kalır.

-- İlanlar
drop policy if exists "ilanlar_select_anon" on public.ilanlar;
create policy "ilanlar_select_anon"
  on public.ilanlar for select
  to anon
  using (true);

-- Forum gönderileri
drop policy if exists "forum_select_anon" on public.forum_posts;
create policy "forum_select_anon"
  on public.forum_posts for select
  to anon
  using (true);

-- Forum yorumları
drop policy if exists "forum_comments_select_anon" on public.forum_comments;
create policy "forum_comments_select_anon"
  on public.forum_comments for select
  to anon
  using (true);

-- Duyurular / kayan story (yalnız aktif)
drop policy if exists "duyuru_select_anon" on public.duyurular;
create policy "duyuru_select_anon"
  on public.duyurular for select
  to anon
  using (is_active = true);

-- Profil fotoğrafları (avatar) — fonksiyon yoksa atlanır
do $$
begin
  grant execute on function public.get_user_photos(text[]) to anon;
exception
  when undefined_function then null;
end $$;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: google_places_proxy.sql
-- =============================================================================

-- ESKİ: Legacy Places REST proxy (nearbysearch/json).
-- Artık uygulama Places API (New) kullanıyor (places.googleapis.com/v1/...).
-- Bu SQL'i çalıştırmanıza gerek yok; Cloud Errors'ı azaltmak için
-- legacy Places API çağrılarını kapatın / anahtar kısıtlarını sadeleştirin.
--
-- Gerekirse fonksiyonu kaldırmak için:
--   drop function if exists public.google_places_proxy(jsonb);
--   drop function if exists public._uri_encode(text);

select 1;


-- =============================================================================
-- FILE: cross_platform_sync.sql
-- =============================================================================

-- Engelsiz Club — teklif veren kendi gönderdiği bildirimleri görebilsin
-- (cihazlar arası "bu ilana teklif verdim" senkronu)

drop policy if exists "bildirim_select_actor" on public.bildirimler;
create policy "bildirim_select_actor"
  on public.bildirimler for select
  to authenticated
  using (
    lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Realtime: inbox / sohbet anlık güncellensin
do $$
begin
  alter publication supabase_realtime add table public.bildirimler;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_posts;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forum_comments;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;

notify pgrst, 'reload schema';


-- =============================================================================
-- FILE: play_ready.sql
-- =============================================================================

-- Engelsiz Club — Play Store öncesi Supabase (SQL Editor’da sırayla çalıştır)
-- Eksik tablolar/policy’ler için güvenli (IF EXISTS / DROP IF EXISTS)

-- 1) İlan sahibi güncelleme
--    ilanlar_update_own.sql
--    bildirimler_mesaj_collapse.sql
--    user_kredi.sql (yorumlar güncel)

-- Aşağısı Dashboard’da tek seferde çalıştırılabilir:

-- İlan UPDATE (sahip: owner_id veya e-posta)
update public.ilanlar i
set owner_id = u.id
from auth.users u
where i.owner_id is null
  and lower(trim(i.owner_email)) = lower(u.email);

drop policy if exists "ilanlar_update_own" on public.ilanlar;
create policy "ilanlar_update_own"
  on public.ilanlar for update
  to authenticated
  using (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    owner_id = auth.uid()
    or lower(trim(owner_email)) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Mesaj bildirimi: gönderen seç + güncelle (üst üste binmesin)
drop policy if exists "bildirim_select_actor_mesaj" on public.bildirimler;
create policy "bildirim_select_actor_mesaj"
  on public.bildirimler for select
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

drop policy if exists "bildirim_update_actor_mesaj" on public.bildirimler;
create policy "bildirim_update_actor_mesaj"
  on public.bildirimler for update
  to authenticated
  using (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  )
  with check (
    type = 'mesaj'
    and lower(actor_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );

-- Kredi kolonları
alter table public.user_profiles
  add column if not exists kredi int not null default 0;
alter table public.user_profiles
  add column if not exists kredi_welcome_gift boolean not null default false;

notify pgrst, 'reload schema';

