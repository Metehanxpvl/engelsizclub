# Dinamik katalog (Supabase + cache)

Uygulamayı her güncellemede yeniden deploy etmeden içerik yönetmek için.

## 1) Supabase SQL

Dashboard → SQL Editor → `supabase/app_catalog.sql` dosyasının **tamamını** Run.

Oluşan tablolar:

| Tablo | Ne tutar |
|-------|----------|
| `app_settings` | key → JSON ayarlar (TTL, yarıçap, duyuru…) |
| `app_categories` | Haklar / uzmanlık / merkez / forum kategorileri |
| `app_content` | Banner, metin, duyuru CMS blokları |
| `app_rights` | Haklar listesi (sihirbaz da buradan beslenir) |
| `app_centers` | Küratör merkez listesi (Places yedeği) |
| `app_diseases` | Ana sayfa hastalık rehberleri |
| `app_catalog_versions` | Ucuz sürüm numaraları (kota dostu sync) |

Okuma: herkes (`anon` + `authenticated`).  
Yazma: `sakir.caykara@gmail.com` (RLS) veya Dashboard Table Editor.

## 2) Flutter

- `lib/services/app_catalog_service.dart` — çek + SharedPreferences cache + TTL + sürüm
- `lib/services/catalog_adapters.dart` — remote → UI model; boşsa hardcoded fallback
- `main.dart` açılışta `AppCatalogService.instance.bootstrap()`

### Sync mantığı
1. Diskten anında yükle (offline açılır)
2. `app_catalog_versions` ile 1 küçük istek
3. Sadece **sürümü artmış** veya **TTL dolmuş** paketleri indir
4. Aksi halde ağ yok → kota yok

Varsayılan TTL: 6 saat (`app_settings.catalog_ttl_hours` ile değişir).

## 3) Örnek: yeni hak ekleme

Table Editor → `app_rights` → Insert.  
Trigger otomatik `rights` sürümünü artırır → uygulama bir sonraki sync’te çeker.

## 4) Bağlı ekranlar
- Haklar sekmesi + sihirbaz → remote haklar/kategoriler
- İlan formu uzmanlık alanı → remote `uzmanlik` kategorileri
- Merkez filtreleri (adapter hazır; Places canlı arama ayrı)
