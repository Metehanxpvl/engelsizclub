# Google Play — Engelsiz Club yayın rehberi

## Paket kimliği
- **applicationId:** `com.sakircaykara.engelsizclub`
- **Uygulama adı:** Engelsiz Club

## In-app ürünler (Play Console → Monetize → Products → In-app products)

Hepsi **Consumable (tüketilebilir)** olmalı. Kimlikler uygulamayla birebir aynı:

| Product ID | Önerilen fiyat | Puan | İndirim |
|------------|----------------|------|---------|
| `point_1`  | ₺69,90         | 1    | —       |
| `point_5`  | ₺314,55        | 5    | %10     |
| `point_10` | ₺594,15        | 10   | %15     |
| `point_30` | ₺1.677,60      | 30   | %20     |
| `point_50` | ₺2.621,25      | 50   | %25     |
| `point_100`| ₺4.893,00      | 100  | %30     |

Birim fiyat: ₺69,90/puan. Paket fiyatı = adet × ₺69,90 × (1 − indirim).

Ödeme Google Play Billing ile alınır; onaylanınca uygulama bakiyeyi Supabase `user_profiles.kredi` alanına yazar.

## İmzalama (upload key)

1. `android/key.properties.example` dosyasını `android/key.properties` olarak kopyala.
2. Keystore üret (Android Studio JBR keytool):

```bat
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore android\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload -dname "CN=Engelsiz Club, O=Engelsiz Club, L=Istanbul, C=TR"
```

3. `key.properties` içine şifreleri yaz (`storeFile=upload-keystore.jks`).
4. **keystore + şifreyi yedekle** — kaybedersen Play güncellemesi zorlaşır.

## AAB üretimi

```bat
flutter build appbundle --release
```

Çıktı: `build/app/outputs/bundle/release/app-release.aab`

## Play Console adımları

1. Yeni uygulama oluştur → uygulama adı Engelsiz Club.
2. **App signing:** AAB yüklerken Play App Signing’i aç.
3. Ürünleri (`point_1` … `point_100`) oluştur, Active yap.
4. Test → Internal testing track’e AAB yükle, lisans test hesabı ekle.
5. Cihazda o hesapla giriş yapıp gerçek satın alma akışını dene.
6. Store listing: kısa/uzun açıklama, ikon 512, feature graphic 1024x500, ekran görüntüleri.
7. Content rating, Privacy policy (engelsizclub.com), Data safety formu.

## Firebase (Android)

Paket: `com.sakircaykara.engelsizclub`  
Firebase App ID: `1:59695056324:android:4e3e2858da075b865b9091`

`google-services.json` → `android/app/` (gitignore’da; yerelde tut).

### Codemagic (CI)

Dosyayı Git’e koyma. Codemagic → Application → **Environment variables**:

1. Grup: `firebase_credentials` (Secret işaretli)
2. Değişken: `ANDROID_FIREBASE_SECRET` = `google-services.json` içeriği (ham JSON veya base64)
3. (iOS için) `IOS_FIREBASE_SECRET` = `GoogleService-Info.plist` içeriği

`codemagic.yaml` build başlamadan önce dosyayı `android/app/google-services.json` olarak yazar.

### Google Sign-In SHA-1 (zorunlu)

Play’den indirilen uygulamada Google giriş için **Play App Signing** SHA-1 şart:

1. Play Console → Uygulama → **Setup / Ayarlar** → **App integrity / Uygulama bütünlüğü** → **App signing**
2. **App signing key certificate** altındaki **SHA-1** değerini kopyala
3. Firebase Console → Project settings → Android app → **Add fingerprint** → yapıştır

Upload key SHA-1 (yerel AAB imzalama; zaten eklendi):
`1D:B8:0C:6C:2E:19:DC:22:21:36:E5:5E:02:E4:94:12:80:12:D6:FF`

```bat
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore android\upload-keystore.jks -alias upload
```

SHA ekledikten sonra birkaç dakika bekleyip uygulamayı yeniden dene. Yeni AAB şart değil; sadece Firebase’e Play SHA-1 eklemek çoğu zaman yeterli.

## Supabase

Dashboard → SQL Editor → `supabase/play_ready.sql` çalıştır.
Site URL / Redirect: `https://engelsizclub.com` ve deep link `io.supabase.engelsizclub://login-callback`.

Supabase → Authentication → URL Configuration → Redirect URLs listesine ekle:
- `io.supabase.engelsizclub://login-callback`
- `https://engelsizclub.com/**`
