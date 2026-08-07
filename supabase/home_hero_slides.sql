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
