#!/usr/bin/env python3
"""Build Engelsiz Club 9:16 promo video (scenes + TTS + FFmpeg)."""

from __future__ import annotations

import asyncio
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parent
SOCIAL = ROOT / "marketing" / "social"
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
BADGE_PLAY = ROOT / "assets" / "images" / "badge_google_play.png"
BADGE_APP = ROOT / "assets" / "images" / "badge_app_store.png"
FRAMES = OUT_DIR / "_frames"
AUDIO = OUT_DIR / "_audio"

W, H = 1080, 1920
BG = (242, 247, 244)
FG = (13, 43, 31)
GREEN = (26, 107, 74)
MUTED = (77, 122, 98)
GOLD = (244, 168, 50)
WHITE = (255, 255, 255)

FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def gradient_bg() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        # soft vertical wash: mint → slightly deeper green tint
        r = int(242 - 18 * t)
        g = int(247 - 10 * t)
        b = int(244 - 22 * t)
        for x in range(W):
            # subtle radial warmth from center
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            d = math.sqrt(dx * dx + dy * dy)
            boost = max(0.0, 1.0 - d) * 8
            px[x, y] = (
                min(255, int(r + boost)),
                min(255, int(g + boost * 0.6)),
                min(255, int(b)),
            )
    return img


def draw_centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    y: int,
    fnt: ImageFont.FreeTypeFont,
    fill,
    max_width: int = 900,
) -> int:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for word in words:
        trial = f"{cur} {word}".strip()
        if draw.textlength(trial, font=fnt) <= max_width:
            cur = trial
        else:
            if cur:
                lines.append(cur)
            cur = word
    if cur:
        lines.append(cur)

    line_h = int(fnt.size * 1.35)
    for i, line in enumerate(lines):
        tw = draw.textlength(line, font=fnt)
        draw.text(((W - tw) / 2, y + i * line_h), line, font=fnt, fill=fill)
    return y + len(lines) * line_h


def fit_cover(src: Image.Image, tw: int, th: int) -> Image.Image:
    sw, sh = src.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    resized = src.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return resized.crop((left, top, left + tw, top + th))


def paste_logo(base: Image.Image, size: int = 520, y: int | None = None) -> None:
    logo = Image.open(ICON).convert("RGBA")
    logo = logo.resize((size, size), Image.Resampling.LANCZOS)
    # remove near-white background so logo sits cleanly
    datas = logo.getdata()
    cleaned = []
    for r, g, b, a in datas:
        if r > 245 and g > 245 and b > 245:
            cleaned.append((r, g, b, 0))
        else:
            cleaned.append((r, g, b, a))
    logo.putdata(cleaned)
    x = (W - size) // 2
    yy = y if y is not None else (H - size) // 2 - 160
    base.paste(logo, (x, yy), logo)


def gold_line(draw: ImageDraw.ImageDraw, y: int, width: int = 160) -> None:
    x0 = (W - width) // 2
    draw.rounded_rectangle([x0, y, x0 + width, y + 6], radius=3, fill=GOLD)


def scene_open() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    paste_logo(img, 560, y=420)
    draw = ImageDraw.Draw(img)
    gold_line(draw, 1040, 120)
    draw_centered_text(draw, "Engelsiz Club", 1080, font(78, True), FG)
    draw_centered_text(
        draw,
        "Özel gereksinimli kahramanlarımız için rehber",
        1200,
        font(36),
        MUTED,
    )
    return img.convert("RGB")


def scene_need() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    draw = ImageDraw.Draw(img)
    draw_centered_text(draw, "Aileler yalnız değil", 520, font(64, True), FG)
    gold_line(draw, 680, 140)
    draw_centered_text(
        draw,
        "Doğru bilgiye ulaşmak zor olmasın. Engelsiz Club, özel gereksinimli çocuklar ve aileleri için güvenilir bir rehber.",
        740,
        font(40),
        MUTED,
        max_width=860,
    )
    paste_logo(img, 280, y=1280)
    return img.convert("RGB")


def scene_from_social(path: Path, caption: str | None = None) -> Image.Image:
    img = gradient_bg().convert("RGBA")
    art = Image.open(path).convert("RGB")
    # phone-like framed panel
    panel_w, panel_h = 920, 1280
    cover = fit_cover(art, panel_w, panel_h)
    # soft shadow
    shadow = Image.new("RGBA", (panel_w + 40, panel_h + 40), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([10, 16, panel_w + 30, panel_h + 36], radius=48, fill=(13, 43, 31, 40))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    px = (W - panel_w) // 2
    py = 220
    img.paste(shadow, (px - 20, py - 10), shadow)
    mask = Image.new("L", (panel_w, panel_h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, panel_w, panel_h], radius=40, fill=255)
    rounded = Image.new("RGBA", (panel_w, panel_h))
    rounded.paste(cover, (0, 0))
    rounded.putalpha(mask)
    img.paste(rounded, (px, py), rounded)
    if caption:
        draw = ImageDraw.Draw(img)
        draw_centered_text(draw, caption, 1580, font(34, True), GREEN)
    return img.convert("RGB")


def scene_features() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    draw = ImageDraw.Draw(img)
    draw_centered_text(draw, "Bir uygulamada", 360, font(58, True), FG)
    gold_line(draw, 500, 120)
    items = [
        ("Rehber", "Hastalık ve gelişim bilgileri"),
        ("Destek", "Aile koçu ve günlük takip"),
        ("Topluluk", "Paylaşım ve dayanışma"),
    ]
    y = 580
    for title, sub in items:
        box = [120, y, W - 120, y + 210]
        draw.rounded_rectangle(box, radius=28, fill=WHITE, outline=(26, 107, 74, 40), width=2)
        draw.text((170, y + 48), title, font=font(44, True), fill=GREEN)
        draw.text((170, y + 118), sub, font=font(32), fill=MUTED)
        y += 250
    return img.convert("RGB")


def scene_cta() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    paste_logo(img, 420, y=360)
    draw = ImageDraw.Draw(img)
    gold_line(draw, 860, 140)
    draw_centered_text(draw, "Hemen keşfet", 920, font(72, True), FG)
    draw_centered_text(
        draw,
        "Engelsiz Club ile doğru bilgiye bir dokunuşla ulaş.",
        1040,
        font(36),
        MUTED,
        max_width=820,
    )
    # CTA pill
    pill = [280, 1220, 800, 1340]
    draw.rounded_rectangle(pill, radius=40, fill=GREEN)
    tw = draw.textlength("Uygulamayı İndir", font=font(40, True))
    draw.text(((W - tw) / 2, 1255), "Uygulamayı İndir", font=font(40, True), fill=WHITE)

    # store badges if present
    by = 1460
    badges: list[Image.Image] = []
    for p in (BADGE_PLAY, BADGE_APP):
        if p.exists():
            b = Image.open(p).convert("RGBA")
            bh = 90
            bw = int(b.width * (bh / b.height))
            badges.append(b.resize((bw, bh), Image.Resampling.LANCZOS))
    if badges:
        total = sum(b.width for b in badges) + 24 * (len(badges) - 1)
        x = (W - total) // 2
        for b in badges:
            img.paste(b, (x, by), b)
            x += b.width + 24
    return img.convert("RGB")


SCENES: list[tuple[str, float, callable]] = []


def build_scenes() -> list[tuple[Path, float]]:
    FRAMES.mkdir(parents=True, exist_ok=True)
    # ~20s total — aligns with Turkish voiceover
    specs = [
        ("01_open.png", 3.2, scene_open),
        ("02_need.png", 3.6, scene_need),
        ("03_story.png", 3.4, lambda: scene_from_social(SOCIAL / "engelsizclub-story-hero.png")),
        ("04_features.png", 3.8, scene_features),
        ("05_ad.png", 3.0, lambda: scene_from_social(SOCIAL / "engelsizclub-ad-cta.png")),
        ("06_cta.png", 3.5, scene_cta),
    ]
    out: list[tuple[Path, float]] = []
    for name, dur, fn in specs:
        path = FRAMES / name
        fn().save(path, "PNG", optimize=True)
        out.append((path, dur))
        print(f"scene {name} ({dur}s)")
    return out


async def make_voiceover(path: Path) -> None:
    import edge_tts

    script = (
        "Engelsiz Club. "
        "Özel gereksinimli kahramanlarımız için rehber. "
        "Aileler yalnız değil. Doğru bilgi, doğru destek. "
        "Rehber, destek ve topluluk tek uygulamada. "
        "Hemen keşfet. Uygulamayı indir."
    )
    # Warm Turkish female voice
    communicate = edge_tts.Communicate(script, voice="tr-TR-EmelNeural", rate="-5%")
    await communicate.save(str(path))
    print(f"voiceover -> {path}")


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def assemble(scenes: list[tuple[Path, float]], voice: Path, out_mp4: Path) -> None:
    """Still scenes → short clips → concat → voice + soft bed."""
    clips_dir = OUT_DIR / "_clips"
    clips_dir.mkdir(parents=True, exist_ok=True)
    clip_paths: list[Path] = []

    for i, (path, dur) in enumerate(scenes):
        clip = clips_dir / f"clip_{i:02d}.mp4"
        # gentle scale-up via crop (Ken Burns-ish) without zoompan bugs
        # start slightly cropped, ease toward full frame
        vf = (
            f"scale=1188:2112,"
            f"crop=1080:1920:"
            f"'floor((iw-1080)*(0.5-0.5*t/{dur:.3f}))':"
            f"'floor((ih-1920)*(0.5-0.5*t/{dur:.3f}))',"
            f"fps=30,format=yuv420p,"
            f"fade=t=in:st=0:d=0.35,fade=t=out:st={max(0.1, dur - 0.35):.2f}:d=0.35"
        )
        run(
            [
                "ffmpeg",
                "-y",
                "-loop",
                "1",
                "-i",
                str(path),
                "-t",
                f"{dur:.3f}",
                "-vf",
                vf,
                "-c:v",
                "libx264",
                "-crf",
                "18",
                "-preset",
                "veryfast",
                "-pix_fmt",
                "yuv420p",
                "-an",
                str(clip),
            ]
        )
        clip_paths.append(clip)

    concat_list = clips_dir / "concat.txt"
    concat_list.write_text("".join(f"file '{p.resolve()}'\n" for p in clip_paths))
    silent = OUT_DIR / "_silent.mp4"
    run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(concat_list),
            "-c",
            "copy",
            str(silent),
        ]
    )

    # match bed length to voice (~20s)
    voice_dur = float(
        subprocess.check_output(
            [
                "ffprobe",
                "-v",
                "error",
                "-show_entries",
                "format=duration",
                "-of",
                "default=nw=1:nk=1",
                str(voice),
            ],
            text=True,
        ).strip()
    )
    bed_len = max(voice_dur + 1.0, sum(d for _, d in scenes))
    bed = AUDIO / "bed.wav"
    run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency=196:duration={bed_len:.2f}",
            "-f",
            "lavfi",
            "-i",
            f"sine=frequency=246.94:duration={bed_len:.2f}",
            "-filter_complex",
            f"[0][1]amix=inputs=2,volume=0.035,"
            f"afade=t=in:st=0:d=1.2,afade=t=out:st={bed_len - 1.5:.2f}:d=1.4[a]",
            "-map",
            "[a]",
            str(bed),
        ]
    )

    mixed = AUDIO / "mixed.m4a"
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(voice),
            "-i",
            str(bed),
            "-filter_complex",
            "[0:a]loudnorm=I=-16:TP=-1.5:LRA=11,apad[v];"
            "[1:a]volume=0.5[b];"
            "[v][b]amix=inputs=2:duration=longest:dropout_transition=2[a]",
            "-map",
            "[a]",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-t",
            f"{bed_len:.2f}",
            str(mixed),
        ]
    )

    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(silent),
            "-i",
            str(mixed),
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-preset",
            "medium",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-shortest",
            "-movflags",
            "+faststart",
            "-pix_fmt",
            "yuv420p",
            str(out_mp4),
        ]
    )
    print(f"done -> {out_mp4}")


def main() -> None:
    AUDIO.mkdir(parents=True, exist_ok=True)
    scenes = build_scenes()
    voice = AUDIO / "voice.mp3"
    asyncio.run(make_voiceover(voice))
    out = OUT_DIR / "engelsizclub-promo-9x16.mp4"
    assemble(scenes, voice, out)
    # also refresh short intro as first 8s extract for Stories
    intro = OUT_DIR / "engelsizclub-intro-9x16.mp4"
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(out),
            "-t",
            "8",
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-c:a",
            "aac",
            "-b:a",
            "160k",
            "-movflags",
            "+faststart",
            str(intro),
        ]
    )


if __name__ == "__main__":
    main()
