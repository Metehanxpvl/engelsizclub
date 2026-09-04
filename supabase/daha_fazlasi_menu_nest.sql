-- Daha Fazlası: iç içe gruplar (parent_id) + sıra (sort_order)
-- Idempotent. Mevcut satırları SİLMEZ.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- (veya: npx supabase db query -f supabase/daha_fazlasi_menu_nest.sql --linked)

alter table public.daha_fazlasi_menu
  add column if not exists parent_id bigint;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'daha_fazlasi_menu_parent_fk'
  ) then
    alter table public.daha_fazlasi_menu
      add constraint daha_fazlasi_menu_parent_fk
      foreign key (parent_id)
      references public.daha_fazlasi_menu (id)
      on delete set null;
  end if;
end $$;

alter table public.daha_fazlasi_menu
  drop constraint if exists daha_fazlasi_menu_parent_not_self;

alter table public.daha_fazlasi_menu
  add constraint daha_fazlasi_menu_parent_not_self
  check (parent_id is null or parent_id <> id);

-- Grup satırları için link_type = 'folder' (eski 'route'/'url' durur)
do $$
declare
  cname text;
begin
  select conname into cname
  from pg_constraint
  where conrelid = 'public.daha_fazlasi_menu'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%link_type%';
  if cname is not null then
    execute format('alter table public.daha_fazlasi_menu drop constraint %I', cname);
  end if;
end $$;

alter table public.daha_fazlasi_menu
  drop constraint if exists daha_fazlasi_menu_link_type_check;

alter table public.daha_fazlasi_menu
  add constraint daha_fazlasi_menu_link_type_check
  check (link_type in ('route', 'url', 'folder'));

create index if not exists daha_fazlasi_menu_parent_sort_idx
  on public.daha_fazlasi_menu (parent_id asc, sort_order asc, id asc);

-- Üst grup: mevcut "Taramalar & Egzersizler & Oyun" satırı parent olur (yoksa ekle).
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

-- Bilinen çocukları (parent_id boşsa) Taramalar altına al. Boyama üst seviyede kalır.
update public.daha_fazlasi_menu c
set
  parent_id = p.id,
  updated_at = now()
from public.daha_fazlasi_menu p
where lower(trim(p.link)) in ('taramalar', 'taramalar_egzersizler_oyun')
  and c.id <> p.id
  and c.parent_id is null
  and (
    lower(trim(c.link)) in (
      'puzzle',
      'cvi',
      'cvi2',
      'mchat',
      'route:puzzle',
      'route:cvi',
      'route:cvi2',
      'route:mchat'
    )
    or lower(c.link) like '%fotografli-puzzle%'
    or lower(c.link) like '%cvi-egzersizleri-2%'
    or lower(c.link) like '%cvi-gorsel-egzersiz%'
    or (
      lower(c.title) like '%puzzled%'
      or lower(c.title) like '%fotoğraflı puzzle%'
      or lower(c.title) like '%fotografli puzzle%'
    )
    or lower(c.title) like '%cvi%'
    or lower(c.title) like '%m-chat%'
    or lower(c.title) like '%mchat%'
    or lower(c.title) like '%otizm tarama%'
  )
  and not (
    lower(trim(c.link)) in ('boyama', '/boyama', 'route:boyama')
    or lower(c.link) like '%boyama.html%'
    or lower(c.title) like '%boyama%'
  );

-- Eksik çocuk satırları (varsa dokunma).
insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, parent_id)
select
  'Puzzled oyun',
  'Fotoğraflı puzzle',
  'route',
  'puzzle',
  'games',
  10,
  true,
  true,
  p.id
from public.daha_fazlasi_menu p
where lower(trim(p.link)) in ('taramalar', 'taramalar_egzersizler_oyun')
  and not exists (
    select 1 from public.daha_fazlasi_menu x
    where lower(trim(x.link)) in ('puzzle', 'route:puzzle')
       or lower(x.link) like '%fotografli-puzzle%'
  )
limit 1;

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, parent_id)
select
  'CVI görsel egzersizleri',
  '20 adımlık yüksek kontrastlı görsel egzersiz',
  'route',
  'cvi',
  'eye',
  20,
  true,
  true,
  p.id
from public.daha_fazlasi_menu p
where lower(trim(p.link)) in ('taramalar', 'taramalar_egzersizler_oyun')
  and not exists (
    select 1 from public.daha_fazlasi_menu x
    where lower(trim(x.link)) in ('cvi', 'route:cvi')
       or (
         lower(x.link) like '%cvi-gorsel-egzersiz%'
         and lower(x.link) not like '%cvi-egzersizleri-2%'
       )
  )
limit 1;

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, parent_id)
select
  'CVI görsel egzersizleri-2',
  'Yıldızlar · Meyveler · Arabalar — Görsel Keşif',
  'route',
  'cvi2',
  'eye',
  30,
  true,
  true,
  p.id
from public.daha_fazlasi_menu p
where lower(trim(p.link)) in ('taramalar', 'taramalar_egzersizler_oyun')
  and not exists (
    select 1 from public.daha_fazlasi_menu x
    where lower(trim(x.link)) in ('cvi2', 'route:cvi2')
       or lower(x.link) like '%cvi-egzersizleri-2%'
       or lower(x.title) like '%cvi egzersizleri-2%'
       or lower(x.title) like '%cvi görsel egzersizleri-2%'
  )
limit 1;

insert into public.daha_fazlasi_menu
  (title, subtitle, link_type, link, icon, sort_order, is_active, is_builtin, parent_id)
select
  'Otizm tarama modülleri',
  'M-CHAT tarama akışı',
  'route',
  'mchat',
  'search',
  40,
  true,
  true,
  p.id
from public.daha_fazlasi_menu p
where lower(trim(p.link)) in ('taramalar', 'taramalar_egzersizler_oyun')
  and not exists (
    select 1 from public.daha_fazlasi_menu x
    where lower(trim(x.link)) in ('mchat', 'route:mchat')
       or lower(x.title) like '%m-chat%'
       or lower(x.title) like '%otizm tarama%'
  )
limit 1;

-- Boyama üst seviyede kalsın (admin isterse taşır). Yoksa ekle; silme yok.
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
  where lower(trim(link)) in ('boyama', '/boyama', 'route:boyama')
     or lower(link) like '%boyama.html%'
     or lower(title) like '%boyama%'
);

notify pgrst, 'reload schema';
