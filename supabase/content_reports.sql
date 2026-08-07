-- Forum / UGC içerik şikayet alanları + durum
-- Supabase SQL Editor'de çalıştırın (user_blocks_reports.sql sonrası).

alter table public.user_reports
  add column if not exists content_type text not null default '';
alter table public.user_reports
  add column if not exists content_id text not null default '';
alter table public.user_reports
  add column if not exists status text not null default 'pending';

create index if not exists user_reports_status_idx
  on public.user_reports (status, created_at desc);

create index if not exists user_reports_content_idx
  on public.user_reports (content_type, content_id);

-- Moderasyon notu (admin): isteğe bağlı
alter table public.user_reports
  add column if not exists moderator_note text not null default '';

notify pgrst, 'reload schema';
