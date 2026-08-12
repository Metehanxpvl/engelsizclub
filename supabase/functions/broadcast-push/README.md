# Broadcast Push (FCM Topics + kişisel)

## Deploy
```bash
# Firebase Console → Project settings → Cloud Messaging → Cloud Messaging API (Legacy) Server key
supabase secrets set FCM_SERVER_KEY="AAAA..."
supabase functions deploy broadcast-push
```

SQL (bir kez): `supabase/user_push_tokens.sql`

## Topics
| Topic | Tercih | Ne zaman |
|-------|--------|----------|
| `duyurular` | Duyurular | Admin duyuru |
| `ilanlar` | Yeni ilanlar | Yeni ilan |
| `forum` | Forum | Yeni gönderi |
| `mesajlar` | Mesajlar | Topic yayınları |

## Kişisel push (forum yanıtı vb.)
```json
{ "toEmail": "user@x.com", "title": "...", "body": "...", "prefKey": "forum", "data": {} }
```

Token’lar `user_push_tokens` tablosunda; edge function service role ile okuyup FCM gönderir.
