-- İlaç prospektüs / küpür analizi önbelleği (gıda `products` tablosundan ayrı)
-- Fotoğraf / base64 bu tabloda YOKTUR. image_url yalnız public HTTPS (R2).
-- Akış: barkod → SELECT; isabet → bitir. Yok veya yalnız fotoğraf → Gemini → INSERT.
-- Ada arama: medicine_name ILIKE (medicines_name_idx); az sonuçta Gemini metin (barkod null).
-- drug_interactions: prospektüs etkileşimleri (jsonb dizi). Mevcut DB: medicines_interactions.sql.
-- prospectus_url / indications: mevcut DB: medicines_prospectus.sql.
-- Gemini / R2 anahtarları burada tutulmaz.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

create table if not exists public.medicines (
  id uuid primary key default gen_random_uuid(),
  barcode text,
  medicine_name text,
  active_ingredient text,
  usage_text text,
  indications text,
  side_effects jsonb not null default '[]'::jsonb,
  drug_interactions jsonb not null default '[]'::jsonb,
  safety_warnings text,
  prospectus_url text,
  image_url text,
  raw_report jsonb not null default '{}'::jsonb,
  source text not null default 'llm',
  created_at timestamptz not null default now(),
  constraint medicines_barcode_chk check (
    barcode is null or char_length(trim(barcode)) >= 4
  ),
  constraint medicines_source_chk check (
    source in ('llm', 'cache', 'manual', 'photo', 'titck', 'public_index')
  )
);

create unique index if not exists medicines_barcode_key
  on public.medicines (barcode)
  where barcode is not null and char_length(trim(barcode)) >= 4;

create index if not exists medicines_barcode_idx
  on public.medicines (barcode)
  where barcode is not null;

create index if not exists medicines_name_idx
  on public.medicines (lower(btrim(medicine_name)))
  where coalesce(btrim(medicine_name), '') <> '';

create index if not exists medicines_created_idx
  on public.medicines (created_at desc);

alter table public.medicines enable row level security;

grant usage on schema public to anon, authenticated, service_role;
grant all on table public.medicines to postgres, service_role;
grant select on table public.medicines to anon, authenticated;
grant insert on table public.medicines to anon, authenticated;
grant update on table public.medicines to anon, authenticated;
grant update, delete on table public.medicines to authenticated;

drop policy if exists "medicines_select_all" on public.medicines;
create policy "medicines_select_all"
  on public.medicines for select
  to anon, authenticated
  using (true);

drop policy if exists "medicines_insert_cache" on public.medicines;
create policy "medicines_insert_cache"
  on public.medicines for insert
  to anon, authenticated
  with check (true);

-- Eksik satır (ad / kullanım boş veya barkodsuz): Gemini / küpür ile doldur.
drop policy if exists "medicines_update_enrich_incomplete" on public.medicines;
create policy "medicines_update_enrich_incomplete"
  on public.medicines for update
  to anon, authenticated
  using (
    barcode is null
    or coalesce(char_length(btrim(barcode)), 0) < 4
    or coalesce(char_length(btrim(medicine_name)), 0) < 2
    or coalesce(char_length(btrim(usage_text)), 0) < 4
    or coalesce(char_length(btrim(prospectus_url)), 0) < 8
    or coalesce(char_length(btrim(indications)), 0) < 4
  )
  with check (true);

drop policy if exists "medicines_update_admin" on public.medicines;
create policy "medicines_update_admin"
  on public.medicines for update
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  )
  with check (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

drop policy if exists "medicines_delete_admin" on public.medicines;
create policy "medicines_delete_admin"
  on public.medicines for delete
  to authenticated
  using (
    lower(coalesce(auth.jwt() ->> 'email', '')) = 'sakir.caykara@gmail.com'
  );

notify pgrst, 'reload schema';
