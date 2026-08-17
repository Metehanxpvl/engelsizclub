# Engelsiz Club — Pazarlama görselleri

Marka renkleri: yeşil `#1A6B4A`, koyu metin `#0D2B1F`, altın `#F4A832`, zemin `#F2F7F4`.

## Sosyal görseller (`social/`)

| Dosya | Format | Kullanım |
|-------|--------|----------|
| `engelsizclub-story-hero.png` | 9:16 | Instagram Story / Reels kapak |
| `engelsizclub-feed-post.png` | 1:1 | Instagram / Facebook feed |
| `engelsizclub-ad-cta.png` | 9:16 | Meta / TikTok reklam |
| `engelsizclub-youtube-thumb.png` | 16:9 | YouTube / yatay promo |
| `engelsizclub-play-feature.png` | 16:9 | Play Store feature graphic taslağı |

## Promo video (`promo/`)

| Dosya | Süre | Kullanım |
|-------|------|----------|
| `engelsizclub-promo-9x16.mp4` | ~20–25 sn | Ana tanıtım (6 sahne + TR ses) |
| `engelsizclub-intro-9x16.mp4` | ~8 sn | Story / Reels kısa kesit |
| `build_promo_video.py` | — | Yeniden üretmek için script |

Yeniden render:
```bash
python3 marketing/promo/build_promo_video.py
```

## Sonraki adımlar

1. Uygulama ekran görüntüleri eklenince walkthrough videosu
2. Gerçek ses kaydı ile TTS değişimi
3. 16:9 yatay kesim (YouTube / landing)
