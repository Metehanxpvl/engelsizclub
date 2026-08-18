#!/usr/bin/env python3
"""Build the 20-second Tuesday Engelsiz Club Reel."""

from __future__ import annotations

import asyncio
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[3]
REEL_DIR = Path(__file__).resolve().parent
ASSETS = REEL_DIR / "assets"
BUILD = REEL_DIR / "_build"
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"

W, H = 1080, 1920
GREEN = (26, 107, 74)
DARK = (13, 43, 31)
MINT = (242, 247, 244)
MUTED = (77, 122, 98)
BLUE = (48, 123, 198)
GOLD = (244, 168, 50)
WHITE = (255, 255, 255)

FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def run(command: list[str]) -> None:
    print("+", " ".join(command))
    subprocess.run(command, check=True)


def probe_duration(path: Path) -> float:
    output = subprocess.check_output(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=nw=1:nk=1",
            str(path),
        ],
        text=True,
    )
    return float(output.strip())


def gradient() -> Image.Image:
    image = Image.new("RGB", (W, H), MINT)
    pixels = image.load()
    for y in range(H):
        t = y / (H - 1)
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            glow = max(0.0, 1.0 - math.sqrt(dx * dx + dy * dy)) * 8
            pixels[x, y] = (
                min(255, int(242 - 18 * t + glow)),
                min(255, int(247 - 10 * t + glow * 0.6)),
                min(255, int(244 - 20 * t)),
            )
    return image


def transparent_logo(size: int) -> Image.Image:
    logo = Image.open(ICON).convert("RGBA").resize((size, size), Image.Resampling.LANCZOS)
    pixels = []
    for red, green, blue, alpha in logo.getdata():
        pixels.append(
            (red, green, blue, 0)
            if red > 245 and green > 245 and blue > 245
            else (red, green, blue, alpha)
        )
    logo.putdata(pixels)
    return logo


def centered(draw: ImageDraw.ImageDraw, text: str, y: int, fnt, fill) -> None:
    width = draw.textlength(text, font=fnt)
    draw.text(((W - width) / 2, y), text, font=fnt, fill=fill)


def make_intro() -> Path:
    image = gradient().convert("RGBA")
    logo = transparent_logo(430)
    image.paste(logo, ((W - logo.width) // 2, 420), logo)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle(((W - 130) // 2, 900, (W + 130) // 2, 908), radius=4, fill=GOLD)
    centered(draw, "Engelsiz Club", 965, font(76, True), DARK)
    centered(draw, "Bilgiye tek dokunuşla ulaş", 1080, font(38, True), GREEN)
    centered(draw, "20 saniyede keşfet", 1150, font(30), MUTED)
    path = BUILD / "intro.png"
    image.convert("RGB").save(path, "PNG", optimize=True)
    return path


def make_cta() -> Path:
    image = gradient().convert("RGBA")
    logo = transparent_logo(360)
    image.paste(logo, ((W - logo.width) // 2, 350), logo)
    draw = ImageDraw.Draw(image)
    centered(draw, "Bilgi • Destek • Topluluk", 790, font(48, True), DARK)
    centered(draw, "hepsi bir arada", 860, font(38), MUTED)
    draw.rounded_rectangle((190, 1000, 890, 1130), radius=46, fill=GREEN)
    centered(draw, "Hemen keşfet", 1036, font(42, True), WHITE)
    centered(draw, "engelsizclub.com", 1195, font(40, True), GREEN)
    centered(draw, "Engelsiz Club", 1280, font(30), MUTED)
    path = BUILD / "cta.png"
    image.convert("RGB").save(path, "PNG", optimize=True)
    return path


def make_overlay(label: str, title: str, accent: tuple[int, int, int], name: str) -> Path:
    """Create a transparent scene overlay.

    The live app already contains clear section headings. Keeping the app scenes
    free of extra text prevents transition stacking and preserves Reels safe
    zones. The parameters remain for readable build call sites.
    """
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))

    path = BUILD / f"overlay-{name}.png"
    overlay.save(path, "PNG", optimize=True)
    return path


def make_cover() -> Path:
    source = Image.open(ASSETS / "04-library-more.png").convert("RGB")
    source = source.resize((W, int(source.height * W / source.width)), Image.Resampling.LANCZOS)
    top = 180
    image = source.crop((0, top, W, top + H)).convert("RGBA")
    dark = Image.new("RGBA", image.size, (7, 35, 25, 130))
    image.alpha_composite(dark)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((62, 170, 478, 245), radius=25, fill=GREEN)
    draw.text((88, 187), "ENGELSİZ CLUB", font=font(30, True), fill=WHITE)
    draw.text((62, 325), "Bilgi", font=font(86, True), fill=WHITE)
    draw.text((62, 425), "Kütüphanesi", font=font(75, True), fill=WHITE)
    draw.rounded_rectangle((62, 550, 700, 650), radius=34, fill=GOLD)
    draw.text((94, 574), "20 saniyede keşfet", font=font(36, True), fill=DARK)
    logo = transparent_logo(180)
    image.paste(logo, (810, 1650), logo)
    path = REEL_DIR / "engelsizclub-sali-reel-cover.png"
    image.convert("RGB").save(path, "PNG", optimize=True)
    return path


def make_clip_from_card(image: Path, output: Path, duration: float, zoom: bool) -> None:
    if zoom:
        vf = (
            "scale=1134:2016,"
            f"crop=1080:1920:'27-10*t/{duration:.3f}':'48-20*t/{duration:.3f}',"
            "fps=30,format=yuv420p"
        )
    else:
        vf = "scale=1080:1920,fps=30,format=yuv420p"
    run(
        [
            "ffmpeg",
            "-y",
            "-loop",
            "1",
            "-i",
            str(image),
            "-t",
            f"{duration:.3f}",
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
            str(output),
        ]
    )


def make_clip_from_screen(
    screenshot: Path,
    overlay: Path,
    output: Path,
    duration: float,
    start_y: int,
    end_y: int,
) -> None:
    y_expr = f"{start_y}+({end_y}-{start_y})*t/{duration:.3f}"
    filter_complex = (
        f"[0:v]scale=1080:-1,crop=1080:1920:0:'{y_expr}',fps=30,format=rgba[screen];"
        "[1:v]scale=1080:1920,format=rgba[overlay];"
        "[screen][overlay]overlay=0:0:format=auto,format=yuv420p[v]"
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-loop",
            "1",
            "-i",
            str(screenshot),
            "-loop",
            "1",
            "-i",
            str(overlay),
            "-t",
            f"{duration:.3f}",
            "-filter_complex",
            filter_complex,
            "-map",
            "[v]",
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-preset",
            "veryfast",
            "-pix_fmt",
            "yuv420p",
            "-an",
            str(output),
        ]
    )


def assemble_video(clips: list[Path], durations: list[float], output: Path) -> None:
    transition = 0.25
    filters: list[str] = []
    previous = "0:v"
    elapsed = durations[0]
    transitions = ["slideleft", "smoothleft", "slideup", "fade"]

    for index in range(1, len(clips)):
        name = f"x{index}"
        offset = elapsed - transition
        filters.append(
            f"[{previous}][{index}:v]xfade=transition={transitions[index - 1]}"
            f":duration={transition}:offset={offset:.3f}[{name}]"
        )
        previous = name
        elapsed += durations[index] - transition
    filters.append(f"[{previous}]fps=30,format=yuv420p[vout]")

    command = ["ffmpeg", "-y"]
    for clip in clips:
        command.extend(["-i", str(clip)])
    command.extend(
        [
            "-filter_complex",
            ";".join(filters),
            "-map",
            "[vout]",
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-preset",
            "medium",
            "-pix_fmt",
            "yuv420p",
            "-t",
            "20",
            str(output),
        ]
    )
    run(command)


async def make_voice(path: Path) -> None:
    import edge_tts

    script = (
        "Engelsiz Club ile güvenilir bilgiye tek dokunuşla ulaş. "
        "Ana sayfadaki bilimsel arama ile kaynaklara göz at. "
        "Güncel duyuruları takip et. "
        "Bilgi Kütüphanesi'nde otizmden serebral palsiye, "
        "Down sendromundan SMA'ya kadar birçok başlığı keşfet. "
        "Engelsiz Club. Bilgi, destek ve topluluk bir arada."
    )
    voice = edge_tts.Communicate(script, voice="tr-TR-EmelNeural", rate="+8%")
    await voice.save(str(path))


def make_subtitles(path: Path) -> None:
    path.write_text(
        """1
00:00:00,350 --> 00:00:02,650
Güvenilir bilgiye tek dokunuşla ulaş.

2
00:00:02,800 --> 00:00:07,000
Bilimsel kaynaklara göz at.

3
00:00:07,000 --> 00:00:11,000
Güncel duyuruları takip et.

4
00:00:11,000 --> 00:00:16,300
Bilgi Kütüphanesi'nde birçok başlığı keşfet.

5
00:00:16,300 --> 00:00:19,850
Bilgi, destek ve topluluk bir arada.
""",
        encoding="utf-8",
    )


def add_audio(video: Path, voice: Path, output: Path) -> None:
    voice_duration = probe_duration(voice)
    processed_voice = BUILD / "voice-processed.m4a"
    # Fit narration into the Reel while preserving natural pitch.
    tempo = max(1.0, voice_duration / 19.3)
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(voice),
            "-filter:a",
            f"atempo={tempo:.5f},loudnorm=I=-16:TP=-1.5:LRA=9,apad",
            "-t",
            "20",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            str(processed_voice),
        ]
    )
    run(
        [
            "ffmpeg",
            "-y",
            "-i",
            str(video),
            "-i",
            str(processed_voice),
            "-map",
            "0:v",
            "-map",
            "1:a",
            "-c:v",
            "libx264",
            "-crf",
            "18",
            "-preset",
            "medium",
            "-pix_fmt",
            "yuv420p",
            "-c:a",
            "aac",
            "-b:a",
            "192k",
            "-t",
            "20",
            "-movflags",
            "+faststart",
            str(output),
        ]
    )


def main() -> None:
    BUILD.mkdir(parents=True, exist_ok=True)

    intro = make_intro()
    cta = make_cta()
    overlays = [
        make_overlay("ANA SAYFA", "Güvenilir bilgi, tek yerde", GREEN, "home"),
        make_overlay("KEŞFET", "Bilimsel arama • Güncel duyurular", BLUE, "news"),
        make_overlay("BİLGİ KÜTÜPHANESİ", "İhtiyacın olan başlığı keşfet", GREEN, "library"),
    ]
    make_cover()

    durations = [2.8, 4.3, 4.0, 5.2, 4.7]
    clips = [BUILD / f"clip-{index}.mp4" for index in range(5)]
    make_clip_from_card(intro, clips[0], durations[0], zoom=True)
    make_clip_from_screen(
        ASSETS / "01-home-top.png",
        overlays[0],
        clips[1],
        durations[1],
        0,
        260,
    )
    make_clip_from_screen(
        ASSETS / "02-home-search-news.png",
        overlays[1],
        clips[2],
        durations[2],
        80,
        300,
    )
    make_clip_from_screen(
        ASSETS / "04-library-more.png",
        overlays[2],
        clips[3],
        durations[3],
        0,
        350,
    )
    make_clip_from_card(cta, clips[4], durations[4], zoom=True)

    silent = BUILD / "silent.mp4"
    assemble_video(clips, durations, silent)

    voice = BUILD / "voice.mp3"
    asyncio.run(make_voice(voice))
    subtitles = REEL_DIR / "engelsizclub-sali-reel.srt"
    make_subtitles(subtitles)
    output = REEL_DIR / "engelsizclub-sali-reel-20s.mp4"
    add_audio(silent, voice, output)
    print(f"done -> {output} ({probe_duration(output):.2f}s)")

    artifacts = Path("/opt/cursor/artifacts")
    artifacts.mkdir(parents=True, exist_ok=True)
    (artifacts / "assets").mkdir(parents=True, exist_ok=True)
    shutil.copy2(output, artifacts / output.name)
    shutil.copy2(
        REEL_DIR / "engelsizclub-sali-reel-cover.png",
        artifacts / "assets" / "engelsizclub-sali-reel-cover.png",
    )


if __name__ == "__main__":
    main()
