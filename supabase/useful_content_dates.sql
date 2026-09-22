-- Fırsat / Destek collector: içerik tarihi kolonları (yalnız ekle).
-- SQL Editor → Run. Mevcut satırları silmez, published yapmaz, FCM yok.
-- date_status: recent | unknown | older
-- content_kind: recent | active_opportunity
-- published_at: kaynak yayın/güncelleme tarihi (crawl last_checked_at değil).
-- Kolon zaten varsa ADD IF NOT EXISTS no-op.

alter table public.useful_content
  add column if not exists date_status text;

alter table public.useful_content
  add column if not exists content_kind text;

alter table public.useful_content
  add column if not exists published_at timestamptz;

comment on column public.useful_content.date_status is
  'recent | unknown | older. Kaynak içerik tarihi; sitemap lastmod veya crawl last_checked_at değil.';

comment on column public.useful_content.content_kind is
  'recent = son 15 gün; active_opportunity = daha eski ama başvuru/deadline/etkinlik hâlâ açık.';

notify pgrst, 'reload schema';
