-- Ekranların native mi yoksa engelsizclub.com WebView mı açılacağı.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın (CLI token gerekmez).
--
-- Boyama / Puzzle: seed web. Sitede düzenle → telefon (bu AAB sonrası) görür.
-- İlanlar / Etkinlikler / Forum / Bilgi Kütüphanesi: seed native.
--   open_mode='web' yapsanız bile uygulama henüz o sekmeleri WebView’e çevirmez
--   (giriş, ilan yazma, geri tuşu, bildirim derin linki native’de). Takip işi.

create table if not exists public.app_screen_config (
  id text primary key,
  title text not null default '',
  open_mode text not null default 'native'
    check (open_mode in ('native', 'web')),
  url text not null default '',
  enabled boolean not null default true,
  sort int not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.app_screen_config
  add column if not exists title text not null default '';
alter table public.app_screen_config
  add column if not exists open_mode text not null default 'native';
alter table public.app_screen_config
  add column if not exists url text not null default '';
alter table public.app_screen_config
  add column if not exists enabled boolean not null default true;
alter table public.app_screen_config
  add column if not exists sort int not null default 0;
alter table public.app_screen_config
  add column if not exists updated_at timestamptz not null default now();

create index if not exists app_screen_config_sort_idx
  on public.app_screen_config (sort asc, id asc);

alter table public.app_screen_config enable row level security;

grant select on table public.app_screen_config to anon, authenticated;
grant insert, update, delete on table public.app_screen_config to authenticated;

drop policy if exists "app_screen_config_select_anon" on public.app_screen_config;
create policy "app_screen_config_select_anon"
  on public.app_screen_config for select
  to anon
  using (enabled = true);

drop policy if exists "app_screen_config_select_auth" on public.app_screen_config;
create policy "app_screen_config_select_auth"
  on public.app_screen_config for select
  to authenticated
  using (
    enabled = true
    or lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "app_screen_config_write_admin" on public.app_screen_config;
create policy "app_screen_config_write_admin"
  on public.app_screen_config for all
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

insert into public.app_screen_config (id, title, open_mode, url, enabled, sort)
values
  (
    'boyama',
    'Boyama',
    'web',
    'https://www.engelsizclub.com/boyama',
    true,
    10
  ),
  (
    'puzzle',
    'Fotoğraflı Puzzle',
    'web',
    'https://www.engelsizclub.com/fotografli-puzzle.html',
    true,
    20
  ),
  (
    'bilgi_kutuphanesi',
    'Bilgi Kütüphanesi',
    'native',
    'https://www.engelsizclub.com',
    true,
    30
  ),
  (
    'ilanlar',
    'İlanlar',
    'native',
    'https://www.engelsizclub.com',
    true,
    40
  ),
  (
    'etkinlikler',
    'Etkinlikler',
    'native',
    'https://www.engelsizclub.com',
    true,
    50
  ),
  (
    'forum',
    'Forum',
    'native',
    'https://www.engelsizclub.com',
    true,
    60
  )
on conflict (id) do nothing;

notify pgrst, 'reload schema';
