-- Daha Fazlası menü öğeleri (aktif/pasif + harici link)
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın

create table if not exists public.daha_fazlasi_menu (
  id bigint generated always as identity primary key,
  title text not null,
  subtitle text not null default '',
  -- 'route' = uygulama içi (aile_kocu, haklar, kartlar, mchat, cvi, gelisim)
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
  ('Aile Koçum', 'Ders, ilaç ve not takibi (çevrimdışı)', 'route', 'aile_kocu', 'family', 10, true, true),
  ('Haklar', 'Devlet hakları ve rehber', 'route', 'haklar', 'balance', 20, true, true),
  ('Kartlar', 'Görsel destek kartları', 'route', 'kartlar', 'grid', 30, true, true),
  ('Otizm Tarama', 'M-CHAT tarama akışı', 'route', 'mchat', 'search', 40, true, true),
  ('CVI Görsel Egzersizleri', '20 adımlık yüksek kontrastlı görsel egzersiz', 'route', 'cvi', 'eye', 50, true, true),
  ('Gelişim Etkinlikleri', '120 etkinlik · 7 grup · filtre ve video', 'route', 'gelisim', 'extension', 60, true, true)
) as v(title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin)
where not exists (select 1 from public.daha_fazlasi_menu limit 1);

notify pgrst, 'reload schema';
