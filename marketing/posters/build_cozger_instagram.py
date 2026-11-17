#!/usr/bin/env python3
"""Engelsiz Club — ÇÖZGER 4:5 Instagram bilgilendirme afişi."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
FAMILY = OUT / "cozger-doctor-family-illustration.png"

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
    line_height: float = 1.24,
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


def paste_family(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    if not FAMILY.exists():
        return
    x0, y0, x1, y1 = box
    width, height = x1 - x0, y1 - y0
    image = Image.open(FAMILY).convert("RGB")
    # Remove the generated checkerboard-style outer background.
    pixels = image.load()
    for py in range(image.height):
        for px in range(image.width):
            red, green, blue = pixels[px, py]
            if red > 225 and green > 230 and blue > 235 and max(red, green, blue) - min(red, green, blue) < 18:
                pixels[px, py] = BLUE_SOFT
    image = ImageOps.fit(
        image,
        (width, height),
        Image.Resampling.LANCZOS,
        centering=(0.52, 0.52),
    ).convert("RGBA")
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1),
        radius=32,
        fill=255,
    )
    image.putalpha(mask)
    base.paste(image, (x0, y0), image)


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
    draw.text((x + 46, y), title, font=font(19, True), fill=NAVY)
    return text_block(draw, detail, x + 46, y + 25, font(15), MUTED, width - 46, 1.22) + 7


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


def build() -> Image.Image:
    base = Image.new("RGB", (W, H), PAPER).convert("RGBA")
    draw = ImageDraw.Draw(base)

    # Header.
    draw.rectangle((0, 0, W, 285), fill=BLUE_SOFT)
    draw.ellipse((-180, 185, 720, 440), fill=(205, 234, 249))
    draw.ellipse((660, -120, 1240, 350), fill=(217, 246, 230))
    paste_logo(base, (38, 28), 64)
    draw.text((114, 34), "Engelsiz Club", font=font(29, True), fill=BRAND)
    draw.text((114, 72), "Aileler için bilgi", font=font(17), fill=MUTED)
    paste_family(base, (670, 20, 1040, 275))

    draw.text((42, 121), "ÇOCUKLAR İÇİN ÖZEL", font=font(31, True), fill=NAVY)
    draw.text((42, 160), "GEREKSİNİM RAPORU", font=font(34, True), fill=BLUE)
    draw.text((42, 205), "(ÇÖZGER)", font=font(42, True), fill=GREEN)
    draw.rounded_rectangle((292, 217, 646, 260), radius=16, fill=YELLOW)
    draw.text((312, 226), "0–18 yaş için resmi rapor", font=font(19, True), fill=NAVY)

    # Definition.
    card(base, (30, 304, 1050, 431), BLUE_SOFT, BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "ÇÖZGER NEDİR?", 54, 321, BLUE)
    text_block(
        draw,
        "Çocuğun özel gereksinim düzeyini belirleyen resmi sağlık kurulu raporudur. Engel oranı yerine gereksinim düzeyi yazar; sağlık, eğitim, rehabilitasyon ve sosyal haklara erişimde kullanılır.",
        54,
        371,
        font(17),
        TEXT,
        960,
        1.22,
    )

    # Application.
    card(base, (30, 451, 650, 850), (241, 248, 255), BLUE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NASIL ALINIR?", 54, 470, BLUE)
    current_y = 525
    steps = [
        ("Randevu al", "MHRS veya ALO 182'den “ÇÖZGER / 18 yaş altı sağlık kurulu” randevusu alın."),
        ("Kurula başvur", "Yetkili hastanenin sağlık kurulu biriminde dilekçe / başvuru formunu doldurun."),
        ("Muayeneleri tamamla", "Çocuk ilgili uzman hekimlerce değerlendirilir; gerektiğinde tetkik istenir."),
        ("Kurula gir", "Uzman görüşleri sağlık kurulunca değerlendirilerek gereksinim düzeyi belirlenir."),
        ("Raporu teslim al", "Rapor en geç 30 gün içinde tamamlanır; e-Devlet'ten de görüntülenebilir."),
    ]
    for index, (title, detail) in enumerate(steps, start=1):
        current_y = numbered_step(draw, index, title, detail, 54, current_y, 566)

    # Documents.
    card(base, (670, 451, 1050, 850), TEAL_SOFT, TEAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "GEREKLİ BELGELER", 694, 470, TEAL)
    current_y = 528
    documents = [
        "Çocuğun kimlik belgesi",
        "Veli / vasi kimlik belgesi",
        "Varsa eski sağlık kurulu raporları",
        "Epikriz, tetkik, reçete ve takip belgeleri",
        "Hastanenin verdiği başvuru formu / dilekçe",
    ]
    for document in documents:
        current_y = check_item(draw, document, 694, current_y, 330, TEAL)
    draw.rounded_rectangle((694, 722, 1026, 820), radius=18, fill=WHITE)
    text_block(
        draw,
        "Çocuğun başvuruda hazır bulunması gerekir. Hastanenin istediği ek belgeler değişebilir.",
        710,
        738,
        font(15, True),
        TEAL,
        300,
        1.2,
    )

    # Benefits.
    card(base, (30, 870, 650, 1130), PURPLE_SOFT, PURPLE)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "NE İŞE YARAR?", 54, 888, PURPLE)
    current_y = 943
    benefits = [
        "RAM değerlendirmesi, özel eğitim ve rehabilitasyon",
        "Bakım aylığı / engelli aylığı ve sosyal yardımlar",
        "Cihaz, ortez-protez ve sağlık hizmetleri",
        "Ulaşım, belediye ve ilgili kamu kolaylıkları",
        "Okul ve diğer resmi kurum başvuruları",
    ]
    for benefit in benefits:
        current_y = check_item(draw, benefit, 54, current_y, 566, PURPLE, 15)

    # Important notes.
    card(base, (670, 870, 1050, 1130), CORAL_SOFT, CORAL)
    draw = ImageDraw.Draw(base)
    title_chip(draw, "ÖNEMLİ NOTLAR", 694, 888, CORAL)
    current_y = 943
    notes = [
        "Rapor süreli veya sürekli olabilir.",
        "18 yaş dolunca erişkin raporu sürecine geçilir.",
        "İtiraz, tebliğden itibaren 30 gün içinde İl Sağlık Müdürlüğü'ne yapılabilir.",
        "Haklar, rapordaki düzeye ve kurum şartlarına göre değişir.",
    ]
    for note in notes:
        current_y = check_item(draw, note, 694, current_y, 330, CORAL, 15)

    # Appointment callout.
    card(base, (30, 1150, 1050, 1248), YELLOW_SOFT, YELLOW)
    draw = ImageDraw.Draw(base)
    draw.rounded_rectangle((54, 1171, 207, 1227), radius=20, fill=YELLOW)
    draw.text((80, 1181), "182", font=font(29, True), fill=NAVY)
    draw.text((232, 1168), "Randevu için", font=font(18), fill=MUTED)
    draw.text((232, 1195), "ALO 182 veya MHRS", font=font(27, True), fill=NAVY)
    draw.text((670, 1172), "Sonuç:", font=font(17), fill=MUTED)
    draw.text((670, 1198), "En geç 30 gün", font=font(25, True), fill=GREEN)

    # Footer.
    draw.rectangle((0, 1275, W, H), fill=NAVY)
    draw.text(
        (35, 1292),
        "Kaynak: ÇÖZGER Yönetmeliği · Sağlık Bakanlığı · MHRS",
        font=font(14),
        fill=WHITE,
    )
    draw.text(
        (35, 1320),
        "Bilgilendirme amaçlıdır; güncel hastane ve kurum uygulaması esastır.",
        font=font(13),
        fill=(194, 218, 234),
    )
    return base.convert("RGB")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    poster = build()
    output = OUT / "cozger-instagram-bilgilendirme.png"
    poster.save(output, "PNG", optimize=True)
    print("wrote", output, poster.size)

    artifacts = Path("/opt/cursor/artifacts/assets")
    artifacts.mkdir(parents=True, exist_ok=True)
    poster.save(artifacts / output.name, "PNG")


if __name__ == "__main__":
    main()
