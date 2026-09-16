#!/usr/bin/env python3
"""81 il için Engelsiz Club müze gezi rehberi posteri.

CITY_NAME boş / ALL / * → kCityNames sırasıyla 81 il.
Tek il adı (veya Antep/Urfa/Maraş) → yalnız o il.
Kayıt: output/{il}_muze_gezisi_{YYYY-MM-DD}.jpg
API anahtarı yazdırılmaz.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
import time
import unicodedata
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

TEXT_MODELS = (
    "gemini-2.5-flash",
    "gemini-flash-latest",
    "gemini-2.0-flash",
)
IMAGEN_MODEL = "imagen-3.0-generate-002"
IMAGEN_REST = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"{IMAGEN_MODEL}:predict"
)
GEMINI_GENERATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "output"

# lib/data/turkish_cities_data.dart kCityNames ile aynı sıra (81 il).
CITIES = (
    "Adana",
    "Adıyaman",
    "Afyonkarahisar",
    "Ağrı",
    "Amasya",
    "Ankara",
    "Antalya",
    "Artvin",
    "Aydın",
    "Balıkesir",
    "Bartın",
    "Batman",
    "Bayburt",
    "Bilecik",
    "Bingöl",
    "Bitlis",
    "Bolu",
    "Burdur",
    "Bursa",
    "Çanakkale",
    "Çankırı",
    "Çorum",
    "Denizli",
    "Diyarbakır",
    "Düzce",
    "Edirne",
    "Elazığ",
    "Erzincan",
    "Erzurum",
    "Eskişehir",
    "Gaziantep",
    "Giresun",
    "Gümüşhane",
    "Hakkari",
    "Hatay",
    "Iğdır",
    "Isparta",
    "İstanbul",
    "İzmir",
    "Kahramanmaraş",
    "Karabük",
    "Karaman",
    "Kars",
    "Kastamonu",
    "Kayseri",
    "Kilis",
    "Kırıkkale",
    "Kırklareli",
    "Kırşehir",
    "Kocaeli",
    "Konya",
    "Kütahya",
    "Malatya",
    "Manisa",
    "Mardin",
    "Mersin",
    "Muğla",
    "Muş",
    "Nevşehir",
    "Niğde",
    "Ordu",
    "Osmaniye",
    "Rize",
    "Sakarya",
    "Samsun",
    "Siirt",
    "Sinop",
    "Sivas",
    "Şanlıurfa",
    "Şırnak",
    "Tekirdağ",
    "Tokat",
    "Trabzon",
    "Tunceli",
    "Uşak",
    "Van",
    "Yalova",
    "Yozgat",
    "Zonguldak",
    "Aksaray",
    "Ardahan",
)

ALIASES = {
    "antep": "Gaziantep",
    "urfa": "Şanlıurfa",
    "maras": "Kahramanmaraş",
    "maraş": "Kahramanmaraş",
    "afyon": "Afyonkarahisar",
    "istanbul": "İstanbul",
    "izmir": "İzmir",
}

LANDMARKS = {
    "Gaziantep": "Gaziantep Castle (Gaziantep Kalesi) on the hill",
    "İstanbul": "Hagia Sophia and Galata silhouette, no photorealism",
    "Ankara": "Ankara Castle (Ankara Kalesi) stone walls",
    "İzmir": "Kadifekale and Gulf of İzmir illustration",
    "Antalya": "Yivli Minare and historic harbor",
    "Konya": "Mevlana complex dome, respectful illustration",
    "Nevşehir": "fairy chimneys of Cappadocia, not a photo",
    "Çanakkale": "Troy horse and strait silhouette",
    "Edirne": "Selimiye Mosque silhouette",
    "Trabzon": "Sümela-inspired cliff monastery illustration",
    "Şanlıurfa": "Balıklıgöl and castle ridge",
    "Mardin": "honey-colored stone old city terraces",
    "Van": "Van Castle above the lake",
    "Kars": "Kars Castle and stone streets",
    "Diyarbakır": "Diyarbakır city walls",
}

VOICELESS = set("pçtkfhsş")
BACK_VOWELS = set("aıou")


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


def fold_city(raw: str) -> str:
    s = unicodedata.normalize("NFKD", str(raw or "")).strip()
    s = "".join(ch for ch in s if not unicodedata.combining(ch)).lower()
    table = str.maketrans(
        {
            "ı": "i",
            "ş": "s",
            "ğ": "g",
            "ü": "u",
            "ö": "o",
            "ç": "c",
            "â": "a",
            "î": "i",
            "û": "u",
        }
    )
    s = s.translate(table)
    return re.sub(r"[^a-z0-9]+", "", s)


def is_all_cities(raw: str) -> bool:
    text = str(raw or "").strip()
    if text in {"", "*", "81"}:
        return True
    return fold_city(text) in {"all", "tum", "hepsi"}


def resolve_city(raw: str) -> str:
    text = str(raw or "").strip()
    if not text:
        raise ValueError("İl adı boş.")
    folded = fold_city(text)
    if folded in ALIASES:
        return ALIASES[folded]
    by_fold = {fold_city(c): c for c in CITIES}
    if folded in by_fold:
        return by_fold[folded]
    raise ValueError(
        f"Geçersiz il adı: {text!r}. Türkiye'nin 81 ili veya Antep/Urfa/Maraş kısaltması kullanın."
    )


def cities_from_input(raw: str) -> list[str]:
    if is_all_cities(raw):
        return list(CITIES)
    return [resolve_city(raw)]


def last_vowel(word: str) -> str:
    for ch in reversed(word):
        cl = ch.lower().replace("i̇", "i")
        if cl in "aeıioöuü":
            return cl
    return "a"


def locative(city: str) -> str:
    """Gaziantep'te, İstanbul'da, Ankara'da."""
    if not city:
        return city
    last = city[-1].lower()
    back = last_vowel(city) in BACK_VOWELS
    vowel = "a" if back else "e"
    cons = "t" if last in VOICELESS else "d"
    return f"{city}'{cons}{vowel}"


def tr_upper(s: str) -> str:
    return s.replace("i", "İ").replace("ı", "I").upper()


def headline(city: str) -> str:
    loc = locative(city)
    prefix, _, suffix = loc.partition("'")
    return f"{tr_upper(prefix)}'{tr_upper(suffix)} MÜZE GEZİSİ"


def slug_city(city: str) -> str:
    raw = unicodedata.normalize("NFKD", city)
    ascii_ = "".join(ch for ch in raw if not unicodedata.combining(ch))
    ascii_ = (
        ascii_.replace("ı", "i")
        .replace("İ", "I")
        .replace("ş", "s")
        .replace("Ş", "S")
        .replace("ğ", "g")
        .replace("Ğ", "G")
        .replace("ü", "u")
        .replace("Ü", "U")
        .replace("ö", "o")
        .replace("Ö", "O")
        .replace("ç", "c")
        .replace("Ç", "C")
    )
    slug = re.sub(r"[^a-zA-Z0-9]+", "", ascii_.lower())
    return slug or "sehir"


def poster_filename(city: str, when: date | None = None) -> str:
    day = (when or datetime.now(timezone.utc).date()).isoformat()
    return f"{slug_city(city)}_muze_gezisi_{day}.jpg"


def fallback_imagen_prompt(city: str) -> str:
    mark = LANDMARKS.get(city, f"the most iconic historic castle or landmark of {city}, Turkey")
    title = headline(city)
    return (
        "Vertical 3:4 modern illustrated travel poster, not a photograph, not 3D render clutter. "
        "Animated editorial vector style, bold shapes, soft grain, hopeful and dignified. "
        f"Hero illustration: {mark}, recognizably {city}, Turkey. "
        "Color palette: deep forest green #1A6B4A, cream #F2F7F4, gold accent, night-teal sky. "
        f"Large centered headline in clear capital Turkish letters exactly: {title}. "
        "Secondary badge: Özel gereksinimli bireyler için ÜCRETSİZ. "
        "Small info row: MüzeKart geçerli devlet müzelerinde; engelli ziyaretçi ve bir refakatçi ücretsiz. "
        "Tiny accessibility icons with labels: rampa, asansör, erişilebilir tuvalet. "
        "Footer centered in one line exactly: — engelsizclub.com — "
        "No pity imagery, no children's faces, no medical equipment close-ups, no extra logos, "
        "no misspelled URL, no watermark besides the footer. High-end tourism poster layout, "
        "generous margins, readable type."
    )


def writer_brief(city: str) -> str:
    mark = LANDMARKS.get(city, f"{city}'s best-known castle or historic monument")
    title = headline(city)
    return f"""You write ONE detailed English image-generation prompt for Imagen.
Return only the prompt text. No markdown, no quotes around the whole prompt.

Poster must match this structure:
- Vertical 3:4 modern animated/illustrated travel poster (not a photo).
- Hero: {mark} for {city}, Turkey.
- Headline in large clear capital letters exactly: {title}
- Emphasis badge: Özel gereksinimli bireyler için ücretsiz
- MüzeKart note for state museums; disabled visitor + one companion free
- Accessibility details: rampa, asansör, erişilebilir tuvalet
- Footer exactly: — engelsizclub.com —
- Engelsiz Club greens (#1A6B4A), cream, gold. Inclusive, proud, not pity.
- No children's faces, no extra brand logos, no QR codes.
Keep all on-poster Turkish phrases exactly as given. Describe layout, lighting, and type hierarchy."""


def extract_text(payload: dict[str, Any]) -> str:
    cands = payload.get("candidates") or []
    if not cands:
        return ""
    parts = ((cands[0] or {}).get("content") or {}).get("parts") or []
    bits = [str(p.get("text") or "") for p in parts if isinstance(p, dict)]
    return "\n".join(bits).strip()


def gemini_writer_prompt(api_key: str, city: str) -> str:
    import requests

    brief = writer_brief(city)
    last_err = ""
    for model in TEXT_MODELS:
        try:
            url = GEMINI_GENERATE.format(model=model)
            res = requests.post(
                url,
                headers={
                    "x-goog-api-key": api_key,
                    "Content-Type": "application/json",
                },
                json={
                    "contents": [{"role": "user", "parts": [{"text": brief}]}],
                    "generationConfig": {"temperature": 0.4, "maxOutputTokens": 900},
                },
                timeout=45,
            )
            if res.status_code >= 400:
                last_err = f"{model} HTTP {res.status_code}"
                continue
            text = extract_text(res.json() if res.content else {})
            text = re.sub(r"^```(?:\w+)?\s*|\s*```$", "", text).strip()
            if len(text) > 80:
                print(f"prompt modeli: {model}")
                return text
            last_err = f"{model} kısa yanıt"
        except Exception as exc:  # noqa: BLE001
            last_err = f"{model} {type(exc).__name__}"
    print(f"metin prompt yedek şablon ({last_err})", file=sys.stderr)
    return fallback_imagen_prompt(city)


def imagen_sdk(api_key: str, prompt: str) -> bytes | None:
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return None
    try:
        client = genai.Client(api_key=api_key)
        cfg = types.GenerateImagesConfig(
            number_of_images=1,
            aspect_ratio="3:4",
            person_generation="DONT_ALLOW",
        )
        result = client.models.generate_images(
            model=IMAGEN_MODEL,
            prompt=prompt,
            config=cfg,
        )
        images = getattr(result, "generated_images", None) or []
        if not images:
            return None
        image = getattr(images[0], "image", None)
        if image is None:
            return None
        for attr in ("image_bytes", "data", "_bytes"):
            raw = getattr(image, attr, None)
            if raw:
                return bytes(raw)
    except Exception as exc:  # noqa: BLE001
        print(f"google-genai Imagen hata: {type(exc).__name__}", file=sys.stderr)
    return None


def imagen_rest(api_key: str, prompt: str) -> bytes | None:
    import base64

    import requests

    try:
        res = requests.post(
            IMAGEN_REST,
            params={"key": api_key},
            json={
                "instances": [{"prompt": prompt}],
                "parameters": {
                    "sampleCount": 1,
                    "aspectRatio": "3:4",
                    "personGeneration": "dont_allow",
                },
            },
            timeout=120,
        )
        if res.status_code >= 400:
            print(f"Imagen REST HTTP {res.status_code}", file=sys.stderr)
            return None
        preds = (res.json() or {}).get("predictions") or []
        if not preds:
            return None
        b64 = preds[0].get("bytesBase64Encoded") or preds[0].get("bytes")
        if not b64:
            return None
        return base64.b64decode(b64)
    except Exception as exc:  # noqa: BLE001
        print(f"Imagen REST hata: {type(exc).__name__}", file=sys.stderr)
        return None


def generate_image(api_key: str, prompt: str) -> bytes | None:
    png = imagen_sdk(api_key, prompt)
    if png:
        return png
    return imagen_rest(api_key, prompt)


def looks_jpeg(data: bytes) -> bool:
    return data.startswith(b"\xff\xd8")


def save_poster(dest: Path, data: bytes) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if looks_jpeg(data):
        dest.write_bytes(data)
        return dest
    png_path = dest.with_suffix(".png")
    png_path.write_bytes(data)
    # İstenen .jpg adı; PNG sihirli ise uzantıyı doğruya çevir.
    return png_path


def existing_poster(dest: Path) -> Path | None:
    if dest.exists():
        return dest
    png = dest.with_suffix(".png")
    if png.exists():
        return png
    return None


def generate_one(
    city: str,
    output_dir: Path,
    *,
    api_key: str,
    dry_run: bool,
    skip_existing: bool,
) -> str:
    """ok | skip | fail"""
    title = headline(city)
    dest = output_dir / poster_filename(city)
    print(f"il={city} baslik={title} dosya={dest.name}")

    if dry_run:
        print(fallback_imagen_prompt(city)[:400])
        return "ok"

    if skip_existing:
        found = existing_poster(dest)
        if found is not None:
            print(f"atlandi (var) {found}")
            return "skip"

    prompt = gemini_writer_prompt(api_key, city)
    data = generate_image(api_key, prompt)
    if not data:
        print(f"Imagen görsel üretmedi: {city}", file=sys.stderr)
        return "fail"

    saved = save_poster(dest, data)
    prompt_path = saved.with_suffix(".prompt.txt")
    prompt_path.write_text(prompt + "\n", encoding="utf-8")
    print(f"kaydedildi {saved} ({len(data)} bytes)")
    return "ok"


def write_github_output(*, cities: list[str], ok: int, fail: int, skip: int) -> None:
    gh_out = env("GITHUB_OUTPUT")
    if not gh_out:
        return
    last = cities[-1] if len(cities) == 1 else "ALL"
    with open(gh_out, "a", encoding="utf-8") as fh:
        fh.write(f"city={last}\n")
        fh.write(f"ok={ok}\n")
        fh.write(f"fail={fail}\n")
        fh.write(f"skip={skip}\n")
        fh.write(f"total={len(cities)}\n")


def delay_seconds() -> float:
    raw = env("POSTER_DELAY_SECONDS") or "8"
    try:
        return max(0.0, float(raw))
    except ValueError:
        return 8.0


def git_checkpoint(done: int) -> None:
    """Actions içinde her N ilden sonra output/ push; kesintide ilerleme kaybolmasın."""
    if env("GITHUB_ACTIONS") != "true":
        return
    raw = env("POSTER_CHECKPOINT_EVERY") or "0"
    try:
        every = int(raw)
    except ValueError:
        every = 0
    if every <= 0 or done % every != 0:
        return
    import subprocess

    add = subprocess.run(
        ["git", "add", "output/"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if add.returncode != 0:
        print(f"checkpoint add hata: {add.stderr}", file=sys.stderr)
        return
    staged = subprocess.run(
        ["git", "diff", "--staged", "--quiet"],
        cwd=REPO_ROOT,
        check=False,
    )
    if staged.returncode == 0:
        return
    subprocess.run(
        [
            "git",
            "commit",
            "-m",
            f"WIP city museum posters ({done} cities).",
        ],
        cwd=REPO_ROOT,
        check=False,
    )
    push = subprocess.run(["git", "push"], cwd=REPO_ROOT, check=False)
    if push.returncode == 0:
        print(f"checkpoint push ({done})")


def run(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Engelsiz Club city museum poster")
    parser.add_argument(
        "--city",
        default=env("CITY_NAME"),
        help="Boş / ALL / * = 81 il. Tek il adı = yalnız o il.",
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)

    try:
        cities = cities_from_input(args.city)
    except ValueError as exc:
        print(exc, file=sys.stderr)
        return 2

    dry_run = bool(args.dry_run)
    skip_existing = env("POSTER_SKIP_EXISTING").lower() not in {"0", "false", "no"}
    wait = delay_seconds()
    print(f"sehir_sayisi={len(cities)} ilk={cities[0]} son={cities[-1]}")

    api_key = ""
    if not dry_run:
        api_key = env("GEMINI_API_KEY") or env("AI_API_KEY")
        if not api_key:
            print("GEMINI_API_KEY yok.", file=sys.stderr)
            return 1

    ok = skip = fail = 0
    for i, city in enumerate(cities):
        print(f"[{i + 1}/{len(cities)}] {city}")
        try:
            status = generate_one(
                city,
                args.output_dir,
                api_key=api_key,
                dry_run=dry_run,
                skip_existing=skip_existing,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"{city} hata: {type(exc).__name__}: {exc}", file=sys.stderr)
            status = "fail"
        if status == "ok":
            ok += 1
        elif status == "skip":
            skip += 1
        else:
            fail += 1
            print(f"devam (tek il başarısız): {city}")
        if not dry_run:
            git_checkpoint(i + 1)
        if i + 1 < len(cities) and not dry_run and status != "skip":
            time.sleep(wait)

    print(f"ozet ok={ok} skip={skip} fail={fail} total={len(cities)}")
    write_github_output(cities=cities, ok=ok, fail=fail, skip=skip)
    if ok + skip == 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
