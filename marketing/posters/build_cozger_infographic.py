#!/usr/bin/env python3
"""Engelsiz Club — ChatGPT tarzı renkli ÇÖZGER infografik afiş."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
FAMILY = Path("/opt/cursor/artifacts/assets/cozger-family-illustration.png")

# Tall colorful infographic (share + print friendly)
W, H = 1400, 4200

# Palette inspired by the reference poster
WHITE = (255, 255, 255)
INK = (35, 40, 55)
MUTED = (70, 78, 95)
HEADER_BG = (232, 245, 255)
BLUE = (66, 133, 244)
BLUE_SOFT = (210, 230, 255)
GREEN = (46, 160, 110)
GREEN_SOFT = (210, 242, 225)
PINK = (232, 96, 140)
PINK_SOFT = (255, 220, 232)
PURPLE = (126, 98, 214)
PURPLE_SOFT = (232, 224, 255)
ORANGE = (245, 150, 55)
ORANGE_SOFT = (255, 232, 205)
TEAL = (40, 170, 175)
TEAL_SOFT = (210, 242, 244)
YELLOW = (250, 200, 60)
YELLOW_SOFT = (255, 244, 200)
BRAND = (26, 107, 74)
GOLD = (244, 168, 50)

FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words = text.split()
    lines, cur = [], ""
    for w in words:
        trial = f"{cur} {w}".strip()
        if draw.textlength(trial, font=fnt) <= max_w:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def draw_text(draw, text, x, y, fnt, fill, max_w, gap=1.28) -> int:
    lines = wrap(draw, text, fnt, max_w)
    lh = int(fnt.size * gap)
    for i, line in enumerate(lines):
        draw.text((x, y + i * lh), line, font=fnt, fill=fill)
    return y + max(1, len(lines)) * lh


def round_rect(base: Image.Image, box, radius, fill, shadow=True):
    x0, y0, x1, y1 = [int(v) for v in box]
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    if shadow:
        d.rounded_rectangle([x0 + 3, y0 + 6, x1 + 3, y1 + 8], radius=radius, fill=(20, 25, 40, 35))
        layer = layer.filter(ImageFilter.GaussianBlur(8))
        base.alpha_composite(layer)
        layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(layer)
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=fill)
    base.alpha_composite(layer)


def header_badge(draw, text, x, y, bg, fg=WHITE):
    fnt = font(22, True)
    tw = draw.textlength(text, font=fnt)
    pad_x, pad_y = 16, 8
    draw.rounded_rectangle([x, y, x + tw + pad_x * 2, y + fnt.size + pad_y * 2], radius=18, fill=bg)
    draw.text((x + pad_x, y + pad_y), text, font=fnt, fill=fg)
    return int(y + fnt.size + pad_y * 2)


def section_box(base, y, height, title, color, soft, content_fn) -> int:
    margin = 48
    round_rect(base, [margin, y, W - margin, y + height], 28, soft, shadow=True)
    # left accent bar
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([margin, y, margin + 18, y + height], radius=10, fill=color)
    # title chip
    title_y = y + 22
    fnt = font(28, True)
    tw = d.textlength(title, font=fnt)
    d.rounded_rectangle([margin + 40, title_y, margin + 60 + tw, title_y + 48], radius=16, fill=color)
    d.text((margin + 50, title_y + 8), title, font=fnt, fill=WHITE)
    content_fn(d, margin + 40, title_y + 70)
    return y + height + 28


def paste_logo(base, size=78, xy=(52, 42)):
    if not ICON.exists():
        return
    logo = Image.open(ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    cleaned = []
    for r, g, b, a in logo.getdata():
        cleaned.append((r, g, b, 0) if r > 245 and g > 245 and b > 245 else (r, g, b, a))
    logo.putdata(cleaned)
    # white circle behind
    circ = Image.new("RGBA", (size + 16, size + 16), (0, 0, 0, 0))
    ImageDraw.Draw(circ).ellipse([0, 0, size + 15, size + 15], fill=WHITE)
    base.paste(circ, (xy[0] - 8, xy[1] - 8), circ)
    base.paste(logo, xy, logo)


def paste_family(base, box):
    x0, y0, x1, y1 = box
    bw, bh = x1 - x0, y1 - y0
    if FAMILY.exists():
        fam = Image.open(FAMILY).convert("RGBA")
        # remove near-white bg lightly
        fam = ImageOps.contain(fam, (bw, bh), Image.Resampling.LANCZOS)
        px = x0 + (bw - fam.width) // 2
        py = y0 + (bh - fam.height) // 2
        base.paste(fam, (px, py), fam)
    else:
        d = ImageDraw.Draw(base)
        d.ellipse([x0 + 40, y0 + 40, x1 - 40, y1 - 40], fill=(255, 220, 200))


def build() -> Image.Image:
    # soft paper background with dots
    img = Image.new("RGB", (W, H), (248, 250, 252))
    px = img.load()
    for y in range(H):
        for x in range(0, W, 28):
            if (x // 28 + y // 28) % 2 == 0 and y % 28 < 2:
                if x < W and y < H:
                    px[x, y] = (235, 240, 246)
    base = img.convert("RGBA")
    d = ImageDraw.Draw(base)

    # ===== HEADER =====
    round_rect(base, [0, 0, W, 520], 0, HEADER_BG, shadow=False)
    # decorative blobs
    d = ImageDraw.Draw(base)
    d.ellipse([-80, -60, 220, 180], fill=(190, 220, 255, 120))
    d.ellipse([1100, 40, 1500, 360], fill=(255, 210, 230, 100))
    d.ellipse([500, 380, 760, 560], fill=(210, 245, 220, 90))

    paste_logo(base, 72, (56, 36))
    d.text((150, 48), "Engelsiz Club", font=font(34, True), fill=BRAND)
    d.text((150, 92), "Aile bilgilendirme afişi", font=font(20), fill=MUTED)

    # speech bubble
    bubble = [56, 150, 620, 230]
    round_rect(base, bubble, 22, WHITE, shadow=True)
    d = ImageDraw.Draw(base)
    d.polygon([(120, 230), (150, 230), (135, 255)], fill=WHITE)
    d.text((78, 170), "Doğru bilgi · sağlıklı adım · mutlu gelecek!", font=font(22, True), fill=PINK)

    d.text((56, 280), "ÇOCUKLAR İÇİN ÖZEL", font=font(42, True), fill=INK)
    d.text((56, 335), "GEREKSİNİM RAPORU", font=font(42, True), fill=BLUE)
    d.text((56, 395), "(ÇÖZGER)", font=font(36, True), fill=GREEN)
    draw_text(
        d,
        "Çocuklarımızın daha iyi bir gelecek için haklarını öğrenelim!",
        56,
        450,
        font(24, True),
        MUTED,
        700,
    )

    paste_family(base, [780, 120, 1340, 500])

    y = 560

    # ===== NEDİR =====
    def nedir(dd, x, yy):
        draw_text(
            dd,
            "ÇÖZGER; 18 yaşından küçük çocukların özel gereksinim durumunu belirlemek ve sosyal / ekonomik haklardan yararlanmasını sağlamak için düzenlenen resmi belgedir. Eski “Sağlık Kurulu Raporu”nun 18 yaş altı çocuklar için yerine geçen sistemidir (20 Şubat 2019 yönetmeliği).",
            x,
            yy,
            font(23),
            INK,
            W - 160,
            1.35,
        )

    y = section_box(base, y, 230, "ÇÖZGER NEDİR?", BLUE, BLUE_SOFT, nedir)

    # ===== NASIL BAŞVURULUR =====
    def basvuru(dd, x, yy):
        draw_text(dd, "Randevuyu şu kanallardan alabilirsiniz:", x, yy, font(23, True), INK, W - 160)
        yy += 42
        for label, detail in [
            ("ALO 182", "Telefonla “18 yaş altı sağlık kurulu / ÇÖZGER polikliniği” randevusu isteyin."),
            ("MHRS", "mhrs.gov.tr veya MHRS uygulamasından aynı birime randevu oluşturun."),
        ]:
            dd.rounded_rectangle([x, yy, x + 130, yy + 40], radius=14, fill=GREEN)
            dd.text((x + 18, yy + 8), label, font=font(20, True), fill=WHITE)
            draw_text(dd, detail, x + 148, yy + 6, font(21), INK, W - 280)
            yy += 56
        draw_text(
            dd,
            "Not: Bazı hastanelerde takip eden hekimin yönlendirmesi süreci hızlandırabilir.",
            x,
            yy,
            font(20),
            MUTED,
            W - 160,
        )

    y = section_box(base, y, 280, "NASIL BAŞVURULUR?", GREEN, GREEN_SOFT, basvuru)

    # ===== ÖNEMLİ =====
    def onemli(dd, x, yy):
        items = [
            "Randevusuz işlem yapılmaz; mutlaka randevu alın.",
            "Başvuruyu ebeveyn, vasi veya koruma altındaysa yetkili kamu görevlisi yapar.",
            "Hasta (15+) ve refakatçi için fotoğraflı kimlik belgesi gerekir.",
            "Daha önce konmuş tanılar için tıbbi evrak / e-Nabız çıktılarını götürün.",
        ]
        for i, t in enumerate(items, 1):
            dd.ellipse([x, yy + 2, x + 34, yy + 36], fill=PINK)
            tw = dd.textlength(str(i), font=font(18, True))
            dd.text((x + (34 - tw) / 2, yy + 6), str(i), font=font(18, True), fill=WHITE)
            yy = draw_text(dd, t, x + 48, yy + 4, font(22), INK, W - 210) + 14

    y = section_box(base, y, 290, "ÖNEMLİ!", PINK, PINK_SOFT, onemli)

    # ===== DEĞERLENDİRME =====
    def degerlendirme(dd, x, yy):
        draw_text(
            dd,
            "Değerlendirme; işlevsellik, engellilik ve sağlığın uluslararası sınıflandırması (ICF) yaklaşımına dayanır. En az 4 branş hekiminin katılımı esastır.",
            x,
            yy,
            font(22),
            INK,
            W - 160,
            1.35,
        )
        yy += 100
        branches = [
            "Çocuk Sağlığı",
            "Çocuk Psikiyatrisi",
            "Nöroloji",
            "Göz",
            "KBB",
            "Çocuk Cerrahisi",
            "FTR",
            "Ortopedi",
        ]
        cx, cy = x, yy
        for b in branches:
            fnt = font(18, True)
            tw = dd.textlength(b, font=fnt)
            bw = tw + 28
            if cx + bw > W - 80:
                cx = x
                cy += 48
            dd.rounded_rectangle([cx, cy, cx + bw, cy + 38], radius=14, fill=PURPLE)
            dd.text((cx + 14, cy + 8), b, font=fnt, fill=WHITE)
            cx += bw + 12

    y = section_box(base, y, 320, "DEĞERLENDİRME NASIL YAPILIR?", PURPLE, PURPLE_SOFT, degerlendirme)

    # ===== DÜZEYLER =====
    def duzeyler(dd, x, yy):
        draw_text(
            dd,
            "Raporda klasik “engel oranı” yerine özel gereksinim düzeyi esas alınır. Aşağıdaki aralıklar haklar için pratik eşleştirmede sık kullanılır:",
            x,
            yy,
            font(21),
            INK,
            W - 160,
            1.32,
        )
        yy += 95
        levels = [
            ("1", "Özel gereksinim var", "≈ %20–39"),
            ("2", "Hafif düzeyde ÖG", "≈ %40–49"),
            ("3", "Orta düzeyde ÖG", "≈ %50–59"),
            ("4", "İleri düzeyde ÖG", "≈ %60–69"),
            ("5", "Çok ileri düzeyde ÖG", "≈ %70–79"),
            ("6", "Belirgin ÖG", "≈ %80–89"),
            ("7", "Özel koşul gereksinimi", "≈ %90–99"),
        ]
        for num, name, rate in levels:
            dd.rounded_rectangle([x, yy, W - 80, yy + 48], radius=14, fill=WHITE)
            dd.ellipse([x + 10, yy + 8, x + 44, yy + 42], fill=ORANGE)
            tw = dd.textlength(num, font=font(18, True))
            dd.text((x + 10 + (34 - tw) / 2, yy + 12), num, font=font(18, True), fill=WHITE)
            dd.text((x + 58, yy + 12), name, font=font(21, True), fill=INK)
            rw = dd.textlength(rate, font=font(20, True))
            dd.text((W - 90 - rw, yy + 12), rate, font=font(20, True), fill=ORANGE)
            yy += 56
        draw_text(
            dd,
            "Not: 5–6–7. düzeyler uygulamada sıklıkla “ağır engelli” kapsamında değerlendirilen durumlarla ilişkilendirilir; kurum uygulamaları değişebilir.",
            x,
            yy + 4,
            font(19),
            MUTED,
            W - 160,
            1.3,
        )

    y = section_box(base, y, 620, "GEREKSİNİM DÜZEYLERİ", ORANGE, ORANGE_SOFT, duzeyler)

    # ===== BELGELER =====
    def belgeler(dd, x, yy):
        docs = [
            "Hasta kimlik belgesi (15 yaş ve üzeri için fotoğraflı)",
            "Refakatçi / veli-vasi kimlik belgesi",
            "Varsa önceki raporlar, epikriz, tetkik ve e-Nabız çıktıları",
            "Başvuru dilekçesi / hastanenin verdiği ÇÖZGER başvuru formu",
        ]
        for t in docs:
            dd.rounded_rectangle([x, yy, x + 34, yy + 34], radius=10, fill=TEAL)
            dd.text((x + 8, yy + 4), "✓", font=font(20, True), fill=WHITE)
            yy = draw_text(dd, t, x + 48, yy + 4, font(22), INK, W - 210) + 16

    y = section_box(base, y, 280, "RAPOR İÇİN GEREKLİ BELGELER", TEAL, TEAL_SOFT, belgeler)

    # ===== İŞLEM AKIŞI =====
    flow_h = 340
    round_rect(base, [48, y, W - 48, y + flow_h], 28, WHITE, shadow=True)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([48, y, 66, y + flow_h], radius=10, fill=BRAND)
    d.rounded_rectangle([88, y + 22, 520, y + 70], radius=16, fill=BRAND)
    d.text((104, y + 32), "RAPOR NASIL ALINIR? (İŞLEMLER)", font=font(26, True), fill=WHITE)

    steps = [
        ("1", "Randevu\n182 / MHRS"),
        ("2", "Kurula git\nform doldur"),
        ("3", "Uzman\nmuayeneleri"),
        ("4", "Evrak teslim\ntarih al"),
        ("5", "Raporu\nteslim al"),
    ]
    box_w = 210
    gap = 18
    start_x = 88
    sy = y + 110
    for i, (num, label) in enumerate(steps):
        sx = start_x + i * (box_w + gap)
        d.rounded_rectangle([sx, sy, sx + box_w, sy + 170], radius=20, fill=HEADER_BG)
        d.ellipse([sx + 78, sy + 16, sx + 130, sy + 68], fill=GOLD)
        tw = d.textlength(num, font=font(24, True))
        d.text((sx + 78 + (52 - tw) / 2, sy + 26), num, font=font(24, True), fill=INK)
        # multiline label
        for li, line in enumerate(label.split("\n")):
            lw = d.textlength(line, font=font(20, True))
            d.text((sx + (box_w - lw) / 2, sy + 90 + li * 28), line, font=font(20, True), fill=INK)
        if i < len(steps) - 1:
            ax = sx + box_w + 2
            d.polygon([(ax, sy + 80), (ax + 14, sy + 90), (ax, sy + 100)], fill=GOLD)
    y += flow_h + 28

    # ===== SÜRE =====
    def sure(dd, x, yy):
        bullets = [
            "Rapor süresi; rapordaki “sürekli / süreli” durumuna göre değişir.",
            "Teslim: başvurudan itibaren en geç 30 gün içinde tamamlanır.",
            "18 yaşını doldurunca ÇÖZGER geçersiz olur; erişkin engelli sağlık kurulu sürecine geçilir.",
            "Sonuca itiraz: tebliğden itibaren 30 gün içinde İl Sağlık Müdürlüğü’ne yapılabilir.",
            "e-Devlet üzerinden rapor görüntülenebilir.",
        ]
        for t in bullets:
            dd.ellipse([x + 4, yy + 10, x + 18, yy + 24], fill=YELLOW)
            yy = draw_text(dd, t, x + 30, yy, font(22), INK, W - 190) + 12

    y = section_box(base, y, 320, "RAPOR SÜRESİ VE TESLİM", YELLOW, YELLOW_SOFT, sure)

    # ===== HAKLAR =====
    def haklar(dd, x, yy):
        rights = [
            "Evde bakım aylığı başvurusu",
            "ÖTV muafiyetli araç (şartlara bağlı)",
            "Eğitim hakkı / RAM ve özel eğitim",
            "Devlet destekli özel eğitim ücreti",
            "Şehir içi ulaşım indirimi / ücretsiz",
            "Elektrik, su, doğalgaz indirimleri",
            "Telefon / internet indirimleri",
            "Vergi indirimi ve ilgili muafiyetler",
        ]
        col_w = (W - 160) // 2
        for i, r in enumerate(rights):
            cx = x + (i % 2) * col_w
            cy = yy + (i // 2) * 52
            dd.rounded_rectangle([cx, cy, cx + col_w - 16, cy + 44], radius=14, fill=WHITE)
            dd.text((cx + 14, cy + 10), "★  " + r, font=font(19, True), fill=PINK)

    y = section_box(base, y, 320, "BU RAPORLA HANGİ HAKLARDAN YARARLANILIR?", PINK, PINK_SOFT, haklar)

    # ===== KAPANIŞ =====
    round_rect(base, [48, y, W - 48, y + 180], 28, BLUE_SOFT, shadow=True)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle([48, y, 66, y + 180], radius=10, fill=BLUE)
    d.text((88, y + 28), "DAHA İYİ BİR GELECEK İÇİN", font=font(28, True), fill=BLUE)
    draw_text(
        d,
        "ÇÖZGER; çocuğunuzun haklarını güvence altına almanın ve fırsat eşitliğini güçlendirmenin önemli bir adımıdır. Bilgiyle güçlenin, çocuğunuzun yanında olun.",
        88,
        y + 78,
        font(22),
        INK,
        W - 180,
        1.35,
    )
    y += 210

    # Footer
    d.rounded_rectangle([0, H - 140, W, H], fill=BRAND)
    paste_logo(base, 64, (56, H - 112))
    d = ImageDraw.Draw(base)
    d.text((140, H - 110), "Engelsiz Club", font=font(30, True), fill=WHITE)
    d.text((140, H - 72), "Bilgiyle güçlenin, çocuğunuzun yanında olun!", font=font(22), fill=(220, 238, 228))
    d.text((140, H - 42), "engelsizclub.com  ·  Bilgilendirme amaçlıdır; güncel işlem için yetkili kurum esas alınır.", font=font(16), fill=(190, 220, 205))

    return base.convert("RGB")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    path = OUT / "cozger-infografik-renkli.png"
    poster.save(path, "PNG", optimize=True)
    print("wrote", path, poster.size)

    # Also make a slightly compressed social share copy
    art = Path("/opt/cursor/artifacts/assets")
    art.mkdir(parents=True, exist_ok=True)
    poster.save(art / "cozger-infografik-renkli.png", "PNG")
    # mid preview for QA
    preview = poster.resize((700, int(700 * H / W)), Image.Resampling.LANCZOS)
    preview.save(OUT / "cozger-infografik-preview.png", "PNG")
    preview.save(art / "cozger-infografik-preview.png", "PNG")


if __name__ == "__main__":
    main()
