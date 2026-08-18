#!/usr/bin/env python3
"""Engelsiz Club — Engelli Aylığı 4:5 Instagram afişi."""

from __future__ import annotations

from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
ILLUSTRATION = OUT / "engelli-ayligi-illustration.png"

URL = "https://www.turkiye.gov.tr/aile-ve-sosyal-hizmetler-sosyal-yardim-basvuru-hizmeti"

W, H = 1080, 1350

NAVY = (18, 51, 76)
BLUE = (48, 123, 198)
BLUE_SOFT = (222, 239, 252)
GREEN = (40, 153, 100)
GREEN_SOFT = (221, 246, 230)
TEAL = (29, 151, 143)
TEAL_SOFT = (219, 245, 240)
PURPLE = (124, 92, 211)
PURPLE_SOFT = (235, 227, 255)
CORAL = (232, 93, 106)
CORAL_SOFT = (255, 229, 232)
YELLOW = (246, 184, 56)
YELLOW_SOFT = (255, 245, 211)
BRAND = (26, 107, 74)
WHITE = (255, 255, 255)
PAPER = (247, 250, 252)
TEXT = (31, 44, 57)
MUTED = (77, 92, 106)

FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def wrap(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textlength(trial, font=fnt) <= width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def text_block(
    draw: ImageDraw.ImageDraw,
    text: str,
    x: int,
    y: int,
    fnt: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    width: int,
    line_height: float = 1.23,
) -> int:
    lines = wrap(draw, text, fnt, width)
    step = int(fnt.size * line_height)
    for index, line in enumerate(lines):
        draw.text((x, y + index * step), line, font=fnt, fill=fill)
    return y + len(lines) * step


def card(
    base: Image.Image,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int],
    accent: tuple[int, int, int],
) -> None:
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle(
        (x0 + 2, y0 + 6, x1 + 2, y1 + 8),
        radius=24,
        fill=(17, 45, 66, 28),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(8))
    base.alpha_composite(shadow)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle(box, radius=24, fill=fill)
    draw.rounded_rectangle((x0, y0, x0 + 12, y1), radius=6, fill=accent)


def title_chip(
    draw: ImageDraw.ImageDraw,
    title: str,
    x: int,
    y: int,
    color: tuple[int, int, int],
) -> None:
    fnt = font(21, True)
    width = draw.textlength(title, font=fnt)
    draw.rounded_rectangle((x, y, x + width + 30, y + 40), radius=14, fill=color)
    draw.text((x + 15, y + 7), title, font=fnt, fill=WHITE)


def paste_logo(base: Image.Image, xy: tuple[int, int], size: int) -> None:
    logo = Image.open(ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    pixels = []
    for red, green, blue, alpha in logo.getdata():
        pixels.append(
            (red, green, blue, 0)
            if red > 245 and green > 245 and blue > 245
            else (red, green, blue, alpha)
        )
    logo.putdata(pixels)
    base.paste(logo, xy, logo)


def paste_illustration(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    if not ILLUSTRATION.exists():
        return
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    image = Image.open(ILLUSTRATION).convert("RGB")
    image = ImageOps.fit(
        image,
        (width, height),
        Image.Resampling.LANCZOS,
        centering=(0.5, 0.5),
    ).convert("RGBA")
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius=32,
        fill=255,
    )
    image.putalpha(mask)
    base.paste(image, (x0, y0), image)


def check_item(
    draw: ImageDraw.ImageDraw,
    text: str,
    x: int,
    y: int,
    width: int,
    color: tuple[int, int, int],
    size: int = 16,
) -> int:
    draw.rounded_rectangle((x, y + 2, x + 25, y + 27), radius=8, fill=color)
    draw.text((x + 5, y + 2), "✓", font=font(16, True), fill=WHITE)
    return text_block(draw, text, x + 36, y, font(size), TEXT, width - 36, 1.22) + 7


def numbered_step(
    draw: ImageDraw.ImageDraw,
    number: int,
    title: str,
    detail: str,
    x: int,
    y: int,
    width: int,
    color: tuple[int, int, int],
) -> int:
    draw.ellipse((x, y + 1, x + 34, y + 35), fill=color)
    number_text = str(number)
    number_width = draw.textlength(number_text, font=font(17, True))
    draw.text((x + (34 - number_width) / 2, y + 6), number_text, font=font(17, True), fill=WHITE)
    draw.text((x + 46, y), title, font=font(19, True), fill=NAVY)
    return text_block(draw, detail, x + 46, y + 25, font(15), MUTED, width - 46, 1.2) + 7


def amount_row(
    draw: ImageDraw.ImageDraw,
    label: str,
    amount: str,
    x: int,
    y: int,
    color: tuple[int, int, int],
) -> int:
    draw.rounded_rectangle((x, y, x + 332, y + 65), radius=18, fill=WHITE)
    draw.rounded_rectangle((x + 10, y + 10, x + 54, y + 55), radius=14, fill=color)
    draw.text((x + 22, y + 18), "₺", font=font(21, True), fill=WHITE)
    draw.text((x + 68, y + 9), label, font=font(15, True), fill=MUTED)
    draw.text((x + 68, y + 31), amount, font=font(23, True), fill=NAVY)
    return y + 75


def build() -> Image.Image:
    base = Image.new("RGB", (W, H), PAPER).convert("RGBA")
    draw = ImageDraw.Draw(base)

    # Header.
    draw.rectangle((0, 0, W, 285), fill=BLUE_SOFT)
    draw.ellipse((-180, 185, 720, 440), fill=(205, 234, 249))
    draw.ellipse((660, -120, 1240, 350), fill=(217, 246, 240))
    paste_logo(base, (38, 28), 64)
    draw.text((114, 34), "Engelsiz Club", font=font(29, True), fill=BRAND)
    draw.text((114, 72), "Haklarınızı bilin", font=font(17), fill=MUTED)
    paste_illustration(base, (655, 18, 1040, 275))

    draw.text((42, 129), "ENGELLİ", font=font(48, True), fill=NAVY)
    draw.text((42, 187), "AYLIĞI", font=font(52, True), fill=BLUE)
    draw.rounded_rectangle((310, 202, 625, 245), radius=16, fill=YELLOW)
    draw.text((330, 211), "2022 sayılı Kanun", font=font(19, True), fill=NAVY)

    # Definition.
    card(base, (30, 304, 1050, 431), BLUE_SOFT, BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NEDİR?", 54, 321, BLUE)
    text_block(
        draw,
        "Sosyal güvencesi olmayan, en az %40 engelli ve gelir şartını sağlayan vatandaşlara 2022 sayılı Kanun kapsamında aylık ödenen sosyal yardımdır. Evde Bakım Yardımından farklıdır.",
        54,
        371,
        font(17),
        TEXT,
        960,
        1.22,
    )

    # Conditions.
    card(base, (30, 451, 650, 823), (241, 248, 255), BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "KİMLER ALABİLİR?", 54, 470, BLUE)
    current_y = 526
    conditions = [
        "18 yaş üstü ve en az %40 engelli sağlık kurulu raporu olanlar",
        "Sosyal güvencesi bulunmayanlar",
        "Kurumsal bakım altında olmayanlar",
        "Hane kişi başı aylık geliri 2026 için 9.358,50 TL'den az olanlar",
    ]
    for condition in conditions:
        current_y = check_item(draw, condition, 54, current_y, 566, BLUE, 16)
    draw.rounded_rectangle((54, 705, 626, 793), radius=18, fill=WHITE)
    text_block(
        draw,
        "18 yaş altı için: en az “Hafif Düzeyde Özel Gereksinim” / %40 raporu olan çocuğun bakımını yapan yakına Engelli Yakını Aylığı bağlanabilir.",
        72,
        720,
        font(15, True),
        BLUE,
        536,
        1.18,
    )

    # Amounts.
    card(base, (670, 451, 1050, 823), GREEN_SOFT, GREEN)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "2026 GÜNCEL TUTARLAR", 694, 470, GREEN)
    current_y = 526
    current_y = amount_row(draw, "%40–69 engelli", "5.793,31 TL / ay", 694, current_y, BLUE)
    current_y = amount_row(draw, "%70 ve üzeri", "8.689,97 TL / ay", 694, current_y, GREEN)
    current_y = amount_row(draw, "Engelli yakını", "5.793,31 TL / ay", 694, current_y, PURPLE)
    text_block(
        draw,
        "Tutarlar memur aylık katsayısına göre dönemsel güncellenir.",
        704,
        756,
        font(14, True),
        MUTED,
        310,
        1.18,
    )

    # Application.
    card(base, (30, 843, 650, 1128), PURPLE_SOFT, PURPLE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NASIL BAŞVURULUR?", 54, 861, PURPLE)
    current_y = 916
    steps = [
        ("Başvuru yap", "e-Devlet Sosyal Yardım Başvurusu veya ikamet yerindeki SYDV."),
        ("Belgeleri sun", "Kimlik ve gerekiyorsa sağlık kurulu raporu / temsil belgesi."),
        ("İnceleme", "Hane gelir ve varlıkları sosyal incelemeyle değerlendirilir."),
        ("Heyet kararı", "Vakıf Mütevelli Heyeti başvuruyu sonuçlandırır."),
    ]
    for index, (title, detail) in enumerate(steps, start=1):
        current_y = numbered_step(draw, index, title, detail, 54, current_y, 566, PURPLE)

    # Documents / important notes.
    card(base, (670, 843, 1050, 1128), CORAL_SOFT, CORAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "GEREKENLER & NOTLAR", 694, 861, CORAL)
    current_y = 916
    notes = [
        "Kimlik belgesi",
        "Engelli sağlık kurulu raporu*",
        "Vasi / vekil başvuruyorsa temsil belgesi",
        "Gelir ve mal varlığı bilgilerinin doğrulanması",
        "Sonuç e-Devlet'ten takip edilebilir",
    ]
    for note in notes:
        current_y = check_item(draw, note, 694, current_y, 330, CORAL, 15)
    draw.rounded_rectangle((694, 1052, 1026, 1103), radius=16, fill=WHITE)
    text_block(
        draw,
        "*20.02.2020 sonrası raporlar sistemden alınabildiği için ayrıca istenmeyebilir.",
        708,
        1062,
        font(13, True),
        CORAL,
        304,
        1.16,
    )

    # QR/application strip.
    card(base, (30, 1148, 1050, 1258), YELLOW_SOFT, YELLOW)
    draw = ImageDraw.Draw(base)
    qr = qrcode.QRCode(version=4, box_size=4, border=1)
    qr.add_data(URL)
    qr.make(fit=True)
    qr_image = qr.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")
    qr_image = qr_image.resize((86, 86), Image.Resampling.NEAREST)
    base.paste(qr_image, (51, 1160))
    draw.text((157, 1166), "e-Devlet'ten başvuru", font=font(24, True), fill=NAVY)
    draw.text((157, 1202), "QR kodu tarat · Sosyal Yardım Başvuru Hizmeti", font=font(16), fill=MUTED)
    draw.text((780, 1166), "Başvuru yeri", font=font(15), fill=MUTED)
    draw.text((780, 1195), "SYDV", font=font(27, True), fill=GREEN)

    # Footer.
    draw.rectangle((0, 1280, W, H), fill=NAVY)
    draw.text(
        (35, 1296),
        "Kaynak: Aile ve Sosyal Hizmetler Bakanlığı · Sosyal Yardımlar Genel Müdürlüğü",
        font=font(13),
        fill=WHITE,
    )
    draw.text(
        (35, 1322),
        "Bilgilendirme amaçlıdır; güncel tutar ve Vakıf değerlendirmesi esastır.",
        font=font(12),
        fill=(194, 218, 234),
    )
    return base.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    output = OUT / "engelli-ayligi-instagram.png"
    poster.save(output, "PNG", optimize=True)
    print("wrote", output, poster.size)

    artifacts = Path("/opt/cursor/artifacts/assets")
    artifacts.mkdir(parents=True, exist_ok=True)
    poster.save(artifacts / output.name, "PNG")


if __name__ == "__main__":
    main()
