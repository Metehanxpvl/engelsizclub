-- Daha Fazlası menü öğeleri (aktif/pasif + harici link)
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın

create table if not exists public.daha_fazlasi_menu (
  id bigint generated always as identity primary key,
  title text not null,
  subtitle text not null default '',
  -- 'route' = uygulama içi (harita, taramalar, aile_kocu, haklar, kartlar, mchat, cvi, cvi2, gelisim, barkod, puzzle)
  -- 'url'   = harici / bilgi-kütüphanesi sayfası
  link_type text not null default 'url'
    check (link_type in ('route', 'url')),
  link text not null,
  icon text not null default 'link',
  sort_order int not null default 0,
  is_active boolean not null default true,
  is_builtin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists daha_fazlasi_menu_sort_idx
  on public.daha_fazlasi_menu (sort_order asc, id asc);

alter table public.daha_fazlasi_menu enable row level security;

-- Herkes aktifleri okusun (misafir + girişli)
drop policy if exists "more_menu_select_anon" on public.daha_fazlasi_menu;
create policy "more_menu_select_anon"
  on public.daha_fazlasi_menu for select
  to anon
  using (is_active = true);

drop policy if exists "more_menu_select_auth" on public.daha_fazlasi_menu;
create policy "more_menu_select_auth"
  on public.daha_fazlasi_menu for select
  to authenticated
  using (
    is_active = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "more_menu_insert_admin" on public.daha_fazlasi_menu;
create policy "more_menu_insert_admin"
  on public.daha_fazlasi_menu for insert
  to authenticated
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "more_menu_update_admin" on public.daha_fazlasi_menu;
create policy "more_menu_update_admin"
  on public.daha_fazlasi_menu for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "more_menu_delete_admin" on public.daha_fazlasi_menu;
create policy "more_menu_delete_admin"
  on public.daha_fazlasi_menu for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

-- İlk seed (tablo boşsa)
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select * from (values
  ('Taramalar & Egzersizler & Oyun', 'Puzzle, CVI egzersizleri ve otizm tarama', 'route', 'taramalar', 'apps', 5, true, true),
  ('engelsiz Boyama', 'Galeriden fotoğraf → siyah-beyaz boyama sayfası', 'route', 'boyama', '🎨', 6, true, true),
  ('Aile Koçum', 'Ders, ilaç ve not takibi (çevrimdışı)', 'route', 'aile_kocu', 'family', 10, true, true),
  ('Haklar', 'Devlet hakları ve rehber', 'route', 'haklar', 'balance', 20, true, true),
  ('Kartlar', 'Görsel destek kartları', 'route', 'kartlar', 'grid', 30, true, true),
  ('Gelişim Etkinlikleri', '120 etkinlik · 7 grup · filtre ve video', 'route', 'gelisim', 'extension', 60, true, true)
) as v(title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
where not exists (select 1 from public.daha_fazlasi_menu limit 1);

-- Harita alt menüden Daha Fazlası’na taşındı (tablo dolu olsa da ekle).
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Harita',
  'Destek merkezleri ve yakındaki hizmet noktaları',
  'route',
  'harita',
  'place',
  0,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(link) in ('harita', 'merkezler')
);

-- Taramalar & Egzersizler & Oyun grubu (tablo dolu olsa da ekle).
-- Çocuklar (puzzle / cvi / cvi2 / mchat) istemcide bu grubun altında açılır.
-- Engelsiz Boyama üst listede kalır (id 13 silinmesin — bkz. daha_fazlasi_boyama_move.sql).
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'Taramalar & Egzersizler & Oyun',
  'Puzzle, CVI egzersizleri ve otizm tarama',
  'route',
  'taramalar',
  'apps',
  5,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where lower(trim(link)) in ('taramalar', 'taramalar_egzersizler_oyun')
);

-- Engelsiz Boyama üst Daha Fazlası satırı (tablo dolu olsa da ekle; id 13 silinmesin).
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
select
  'engelsiz Boyama',
  'Galeriden fotoğraf → siyah-beyaz boyama sayfası',
  'route',
  'boyama',
  '🎨',
  6,
  true,
  true
where not exists (
  select 1 from public.daha_fazlasi_menu
  where id = 13
     or lower(trim(link)) in ('boyama', '/boyama', 'route:boyama')
     or lower(link) like '%boyama.html%'
     or lower(title) like '%boyama%'
);

notify pgrst, 'reload schema';
