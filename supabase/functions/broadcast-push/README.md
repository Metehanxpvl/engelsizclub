# Broadcast Push (FCM Topics)

## Deploy
```bash
# Firebase Console → Project settings → Cloud Messaging → Cloud Messaging API (Legacy) Server key
supabase secrets set FCM_SERVER_KEY="AAAA..."
supabase functions deploy broadcast-push
```

## Topics (uygulama tercih anahtarları)
| Topic | Tercih | Ne zaman |
|-------|--------|----------|
| `duyurular` | Duyurular / Haberler | Admin duyuru ekleyince (görselli) |
| `ilanlar` | Yeni ilanlar | Yeni ilan yayınlanınca |
| `forum` | Forum paylaşımları | Yeni forum gönderisi |
| `mesajlar` | Mesajlar | (ileride) |

Kullanıcı profil → Bildirimler ile aç/kapa; cihaz FCM topic'e abone olur/çıkar.

## Görsel
Duyuru `image_url` **https** olmalı. Galeriden base64 (`data:`) yüklenirse push metin-only gider; görselli bildirim için URL kullanın veya R2'ye yükleyin.
