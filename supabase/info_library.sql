-- Dinamik Bilgi Kütüphanesi içerikleri
-- Supabase Dashboard → SQL Editor → çalıştır

create table if not exists public.info_library_contents (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null default '',
  youtube_url text not null default '',
  source text not null default '',
  category text not null default 'genel',
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_by text not null default '',
  created_at timestamptz not null default now()
);

-- Daha önce tablo oluşturulduysa kaynak sütununu ekle
alter table public.info_library_contents
  add column if not exists source text not null default '';

create index if not exists info_library_category_sort_idx
  on public.info_library_contents (category, is_active, sort_order, created_at desc);

alter table public.info_library_contents enable row level security;

-- Herkes aktif içerikleri okuyabilir (misafir / girişli)
drop policy if exists "info_library_select_public" on public.info_library_contents;
create policy "info_library_select_public"
  on public.info_library_contents for select
  to anon, authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_insert_admin" on public.info_library_contents;
create policy "info_library_insert_admin"
  on public.info_library_contents for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_update_admin" on public.info_library_contents;
create policy "info_library_update_admin"
  on public.info_library_contents for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "info_library_delete_admin" on public.info_library_contents;
create policy "info_library_delete_admin"
  on public.info_library_contents for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- Örnek seed (yoksa)
insert into public.info_library_contents (title, description, youtube_url, source, category, sort_order)
select
  'Tummy Time’a Nasıl Başlanır?',
  'Prematüre bebeklerde yüzüstü uyanık süre, boyun ve omuz gücünü destekler. Kısa tutun, doktorunuza danışın. Bu içerik bilgilendirme amaçlıdır.',
  'https://www.youtube.com/watch?v=zQfuBFwVZ5E',
  'Pathways.org',
  'premature',
  0
where not exists (
  select 1 from public.info_library_contents where category = 'premature' limit 1
);

notify pgrst, 'reload schema';
