-- Fırsat / Destek pending kayıtlara story görseli.
-- SQL Editor → Run. duyurular tablosuna dokunmaz.
-- Admin incelemede galeriden yüklenen (veya RSS enclosure) URL burada tutulur;
-- Onayla → addDuyuru(image_url) ile Güncel Duyurular story’sine geçer.

alter table public.useful_content
  add column if not exists image_url text not null default '';

notify pgrst, 'reload schema';
