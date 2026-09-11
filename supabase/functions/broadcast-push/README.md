# OS Push (FCM) — broadcast-push + notify-push

Service account JSON **Flutter uygulamasına konmaz**. Yalnızca Supabase Edge Function secret.

## Secrets (Dashboard → Edge Functions → Secrets veya CLI)

```bash
# Önerilen: Firebase Console → Project settings → Service accounts → Generate new private key
supabase secrets set FIREBASE_SERVICE_ACCOUNT_JSON="$(cat path/to/engelsizclub-e5842-*.json)"

# Yedek (eski Cloud Messaging API Legacy server key hâlâ varsa)
supabase secrets set FCM_SERVER_KEY="AAAA..."

# Database webhook / pg_net → notify-push kimliği (uzun rastgele dize)
supabase secrets set NOTIFY_PUSH_SECRET="uzun-rastgele-dize"

supabase functions deploy broadcast-push
supabase functions deploy notify-push --no-verify-jwt
```

`FCM_PROJECT_ID` isteğe bağlı; service account içindeki `project_id` (`engelsizclub-e5842`) kullanılır.

## SQL (Dashboard → SQL Editor → Run)

1. `supabase/user_push_tokens.sql` (yoksa)
2. `supabase/notify_push.sql` (push_dispatch + INSERT tetikleyici)

Vault secret (pg_net için, SQL içine service role yazmayın):

```sql
select vault.create_secret(
  'BURAYA_NOTIFY_PUSH_SECRET',
  'notify_push_secret'
);
```

**veya** Database Webhooks: tablo `bildirimler` INSERT →
`https://qycrkqwqrysypvqaipqn.supabase.co/functions/v1/notify-push`
Header: `Authorization: Bearer <NOTIFY_PUSH_SECRET>`

İkisini birden açmayın; `push_dispatch` yine de çift gönderimi keser.

## Topics (istemci `broadcast-push`)

| Topic | Tercih | Ne zaman |
|-------|--------|----------|
| `duyurular` | Duyurular | Admin duyuru |
| `ilanlar` | Yeni ilanlar | Yeni ilan |
| `forum` | Forum | Yeni gönderi |
| `mesajlar` | Mesajlar | Topic yayınları |

## Kişisel OS push (sunucu, `bildirimler` INSERT)

| type | event |
|------|--------|
| `forum_like` | COMMENT_LIKED |
| `forum_follow` | COMMENT_CREATED |
| `forum_comment` | POST_COMMENTED |
| `forum_reply` | REPLY_RECEIVED |
| `mesaj` | MESSAGE_RECEIVED |

Özel mesaj metni FCM gövdesine yazılmaz. Geçersiz FCM token’ları `user_push_tokens` tablosundan silinir.
