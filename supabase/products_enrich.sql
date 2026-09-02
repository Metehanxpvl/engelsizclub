-- Eksik ürün satırlarını zenginleştirme (içindekiler / görsel / safety_report)
-- Mevcut kurulum: supabase/products.sql INSERT var, UPDATE yalnız admin.
-- Bu dosya: içindekiler boşken anon + authenticated UPDATE.
-- Yeniden çalıştırmak yeni sütun gerektirmez; RLS hâlâ boş içindekileri güncellemeye izin vermeli.
-- Uygulama: ad-only satır gösterilir; Gemini metin içindekileri doldurunca UPDATE.
-- Supabase Dashboard → SQL Editor → çalıştırın
-- https://supabase.com/dashboard/project/qycrkqwqrysypvqaipqn/sql/new

grant update on table public.products to anon, authenticated;

-- Yalnız şu an içindekileri boş olan satır (tam kayıt ezilmez).
drop policy if exists "products_update_enrich_incomplete" on public.products;
create policy "products_update_enrich_incomplete"
  on public.products for update
  to anon, authenticated
  using (
    coalesce(char_length(btrim(ingredients)), 0) < 4
    or btrim(ingredients) ~* '^(unknown|n/a|none|not available|içindekiler metni yok|içindekiler metni sınırlı|icerik bilgisi sınırlı|içerik bilgisi sınırlı)[. ;]*$'
  )
  with check (true);

notify pgrst, 'reload schema';
