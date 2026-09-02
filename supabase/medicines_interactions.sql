-- İlaç etkileşimleri (prospektüs / küpür özeti)
-- Additive: mevcut medicines tablosuna sütun ekler. RLS / politikalar değişmez.
-- Gemini JSON: drug_interactions string dizisi. Eski satırlar [] kalır.
-- Cache INSERT/UPDATE bu diziyi yazar (lib/models/medicine_report.dart).
-- Supabase Dashboard → SQL Editor → bu dosyayı çalıştırın
-- https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

alter table public.medicines
  add column if not exists drug_interactions jsonb not null default '[]'::jsonb;

comment on column public.medicines.drug_interactions is
  'Prospektüste yer alan ilaç / etken madde etkileşimleri (bilgi amaçlı dizi). Gemini JSON: drug_interactions.';

notify pgrst, 'reload schema';
