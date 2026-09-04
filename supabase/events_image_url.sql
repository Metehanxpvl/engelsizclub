-- events / etkinlikler: scraper görsel kolonu (PGRST204 düzeltmesi)
-- Dashboard: https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new
--
-- Hata: events upsert HTTP 400 PGRST204
--   "Could not find the 'image_url' column of 'events' in the schema cache"
-- Sebep: scripts/avm_scraper.py AVM kapak görselini eklediğinden beri
--   events satırlarına image_url gönderiyor; supabase/events.sql ile
--   oluşturulan tabloda bu kolon yok.
--
-- Bu dosya additive ve tekrar çalıştırılabilir (idempotent):
--   DROP yok, DELETE yok, veri kaybı yok.
-- events.sql'den sonra çalıştırılır; events.sql hiç uygulanmadıysa önce onu
-- çalıştırın (etkinlikler senkron kolonları ve indeksleri oradan gelir).

-- ── public.events: scraper'ın yazdığı kolonlar ────────────────────────────
-- avm_scraper.coerce_event() tam olarak şu anahtarları gönderir:
--   city, avm_name, event_name, event_date, description, image_url
-- İlk beşi events.sql'de zaten var; eksik olan yalnızca image_url.
-- Aşağıdaki blok yine de hepsini güvenceye alır (yeniden çalıştırılabilir).
alter table public.events
  add column if not exists image_url text;

alter table public.events
  add column if not exists city text;

alter table public.events
  add column if not exists avm_name text;

alter table public.events
  add column if not exists event_name text;

alter table public.events
  add column if not exists event_date text;

alter table public.events
  add column if not exists description text;

-- image_url boş string ile gelebilir; NULL da kabul (kapağı bulunamayan AVM).
-- Mevcut satırlar güncellenmez — dosya tamamen additive.
alter table public.events
  alter column image_url set default '';

-- ── public.etkinlikler: senkronun yazdığı kolonlar ────────────────────────
-- avm_scraper.sync_etkinlikler() şunları yazar: title, description, city,
-- avm_name, image_url, source, external_id, user_edited, is_active,
-- sort_order, sort_index, created_by
alter table public.etkinlikler
  add column if not exists image_url text;

alter table public.etkinlikler
  add column if not exists avm_name text not null default '';

alter table public.etkinlikler
  add column if not exists source text;

alter table public.etkinlikler
  add column if not exists external_id text;

alter table public.etkinlikler
  add column if not exists user_edited boolean not null default false;

alter table public.etkinlikler
  add column if not exists sort_order int not null default 0;

alter table public.etkinlikler
  add column if not exists sort_index int not null default 0;

alter table public.etkinlikler
  add column if not exists created_by text not null default '';

alter table public.etkinlikler
  alter column image_url set default '';

alter table public.etkinlikler
  alter column image_url drop not null;

-- ── PostgREST şema önbelleği ──────────────────────────────────────────────
-- PGRST204 bir şema-önbellek hatasıdır; kolon eklendikten sonra
-- PostgREST'in önbelleğini yenilemesi gerekir.
notify pgrst, 'reload schema';
