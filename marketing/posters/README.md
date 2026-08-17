# Bilgilendirme afişleri

## ÇÖZGER

| Dosya | Format | Kullanım |
|-------|--------|----------|
| `cozger-bilgilendirme-afisi.png` | 1240×2200 | Detaylı bilgilendirme (nedir, ne işe yarar, nasıl alınır, notlar) |
| `cozger-ozet-story.png` | 1080×1920 | Instagram Story / hızlı özet |
| `cozger-hero-visual.png` | görsel | Kapak / sosyal destek görseli |

Yeniden üretmek:
```bash
python3 marketing/posters/build_cozger_poster.py
```

Not: Afiş bilgilendirme amaçlıdır; resmi işlem için yetkili hastane / kurum esas alınmalıdır.

## ChatGPT tarzı renkli infografik

| Dosya | Boyut | Kullanım |
|-------|-------|----------|
| `cozger-infografik-renkli.png` | 1400×4200 | Tam detaylı renkli afiş (tüm bölümler) |
| `cozger-infografik-preview.png` | önizleme | Hızlı bakış |

Yeniden üretmek:
```bash
python3 marketing/posters/build_cozger_infographic.py
```
