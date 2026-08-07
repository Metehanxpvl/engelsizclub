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
