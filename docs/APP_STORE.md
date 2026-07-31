# App Store — Engelsiz Club (Codemagic + GitHub)

Windows’ta Mac olmadığı için iOS build’i **Codemagic** üretir; kod **GitHub**’da kalır.

## Paket kimliği
- **Bundle ID:** `com.sakircaykara.engelsizclub`
- **Uygulama adı:** Engelsiz Club
- **Repo:** https://github.com/Metehanxpvl/engelsizclub
- **Config:** kökteki `codemagic.yaml`

---

## Adım 1 — Apple tarafı (bir kez)

1. [Apple Developer Program](https://developer.apple.com/programs/) üyeliği
2. [Certificates, Identifiers & Profiles](https://developer.apple.com/account/resources/identifiers/list) → **Identifiers** → **+**  
   - App ID: `com.sakircaykara.engelsizclub`  
   - Push Notifications’ı (bildirim kullanıyorsanız) işaretleyin
3. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → New App  
   - Platforms: iOS  
   - Name: Engelsiz Club  
   - Bundle ID: `com.sakircaykara.engelsizclub`  
   - SKU: `engelsizclub-ios`
4. **API Key:** App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**  
   - **Generate API Key** → Access: **App Manager** (veya Admin)  
   - **Key ID**, **Issuer ID** not alın  
   - `.p8` dosyasını indirin (yalnızca bir kez)

---

## Adım 2 — Codemagic hesabı

1. https://codemagic.io → **Sign up with GitHub**
2. Repo’yu yetkilendirin: `Metehanxpvl/engelsizclub`
3. **Add application** → GitHub → `engelsizclub` seçin  
   - Project type: **Flutter App** (veya “Configure later” / yaml)
4. Uygulama ayarında **codemagic.yaml** kullanıldığından emin olun

---

## Adım 3 — Apple Developer Portal entegrasyonu

Codemagic → **Teams** → sizin team → **Team integrations** → **Developer Portal**:

1. **Manage keys** → **Add key**
2. **Key name:** `EngelsizClubASC`  
   *(bu isim `codemagic.yaml` içindeki `integrations.app_store_connect` ile birebir aynı olmalı)*
3. Issuer ID + Key ID + `.p8` yükleyin → Save

Codemagic bu anahtarla **Distribution sertifikası + App Store provisioning profile**’ı otomatik üretebilir / yenileyebilir.

---

## Adım 4 — İlk build

1. Değişiklikleri GitHub’a push edin (`codemagic.yaml` + iOS bundle id)
2. Codemagic → uygulama → **Start new build**
3. Workflow seçin: **iOS → TestFlight**
4. Build bitince:
   - IPA artifact iner
   - TestFlight’a yüklenir (API key doğruysa)
5. App Store Connect → **TestFlight** → build’i onaylayın / testçi ekleyin

Mağaza incelemesine göndermek için workflow: **iOS → App Store Review**  
(veya `codemagic.yaml` içinde `submit_to_app_store: true`).

---

## Adım 5 — Mağaza listesi (App Store Connect)

Build geldikten sonra doldurun:
- Ekran görüntüleri
- Açıklama / anahtar kelimeler
- Destek URL: `https://engelsizclub.com`
- Gizlilik politikası
- App Privacy formu
- Yaş derecelendirmesi
- İnceleme hesabı (test e-posta + şifre)

Sonra **Add for Review** → **Submit to App Review**.

---

## Sürüm numarası

`pubspec.yaml` → `version: 1.0.23+24`  
Her yeni yüklemede **+build** artmalı (örn. `1.0.24+25`).

---

## Firebase (iOS)

Bundle ID ile iOS app ekleyin → `GoogleService-Info.plist` → `ios/Runner/`  
(Push / Google Sign-In için gerekli olabilir.)

---

## Sorun giderme

| Sorun | Çözüm |
|--------|--------|
| Integration not found `EngelsizClubASC` | Team integrations’da key adı birebir aynı mı? |
| No matching provisioning profile | Bundle ID Apple’da tanımlı mı? Codemagic’in sertifika üretmesine izin verildi mi? |
| Invalid Bundle | `pubspec` build numarası önceki yüklemeden büyük olmalı |
| TestFlight’ta build yok | API key yetkisi App Manager+; e-posta spam klasörü; processing 5–15 dk sürebilir |

---

## Kontrol listesi

- [ ] Apple Developer aktif
- [ ] Bundle ID + App Store Connect app oluşturuldu
- [ ] API Key (.p8) Codemagic’e `EngelsizClubASC` adıyla eklendi
- [ ] GitHub’da `codemagic.yaml` var ve push edildi
- [ ] **iOS → TestFlight** build yeşil
- [ ] Store listing dolduruldu → Submit for Review

GitHub Actions workflow (`.github/workflows/ios-testflight.yml`) yedek olarak duruyor; Codemagic kullanıyorsanız onu çalıştırmanız gerekmez.
