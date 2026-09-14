-- Bilimsel araştırma pending kayıtlara story görseli.
-- SQL Editor → Run. Mevcut satırları silmez; duyurular tablosuna dokunmaz.
-- Admin incelemede galeriden yüklenen (veya https URL) burada tutulur;
-- Onayla → addDuyuru(image_url, notify) ile Güncel Duyurular story’sine geçer.

alter table public.scientific_researches
  add column if not exists image_url text not null default '';

notify pgrst, 'reload schema';
