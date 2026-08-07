-- ESKİ: Legacy Places REST proxy (nearbysearch/json).
-- Artık uygulama Places API (New) kullanıyor (places.googleapis.com/v1/...).
-- Bu SQL'i çalıştırmanıza gerek yok; Cloud Errors'ı azaltmak için
-- legacy Places API çağrılarını kapatın / anahtar kısıtlarını sadeleştirin.
--
-- Gerekirse fonksiyonu kaldırmak için:
--   drop function if exists public.google_places_proxy(jsonb);
--   drop function if exists public._uri_encode(text);

select 1;
