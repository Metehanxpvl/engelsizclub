#!/usr/bin/env python3
"""Engelsiz Club — Evde Bakım Yardımı 4:5 Instagram afişi."""

from __future__ import annotations

from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
ILLUSTRATION = OUT / "evde-bakim-yardimi-illustration.png"

URL = "https://www.turkiye.gov.tr/aile-ve-sosyal-hizmetler-bakim-ihtiyaci-olan-engellilerin-evde-bakim-taleplerinin-on-basvurusu"

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
        centering=(0.5, 0.52),
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


def build() -> Image.Image:
    base = Image.new("RGB", (W, H), PAPER).convert("RGBA")
    draw = ImageDraw.Draw(base)

    # Header.
    draw.rectangle((0, 0, W, 285), fill=GREEN_SOFT)
    draw.ellipse((-180, 185, 720, 440), fill=(207, 239, 225))
    draw.ellipse((660, -120, 1240, 350), fill=(218, 240, 250))
    paste_logo(base, (38, 28), 64)
    draw.text((114, 34), "Engelsiz Club", font=font(29, True), fill=BRAND)
    draw.text((114, 72), "Aileler için bilgi", font=font(17), fill=MUTED)
    paste_illustration(base, (665, 18, 1040, 275))

    draw.text((42, 126), "EVDE BAKIM", font=font(41, True), fill=NAVY)
    draw.text((42, 177), "YARDIMI", font=font(50, True), fill=GREEN)
    draw.rounded_rectangle((42, 236, 518, 272), radius=15, fill=YELLOW)
    draw.text((62, 243), "Halk arasında: bakım aylığı", font=font(18, True), fill=NAVY)

    # Definition.
    card(base, (30, 304, 1050, 431), GREEN_SOFT, GREEN)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NEDİR?", 54, 321, GREEN)
    text_block(
        draw,
        "Tam bağımlı engelli bireyin bakımının aile yanında sürdürülmesini desteklemek amacıyla, bakım hizmetini fiilen sağlayan hak sahibine ödenen ekonomik destektir.",
        54,
        371,
        font(18),
        TEXT,
        960,
        1.23,
    )

    # Conditions.
    card(base, (30, 451, 650, 830), (241, 248, 255), BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "3 TEMEL ŞART BİRLİKTE ARANIR", 54, 470, BLUE)
    current_y = 528
    conditions = [
        (
            "Uygun sağlık raporu",
            "18+ için “tam bağımlı” (eski raporda “ağır engelli”); çocukta “Çok İleri / Belirgin ÖG” veya “Özel Koşul Gereksinimi” düzeyi.",
        ),
        (
            "Gelir şartı",
            "Hanede kişi başına düşen aylık gelir, net asgari ücretin 2/3'ünden az olmalıdır.",
        ),
        (
            "Bakım ihtiyacı",
            "Kişinin günlük hayatını başkasının yardım ve bakımı olmadan sürdüremediği heyetçe tespit edilmelidir.",
        ),
    ]
    for index, (title, detail) in enumerate(conditions, start=1):
        current_y = numbered_step(draw, index, title, detail, 54, current_y, 566, BLUE)
    draw.rounded_rectangle((54, 745, 626, 801), radius=17, fill=WHITE)
    draw.text((72, 760), "Yalnızca rapor veya yalnızca gelir şartı yeterli değildir.", font=font(16, True), fill=BLUE)

    # Documents.
    card(base, (670, 451, 1050, 830), TEAL_SOFT, TEAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "GEREKLİ BELGELER", 694, 470, TEAL)
    current_y = 528
    documents = [
        "T.C. kimlik numarası / kimlik bilgileri",
        "Engelli sağlık kurulu raporu veya uygun ÇÖZGER",
        "Hane gelir ve mal varlığı beyanı; varsa belgeleri",
        "Açık Rıza Formu",
        "Gerekli durumda vasi / mahkeme kararı",
        "İstenirse öğrenim, boşanma veya ek durum belgeleri",
    ]
    for document in documents:
        current_y = check_item(draw, document, 694, current_y, 330, TEAL, 15)
    draw.rounded_rectangle((694, 740, 1026, 800), radius=17, fill=WHITE)
    text_block(
        draw,
        "Başvurunun durumuna göre ek evrak istenebilir.",
        710,
        755,
        font(15, True),
        TEAL,
        300,
        1.18,
    )

    # Application flow.
    card(base, (30, 850, 650, 1128), PURPLE_SOFT, PURPLE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NASIL BAŞVURULUR?", 54, 868, PURPLE)
    current_y = 923
    steps = [
        ("Ön başvuru", "e-Devlet'ten veya İl Müdürlüğü / Sosyal Hizmet Merkezinden başvurun."),
        ("Belgeler", "İstenen beyan ve belgeleri tamamlayın."),
        ("Hane ziyareti", "Heyet kişiyi ve ailesini yaşadığı yerde değerlendirir."),
        ("Karar", "Bakım raporu ve gelir incelemesi sonucu bildirilir."),
    ]
    for index, (title, detail) in enumerate(steps, start=1):
        current_y = numbered_step(draw, index, title, detail, 54, current_y, 566, PURPLE)

    # Important notes.
    card(base, (670, 850, 1050, 1128), CORAL_SOFT, CORAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "ÖNEMLİ NOTLAR", 694, 868, CORAL)
    current_y = 923
    notes = [
        "Ödeme, bakımı fiilen sağlayan hak sahibine yapılır.",
        "Yardım tutarı dönemsel olarak güncellenir.",
        "Gelir, adres, hane ve sağlık durumundaki değişiklikleri ilgili birime bildirin.",
        "Ödeme bilgisi e-Devlet'ten sorgulanabilir.",
    ]
    for note in notes:
        current_y = check_item(draw, note, 694, current_y, 330, CORAL, 15)

    # Direct application / QR.
    card(base, (30, 1148, 1050, 1258), YELLOW_SOFT, YELLOW)
    draw = ImageDraw.Draw(base)
    qr = qrcode.QRCode(version=5, box_size=4, border=1)
    qr.add_data(URL)
    qr.make(fit=True)
    qr_image = qr.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")
    qr_image = qr_image.resize((86, 86), Image.Resampling.NEAREST)
    base.paste(qr_image, (51, 1160))
    draw.text((157, 1166), "e-Devlet'ten ön başvuru", font=font(24, True), fill=NAVY)
    draw.text((157, 1202), "QR kodu tarat · Aile ve Sosyal Hizmetler Bakanlığı", font=font(16), fill=MUTED)
    draw.text((750, 1167), "Güncel tutar", font=font(16), fill=MUTED)
    draw.text((750, 1196), "Dönemsel güncellenir", font=font(21, True), fill=GREEN)

    # Footer.
    draw.rectangle((0, 1280, W, H), fill=NAVY)
    draw.text(
        (35, 1296),
        "Kaynak: Aile ve Sosyal Hizmetler Bakanlığı · Evde Bakım Yardımı Yönetmeliği",
        font=font(13),
        fill=WHITE,
    )
    draw.text(
        (35, 1322),
        "Bilgilendirme amaçlıdır; güncel mevzuat ve kurum değerlendirmesi esastır.",
        font=font(12),
        fill=(194, 218, 234),
    )
    return base.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    output = OUT / "evde-bakim-yardimi-instagram.png"
    poster.save(output, "PNG", optimize=True)
    print("wrote", output, poster.size)

    artifacts = Path("/opt/cursor/artifacts/assets")
    artifacts.mkdir(parents=True, exist_ok=True)
    poster.save(artifacts / output.name, "PNG")


if __name__ == "__main__":
    main()
