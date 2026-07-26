# Engelsiz Club — Web Deploy (Firebase + GoDaddy)

## Önkoşullar
- Google hesabı (Firebase)
- Node.js + npm
- Firebase CLI: `npm install -g firebase-tools`
- GoDaddy domain: `engelsizclub.com`
- Supabase proje erişimi

## 1) Build
```bash
flutter build web --release
```

## 2) Firebase login ve proje
```bash
firebase login
firebase projects:list
```

Eğer `engelsizclub` projesi yoksa:
1. https://console.firebase.google.com → **Add project** → adı `engelsizclub`
2. Hosting’i etkinleştir (veya ilk deploy otomatik açar)
3. `.firebaserc` içindeki proje ID’yi gerçek proje ID ile değiştir

```bash
firebase use engelsizclub
# veya
firebase use --add
```

## 3) Deploy
```bash
firebase deploy --only hosting
```

Geçici URL örneği: `https://engelsizclub.web.app`

## 4) Custom domain (Firebase Console)
1. Hosting → **Add custom domain**
2. `www.engelsizclub.com` ekle
3. Ardından `engelsizclub.com` ekle (apex → www yönlendirmesi önerilir)
4. Firebase’in verdiği DNS kayıtlarını not al

## 5) GoDaddy DNS
GoDaddy → Domainler → `engelsizclub.com` → DNS:

| Tip | Ad | Değer | Not |
|-----|-----|--------|-----|
| A | @ | Firebase’in verdiği IP’ler | apex |
| CNAME | www | Firebase’in verdiği host | örn. `engelsizclub.web.app` |
| TXT | @ veya Firebase’in istediği | doğrulama kaydı | ilk kurulumda |

DNS yayılımı birkaç dakika–birkaç saat sürebilir. SSL Firebase’de otomatik provision edilir.

## 6) Supabase Auth URL’leri
Supabase Dashboard → Authentication → URL Configuration:

- **Site URL:** `https://www.engelsizclub.com`
- **Redirect URLs:**
  - `https://www.engelsizclub.com/**`
  - `https://engelsizclub.com/**`
  - `io.supabase.engelsizclub://login-callback/`
  - (geliştirme için) `http://localhost:*/**`

## 7) Google ile giriş (zorunlu)
Supabase Dashboard → Authentication → Providers → **Google** → Enable:

### A) Google Cloud Console (Web client)
1. https://console.cloud.google.com/apis/credentials
2. **Create Credentials → OAuth client ID → Web application**
3. **Authorized JavaScript origins:**
   - `https://www.engelsizclub.com`
   - `https://engelsizclub-e5842.web.app`
   - `http://localhost` (geliştirme)
4. **Authorized redirect URIs** (tam olarak şu — app URL değil):
   ```
   https://qycrkqwqrysypvqaipqn.supabase.co/auth/v1/callback
   ```
5. Client ID + Client Secret’ı kopyala

### B) Supabase Google provider
1. Authentication → Providers → Google → **Enable**
2. Client ID / Client Secret’ı yapıştır (Web client’tan; Android client değil)
3. Save

### C) Supabase URL Configuration
Authentication → URL Configuration:
- **Site URL:** `https://www.engelsizclub.com`
- **Redirect URLs:**
  - `https://www.engelsizclub.com/**`
  - `https://engelsizclub.com/**`
  - `https://engelsizclub-e5842.web.app/**`
  - `http://localhost:*/**`
  - `io.supabase.engelsizclub://login-callback/`

### D) Hâlâ `unexpected_failure` / 500 alıyorsan
1. Supabase → Logs → Auth: hatanın gerçek metnini oku
2. Google provider’ı **Disable → Enable** yapıp Client ID/Secret’ı yeniden yapıştır
3. Client Secret’ın doğru ve Web tipinde olduğundan emin ol
4. Google hesabında e-posta izninin verildiğinden emin ol

Uygulama akışı: önce Aile / Uzman / Bakıcı seçilir → Google butonu görünür → seçilen rol hesaba yazılır.

## Başarı kontrolü
- [ ] `https://www.engelsizclub.com` açılıyor
- [ ] HTTPS geçerli
- [ ] Uygulama shell yükleniyor
- [ ] Kayıt / giriş çalışıyor
- [ ] Google ile giriş (rol seçimi sonrası) çalışıyor
