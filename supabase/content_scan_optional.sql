-- Content-scan isteğe bağlı kolonlar (geriye dönük uyumlu).
-- SQL Editor → Run. Mevcut satırları silmez, status değiştirmez, FCM yok.
-- Collector bu kolonlar yoksa da pending yazar (PGRST204 olursa kolonları düşürür).

alter table public.news_candidates
  add column if not exists ai_generated boolean not null default true;

alter table public.news_candidates
  add column if not exists risk_flag boolean not null default false;

alter table public.news_candidates
  add column if not exists confidence numeric;

alter table public.news_candidates
  add column if not exists enrich_failed boolean not null default false;

alter table public.news_candidates
  add column if not exists sources jsonb not null default '[]'::jsonb;

alter table public.useful_content
  add column if not exists ai_generated boolean;

alter table public.useful_content
  add column if not exists risk_flag boolean;

alter table public.useful_content
  add column if not exists confidence numeric;

alter table public.useful_content
  add column if not exists enrich_failed boolean;

alter table public.scientific_researches
  add column if not exists ai_generated boolean;

alter table public.scientific_researches
  add column if not exists risk_flag boolean;

alter table public.scientific_researches
  add column if not exists confidence numeric;

alter table public.scientific_researches
  add column if not exists enrich_failed boolean;

notify pgrst, 'reload schema';
