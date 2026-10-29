# Content scan (Engelsiz Club)

GitHub Actions ile haber / fırsat / destek / bilim tarar ve **mevcut admin kuyruklarına** `pending` yazar. Kullanıcıya otomatik yayın ve FCM yoktur.

## Adım 0 eşlemesi

| Ekran | Tablo | Status |
| --- | --- | --- |
| Yeni Haberler | `public.news_candidates` | `pending` |
| Fırsatlar ve Destekler (chip: Fırsat / Destek / Hak / Burs…) | `public.useful_content` | `pending_review` |
| Bilim inceleme | `public.scientific_researches` | `pending_review` |

Admin paneli Flutter; veri kaynağı **Supabase**. Şema değiştirilmedi; isteğe bağlı kolonlar: `supabase/content_scan_optional.sql`.

Mevcut gazete RSS (`daily-news-scan`), belediye collector ve bilimsel collector duruyor. Bu hat `config/sources.json` üzerinden Google News, GDELT, DergiPark, OpenAlex ekler.

## Kurulum

1. Repo secrets:
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `ANTHROPIC_API_KEY` (tercih, ucuz Haiku)
   - yoksa mevcut `GEMINI_API_KEY` / `AI_API_KEY`
   - isteğe bağlı `NCBI_API_KEY`
2. (Önerilir) Dashboard → SQL Editor → `supabase/content_scan_optional.sql` Run.
3. Actions → **Content scan** → Run workflow. Cron: her gün 09:00 Türkiye (06:00 UTC).

Auto-approve kapalıdır. Açmak için secret `CONTENT_SCAN_AUTO_APPROVE=true` **veya** `config/pipeline.json` içinde `"auto_approve": true`. Açılsa bile haber ve bilim yine pending kalır; risk_flag olan kayıt asla otomatik geçmez.

## Yeni kaynak / durum

- Kaynak: `config/sources.json` → `google_news.queries`, `official_via_news.queries` veya `catalog` dizisine bir satır.
- Durum: `config/conditions.json` dizisine `{id, ad, tr, en}` ekle. Google News, OpenAlex, PubMed, ClinicalTrials sorguları bundan üretilir.
- Anahtarları koda gömmeyin.

`catalog` içinde 30+ named kaynak vardır (Google News, resmi site: sorguları, GDELT, OpenAlex, PubMed, ClinicalTrials, DergiPark, büyükşehirler).

## Çalışma kuralları

- Kaynak hata verirse logla, atla, devam et.
- Tekrar: URL + başlık hash + fuzzy > 0.85; aynı haber `sources[]` ile birleşir.
- `seen.json` Actions cache’dedir (repoya commit yok). Değişiklik yoksa commit yok.
- Çalışma başına en fazla 60 kayıt LLM’e gider. LLM hata → kayıt yine pending + `enrich_failed`.
- robots / ToS: RSS ve açık API; ağır HTML kazıma yok.

## Maliyet tahmini

- GitHub Actions: haber 3×/gün + bilim 1×/gün, `timeout-minutes: 10`, npm cache. Ayda ~120 dakika üst sınırı (çoğu run daha kısa).
- Anthropic Haiku: 60 kayıt × ~800 token ≈ 50k token/çalışma. Haber 3 run ≈ 150k token/gün → kabaca birkaç dolar/ay (kota ve fiyata göre değişir). Gemini yedek ücretsiz kotada kalabilir.

## Yerel

```bash
cd scripts/content-scan
npm ci
npm test
# SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... ANTHROPIC_API_KEY=... npm run scan:news
```
