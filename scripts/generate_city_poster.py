#!/usr/bin/env python3
"""81 il için Engelsiz Club müze gezi rehberi posteri.

CITY_NAME boş / ALL / * → kCityNames sırasıyla 81 il.
Tek il adı (veya Antep/Urfa/Maraş) → yalnız o il.
Kayıt: output/{il}_muze_gezisi_{YYYY-MM-DD}.jpg
API anahtarı yazdırılmaz.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import traceback
import unicodedata
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

# Metin: Google AI Studio (gemini-2.0-flash 2026-06-01'de kapatıldı → 404).
TEXT_MODELS = (
    "gemini-2.5-flash",
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-flash-latest",
    "gemini-2.5-flash-lite",
)
# Görsel: 2026 docs Interactions API (generate_content artık görsel dönmeyebilir).
# gemini-3.1-flash-image = Nano Banana 2; lite = hızlı; 2.5 = eski Nano Banana.
IMAGE_MODELS = (
    "gemini-3.1-flash-image",
    "gemini-3.1-flash-lite-image",
    "gemini-2.5-flash-image",
    "gemini-3-pro-image",
)
INTERACTIONS_URLS = (
    "https://generativelanguage.googleapis.com/v1beta/interactions",
    "https://generativelanguage.googleapis.com/v1/interactions",
)
API_VERSIONS = ("v1beta", "v1")

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = REPO_ROOT / "output"
GITHUB_RAW_OUTPUT = (
    "https://raw.githubusercontent.com/Metehanxpvl/engelsizclub/main/output"
)
POSTER_FILE_RE = re.compile(
    r"^([a-z0-9]+)_muze_gezisi_(\d{4}-\d{2}-\d{2})\.(jpg|jpeg|png)$",
    re.IGNORECASE,
)

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


def generate_content_urls(model: str) -> tuple[str, ...]:
    return tuple(
        f"https://generativelanguage.googleapis.com/{ver}/models/{model}:generateContent"
        for ver in API_VERSIONS
    )


def env(name: str) -> str:
    return os.environ.get(name, "").strip()


_LAST_IMAGE_ERROR = ""
_GEMINI_FAIL_STREAK = 0


def note_image_error(msg: str) -> None:
    global _LAST_IMAGE_ERROR
    text = (msg or "").strip()[:400]
    if not text:
        return
    _LAST_IMAGE_ERROR = text
    print(text, file=sys.stderr)


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
    return f"""You write ONE detailed English image-generation prompt.
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


def _clean_writer_text(text: str) -> str:
    return re.sub(r"^```(?:\w+)?\s*|\s*```$", "", (text or "").strip()).strip()


def gemini_writer_prompt_sdk(api_key: str, city: str) -> str:
    try:
        from google import genai
        from google.genai import types
    except ImportError:
        return ""
    brief = writer_brief(city)
    try:
        client = genai.Client(api_key=api_key)
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        return ""
    for model in TEXT_MODELS:
        try:
            response = client.models.generate_content(
                model=model,
                contents=brief,
                config=types.GenerateContentConfig(
                    temperature=0.4,
                    max_output_tokens=900,
                ),
            )
            text = _clean_writer_text(getattr(response, "text", None) or "")
            if len(text) > 80:
                print(f"prompt modeli: {model}")
                return text
            print(f"{model} kısa yanıt", file=sys.stderr)
        except Exception:  # noqa: BLE001
            print(f"metin generate_content hata: {model}", file=sys.stderr)
            traceback.print_exc()
    return ""


def gemini_writer_prompt_rest(api_key: str, city: str) -> str:
    try:
        import requests
    except ImportError:
        return ""
    brief = writer_brief(city)
    for model in TEXT_MODELS:
        for url in generate_content_urls(model):
            try:
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
                    print(f"{model} HTTP {res.status_code} {url}", file=sys.stderr)
                    continue
                text = _clean_writer_text(extract_text(res.json() if res.content else {}))
                if len(text) > 80:
                    print(f"prompt modeli: {model}")
                    return text
            except Exception:  # noqa: BLE001
                print(f"metin REST hata: {model}", file=sys.stderr)
                traceback.print_exc()
    return ""


def gemini_writer_prompt(api_key: str, city: str) -> str:
    text = gemini_writer_prompt_sdk(api_key, city)
    if text:
        return text
    text = gemini_writer_prompt_rest(api_key, city)
    if text:
        return text
    print("metin prompt yedek şablon", file=sys.stderr)
    return fallback_imagen_prompt(city)


def _as_bytes(data: Any) -> bytes | None:
    if data is None:
        return None
    if isinstance(data, (bytes, bytearray, memoryview)):
        raw = bytes(data)
        return raw or None
    if isinstance(data, str) and data.strip():
        import base64

        try:
            return base64.b64decode(data)
        except Exception:  # noqa: BLE001
            return None
    return None


def extract_inline_image_bytes(response: Any) -> bytes | None:
    """google-genai generate_content yanıtından ilk inline görseli al."""
    parts: list[Any] = []
    if isinstance(response, dict):
        top_parts = response.get("parts")
        cands = response.get("candidates") or []
    else:
        top_parts = getattr(response, "parts", None)
        cands = getattr(response, "candidates", None) or []
    if top_parts:
        parts.extend(list(top_parts))
    for cand in cands:
        if isinstance(cand, dict):
            nested = ((cand.get("content") or {}) or {}).get("parts") or []
            parts.extend(nested)
            continue
        content = getattr(cand, "content", None)
        cand_parts = getattr(content, "parts", None) if content is not None else None
        if cand_parts:
            parts.extend(list(cand_parts))
    seen: set[int] = set()
    for part in parts:
        ident = id(part)
        if ident in seen:
            continue
        seen.add(ident)
        inline = None
        if isinstance(part, dict):
            inline = part.get("inline_data") or part.get("inlineData")
        else:
            inline = getattr(part, "inline_data", None) or getattr(part, "inlineData", None)
        if inline is None:
            continue
        data = None
        if isinstance(inline, dict):
            data = inline.get("data") or inline.get("image_bytes")
        else:
            data = getattr(inline, "data", None) or getattr(inline, "image_bytes", None)
        raw = _as_bytes(data)
        if raw:
            return raw
        as_image = getattr(part, "as_image", None)
        if callable(as_image):
            try:
                image = as_image()
                for attr in ("image_bytes", "data", "_bytes"):
                    raw = _as_bytes(getattr(image, attr, None) if image is not None else None)
                    if raw:
                        return raw
            except Exception:  # noqa: BLE001
                continue
    return None


def extract_inline_image_bytes_rest(payload: dict[str, Any]) -> bytes | None:
    return extract_inline_image_bytes(
        {
            "candidates": payload.get("candidates") or [],
        }
    )


def build_image_gen_config(modalities: list[str] | None = None) -> Any:
    """Nano Banana docs: IMAGE-only. TEXT+IMAGE is a fallback."""
    from google.genai import types

    mods = list(modalities or ["IMAGE"])
    kwargs: dict[str, Any] = {"response_modalities": mods}
    image_config_cls = getattr(types, "ImageConfig", None)
    if image_config_cls is not None:
        try:
            kwargs["image_config"] = image_config_cls(aspect_ratio="3:4")
        except TypeError:
            pass
    try:
        return types.GenerateContentConfig(**kwargs)
    except TypeError:
        return types.GenerateContentConfig(response_modalities=mods)


def _log_finish_reason(response: Any, model: str) -> None:
    try:
        cands = getattr(response, "candidates", None) or []
        if not cands:
            print(f"{model} generate_content görsel yok (aday yok)", file=sys.stderr)
            return
        cand = cands[0]
        reason = (
            cand.get("finishReason") or cand.get("finish_reason")
            if isinstance(cand, dict)
            else getattr(cand, "finish_reason", None)
        )
        print(f"{model} generate_content görsel yok finish={reason}", file=sys.stderr)
    except Exception:  # noqa: BLE001
        print(f"{model} generate_content görsel yok", file=sys.stderr)


def extract_interaction_image_bytes(payload: Any) -> bytes | None:
    """interactions.create / REST yanıtından görsel al."""
    if payload is None:
        return None
    img = getattr(payload, "output_image", None)
    if img is None and isinstance(payload, dict):
        img = payload.get("output_image") or payload.get("outputImage")
    raw = None
    if img is not None:
        if isinstance(img, dict):
            raw = _as_bytes(img.get("data") or img.get("image_bytes"))
        else:
            raw = _as_bytes(getattr(img, "data", None) or getattr(img, "image_bytes", None))
        if raw:
            return raw
    if not isinstance(payload, dict):
        payload = {
            "steps": getattr(payload, "steps", None),
            "outputs": getattr(payload, "outputs", None),
        }
    for step in payload.get("steps") or []:
        if isinstance(step, dict):
            blocks = step.get("content") or step.get("contents") or []
        else:
            blocks = getattr(step, "content", None) or []
        for block in blocks or []:
            btype = (
                block.get("type")
                if isinstance(block, dict)
                else getattr(block, "type", "")
            )
            if str(btype).lower() not in {"image", "image_blob", "inline_image"}:
                continue
            data = (
                block.get("data")
                if isinstance(block, dict)
                else getattr(block, "data", None)
            )
            raw = _as_bytes(data)
            if raw:
                return raw
    return extract_inline_image_bytes(payload)


def generate_image_interactions_sdk(api_key: str, prompt: str) -> bytes | None:
    try:
        from google import genai
    except ImportError:
        return None
    try:
        client = genai.Client(api_key=api_key)
        create = getattr(getattr(client, "interactions", None), "create", None)
    except Exception as exc:  # noqa: BLE001
        note_image_error(f"interactions client: {exc}")
        return None
    if not callable(create):
        return None
    for model in IMAGE_MODELS:
        try:
            interaction = create(model=model, input=prompt)
            data = extract_interaction_image_bytes(interaction)
            if data:
                print(f"görsel modeli: {model} (interactions)")
                return data
            note_image_error(f"{model} interactions görsel yok")
        except Exception as exc:  # noqa: BLE001
            note_image_error(f"{model} interactions hata: {exc}")
    return None


def generate_image_interactions_rest(api_key: str, prompt: str) -> bytes | None:
    try:
        import requests
    except ImportError:
        return None
    for model in IMAGE_MODELS:
        body = {
            "model": model,
            "input": [{"type": "text", "text": prompt}],
        }
        for url in INTERACTIONS_URLS:
            try:
                res = requests.post(
                    url,
                    headers={
                        "x-goog-api-key": api_key,
                        "Content-Type": "application/json",
                    },
                    json=body,
                    timeout=120,
                )
                if res.status_code >= 400:
                    snippet = (res.text or "").replace("\n", " ")[:220]
                    note_image_error(
                        f"{model} interactions HTTP {res.status_code} {snippet}"
                    )
                    continue
                data = extract_interaction_image_bytes(
                    res.json() if res.content else {}
                )
                if data:
                    print(f"görsel modeli: {model} (interactions REST)")
                    return data
                note_image_error(f"{model} interactions REST görsel yok")
            except Exception as exc:  # noqa: BLE001
                note_image_error(f"{model} interactions REST hata: {exc}")
    return None


def generate_image_sdk(api_key: str, prompt: str) -> bytes | None:
    try:
        from google import genai
    except ImportError:
        print("google-genai yok", file=sys.stderr)
        return None
    try:
        client = genai.Client(api_key=api_key)
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        return None
    configs: list[Any] = []
    for mods in (["IMAGE"], ["TEXT", "IMAGE"]):
        try:
            configs.append(build_image_gen_config(mods))
        except Exception:  # noqa: BLE001
            traceback.print_exc()
    if not configs:
        return None
    for model in IMAGE_MODELS:
        for cfg in configs:
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=cfg,
                )
                data = extract_inline_image_bytes(response)
                if data:
                    print(f"görsel modeli: {model}")
                    return data
                _log_finish_reason(response, model)
            except Exception:  # noqa: BLE001
                print(f"görsel generate_content hata: {model}", file=sys.stderr)
                traceback.print_exc()
    return None


def generate_image_rest(api_key: str, prompt: str) -> bytes | None:
    """generateContent REST yedek (Interactions yoksa)."""
    try:
        import requests
    except ImportError:
        return None
    modality_sets = (["TEXT", "IMAGE"], ["IMAGE"])
    configs = (
        {"responseModalities": None},  # placeholder, filled below
    )
    for model in IMAGE_MODELS:
        for url in generate_content_urls(model):
            for modalities in modality_sets:
                for with_ratio in (False, True):
                    gen: dict[str, Any] = {"responseModalities": modalities}
                    if with_ratio:
                        gen["imageConfig"] = {"aspectRatio": "3:4"}
                    body = {
                        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
                        "generationConfig": gen,
                    }
                    try:
                        res = requests.post(
                            url,
                            headers={
                                "x-goog-api-key": api_key,
                                "Content-Type": "application/json",
                            },
                            json=body,
                            timeout=120,
                        )
                        if res.status_code >= 400:
                            snippet = (res.text or "").replace("\n", " ")[:220]
                            note_image_error(
                                f"{model} generateContent HTTP {res.status_code} {snippet}"
                            )
                            continue
                        data = extract_inline_image_bytes_rest(
                            res.json() if res.content else {}
                        )
                        if data:
                            print(f"görsel modeli: {model} (REST)")
                            return data
                        note_image_error(f"{model} REST görsel yok")
                    except Exception as exc:  # noqa: BLE001
                        note_image_error(f"{model} REST hata: {exc}")
    return None


def generate_image(api_key: str, prompt: str) -> bytes | None:
    data = generate_image_interactions_sdk(api_key, prompt)
    if data:
        return data
    data = generate_image_interactions_rest(api_key, prompt)
    if data:
        return data
    data = generate_image_sdk(api_key, prompt)
    if data:
        return data
    return generate_image_rest(api_key, prompt)


def looks_jpeg(data: bytes) -> bool:
    return data.startswith(b"\xff\xd8")


def _poster_font(size: int):
    from PIL import ImageFont

    for path in (
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
        "C:\\Windows\\Fonts\\segoeui.ttf",
        "C:\\Windows\\Fonts\\arial.ttf",
    ):
        if Path(path).is_file():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def _wrap_text(draw, text: str, font, max_width: int) -> list[str]:
    words = (text or "").split()
    if not words:
        return [""]
    lines: list[str] = []
    current = words[0]
    for word in words[1:]:
        trial = f"{current} {word}"
        bbox = draw.textbbox((0, 0), trial, font=font)
        if bbox[2] - bbox[0] <= max_width:
            current = trial
        else:
            lines.append(current)
            current = word
    lines.append(current)
    return lines


def render_fallback_poster(city: str) -> bytes:
    """Gemini görsel veremezse yerel 3:4 Engelsiz Club posteri."""
    from io import BytesIO

    from PIL import Image, ImageDraw

    w, h = 768, 1024
    img = Image.new("RGB", (w, h), "#0F3D2C")
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, w, int(h * 0.42)), fill="#1A6B4A")
    draw.ellipse((-120, -160, 320, 280), fill="#2F9B6A")
    draw.rounded_rectangle((48, 220, w - 48, h - 88), radius=28, fill="#F2F7F4")
    title_font = _poster_font(42)
    sub_font = _poster_font(28)
    body_font = _poster_font(22)
    foot_font = _poster_font(20)
    title = headline(city)
    max_w = w - 120
    y = 260
    for line in _wrap_text(draw, title, title_font, max_w):
        bbox = draw.textbbox((0, 0), line, font=title_font)
        tw = bbox[2] - bbox[0]
        draw.text(((w - tw) / 2, y), line, font=title_font, fill="#1A6B4A")
        y += 52
    y += 16
    badge = "Özel gereksinimli bireyler için ücretsiz"
    for line in _wrap_text(draw, badge, sub_font, max_w):
        bbox = draw.textbbox((0, 0), line, font=sub_font)
        tw = bbox[2] - bbox[0]
        draw.text(((w - tw) / 2, y), line, font=sub_font, fill="#B45309")
        y += 36
    y += 18
    details = (
        "MüzeKart devlet müzelerinde geçerli. "
        "Engelli ziyaretçi ve bir refakatçi ücretsiz. "
        "Rampa · asansör · erişilebilir tuvalet"
    )
    for line in _wrap_text(draw, details, body_font, max_w):
        bbox = draw.textbbox((0, 0), line, font=body_font)
        tw = bbox[2] - bbox[0]
        draw.text(((w - tw) / 2, y), line, font=body_font, fill="#334155")
        y += 32
    footer = "— engelsizclub.com —"
    bbox = draw.textbbox((0, 0), footer, font=foot_font)
    tw = bbox[2] - bbox[0]
    draw.text(((w - tw) / 2, h - 58), footer, font=foot_font, fill="#F2F7F4")
    buf = BytesIO()
    img.save(buf, format="JPEG", quality=86, optimize=True)
    return buf.getvalue()


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
    global _GEMINI_FAIL_STREAK
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

    prompt = fallback_imagen_prompt(city)
    try:
        data = None
        if _GEMINI_FAIL_STREAK < 2:
            data = generate_image(api_key, prompt)
            if data:
                _GEMINI_FAIL_STREAK = 0
            else:
                _GEMINI_FAIL_STREAK += 1
                print(
                    f"Gemini görsel yok ({_GEMINI_FAIL_STREAK}/2), yerel poster: {city}",
                    file=sys.stderr,
                )
        if not data:
            data = render_fallback_poster(city)
            print(f"yerel poster {city} ({len(data)} bytes)")
    except Exception:  # noqa: BLE001
        print(f"görsel üretim istisnası: {city}", file=sys.stderr)
        traceback.print_exc()
        try:
            data = render_fallback_poster(city)
            print(f"yerel poster (istisna sonrası) {city}")
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            return "fail"
    if not data:
        print(f"görsel üretmedi: {city}", file=sys.stderr)
        return "fail"

    try:
        saved = save_poster(dest, data)
        prompt_path = saved.with_suffix(".prompt.txt")
        prompt_path.write_text(prompt + "\n", encoding="utf-8")
    except Exception:  # noqa: BLE001
        print(f"kayıt istisnası: {city}", file=sys.stderr)
        traceback.print_exc()
        return "fail"
    print(f"kaydedildi {saved} ({len(data)} bytes)")
    return "ok"


def scan_output_posters(output_dir: Path) -> list[dict[str, str]]:
    """output/*_muze_gezisi_YYYY-MM-DD.jpg|png — aynı il için en yeni tarih."""
    slug_to_city = {slug_city(c): c for c in CITIES}
    best: dict[str, dict[str, str]] = {}
    if not output_dir.is_dir():
        return []
    for path in output_dir.iterdir():
        if not path.is_file():
            continue
        match = POSTER_FILE_RE.match(path.name)
        if not match:
            continue
        slug = match.group(1).lower()
        day = match.group(2)
        prev = best.get(slug)
        if prev is not None and day < prev["date"]:
            continue
        best[slug] = {
            "city": slug_to_city.get(slug, slug),
            "slug": slug,
            "file": path.name,
            "date": day,
            "url": f"{GITHUB_RAW_OUTPUT}/{path.name}",
        }
    order = {slug_city(c): i for i, c in enumerate(CITIES)}
    return sorted(best.values(), key=lambda row: order.get(row["slug"], 999))


def write_index(
    output_dir: Path,
    *,
    ok: int,
    fail: int,
    skip: int,
    total: int,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)
    posters = scan_output_posters(output_dir)
    payload = {
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "ok": ok,
        "fail": fail,
        "skip": skip,
        "total": total,
        "status": "ok" if posters else "empty",
        "error": _LAST_IMAGE_ERROR or None,
        "posters": posters,
    }
    dest = output_dir / "index.json"
    dest.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"index yazildi {dest} poster={len(posters)}")
    return dest


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
            try:
                write_index(
                    args.output_dir,
                    ok=0,
                    fail=len(cities),
                    skip=0,
                    total=len(cities),
                )
            except Exception:  # noqa: BLE001
                traceback.print_exc()
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
        except Exception:  # noqa: BLE001
            print(f"{city} hata (devam)", file=sys.stderr)
            traceback.print_exc()
            status = "fail"
        if status == "ok":
            ok += 1
        elif status == "skip":
            skip += 1
        else:
            fail += 1
            print(f"devam (tek il başarısız): {city}")
        if not dry_run:
            try:
                write_index(
                    args.output_dir,
                    ok=ok,
                    fail=fail,
                    skip=skip,
                    total=len(cities),
                )
                git_checkpoint(i + 1)
            except Exception:  # noqa: BLE001
                traceback.print_exc()
        if i + 1 < len(cities) and not dry_run and status != "skip":
            if _GEMINI_FAIL_STREAK >= 2:
                time.sleep(0.05)
            else:
                time.sleep(wait)

    print(f"ozet ok={ok} skip={skip} fail={fail} total={len(cities)}")
    try:
        write_index(
            args.output_dir,
            ok=ok,
            fail=fail,
            skip=skip,
            total=len(cities),
        )
    except Exception:  # noqa: BLE001
        traceback.print_exc()
    try:
        write_github_output(cities=cities, ok=ok, fail=fail, skip=skip)
    except Exception:  # noqa: BLE001
        traceback.print_exc()
    if fail and ok + skip == 0:
        print("hiç poster üretilmedi.", file=sys.stderr)
        return 1
    posters = scan_output_posters(args.output_dir)
    if not posters:
        print("output/ içinde jpg/png yok; job başarısız.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
