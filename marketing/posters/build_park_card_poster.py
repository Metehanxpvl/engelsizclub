#!/usr/bin/env python3
"""Engelsiz Club — Engelli / Gazi Park Kartı Instagram afişi."""

from __future__ import annotations

from pathlib import Path

import qrcode
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
ILLUSTRATION = Path("/opt/cursor/artifacts/assets/park-karti-illustration.png")

URL = "https://www.turkiye.gov.tr/emniyet-engelli-gazi-park-karti-basvurusu"

W, H = 1080, 1350

NAVY = (18, 51, 76)
BLUE = (48, 123, 198)
BLUE_SOFT = (222, 239, 252)
TEAL = (29, 151, 143)
TEAL_SOFT = (219, 245, 240)
CORAL = (232, 93, 106)
CORAL_SOFT = (255, 229, 232)
YELLOW = (246, 184, 56)
YELLOW_SOFT = (255, 245, 211)
GREEN = (26, 107, 74)
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
    line_height: float = 1.25,
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
    fnt = font(22, True)
    width = draw.textlength(title, font=fnt)
    draw.rounded_rectangle((x, y, x + width + 30, y + 42), radius=14, fill=color)
    draw.text((x + 15, y + 8), title, font=fnt, fill=WHITE)


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
    image = Image.open(ILLUSTRATION).convert("RGBA")
    # Remove white corners from the generated clipart.
    data = []
    for red, green, blue, alpha in image.getdata():
        distance = max(0, 255 - min(red, green, blue))
        data.append((red, green, blue, min(alpha, distance * 4)))
    image.putdata(data)
    image = ImageOps.contain(image, (x1 - x0, y1 - y0), Image.Resampling.LANCZOS)
    base.paste(
        image,
        (x0 + (x1 - x0 - image.width) // 2, y0 + (y1 - y0 - image.height) // 2),
        image,
    )


def numbered_step(
    draw: ImageDraw.ImageDraw,
    number: int,
    title: str,
    detail: str,
    x: int,
    y: int,
    width: int,
) -> int:
    draw.ellipse((x, y + 1, x + 34, y + 35), fill=BLUE)
    number_text = str(number)
    number_width = draw.textlength(number_text, font=font(17, True))
    draw.text((x + (34 - number_width) / 2, y + 6), number_text, font=font(17, True), fill=WHITE)
    draw.text((x + 46, y), title, font=font(20, True), fill=NAVY)
    return text_block(draw, detail, x + 46, y + 27, font(16), MUTED, width - 46, 1.25) + 8


def check_item(
    draw: ImageDraw.ImageDraw,
    text: str,
    x: int,
    y: int,
    width: int,
    color: tuple[int, int, int],
) -> int:
    draw.rounded_rectangle((x, y + 2, x + 25, y + 27), radius=8, fill=color)
    draw.text((x + 5, y + 2), "✓", font=font(16, True), fill=WHITE)
    return text_block(draw, text, x + 36, y, font(16), TEXT, width - 36, 1.25) + 8


def build() -> Image.Image:
    image = Image.new("RGB", (W, H), PAPER)
    base = image.convert("RGBA")
    draw = ImageDraw.Draw(base)

    # Header with friendly wave and illustration.
    draw.rectangle((0, 0, W, 285), fill=BLUE_SOFT)
    draw.ellipse((-180, 185, 720, 440), fill=(205, 234, 249))
    draw.ellipse((650, -120, 1220, 340), fill=(217, 246, 240))
    paste_logo(base, (38, 29), 64)
    draw.text((114, 35), "Engelsiz Club", font=font(29, True), fill=GREEN)
    draw.text((114, 73), "Haklarınızı bilin", font=font(17), fill=MUTED)
    paste_illustration(base, (670, 20, 1040, 275))

    draw.text((42, 122), "ENGELLİ / GAZİ", font=font(38, True), fill=NAVY)
    draw.text((42, 168), "PARK KARTI", font=font(49, True), fill=BLUE)
    draw.rounded_rectangle((42, 232, 525, 272), radius=16, fill=YELLOW)
    draw.text((62, 240), "Başvuru artık e-Devlet'te!", font=font(21, True), fill=NAVY)

    # What it is.
    card(base, (30, 304, 1050, 431), BLUE_SOFT, BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NE İŞE YARAR?", 54, 321, BLUE)
    text_block(
        draw,
        "Engelli ve gazilerin, kendileri için ayrılmış park alanlarından yararlanabilmesi amacıyla EGM tarafından düzenlenen kişiye özel karttır.",
        54,
        372,
        font(18),
        TEXT,
        960,
        1.24,
    )

    # Application / requirements columns.
    card(base, (30, 451, 650, 815), (241, 248, 255), BLUE)
    card(base, (670, 451, 1050, 815), TEAL_SOFT, TEAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NASIL BAŞVURULUR?", 54, 470, BLUE)
    current_y = 526
    steps = [
        ("e-Devlet'e gir", "Kimlik doğrulama yöntemlerinden biriyle giriş yap."),
        ("Hizmeti ara", "\"Engelli / Gazi Park Kartı Başvurusu\" yaz."),
        ("EGM hizmetini aç", "Bilgilerini kontrol et ve ekrandaki adımları tamamla."),
        ("Kartını temin et", "Barkodlu / karekodlu kartını hizmet ekranından üret veya teslim yönlendirmesini takip et."),
    ]
    for index, (title, detail) in enumerate(steps, start=1):
        current_y = numbered_step(draw, index, title, detail, 54, current_y, 566)

    title_chip(draw, "NELER GEREKİR?", 694, 470, TEAL)
    current_y = 528
    requirements = [
        "e-Devlet erişimi ve T.C. kimlik doğrulaması",
        "Sistemde doğrulanabilir engellilik / gazilik kaydı",
        "Güncel iletişim ve ikamet adresi",
        "Hizmet ekranı isterse statünüze özel ek bilgi / belge",
    ]
    for requirement in requirements:
        current_y = check_item(draw, requirement, 694, current_y, 330, TEAL)
    draw.rounded_rectangle((694, 710, 1026, 785), radius=18, fill=WHITE)
    text_block(
        draw,
        "Belge listesi kişiye göre değişebilir; başvuru ekranında istenenleri esas alın.",
        710,
        725,
        font(15, True),
        TEAL,
        300,
        1.2,
    )

    # Usage.
    card(base, (30, 835, 650, 1087), CORAL_SOFT, CORAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "KULLANIRKEN DİKKAT", 54, 853, CORAL)
    current_y = 910
    warnings = [
        "Kart kişiye özeldir; başkasına kullandırılamaz.",
        "Hak sahibi araçtayken kullanılmalıdır.",
        "Park sırasında kartı ön camda görünür tutun.",
        "Yasaklı / tehlikeli alanlara park hakkı vermez.",
    ]
    for warning in warnings:
        current_y = check_item(draw, warning, 54, current_y, 566, CORAL)

    # QR area.
    card(base, (670, 835, 1050, 1087), YELLOW_SOFT, YELLOW)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "DOĞRUDAN BAŞVURU", 694, 853, YELLOW)
    qr = qrcode.QRCode(version=4, box_size=5, border=2)
    qr.add_data(URL)
    qr.make(fit=True)
    qr_image = qr.make_image(fill_color=NAVY, back_color=WHITE).convert("RGB")
    qr_image = qr_image.resize((148, 148), Image.Resampling.NEAREST)
    base.paste(qr_image, (694, 915))
    draw.text((860, 922), "QR kodu", font=font(22, True), fill=NAVY)
    draw.text((860, 953), "tarat", font=font(22, True), fill=NAVY)
    text_block(draw, "ve e-Devlet EGM hizmetine git.", 860, 990, font(15), MUTED, 160, 1.2)

    # ISPAK distinction, critical accuracy note.
    card(base, (30, 1107, 1050, 1248), TEAL_SOFT, TEAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "İSTANBUL / İSPARK İÇİN AYRI KAYIT", 54, 1125, TEAL)
    text_block(
        draw,
        "Park kartı tek başına İSPARK ücretsiz kullanım kaydı değildir. Plakanızı ayrıca ispark.istanbul/basvuru üzerinden tanımlatın. Engelli başvurusunda ruhsatta “Engelli” ibaresi; gazi başvurusunda Bakanlık kartı + ruhsat gerekir.",
        54,
        1177,
        font(17),
        TEXT,
        960,
        1.23,
    )

    # Footer.
    draw.rectangle((0, 1275, W, H), fill=NAVY)
    draw.text((35, 1293), "Kaynak: e-Devlet · Emniyet Genel Müdürlüğü · İSPARK", font=font(14), fill=WHITE)
    draw.text(
        (35, 1320),
        "Bilgilendirme amaçlıdır; güncel başvuru ekranı ve kurum kuralları esastır.",
        font=font(13),
        fill=(194, 218, 234),
    )

    return base.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    output = OUT / "engelli-gazi-park-karti-instagram.png"
    poster.save(output, "PNG", optimize=True)
    print("wrote", output, poster.size)

    artifacts = Path("/opt/cursor/artifacts/assets")
    artifacts.mkdir(parents=True, exist_ok=True)
    poster.save(artifacts / output.name, "PNG")


if __name__ == "__main__":
    main()
