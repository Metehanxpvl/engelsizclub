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
2. **Key name:** `engelsizclub`  
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
- **Destek URL:** `https://engelsizclub.com/support.html` (veya `https://engelsizclub-e5842.web.app/support.html`)
- **Gizlilik politikası URL:** `https://engelsizclub.com/privacy.html`
- **EULA (Kullanım Koşulları):** App Store Connect → App Information → EULA alanına uygulama içi koşulları ekleyin veya açıklamada “Kullanım Koşulları uygulama içindedir” ifadesini kullanın
- App Privacy formu
- Yaş derecelendirmesi
- İnceleme hesabı (test e-posta + şifre)

Sonra **Add for Review** → **Submit to App Review**.

---

## App Store reddi (Guideline 4.8 / 1.2 / 1.5) — düzeltmeler

| Guideline | Gereksinim | Projede |
|-----------|------------|---------|
| **4.8** Sign in with Apple | Google yanında Apple girişi | iOS’ta `SignInWithAppleButton` + `AppleAuthService` |
| **1.2** UGC | EULA sıfır tolerans, filtre, rapor, engel, 24 saat | `legal_texts.dart`, `ugc_terms_gate.dart`, `content_moderation.dart`, `user_safety_sheet.dart` |
| **1.5** Destek URL | Çalışan destek sayfası | `web/support.html` → Firebase Hosting |

### Apple Developer (bir kez)

1. [Identifiers](https://developer.apple.com/account/resources/identifiers/list) → `com.sakircaykara.engelsizclub` → **Sign In with Apple** capability açık
2. `ios/Runner/Runner.entitlements` içinde `com.apple.developer.applesignin` (projede eklendi)

### Supabase — Apple provider

**iOS native (bizim uygulama — `signInWithIdToken`):**

1. Dashboard → **Authentication** → **Providers** → **Apple** → Enable
2. **Client IDs:** `com.sakircaykara.engelsizclub`
3. **Secret Key:** **boş bırakın** (native akışta OAuth secret gerekmez)
4. **Allow new users to sign up** açık

> Supabase dokümantasyonu: *“If you're building a native app only, you do not need to configure the OAuth settings.”*  
> Secret alanına `.p8` dosyasının ham içeriğini yapıştırmayın — hata: **“Secret key should be a JWT.”**

**Web/Android OAuth da kullanacaksanız** (Google tarayıcı köprüsü vb.):

1. Apple Developer → **Services ID** oluşturun (ör. `com.sakircaykara.engelsizclub.auth`)
2. Callback URL: `https://qycrkqwqrysypvqaipqn.supabase.co/auth/v1/callback`
3. **Keys** → Sign in with Apple key → `AuthKey_XXXX.p8` indirin (tek seferlik)
4. JWT üretin:
   ```powershell
   node tool/generate_apple_secret.mjs `
     --team-id TEAM_ID `
     --key-id KEY_ID `
     --client-id com.sakircaykara.engelsizclub.auth `
     --p8 .\AuthKey_KEY_ID.p8
   ```
5. Supabase **Client IDs:** `com.sakircaykara.engelsizclub.auth, com.sakircaykara.engelsizclub`  
   (Services ID **ilk sırada** — web OAuth için)
6. **Secret Key:** üretilen JWT (6 ayda bir yenileyin)

Alternatif: [Supabase Apple docs](https://supabase.com/docs/guides/auth/social-login/auth-apple) sayfasındaki tarayıcı JWT aracı.

### İncelemeye cevap (Resolution Center)

Apple’ın istediği gibi fiziksel cihazda kısa ekran kaydı ekleyin:
1. Giriş ekranında **Apple ile giriş** ve **Google ile giriş** birlikte görünüyor
2. Forum gönderisinde **Şikayet et / Engelle**
3. Destek URL’si tarayıcıda açılıyor (`support.html`)

---

## Sürüm numarası

`pubspec.yaml` → `version: 1.0.66+71`  
Her yeni yüklemede **+build** artmalı (örn. `1.0.67+72`).

---

## Firebase (Codemagic secret group)

Dosyalar gitignore’da (`google-services.json` / `GoogleService-Info.plist`) — GitHub’a gitmez.

Codemagic → **Environment variables** → Secret group adı: **`firebase_credentials`**

| Variable | Değer |
|----------|--------|
| `ANDROID_FIREBASE_SECRET` | `android/app/google-services.json` (ham JSON veya base64) |
| `IOS_FIREBASE_SECRET` | `ios/Runner/GoogleService-Info.plist` (ham plist veya base64) |

Windows base64 örneği:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios\Runner\GoogleService-Info.plist"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\app\google-services.json"))
```

Build script’leri bu env’leri dosyaya yazar (`codemagic.yaml`).

---

## Sorun giderme

| Sorun | Çözüm |
|--------|--------|
| Integration not found `engelsizclub` | Team integrations’da key adı birebir aynı mı? (`codemagic.yaml` → `integrations.app_store_connect`) |
| No matching provisioning profile | Bundle ID Apple’da tanımlı mı? Codemagic’in sertifika üretmesine izin verildi mi? |
| Invalid Bundle | `pubspec` build numarası önceki yüklemeden büyük olmalı |
| TestFlight’ta build yok | API key yetkisi App Manager+; e-posta spam klasörü; processing 5–15 dk sürebilir |

---

## Kontrol listesi

- [ ] Apple Developer aktif
- [ ] Bundle ID + App Store Connect app oluşturuldu
- [ ] API Key (.p8) Codemagic’e `engelsizclub` adıyla eklendi
- [ ] GitHub’da `codemagic.yaml` var ve push edildi
- [ ] **iOS TestFlight** (`ios-testflight`) build yeşil
- [ ] Store listing dolduruldu → Submit for Review

GitHub Actions workflow (`.github/workflows/ios-testflight.yml`) yedek olarak duruyor; Codemagic kullanıyorsanız onu çalıştırmanız gerekmez.
