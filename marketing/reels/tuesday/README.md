# Salı Reels — Ana Sayfa ve Bilgi Kütüphanesi

## Çıktılar

- `engelsizclub-sali-reel-20s.mp4` — 1080×1920, 20 saniye, Türkçe ses
- `engelsizclub-sali-reel-cover.png` — Reels kapak görseli
- `engelsizclub-sali-reel.srt` — isteğe bağlı altyazı dosyası
- `caption.md` — Instagram paylaşım metni

## Sahne akışı

1. Engelsiz Club logo açılışı
2. Ana sayfa ve bilimsel arama
3. Güncel duyurular
4. Bilgi Kütüphanesi kartları
5. `engelsizclub.com` çağrısı

## Yeniden üretme

```bash
pip install edge-tts pillow
python3 marketing/reels/tuesday/build_tuesday_reel.py
```

Canlı uygulama ekranlarını yeniden yakalamak için:

```bash
npm install --prefix /tmp/reel-tools puppeteer-core
node marketing/reels/tuesday/capture_app_screens.mjs
```
