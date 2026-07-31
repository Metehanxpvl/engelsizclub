-- İlan satıldı / yayından kaldır durumu
alter table public.ilanlar
  add column if not exists status text not null default 'active';

alter table public.ilanlar
  drop constraint if exists ilanlar_status_check;

alter table public.ilanlar
  add constraint ilanlar_status_check
  check (status in ('active', 'sold'));

create index if not exists ilanlar_status_idx on public.ilanlar (status);
