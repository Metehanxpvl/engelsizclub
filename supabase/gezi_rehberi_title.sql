-- Gezi Rehberi: yer başlığı + il içi sıra (1. 2. 3.)
-- Supabase Dashboard → SQL Editor → çalıştırın (additive; kampanya / tiles'a dokunmaz)

alter table public.gezi_rehberi
  add column if not exists title text not null default '';

alter table public.gezi_rehberi
  add column if not exists sort_index int not null default 0;

-- İl bazında 1, 2, 3… (mevcut sort_order / created_at sırasını korur)
with ranked as (
  select
    id,
    row_number() over (
      partition by city_slug
      order by
        nullif(sort_index, 0),
        sort_order,
        created_at,
        id
    ) as rn
  from public.gezi_rehberi
)
update public.gezi_rehberi g
set
  sort_index = r.rn,
  sort_order = r.rn
from ranked r
where g.id = r.id;

create index if not exists gezi_rehberi_city_sort_idx
  on public.gezi_rehberi (city_slug, is_active, sort_index, id);

notify pgrst, 'reload schema';
