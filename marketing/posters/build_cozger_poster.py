#!/usr/bin/env python3
"""Engelsiz Club — ÇÖZGER bilgilendirme afişi."""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"

# Print-friendly A4 @ ~200dpi-ish vertical social/print hybrid
W, H = 1240, 2200

BG = (242, 247, 244)
FG = (13, 43, 31)
GREEN = (26, 107, 74)
GREEN_DARK = (18, 74, 52)
MUTED = (77, 122, 98)
GOLD = (244, 168, 50)
WHITE = (255, 255, 255)
CARD = (255, 255, 255)
SOFT = (220, 238, 228)

FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"


def f(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def gradient() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        # soft mint wash + slight green header band feel at top
        r = int(242 - 12 * t)
        g = int(247 - 6 * t)
        b = int(244 - 16 * t)
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            edge = abs(dx) * 6
            px[x, y] = (
                max(0, min(255, int(r - edge))),
                max(0, min(255, int(g - edge * 0.4))),
                max(0, min(255, int(b - edge * 0.2))),
            )
    return img


def wrap(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words = text.split()
    lines, cur = [], ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textlength(trial, font=font) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def text_block(draw, text, x, y, font, fill, max_w, line_gap=1.32) -> int:
    lines = wrap(draw, text, font, max_w)
    lh = int(font.size * line_gap)
    for i, line in enumerate(lines):
        draw.text((x, y + i * lh), line, font=font, fill=fill)
    return y + len(lines) * lh


def rounded_card(base: Image.Image, box, radius=28, fill=CARD, shadow=True):
    x0, y0, x1, y1 = box
    if shadow:
        sh = Image.new("RGBA", base.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(sh)
        sd.rounded_rectangle([x0 + 4, y0 + 8, x1 + 4, y1 + 10], radius=radius, fill=(13, 43, 31, 28))
        sh = sh.filter(ImageFilter.GaussianBlur(10))
        base.alpha_composite(sh)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle(box, radius=radius, fill=fill)


def pill(draw, text, x, y, font, bg=GREEN, fg=WHITE, pad_x=18, pad_y=10):
    tw = draw.textlength(text, font=font)
    box = [x, y, x + tw + pad_x * 2, y + font.size + pad_y * 2]
    draw.rounded_rectangle(box, radius=22, fill=bg)
    draw.text((x + pad_x, y + pad_y), text, font=font, fill=fg)
    return int(box[3])


def paste_logo(base: Image.Image, size=110, xy=(56, 48)):
    logo = Image.open(ICON).convert("RGBA")
    logo = logo.resize((size, size), Image.Resampling.LANCZOS)
    cleaned = []
    for r, g, b, a in logo.getdata():
        cleaned.append((r, g, b, 0) if r > 245 and g > 245 and b > 245 else (r, g, b, a))
    logo.putdata(cleaned)
    base.paste(logo, xy, logo)


def section_title(draw, text, x, y):
    # gold accent bar
    draw.rounded_rectangle([x, y + 8, x + 14, y + 42], radius=4, fill=GOLD)
    draw.text((x + 28, y), text, font=f(34, True), fill=GREEN_DARK)
    return y + 56


def build() -> Image.Image:
    base = gradient().convert("RGBA")
    draw = ImageDraw.Draw(base)

    # Top brand bar
    draw.rounded_rectangle([0, 0, W, 190], radius=0, fill=GREEN)
    # soft wave under header
    for i in range(40):
        a = int(40 - i)
        draw.ellipse([-80, 150 + i, W + 80, 230 + i], fill=(26, 107, 74, max(0, a)))

    paste_logo(base, 96, (48, 42))
    draw.text((168, 52), "Engelsiz Club", font=f(40, True), fill=WHITE)
    draw.text((168, 104), "Aileler için bilgilendirme afişi", font=f(22), fill=(220, 238, 228))

    y = 220
    # Hero title card
    rounded_card(base, [40, y, W - 40, y + 210], radius=32, fill=WHITE)
    draw = ImageDraw.Draw(base)
    draw.text((72, y + 28), "ÇÖZGER Raporu", font=f(52, True), fill=FG)
    draw.text((72, y + 96), "Çocuklar İçin Özel Gereksinim Raporu", font=f(28, True), fill=GREEN)
    y = text_block(
        draw,
        "0–18 yaş çocukların özel gereksinim düzeyini belirleyen resmi sağlık kurulu belgesidir. Engel oranı yerine gereksinim düzeyi yazar.",
        72,
        y + 138,
        f(22),
        MUTED,
        W - 160,
    )

    y = 460
    # Nedir
    rounded_card(base, [40, y, W - 40, y + 260], radius=28)
    draw = ImageDraw.Draw(base)
    y = section_title(draw, "Nedir?", 72, y + 28)
    y = text_block(
        draw,
        "20 Şubat 2019 yönetmeliğiyle 18 yaş altı çocuklar için eski engelli sağlık raporu yerine gelir. Amaç; çocuğun sağlık, eğitim, rehabilitasyon ve sosyal-ekonomik haklara erişimini sağlamaktır. Raporda “engelli / ağır engelli” gibi damgalayıcı ifadeler yerine özel gereksinim seviyeleri kullanılır.",
        72,
        y,
        f(23),
        FG,
        W - 160,
        1.38,
    )

    y = 760
    # Ne işe yarar
    rounded_card(base, [40, y, W - 40, y + 430], radius=28)
    draw = ImageDraw.Draw(base)
    y = section_title(draw, "Ne işe yarar?", 72, y + 28)
    benefits = [
        ("Özel eğitim & rehabilitasyon", "RAM değerlendirmesi ve özel eğitim / rehabilitasyon hizmetleri"),
        ("Sosyal & ekonomik destekler", "Engelli aylığı, bakım aylığı ve ilgili sosyal yardımlar"),
        ("Sağlık hizmetleri", "Cihaz, ortez-protez, tedavi ve takip süreçlerinde dayanak"),
        ("Ulaşım & kamu kolaylıkları", "İndirim / muafiyet ve diğer yasal hak başvurularında belge"),
        ("Kurum başvuruları", "Okul, belediye, SGK ve sosyal hizmet süreçlerinde resmi kanıt"),
    ]
    yy = y
    for title, sub in benefits:
        draw.ellipse([76, yy + 8, 96, yy + 28], fill=GOLD)
        draw.text((112, yy), title, font=f(24, True), fill=GREEN_DARK)
        yy = text_block(draw, sub, 112, yy + 34, f(20), MUTED, W - 200) + 14

    y = 1230
    # Nasıl alınır
    rounded_card(base, [40, y, W - 40, y + 520], radius=28)
    draw = ImageDraw.Draw(base)
    y = section_title(draw, "Nasıl alınır? (Adım adım)", 72, y + 28)
    steps = [
        ("1", "Randevu al", "MHRS (mhrs.gov.tr / uygulama) veya ALO 182 ile “ÇÖZGER / 18 yaş altı sağlık kurulu” randevusu oluşturun."),
        ("2", "Belgeleri hazırla", "Çocuk kimliği, veli/vasi kimliği, varsa önceki raporlar, epikriz, tetkik ve takip belgelerini yanınıza alın."),
        ("3", "Hastaneye başvurun", "ÇÖZGER vermeye yetkili devlet / üniversite hastanesinin sağlık kurulu birimine dilekçe ile başvurun; kullanım amacını formda belirtin."),
        ("4", "Uzman değerlendirmesi", "İlgili branşlar (çocuk sağlığı, çocuk psikiyatrisi, nöroloji, göz, KBB, FTR vb.) çocuğu değerlendirir; gerekirse konsültasyon istenir."),
        ("5", "Kurul kararı & teslim", "Sağlık kurulu raporu tamamlar. Başvurudan itibaren en geç 30 gün içinde sonuçlanır; e-Devlet’ten de görüntülenebilir."),
    ]
    yy = y
    for num, title, desc in steps:
        # number circle
        draw.ellipse([72, yy, 118, yy + 46], fill=GREEN)
        tw = draw.textlength(num, font=f(22, True))
        draw.text((72 + (46 - tw) / 2, yy + 8), num, font=f(22, True), fill=WHITE)
        draw.text((136, yy + 6), title, font=f(24, True), fill=FG)
        yy = text_block(draw, desc, 136, yy + 40, f(20), MUTED, W - 220) + 16

    y = 1790
    # Önemli notlar - two columns-ish stacked
    rounded_card(base, [40, y, W - 40, y + 280], radius=28, fill=SOFT)
    draw = ImageDraw.Draw(base)
    y = section_title(draw, "Önemli notlar", 72, y + 24)
    notes = [
        "• Rapor süreli veya sürekli olabilir; süresi bitmeden yenileyin.",
        "• 18 yaşını doldurunca ÇÖZGER geçerliliğini yitirir; erişkin engelli sağlık kurulu sürecine geçilir.",
        "• Sonuca itiraz: tebliğden itibaren 30 gün içinde İl Sağlık Müdürlüğü’ne yapılabilir.",
        "• Haklar rapordaki özel gereksinim düzeyine ve ilgili kurum kurallarına göre değişir.",
        "• Bu afiş bilgilendirme amaçlıdır; güncel işlem için yetkili hastane / kurum esas alınmalıdır.",
    ]
    yy = y
    for n in notes:
        yy = text_block(draw, n, 72, yy, f(20), FG, W - 160, 1.35) + 6

    # Footer
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle([0, H - 90, W, H], fill=GREEN)
    draw.text((56, H - 62), "Engelsiz Club  ·  engelsizclub.com", font=f(22, True), fill=WHITE)
    draw.text((56, H - 36), "Doğru bilgi, doğru destek", font=f(18), fill=(220, 238, 228))

    return base.convert("RGB")


def build_story_summary() -> Image.Image:
    """Shorter 9:16 shareable summary poster."""
    w, h = 1080, 1920
    img = Image.new("RGB", (w, h), BG)
    px = img.load()
    for y in range(h):
        t = y / (h - 1)
        for x in range(w):
            px[x, y] = (
                int(242 - 14 * t),
                int(247 - 8 * t),
                int(244 - 18 * t),
            )
    base = img.convert("RGBA")
    d = ImageDraw.Draw(base)
    d.rectangle([0, 0, w, 220], fill=GREEN)
    paste_logo(base, 88, (40, 56))
    d.text((150, 70), "Engelsiz Club", font=f(36, True), fill=WHITE)
    d.text((150, 120), "Bilgilendirme", font=f(22), fill=SOFT)

    d.text((56, 270), "ÇÖZGER", font=f(64, True), fill=FG)
    d.text((56, 350), "Çocuklar İçin Özel Gereksinim Raporu", font=f(26, True), fill=GREEN)
    y = text_block(
        d,
        "0–18 yaş çocukların özel gereksinim düzeyini belirleyen resmi belgedir. Özel eğitim, rehabilitasyon, sosyal destek ve birçok yasal hak için temel dayanak olur.",
        56,
        410,
        f(26),
        MUTED,
        w - 112,
        1.4,
    )

    # 3 cards
    cards = [
        ("Nedir?", "Engel oranı yerine özel gereksinim seviyesi yazar. Damgalayıcı ifadeler kaldırılmıştır."),
        ("Ne işe yarar?", "Özel eğitim, bakım/engelli aylığı, sağlık ve kurum başvurularında kullanılır."),
        ("Nasıl alınır?", "MHRS / 182 → yetkili hastane → uzmanlar → kurul → en geç 30 gün; e-Devlet’te görünür."),
    ]
    yy = 620
    for title, body in cards:
        rounded_card(base, [48, yy, w - 48, yy + 230], radius=28)
        d = ImageDraw.Draw(base)
        d.rounded_rectangle([72, yy + 36, 86, yy + 70], radius=4, fill=GOLD)
        d.text((104, yy + 30), title, font=f(32, True), fill=GREEN_DARK)
        text_block(d, body, 72, yy + 90, f(24), FG, w - 160, 1.38)
        yy += 260

    d = ImageDraw.Draw(base)
    d.rounded_rectangle([48, yy + 10, w - 48, yy + 160], radius=28, fill=GREEN)
    d.text((80, yy + 40), "Detaylı afiş için", font=f(24), fill=SOFT)
    d.text((80, yy + 80), "Engelsiz Club’ı inceleyin", font=f(34, True), fill=WHITE)

    d.rectangle([0, h - 70, w, h], fill=GREEN_DARK)
    d.text((56, h - 48), "engelsizclub.com", font=f(22, True), fill=WHITE)
    return base.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    poster_path = OUT / "cozger-bilgilendirme-afisi.png"
    poster.save(poster_path, "PNG", optimize=True)
    print("wrote", poster_path, poster.size)

    story = build_story_summary()
    story_path = OUT / "cozger-ozet-story.png"
    story.save(story_path, "PNG", optimize=True)
    print("wrote", story_path, story.size)

    # also copy to artifacts
    art = Path("/opt/cursor/artifacts/assets")
    art.mkdir(parents=True, exist_ok=True)
    poster.save(art / "cozger-bilgilendirme-afisi.png", "PNG")
    story.save(art / "cozger-ozet-story.png", "PNG")


if __name__ == "__main__":
    main()
