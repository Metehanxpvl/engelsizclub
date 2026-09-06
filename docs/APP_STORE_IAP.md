# App Store — In-App Purchase (Guideline 2.1b)

Apple incelemesi sandbox satın almayı ve **sürüme bağlı IAP ürünlerini** ister. Bu dosya Connect tıklama listesidir; uygulamada sahte ödeme yoktur.

## Ürün kimlikleri (kod ile birebir)

Hepsi **Consumable (tüketilebilir)**. Bundle ID: `com.sakircaykara.engelsizclub`.

| Puan | Öncelikli iOS ID | Eski / Play ID (uygulama da sorar) |
|------|------------------|-------------------------------------|
| 1    | `puan_1`         | `point_1` / `kredi_1`               |
| 5    | `puan_5`         | `point_5` / `kredi_5`               |
| 10   | `puan_10`        | `point_10` / `kredi_10`             |
| 30   | `puan_30`        | `point_30` / `kredi_30`             |
| 50   | `puan_50`        | `point_50` / `kredi_50`             |
| 100  | `puan_100`       | `point_100` / `kredi_100`           |

**Connect’te zaten `point_*` oluşturduysanız yenisini açmayın.** Uygulama her iki kümeyi de sorar. Altı ürünü de **aynı kümeden** bu sürüme ekleyin.

Önerilen fiyatlar (Play ile aynı): ₺69,90 / ₺314,55 / ₺594,15 / ₺1.677,60 / ₺2.621,25 / ₺4.893,00.

## Paid Apps Agreement (zorunlu)

1. [App Store Connect](https://appstoreconnect.apple.com) → **Business / Agreements, Tax, and Banking**
2. **Paid Applications Agreement** durumu **Active** olmalı (Pending / Expired sandbox’ı kırar)
3. Banka + vergi formları tamamlanmış olmalı

Sandbox, Agreement olmadan ürün döndürmez; `queryProductDetails` boş gelir.

## IAP oluştur / metadata

Her ürün için:

1. Apps → Engelsiz Club → **Monetization** → **In-App Purchases** → **+**
2. Type: **Consumable**
3. Product ID: yukarıdaki tablodan (ör. `puan_1`) — sonra değiştirilemez
4. Reference Name: `1 Puan` vb.
5. Price: Türkiye fiyatı
6. Localization (en az İngilizce + Türkçe): Display Name + Description
7. **Review screenshot (zorunlu):** iPhone veya iPad’de **Profil → Puan Yükle / Satın Al** ekranı (paket listesi). 640×920 veya daha büyük PNG/JPEG
8. Review Notes: “Consumable points for listing offers. Sandbox: sign in with App Review account; tap profile → Puan Yükle → pick a pack → App Store ile Öde.”

Durum **Ready to Submit** olmalı (Missing Metadata = screenshot eksik).

## Bu sürüme IAP bağla + yeni binary

Apple hem **yeni IPA** hem **IAP submit** ister.

1. Codemagic: dal `release/ios-1.0.66-71` (veya `main` ile aynı sürüm) → **iOS TestFlight** / App Store workflow
2. App Store Connect → uygulama sürümü (build `1.0.102` / `110` veya pubspec’teki güncel)
3. **In-App Purchases and Subscriptions** → **+** → altı Consumable’ı seç
4. Her IAP satırında Review screenshot yüklü olsun
5. Build’i bu sürüme ekle (Codemagic IPA / TestFlight)
6. **Add for Review** → **Submit**

Ürünleri sürüme eklemeden yalnızca binary göndermek 2.1(b) reddidir.

## İnceleme hesabı

- App Review Information’da çalışan e-posta + şifre
- O hesapla **Puan Yükle** görünür (uzman / bakıcı / aile)
- İnceleyici sandbox Apple ID kullanır; uygulama içinde ekstra “onay” yoktur

## Kod (özet)

- `lib/services/play_billing_service.dart` — `in_app_purchase` / StoreKit 2, boş ürün listesi sessiz satın alma yapmaz
- iPad: ortalanmış satın alma penceresi; StoreKit sheet’i Flutter dialog’unun arkasında kalmaz
- Başarı yalnızca gerçek `PurchaseStatus.purchased` / `restored` ile
