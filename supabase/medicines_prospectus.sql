-- İlaç resmi prospektüs (KT) URL + "ne için kullanılır"
-- Additive: mevcut medicines tablosuna sütun ekler. Gıda `products` dokunulmaz.
-- Kaynak: TİTCK SKRS barkod indeksi + isteğe bağlı TİTCK KÜB/KT PDF + Gemini özet.
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

alter table public.medicines
  add column if not exists prospectus_url text;

alter table public.medicines
  add column if not exists indications text;

comment on column public.medicines.prospectus_url is
  'Resmi kullanma talimatı (KT) veya e-KT HTTPS. TİTCK PDF veya karekod URL.';

comment on column public.medicines.indications is
  'Prospektüs: ne için kullanılır (bilgi amaçlı metin).';

alter table public.medicines drop constraint if exists medicines_source_chk;
alter table public.medicines add constraint medicines_source_chk
  check (source in ('llm', 'cache', 'manual', 'photo', 'titck', 'public_index'));

-- Tam satırda boş prospectus_url doldurulabilsin (önbellek + resmi PDF).
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

notify pgrst, 'reload schema';
