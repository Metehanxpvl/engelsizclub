#!/usr/bin/env python3
"""Build Engelsiz Club walkthrough promo from real app screenshots."""

from __future__ import annotations

import asyncio
import math
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parent
SHOTS = ROOT / "marketing" / "screenshots"
ICON = ROOT / "assets" / "icon" / "app_icon_clean.png"
BADGE_PLAY = ROOT / "assets" / "images" / "badge_google_play.png"
BADGE_APP = ROOT / "assets" / "images" / "badge_app_store.png"
FRAMES = OUT_DIR / "_frames_app"
AUDIO = OUT_DIR / "_audio_app"
CLIPS = OUT_DIR / "_clips_app"

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


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd))
    subprocess.run(cmd, check=True)


def gradient_bg() -> Image.Image:
    img = Image.new("RGB", (W, H), BG)
    px = img.load()
    for y in range(H):
        t = y / (H - 1)
        r = int(242 - 18 * t)
        g = int(247 - 10 * t)
        b = int(244 - 22 * t)
        for x in range(W):
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


def draw_centered_text(draw, text, y, fnt, fill, max_width=900) -> int:
    words = text.split()
    lines, cur = [], ""
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


def paste_logo(base: Image.Image, size: int = 520, y: int | None = None) -> None:
    logo = Image.open(ICON).convert("RGBA")
    logo = logo.resize((size, size), Image.Resampling.LANCZOS)
    datas = []
    for r, g, b, a in logo.getdata():
        datas.append((r, g, b, 0) if r > 245 and g > 245 and b > 245 else (r, g, b, a))
    logo.putdata(datas)
    x = (W - size) // 2
    yy = y if y is not None else (H - size) // 2 - 160
    base.paste(logo, (x, yy), logo)


def phone_frame(shot: Path, caption: str) -> Image.Image:
    """Place screenshot in a phone-like frame on brand background."""
    img = gradient_bg().convert("RGBA")
    raw = Image.open(shot).convert("RGB")
    # Crop status/browser chrome a bit if very tall retina capture
    rw, rh = raw.size
    # Prefer center content; keep most of the UI
    target_aspect = 9 / 19.5
    cur_aspect = rw / rh
    if cur_aspect > target_aspect:
        new_w = int(rh * target_aspect)
        left = (rw - new_w) // 2
        raw = raw.crop((left, 0, left + new_w, rh))
    else:
        new_h = int(rw / target_aspect)
        top = 0
        raw = raw.crop((0, top, rw, min(rh, top + new_h)))

    panel_w, panel_h = 900, 1550
    phone = ImageOps.fit(raw, (panel_w, panel_h), Image.Resampling.LANCZOS)

    # shadow
    shadow = Image.new("RGBA", (panel_w + 50, panel_h + 50), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([8, 18, panel_w + 38, panel_h + 48], radius=56, fill=(13, 43, 31, 45))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))

    # rounded phone
    mask = Image.new("L", (panel_w, panel_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, panel_w, panel_h], radius=48, fill=255)
    rounded = Image.new("RGBA", (panel_w, panel_h))
    rounded.paste(phone, (0, 0))
    rounded.putalpha(mask)

    # thin green bezel
    bezel = Image.new("RGBA", (panel_w + 16, panel_h + 16), (0, 0, 0, 0))
    ImageDraw.Draw(bezel).rounded_rectangle(
        [0, 0, panel_w + 15, panel_h + 15], radius=54, fill=GREEN
    )
    inner_mask = Image.new("L", (panel_w, panel_h), 0)
    ImageDraw.Draw(inner_mask).rounded_rectangle([0, 0, panel_w, panel_h], radius=48, fill=255)

    px = (W - panel_w) // 2
    py = 140
    img.paste(shadow, (px - 20, py - 8), shadow)
    img.paste(bezel, (px - 8, py - 8), bezel)
    img.paste(rounded, (px, py), rounded)

    draw = ImageDraw.Draw(img)
    # caption pill
    tw = draw.textlength(caption, font=font(34, True))
    pad_x, pad_y = 36, 18
    bx0 = (W - tw) / 2 - pad_x
    by0 = 1740
    bx1 = (W + tw) / 2 + pad_x
    by1 = by0 + 34 + pad_y * 2
    draw.rounded_rectangle([bx0, by0, bx1, by1], radius=28, fill=GREEN)
    draw.text(((W - tw) / 2, by0 + pad_y), caption, font=font(34, True), fill=WHITE)
    return img.convert("RGB")


def scene_open() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    paste_logo(img, 520, y=380)
    draw = ImageDraw.Draw(img)
    x0 = (W - 120) // 2
    draw.rounded_rectangle([x0, 980, x0 + 120, 986], radius=3, fill=GOLD)
    draw_centered_text(draw, "Engelsiz Club", 1020, font(76, True), FG)
    draw_centered_text(
        draw,
        "Özel gereksinimli kahramanlarımız için rehber",
        1140,
        font(34),
        MUTED,
    )
    return img.convert("RGB")


def scene_cta() -> Image.Image:
    img = gradient_bg().convert("RGBA")
    paste_logo(img, 380, y=320)
    draw = ImageDraw.Draw(img)
    x0 = (W - 140) // 2
    draw.rounded_rectangle([x0, 780, x0 + 140, 786], radius=3, fill=GOLD)
    draw_centered_text(draw, "Hemen keşfet", 830, font(68, True), FG)
    draw_centered_text(
        draw,
        "Rehber, harita, ilan, forum ve aile desteği tek uygulamada.",
        940,
        font(34),
        MUTED,
        max_width=860,
    )
    pill = [260, 1180, 820, 1300]
    draw.rounded_rectangle(pill, radius=40, fill=GREEN)
    tw = draw.textlength("Uygulamayı İndir", font=font(40, True))
    draw.text(((W - tw) / 2, 1215), "Uygulamayı İndir", font=font(40, True), fill=WHITE)

    badges = []
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
            img.paste(b, (x, 1420), b)
            x += b.width + 24
    return img.convert("RGB")


SCREENS = [
    ("01-ana.png", "Ana Sayfa", 3.0),
    ("02-harita.png", "Yakın Merkezler", 2.8),
    ("03-ilanlar.png", "İlanlar", 2.8),
    ("04-forum.png", "Topluluk Forumu", 2.8),
    ("05-daha-fazlasi.png", "Daha Fazlası", 2.6),
    ("06-devlet-destekleri.png", "Devlet Destekleri", 2.8),
    ("07-bilgi.png", "Bilgi Kütüphanesi", 2.8),
]


def build_scenes() -> list[tuple[Path, float]]:
    FRAMES.mkdir(parents=True, exist_ok=True)
    out: list[tuple[Path, float]] = []

    open_p = FRAMES / "00_open.png"
    scene_open().save(open_p, "PNG", optimize=True)
    out.append((open_p, 3.0))
    print("scene open")

    for fname, caption, dur in SCREENS:
        src = SHOTS / fname
        if not src.exists():
            print(f"skip missing {fname}")
            continue
        path = FRAMES / f"shot_{fname}"
        phone_frame(src, caption).save(path, "PNG", optimize=True)
        out.append((path, dur))
        print(f"scene {fname} ({caption})")

    cta_p = FRAMES / "99_cta.png"
    scene_cta().save(cta_p, "PNG", optimize=True)
    out.append((cta_p, 3.5))
    print("scene cta")
    return out


async def make_voiceover(path: Path) -> None:
    import edge_tts

    script = (
        "Engelsiz Club. "
        "Özel gereksinimli kahramanlarımız için rehber. "
        "Ana sayfada bilgi ve duyurular. "
        "Haritada yakındaki merkezler. "
        "İlanlarla uzman ve destek bul. "
        "Forumda aileler birbirini destekler. "
        "Devlet destekleri ve haklar tek dokunuşta. "
        "Bilgi kütüphanesi her zaman yanında. "
        "Hemen keşfet. Uygulamayı indir."
    )
    communicate = edge_tts.Communicate(script, voice="tr-TR-EmelNeural", rate="-4%")
    await communicate.save(str(path))
    print(f"voiceover -> {path}")


def assemble(scenes: list[tuple[Path, float]], voice: Path, out_mp4: Path) -> None:
    CLIPS.mkdir(parents=True, exist_ok=True)
    clip_paths: list[Path] = []
    for i, (path, dur) in enumerate(scenes):
        clip = CLIPS / f"clip_{i:02d}.mp4"
        vf = (
            f"scale=1188:2112,"
            f"crop=1080:1920:"
            f"'floor((iw-1080)*(0.5-0.5*t/{dur:.3f}))':"
            f"'floor((ih-1920)*(0.5-0.5*t/{dur:.3f}))',"
            f"fps=30,format=yuv420p,"
            f"fade=t=in:st=0:d=0.28,fade=t=out:st={max(0.1, dur - 0.28):.2f}:d=0.28"
        )
        run(
            [
                "ffmpeg", "-y", "-loop", "1", "-i", str(path), "-t", f"{dur:.3f}",
                "-vf", vf, "-c:v", "libx264", "-crf", "18", "-preset", "veryfast",
                "-pix_fmt", "yuv420p", "-an", str(clip),
            ]
        )
        clip_paths.append(clip)

    concat_list = CLIPS / "concat.txt"
    concat_list.write_text("".join(f"file '{p.resolve()}'\n" for p in clip_paths))
    silent = OUT_DIR / "_silent_app.mp4"
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat_list), "-c", "copy", str(silent)])

    total = sum(d for _, d in scenes)
    voice_dur = float(
        subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_entries", "format=duration",
             "-of", "default=nw=1:nk=1", str(voice)],
            text=True,
        ).strip()
    )
    bed_len = max(total, voice_dur + 0.8)
    AUDIO.mkdir(parents=True, exist_ok=True)
    bed = AUDIO / "bed.wav"
    run(
        [
            "ffmpeg", "-y",
            "-f", "lavfi", "-i", f"sine=frequency=196:duration={bed_len:.2f}",
            "-f", "lavfi", "-i", f"sine=frequency=246.94:duration={bed_len:.2f}",
            "-filter_complex",
            f"[0][1]amix=inputs=2,volume=0.03,afade=t=in:st=0:d=1.0,afade=t=out:st={bed_len-1.4:.2f}:d=1.3[a]",
            "-map", "[a]", str(bed),
        ]
    )
    mixed = AUDIO / "mixed.m4a"
    run(
        [
            "ffmpeg", "-y", "-i", str(voice), "-i", str(bed),
            "-filter_complex",
            "[0:a]loudnorm=I=-16:TP=-1.5:LRA=11,apad[v];[1:a]volume=0.45[b];"
            "[v][b]amix=inputs=2:duration=longest:dropout_transition=2[a]",
            "-map", "[a]", "-c:a", "aac", "-b:a", "192k", "-t", f"{bed_len:.2f}", str(mixed),
        ]
    )
    run(
        [
            "ffmpeg", "-y", "-i", str(silent), "-i", str(mixed),
            "-c:v", "libx264", "-crf", "18", "-preset", "medium",
            "-c:a", "aac", "-b:a", "192k", "-shortest",
            "-movflags", "+faststart", "-pix_fmt", "yuv420p", str(out_mp4),
        ]
    )
    print(f"done -> {out_mp4}")


def main() -> None:
    scenes = build_scenes()
    voice = AUDIO / "voice.mp3"
    AUDIO.mkdir(parents=True, exist_ok=True)
    asyncio.run(make_voiceover(voice))
    out = OUT_DIR / "engelsizclub-promo-9x16.mp4"
    assemble(scenes, voice, out)
    intro = OUT_DIR / "engelsizclub-intro-9x16.mp4"
    run(
        [
            "ffmpeg", "-y", "-i", str(out), "-t", "8",
            "-c:v", "libx264", "-crf", "18", "-c:a", "aac", "-b:a", "160k",
            "-movflags", "+faststart", str(intro),
        ]
    )


if __name__ == "__main__":
    main()
