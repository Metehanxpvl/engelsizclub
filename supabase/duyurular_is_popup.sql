-- Duyurular: pop-up haber vs yatay liste (Güncel Haber)
-- Supabase Dashboard → SQL Editor → New query → çalıştır

alter table public.duyurular
  add column if not exists is_popup boolean not null default false;

create index if not exists duyurular_popup_active_created_idx
  on public.duyurular (is_popup, is_active, created_at desc);

notify pgrst, 'reload schema';
