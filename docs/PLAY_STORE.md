# Google Play — Engelsiz Club yayın rehberi

## Paket kimliği
- **applicationId:** `com.engelsizclub.app`
- **Uygulama adı:** Engelsiz Club

## In-app ürünler (Play Console → Monetize → Products → In-app products)

Hepsi **Consumable (tüketilebilir)** olmalı. Kimlikler uygulamayla birebir aynı:

| Product ID | Önerilen fiyat | Puan |
|------------|----------------|------|
| `kredi_1`  | ₺49,90         | 1    |
| `kredi_5`  | ₺199,90        | 5    |
| `kredi_10` | ₺349,90        | 10   |

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
3. Ürünleri (`kredi_1` / `kredi_5` / `kredi_10`) oluştur, Active yap.
4. Test → Internal testing track’e AAB yükle, lisans test hesabı ekle.
5. Cihazda o hesapla giriş yapıp gerçek satın alma akışını dene.
6. Store listing: kısa/uzun açıklama, ikon 512, feature graphic 1024x500, ekran görüntüleri.
7. Content rating, Privacy policy (engelsizclub.com), Data safety formu.

## Firebase (Android)

`com.engelsizclub.app` için Firebase Console’da Android uygulaması ekle; `google-services.json` indirip `android/app/` altına koy (gitignore’da — commit etme). Google Sign-In için SHA-1:

```bat
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore android\upload-keystore.jks -alias upload
```

SHA-1’i Firebase Android uygulamasına ekle.

## Supabase

Dashboard → SQL Editor → `supabase/play_ready.sql` çalıştır.
Site URL / Redirect: `https://engelsizclub.com` ve deep link `io.supabase.engelsizclub://login-callback`.
