#!/usr/bin/env python3
"""AVM çocuk/aile etkinlik scraper → public.events + public.etkinlikler.

Kaynak listesi: scripts/avm_sources.json (şehir + AVM + public URL).
Sayfa HTML'i sade metne çevrilir, Gemini yalnızca çocuk/aile etkinliklerini
JSON dizi olarak çıkarır. Görsel: etkinlik kartı fotoğrafı varsa o, yoksa
AVM sayfasının og:image / twitter:image / hero kapağı (küçük logo/sprite atlanır).
Upsert: events unique (city, avm_name, event_name,
event_date). Etkinlikler sayfası public.etkinlikler okuduğu için aynı kayıt
source='avm_scrape' + external_id (sha256) ile oraya senkronlanır.

Kullanıcı düzenlemesi (user_edited) ve silinen external_id'ler ezilmez.

Env (asla loglama):
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY  (veya SUPABASE_SERVICE_KEY)
  GEMINI_API_KEY

Yerel:
  pip install -r scripts/requirements-avm.txt
  python scripts/avm_scraper.py
  python scripts/avm_scraper.py --dry-run
  python scripts/avm_scraper.py --max-sources 2
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import random
import re
import sys
import time
from datetime import date
from pathlib import Path
from typing import Any, NamedTuple
from urllib.parse import urljoin, urlparse

import httpx
from bs4 import BeautifulSoup

# Optional: playwright for JS-rendered SPA pages
try:
    from playwright.sync_api import sync_playwright  # type: ignore[import-untyped]

    HAS_PLAYWRIGHT = True
except ImportError:
    HAS_PLAYWRIGHT = False

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
SOURCES_PATH = SCRIPT_DIR / "avm_sources.json"

USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
)
FETCH_TIMEOUT = 30.0
FETCH_RETRIES = 3
RETRY_HTTP_STATUS = {429, 502, 503, 504}
GEMINI_TIMEOUT = 45.0
DELAY_MIN = 1.0
DELAY_MAX = 2.0
MAX_HTML_BYTES = 1_800_000
CHUNK_CHARS = 12_000
CHUNK_OVERLAP = 400
SOURCE_TAG = "avm_scrape"
SORT_FLOOR = 1000

GEMINI_MODELS = (
    "gemini-flash-latest",
    "gemini-3.8-flash",
    "gemini-flash-lite-latest",
)

SKIP_STATUS = {401, 403, 404, 410, 429, 500, 502, 503, 504}

_TR_MONTHS = (
    "",
    "Ocak",
    "Şubat",
    "Mart",
    "Nisan",
    "Mayıs",
    "Haziran",
    "Temmuz",
    "Ağustos",
    "Eylül",
    "Ekim",
    "Kasım",
    "Aralık",
)


def _today_tr() -> str:
    d = date.today()
    return f"{d.day} {_TR_MONTHS[d.month]} {d.year}"


def _load_dotenv() -> None:
    path = ROOT / ".env"
    if not path.is_file():
        return
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        if not key or key in os.environ:
            continue
        val = val.strip().strip("'").strip('"')
        os.environ[key] = val


def _env(name: str, *alts: str) -> str:
    for key in (name, *alts):
        val = (os.environ.get(key) or "").strip()
        if val:
            return val
    return ""


_CANONICAL_SUPABASE_URL = "https://qycrkqwqrysypvqaipqn.supabase.co"
_TYPO_HOST = "qycrkqwqrysypvqipqn.supabase.co"


def _normalize_supabase_url(raw: str) -> str:
    """Trim, ensure https://, strip trailing slash; rewrite known typo host."""
    s = (raw or "").strip()
    if not s:
        return s
    if not re.match(r"^https?://", s, flags=re.I):
        s = f"https://{s}"
    s = s.rstrip("/")
    host = (urlparse(s).hostname or "").lower()
    if not host:
        host = s.split("://", 1)[-1].split("/", 1)[0].lower()
    has_typo = host == _TYPO_HOST or (
        "ypvqipqn" in host and "ypvqaipqn" not in host
    )
    if has_typo:
        print("Using corrected SUPABASE_URL host", flush=True)
        return _CANONICAL_SUPABASE_URL
    return s


def _redact_error(msg: str) -> str:
    msg = re.sub(r"key=[^&\s]+", "key=REDACTED", msg, flags=re.I)
    msg = re.sub(r"Bearer\s+\S+", "Bearer REDACTED", msg, flags=re.I)
    msg = re.sub(r"AIza[0-9A-Za-z_\-]{10,}", "REDACTED", msg)
    return msg


def polite_sleep() -> None:
    time.sleep(random.uniform(DELAY_MIN, DELAY_MAX))


def normalize_ws(value: str) -> str:
    return re.sub(r"\s+", " ", (value or "").strip())


def external_id(city: str, avm: str, name: str, event_date: str) -> str:
    raw = "|".join(
        normalize_ws(x) for x in (city, avm, name, event_date)
    )
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def html_to_text(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    for tag in soup(["script", "style", "noscript", "svg", "iframe", "form"]):
        tag.decompose()
    lines = []
    for ln in soup.get_text("\n").splitlines():
        cleaned = normalize_ws(ln)
        if cleaned:
            lines.append(cleaned)
    return "\n".join(lines)


# Tiny logos / sprites / social icons — not usable as an event cover.
_SKIP_IMAGE_URL = re.compile(
    r"(?:^|/)(?:logos?|icons?|favicons?|sprites?|pixels?|"
    r"tracking|badges?|buttons?|arrows?|social)(?:[-_/.\?]|$)|"
    r"(?:favicon|apple-touch|android-chrome|mstile)|"
    r"(?:whatsapp|facebook|instagram|linkedin|pinterest|tiktok|youtube)"
    r"[-_/](?:icon|logo)?|"
    r"\b(?:16x16|32x32|48x48|64x64|96x96|128x128)\b|"
    r"spacer|blank\.gif|1x1\.(?:gif|png|jpg)",
    re.I,
)
_SKIP_IMAGE_EXT = re.compile(r"\.(?:svg|ico|gif|mp4|webm|m4v)(?:\?|$)", re.I)
_PHOTO_EXT = re.compile(r"\.(?:jpe?g|png|webp|avif)(?:\?|$)", re.I)
_SKIP_IMAGE_URL = re.compile(
    r"(?:^|/)(?:logos?|icons?|favicons?|sprites?|pixels?|"
    r"tracking|badges?|buttons?|arrows?|social)(?:[-_/.\?]|$)|"
    r"(?:favicon|apple-touch|android-chrome|mstile)|"
    r"(?:whatsapp|facebook|instagram|linkedin|pinterest|tiktok|youtube)"
    r"[-_/](?:icon|logo)?|"
    r"\b(?:16x16|32x32|48x48|64x64|96x96|128x128)\b|"
    r"spacer|blank\.gif|1x1\.(?:gif|png|jpg)|"
    r"dummy\.png|transparent\.png|facebook\.png|event-offer-m\.png|"
    r"hugedomains|holder\.js|_logo\.png|/logo\.png",
    re.I,
)
_PHOTO_HINT = re.compile(
    r"hero|banner|slider|swiper|carousel|cover|gallery|etkinlik|event|"
    r"kampanya|campaign|aktivite|activity|haber|duyuru|featured|"
    r"og-image|main[-_]?img|visual|photo|gorsel|görsel|slide",
    re.I,
)
_EVENT_HINT = re.compile(
    r"etkinlik|event|kampanya|campaign|aktivite|workshop|atoly|atöly|"
    r"masal|cocuk|çocuk|aile|family|kids",
    re.I,
)
_BG_URL = re.compile(r"url\((['\"]?)(.+?)\1\)", re.I)
_DIM_ATTR = re.compile(r"(\d{2,5})\s*[x×]\s*(\d{2,5})", re.I)


def _abs_http(raw: str, base_url: str) -> str:
    if not raw or raw.startswith("data:"):
        return ""
    abs_url = urljoin(base_url, raw.strip())
    if abs_url.startswith("http://") or abs_url.startswith("https://"):
        return abs_url
    return ""


def _looks_like_photo_url(url: str) -> bool:
    if not url:
        return False
    path = urlparse(url).path.lower()
    if _SKIP_IMAGE_EXT.search(path) or _SKIP_IMAGE_EXT.search(url):
        return False
    if _SKIP_IMAGE_URL.search(url):
        return False
    if not _PHOTO_EXT.search(path):
        return False
    return True


def _int_attr(tag: Any, *names: str) -> int:
    for name in names:
        raw = (tag.get(name) or "").strip()
        if not raw:
            continue
        m = re.search(r"(\d{2,5})", raw)
        if m:
            try:
                return int(m.group(1))
            except ValueError:
                continue
    return 0


def _best_from_srcset(srcset: str, base_url: str) -> str:
    best_url = ""
    best_w = -1
    for part in (srcset or "").split(","):
        bits = part.strip().split()
        if not bits:
            continue
        url = _abs_http(bits[0], base_url)
        if not url:
            continue
        width = 0
        if len(bits) > 1:
            token = bits[-1].lower()
            if token.endswith("w"):
                try:
                    width = int(token[:-1])
                except ValueError:
                    width = 0
            elif token.endswith("x"):
                try:
                    width = int(float(token[:-1]) * 800)
                except ValueError:
                    width = 0
        if width >= best_w and _looks_like_photo_url(url):
            best_w = width
            best_url = url
    return best_url


def _tag_image_url(tag: Any, base_url: str) -> str:
    for attr in (
        "srcset",
        "data-srcset",
        "data-lazy-srcset",
    ):
        raw = (tag.get(attr) or "").strip()
        if raw:
            hit = _best_from_srcset(raw, base_url)
            if hit:
                return hit
    for attr in (
        "src",
        "data-src",
        "data-lazy-src",
        "data-original",
        "data-bg",
        "data-background",
        "data-image",
        "data-src-large",
        "content",
    ):
        raw = (tag.get(attr) or "").strip()
        if raw:
            url = _abs_http(raw, base_url)
            if url and _looks_like_photo_url(url):
                return url
    style = tag.get("style") or ""
    m = _BG_URL.search(style)
    if m:
        url = _abs_http(m.group(2), base_url)
        if url and _looks_like_photo_url(url):
            return url
    return ""


def _score_image(
    url: str,
    *,
    kind: str,
    width: int = 0,
    height: int = 0,
    hint: str = "",
) -> int:
    if not _looks_like_photo_url(url):
        return 0
    score = {
        "og": 100,
        "twitter": 92,
        "jsonld": 88,
        "link": 80,
        "hero": 72,
        "event": 78,
        "img": 40,
    }.get(kind, 30)
    if width and height:
        if min(width, height) < 80:
            return 0
        if min(width, height) >= 400:
            score += 18
        elif min(width, height) >= 240:
            score += 10
        if width >= 600:
            score += 8
    elif _DIM_ATTR.search(url):
        m = _DIM_ATTR.search(url)
        if m and min(int(m.group(1)), int(m.group(2))) < 80:
            return 0
    if hint and _PHOTO_HINT.search(hint):
        score += 16
    if hint and _EVENT_HINT.search(hint):
        score += 12
    path = urlparse(url).path.lower()
    if any(path.endswith(ext) for ext in (".jpg", ".jpeg", ".webp", ".avif")):
        score += 6
    return score


def _walk_jsonld_images(node: Any) -> list[str]:
    out: list[str] = []
    if isinstance(node, str):
        if node.startswith("http"):
            out.append(node)
        return out
    if isinstance(node, list):
        for item in node:
            out.extend(_walk_jsonld_images(item))
        return out
    if not isinstance(node, dict):
        return out
    for key in ("image", "thumbnailUrl", "thumbnail", "photo", "contentUrl"):
        if key in node:
            out.extend(_walk_jsonld_images(node[key]))
    if node.get("@type") == "ImageObject" and node.get("url"):
        out.append(str(node["url"]))
    for key, val in node.items():
        if key in ("image", "thumbnailUrl", "thumbnail", "photo", "contentUrl", "url"):
            continue
        if isinstance(val, (dict, list)):
            out.extend(_walk_jsonld_images(val))
    return out


def _nearby_text(tag: Any, limit: int = 280) -> str:
    parent = tag
    for _ in range(5):
        if parent is None:
            break
        text = normalize_ws(parent.get_text(" ", strip=True))
        alt = normalize_ws(
            " ".join(
                filter(
                    None,
                    [
                        tag.get("alt") if parent is tag else "",
                        tag.get("title") if parent is tag else "",
                    ],
                )
            )
        )
        blob = normalize_ws(f"{alt} {text}")
        if len(blob) > 12:
            return blob[:limit]
        parent = getattr(parent, "parent", None)
    return ""


class ImageCandidate:
    __slots__ = ("url", "score", "text")

    def __init__(self, url: str, score: int, text: str = "") -> None:
        self.url = url
        self.score = score
        self.text = text


def extract_image_candidates(html: str, base_url: str) -> list[ImageCandidate]:
    """Rank usable photos from a mall page (og/twitter/json-ld/hero/event cards)."""
    soup = BeautifulSoup(html, "html.parser")
    found: dict[str, ImageCandidate] = {}

    def add(url: str, score: int, text: str = "") -> None:
        if not url or score <= 0:
            return
        prev = found.get(url)
        if prev is None or score > prev.score:
            found[url] = ImageCandidate(url, score, text)

    for prop, kind in (
        ("og:image", "og"),
        ("og:image:url", "og"),
        ("og:image:secure_url", "og"),
        ("twitter:image", "twitter"),
        ("twitter:image:src", "twitter"),
    ):
        tag = soup.find("meta", attrs={"property": prop}) or soup.find(
            "meta", attrs={"name": prop}
        )
        if not tag:
            continue
        url = _abs_http((tag.get("content") or "").strip(), base_url)
        add(url, _score_image(url, kind=kind), prop)

    for link in soup.find_all("link"):
        rel = " ".join(link.get("rel") or []).lower()
        if "image_src" in rel or (
            "preload" in rel and (link.get("as") or "").lower() == "image"
        ):
            url = _abs_http((link.get("href") or "").strip(), base_url)
            add(url, _score_image(url, kind="link"), rel)

    for script in soup.find_all("script", attrs={"type": "application/ld+json"}):
        raw = script.string or script.get_text() or ""
        if not raw.strip():
            continue
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            continue
        for raw_url in _walk_jsonld_images(data):
            url = _abs_http(raw_url, base_url)
            add(url, _score_image(url, kind="jsonld"), "jsonld")

    for img in soup.find_all(["img", "source"]):
        url = _tag_image_url(img, base_url)
        if not url:
            continue
        width = _int_attr(img, "width")
        height = _int_attr(img, "height")
        hint = " ".join(
            filter(
                None,
                [
                    img.get("alt") or "",
                    img.get("title") or "",
                    img.get("class") and " ".join(img.get("class") or []),
                    img.get("id") or "",
                ],
            )
        )
        parent_hint = ""
        parent = img.parent
        for _ in range(4):
            if parent is None:
                break
            parent_hint += " " + " ".join(parent.get("class") or [])
            parent_hint += " " + (parent.get("id") or "")
            parent = parent.parent
        blob = f"{hint} {parent_hint}"
        kind = "img"
        if _EVENT_HINT.search(blob):
            kind = "event"
        elif _PHOTO_HINT.search(blob):
            kind = "hero"
        score = _score_image(
            url, kind=kind, width=width, height=height, hint=blob
        )
        add(url, score, _nearby_text(img))

    for node in soup.find_all(True):
        style = node.get("style") or ""
        m = _BG_URL.search(style)
        if not m:
            continue
        url = _abs_http(m.group(2), base_url)
        hint = " ".join(node.get("class") or []) + " " + (node.get("id") or "")
        kind = "hero" if _PHOTO_HINT.search(hint) else "img"
        add(
            url,
            _score_image(url, kind=kind, hint=hint),
            _nearby_text(node),
        )

    ranked = sorted(found.values(), key=lambda c: c.score, reverse=True)
    return [c for c in ranked if c.score >= 40]


def extract_mall_cover(html: str, base_url: str) -> str:
    cands = extract_image_candidates(html, base_url)
    return cands[0].url if cands else ""


def pick_event_image(
    event_name: str, candidates: list[ImageCandidate], mall_cover: str
) -> str:
    """Prefer a photo whose nearby text mentions this event; else mall cover."""
    name = normalize_ws(event_name).lower()
    if name and len(name) >= 5 and candidates:
        needle = name[:48]
        best: ImageCandidate | None = None
        for cand in candidates:
            text = (cand.text or "").lower()
            if not text:
                continue
            if needle in text or (len(needle) > 10 and needle[:14] in text):
                if best is None or cand.score > best.score:
                    best = cand
        if best and best.url:
            return best.url
    return mall_cover


def chunk_text(text: str) -> list[str]:
    if not text:
        return []
    if len(text) <= CHUNK_CHARS:
        return [text]
    chunks: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        end = min(n, i + CHUNK_CHARS)
        if end < n:
            nl = text.rfind("\n", i + CHUNK_CHARS // 2, end)
            if nl > i:
                end = nl
        piece = text[i:end].strip()
        if piece:
            chunks.append(piece)
        if end >= n:
            break
        i = max(end - CHUNK_OVERLAP, i + 1)
    return chunks


def gemini_prompt(city: str, avm_name: str, today: str, page_text: str) -> str:
    return f"""Sen Engelsiz Club için AVM etkinlik ayrıştırıcısısın.
Bugünün tarihi: {today} (Türkiye).
Kaynak AVM: {avm_name}, şehir: {city}.

Görevin: Aşağıdaki sayfa metninden çocuklara, ailelere veya genel ziyaretçilere
yönelik TÜM etkinlikleri çıkar.
Tarih kuralı: Tarihi açıkça yazılmış etkinliklerde bu haftayı (7 gün) tercih et,
AMA tarih belirtilmemişse veya "her hafta sonu", "sürekli", "devam ediyor" gibi
ifadeler varsa onları DA dahil et — event_date alanına "Her hafta sonu" veya
"Devam ediyor" yaz.

Şunları DAHİL ET: çocuk atölyesi, masal saati, 23 Nisan, aile festivali,
oyun alanı etkinliği, bebek/çocuk kulübü, ücretsiz minik etkinlikleri,
okul öncesi atölye, ailece katılınan gösteriler, tiyatro, sirk, gösteri,
müzik etkinliği, dans gösterisi, resim/el sanatları atölyesi, bilim atölyesi,
doğa etkinliği, spor etkinliği, karakter buluşması, kostüm partisi,
sinema etkinliği, kitap okuma, AVM içi animasyon / eğlence programı,
açık hava etkinlikleri, konser (aile/çocuk dostu olanlar), paten/buz pateni,
tema parkı etkinlikleri.
Şunları HARİÇ TUT: yalnızca yetişkinlere yönelik konser/stand-up
(çocuk/aile belirtilmemişse), mağaza indirimi, restoran kampanyası,
iş ilanı, üyelik, genel AVM tanıtımı.

Çıktı: yalnızca bir JSON dizisi. Markdown yok, açıklama yok.
Her öğe tam olarak bu anahtarlar:
{{
  "city": "{city}",
  "avm_name": "{avm_name}",
  "event_name": "kısa Türkçe başlık",
  "event_date": "insan okur Türkçe tarih (ör. 5 Eylül 2026 veya 5-6 Eylül 2026, 14:00)",
  "description": "1-3 cümle Türkçe özet"
}}
city ve avm_name her zaman verilen değerler olsun.
Uygun etkinlik yoksa boş dizi: []

Sayfa metni:
{page_text}
"""


def parse_json_array(raw: str) -> list[dict[str, Any]]:
    if not raw:
        return []
    text = raw.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.I)
    text = re.sub(r"\s*```$", "", text)
    start = text.find("[")
    end = text.rfind("]")
    if start < 0 or end <= start:
        return []
    blob = text[start : end + 1]
    try:
        data = json.loads(blob)
    except json.JSONDecodeError:
        blob = re.sub(r",\s*]", "]", blob)
        blob = re.sub(r",\s*}", "}", blob)
        try:
            data = json.loads(blob)
        except json.JSONDecodeError:
            return []
    if not isinstance(data, list):
        return []
    out: list[dict[str, Any]] = []
    for item in data:
        if isinstance(item, dict):
            out.append(item)
    return out


def extract_gemini_text(payload: dict[str, Any]) -> str:
    cands = payload.get("candidates") or []
    if not cands:
        return ""
    content = (cands[0] or {}).get("content") or {}
    parts = content.get("parts") or []
    bits = []
    for part in parts:
        if isinstance(part, dict) and part.get("text"):
            bits.append(str(part["text"]))
    return "\n".join(bits).strip()


class GeminiClient:
    def __init__(self, api_key: str, http: httpx.Client) -> None:
        self._key = api_key
        self._http = http
        preferred = _env("GEMINI_MODEL") or GEMINI_MODELS[0]
        models: list[str] = []
        for m in (preferred, *GEMINI_MODELS):
            if m and m not in models:
                models.append(m)
        self._models = models

    def extract_events(
        self, city: str, avm_name: str, today: str, page_text: str
    ) -> list[dict[str, Any]]:
        merged: dict[str, dict[str, Any]] = {}
        for chunk in chunk_text(page_text):
            prompt = gemini_prompt(city, avm_name, today, chunk)
            rows = self._generate_array(prompt)
            for row in rows:
                event = coerce_event(row, city, avm_name)
                if not event:
                    continue
                key = (
                    event["city"],
                    event["avm_name"],
                    event["event_name"],
                    event["event_date"],
                )
                merged[key] = event
            polite_sleep()
        return list(merged.values())

    def _generate_array(self, prompt: str) -> list[dict[str, Any]]:
        last_err = ""
        configs: list[dict[str, Any]] = [
            {
                "temperature": 0.2,
                "responseMimeType": "application/json",
            },
            {"temperature": 0.2},
        ]
        for model in self._models:
            for gen_cfg in configs:
                try:
                    body = {
                        "contents": [
                            {"role": "user", "parts": [{"text": prompt}]}
                        ],
                        "generationConfig": gen_cfg,
                    }
                    url = (
                        "https://generativelanguage.googleapis.com/v1beta/"
                        f"models/{model}:generateContent"
                    )
                    res = self._http.post(
                        url,
                        headers={
                            "x-goog-api-key": self._key,
                            "Content-Type": "application/json",
                        },
                        json=body,
                        timeout=GEMINI_TIMEOUT,
                    )
                    if res.status_code in (404, 400):
                        last_err = f"{model} HTTP {res.status_code}"
                        continue
                    if res.status_code >= 400:
                        last_err = f"{model} HTTP {res.status_code}"
                        continue
                    data = res.json()
                    text = extract_gemini_text(data)
                    if not text.strip():
                        last_err = f"{model} empty"
                        continue
                    parsed = parse_json_array(text)
                    if parsed or text.strip() == "[]":
                        return parsed
                except (httpx.HTTPError, ValueError, json.JSONDecodeError) as exc:
                    last_err = _redact_error(str(exc))
                    continue
        if last_err:
            print(f"  Gemini atlandı: {last_err}", file=sys.stderr)
        return []


def coerce_event(
    row: dict[str, Any], city: str, avm_name: str
) -> dict[str, str] | None:
    name = normalize_ws(str(row.get("event_name") or row.get("title") or ""))
    event_date = normalize_ws(
        str(row.get("event_date") or row.get("date") or "")
    )
    desc = normalize_ws(str(row.get("description") or ""))
    if not name or not event_date:
        return None
    image_url = normalize_ws(
        str(row.get("image_url") or row.get("image") or "")
    )
    if image_url and not image_url.startswith(("http://", "https://")):
        image_url = ""
    return {
        "city": normalize_ws(city)[:120],
        "avm_name": normalize_ws(avm_name)[:160],
        "event_name": name[:240],
        "event_date": event_date[:160],
        "description": desc[:2000],
        "image_url": image_url[:500],
    }


def _fetch_with_playwright(url: str) -> str | None:
    """Render a JS-heavy page with headless Chromium; returns HTML or None."""
    if not HAS_PLAYWRIGHT:
        return None
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            ctx = browser.new_context(
                user_agent=USER_AGENT,
                locale="tr-TR",
                viewport={"width": 1280, "height": 900},
                extra_http_headers={
                    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
                    "Upgrade-Insecure-Requests": "1",
                },
            )
            page = ctx.new_page()
            page.goto(url, wait_until="domcontentloaded", timeout=35_000)
            # Wait a bit for JS to hydrate content
            page.wait_for_timeout(3000)
            html = page.content()
            browser.close()
        return html
    except Exception as exc:  # noqa: BLE001
        print(f"  playwright hatası: {_redact_error(str(exc))}", file=sys.stderr)
        return None


# Minimum text length to consider a page useful
_MIN_TEXT_LEN = 80
# Threshold: if plain fetch text is below this, try Playwright
_JS_FALLBACK_THRESHOLD = 200


class FetchedPage(NamedTuple):
    text: str
    html: str
    final_url: str
    cover: str


_BROWSER_HEADERS = {
    "User-Agent": USER_AGENT,
    "Accept": (
        "text/html,application/xhtml+xml,application/xml;q=0.9,"
        "image/avif,image/webp,*/*;q=0.8"
    ),
    "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Cache-Control": "no-cache",
    "Pragma": "no-cache",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-User": "?1",
    "Upgrade-Insecure-Requests": "1",
}


def _http_get_html(
    http: httpx.Client, url: str
) -> tuple[str | None, str]:
    html: str | None = None
    final_url = url
    last_err = ""
    for attempt in range(1, FETCH_RETRIES + 1):
        try:
            res = http.get(
                url,
                timeout=FETCH_TIMEOUT,
                follow_redirects=True,
                headers=_BROWSER_HEADERS,
            )
            final_url = str(res.url)
            if res.status_code in RETRY_HTTP_STATUS and attempt < FETCH_RETRIES:
                wait = min(1.5 * attempt, 6.0)
                print(
                    f"  HTTP {res.status_code}, yeniden deneme "
                    f"{attempt}/{FETCH_RETRIES} ({wait:.0f}s)",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            if res.status_code < 400:
                raw = res.content[:MAX_HTML_BYTES]
                try:
                    html = raw.decode(res.encoding or "utf-8", errors="replace")
                except LookupError:
                    html = raw.decode("utf-8", errors="replace")
                return html, final_url
            print(f"  HTTP {res.status_code}", file=sys.stderr)
            return html, final_url
        except (
            httpx.TimeoutException,
            httpx.ConnectError,
            httpx.RemoteProtocolError,
        ) as exc:
            last_err = _redact_error(str(exc))
            if attempt < FETCH_RETRIES:
                wait = min(1.5 * attempt, 6.0)
                print(
                    f"  geçici hata, yeniden deneme {attempt}/{FETCH_RETRIES} "
                    f"({wait:.0f}s): {last_err}",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            print(f"  istek hatası: {last_err}", file=sys.stderr)
            return html, final_url
        except httpx.HTTPError as exc:
            print(f"  istek hatası: {_redact_error(str(exc))}", file=sys.stderr)
            return html, final_url
    if last_err:
        print(f"  istek hatası: {last_err}", file=sys.stderr)
    return html, final_url


def _maybe_playwright(
    url: str,
    html: str | None,
    plain_text: str,
    cover: str,
) -> tuple[str | None, str, str]:
    """JS-render when the static page is thin (SPA) so og:image can appear."""
    need_js = len(plain_text) < _JS_FALLBACK_THRESHOLD
    if not cover and len(plain_text) < 500:
        need_js = True
    if not need_js or not HAS_PLAYWRIGHT:
        return html, plain_text, cover
    print("  → JS render deneniyor (playwright)…", file=sys.stderr)
    rendered = _fetch_with_playwright(url)
    if not rendered:
        return html, plain_text, cover
    rendered_text = html_to_text(rendered)
    rendered_cover = extract_mall_cover(rendered, url)
    better_text = len(rendered_text) > len(plain_text)
    better_cover = bool(rendered_cover) and (
        not cover or rendered_cover != cover
    )
    if better_text or (better_cover and not cover):
        return rendered, rendered_text, rendered_cover or cover
    if better_cover:
        return rendered, rendered_text or plain_text, rendered_cover
    return html, plain_text, cover


def fetch_html(
    http: httpx.Client,
    url: str,
    *,
    require_text: bool = True,
    use_playwright: bool = True,
) -> FetchedPage | None:
    html, final_url = _http_get_html(http, url)
    plain_text = html_to_text(html) if html else ""
    cover = extract_mall_cover(html, final_url) if html else ""
    if use_playwright:
        html, plain_text, cover = _maybe_playwright(
            url, html, plain_text, cover
        )

    if not html:
        print("  sayfa alınamadı, atlandı", file=sys.stderr)
        return None

    low = html.lower()
    if "password" in low and "login" in low and len(plain_text) < 400:
        print("  giriş duvarı, atlandı", file=sys.stderr)
        return None
    if "login" in final_url.lower() and "<html" not in html.lower()[:500]:
        print("  giriş/paywall sayfası, atlandı", file=sys.stderr)
        return None

    text = plain_text if plain_text else html_to_text(html)
    if require_text and len(text) < _MIN_TEXT_LEN:
        print(f"  metin çok kısa ({len(text)} karakter), atlandı", file=sys.stderr)
        return None
    if not cover:
        cover = extract_mall_cover(html, final_url)
    return FetchedPage(text=text, html=html, final_url=final_url, cover=cover)


def fetch_page(http: httpx.Client, url: str) -> FetchedPage | None:
    return fetch_html(http, url, require_text=True)


class Supabase:
    def __init__(self, url: str, key: str, http: httpx.Client) -> None:
        self._url = url.rstrip("/")
        self._http = http
        self._headers = {
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
        }

    def _req(
        self,
        method: str,
        path: str,
        *,
        params: dict[str, str] | None = None,
        json_body: Any = None,
        extra_headers: dict[str, str] | None = None,
    ) -> httpx.Response:
        headers = dict(self._headers)
        if extra_headers:
            headers.update(extra_headers)
        res = self._http.request(
            method,
            f"{self._url}{path}",
            params=params,
            json=json_body,
            headers=headers,
            timeout=30.0,
        )
        return res

    def require_etkinlikler_columns(self) -> None:
        res = self._req(
            "GET",
            "/rest/v1/etkinlikler",
            params={
                "select": "id,source,external_id,avm_name,user_edited,is_active",
                "limit": "0",
            },
        )
        if res.status_code >= 400:
            raise SystemExit(
                "etkinlikler scrape kolonları yok. Supabase SQL Editor’de "
                "supabase/events.sql çalıştırın. "
                f"HTTP {res.status_code}"
            )

    def upsert_events(self, rows: list[dict[str, str]]) -> int:
        if not rows:
            return 0
        res = self._req(
            "POST",
            "/rest/v1/events",
            params={"on_conflict": "city,avm_name,event_name,event_date"},
            json_body=rows,
            extra_headers={
                "Prefer": "resolution=merge-duplicates,return=minimal",
            },
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"events upsert HTTP {res.status_code}: "
                f"{_redact_error(res.text[:400])}"
            )
        return len(rows)

    def deleted_ids(self) -> set[str]:
        res = self._req(
            "GET",
            "/rest/v1/deleted_avm_events",
            params={"select": "external_id", "limit": "20000"},
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"deleted_avm_events HTTP {res.status_code}: "
                f"{_redact_error(res.text[:400])}"
            )
        return {
            str(r.get("external_id"))
            for r in res.json()
            if r.get("external_id")
        }

    def scraped_etkinlikler(self) -> dict[str, dict[str, Any]]:
        res = self._req(
            "GET",
            "/rest/v1/etkinlikler",
            params={
                "select": "id,external_id,user_edited,is_active,sort_index",
                "source": "eq.avm_scrape",
                "limit": "20000",
            },
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"etkinlikler GET HTTP {res.status_code}: "
                f"{_redact_error(res.text[:400])}"
            )
        out: dict[str, dict[str, Any]] = {}
        for row in res.json():
            eid = str(row.get("external_id") or "")
            if eid:
                out[eid] = row
        return out

    def max_sort_index(self) -> int:
        res = self._req(
            "GET",
            "/rest/v1/etkinlikler",
            params={
                "select": "sort_index",
                "order": "sort_index.desc",
                "limit": "1",
            },
        )
        if res.status_code >= 400:
            return SORT_FLOOR
        rows = res.json()
        if not rows:
            return SORT_FLOOR
        val = rows[0].get("sort_index")
        try:
            return max(int(val or 0), SORT_FLOOR)
        except (TypeError, ValueError):
            return SORT_FLOOR

    def insert_etkinlikler(self, rows: list[dict[str, Any]]) -> int:
        if not rows:
            return 0
        res = self._req(
            "POST",
            "/rest/v1/etkinlikler",
            params={"on_conflict": "external_id"},
            json_body=rows,
            extra_headers={
                "Prefer": "resolution=ignore-duplicates,return=minimal",
            },
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"etkinlikler insert HTTP {res.status_code}: "
                f"{_redact_error(res.text[:400])}"
            )
        return len(rows)

    def patch_etkinlik(self, row_id: int, patch: dict[str, Any]) -> None:
        res = self._req(
            "PATCH",
            "/rest/v1/etkinlikler",
            params={"id": f"eq.{row_id}"},
            json_body=patch,
            extra_headers={"Prefer": "return=minimal"},
        )
        if res.status_code >= 400:
            raise RuntimeError(
                f"etkinlikler patch id={row_id} HTTP {res.status_code}: "
                f"{_redact_error(res.text[:400])}"
            )


def etkinlik_description(event: dict[str, str]) -> str:
    date_line = event["event_date"]
    body = event.get("description") or ""
    if body:
        return f"{date_line}\n\n{body}"
    return date_line


def sync_etkinlikler(
    db: Supabase,
    events: list[dict[str, str]],
    covers: dict[tuple[str, str], str],
) -> tuple[int, int, int]:
    deleted = db.deleted_ids()
    existing = db.scraped_etkinlikler()
    next_sort = db.max_sort_index()
    inserts: list[dict[str, Any]] = []
    updated = 0
    skipped = 0
    for event in events:
        eid = external_id(
            event["city"],
            event["avm_name"],
            event["event_name"],
            event["event_date"],
        )
        if eid in deleted:
            skipped += 1
            continue
        mall_cover = covers.get((event["city"], event["avm_name"])) or ""
        cover = (event.get("image_url") or "").strip() or mall_cover
        payload_core = {
            "title": event["event_name"],
            "description": etkinlik_description(event),
            "city": event["city"],
            "avm_name": event["avm_name"],
        }
        row = existing.get(eid)
        if row:
            if row.get("user_edited") is True or row.get("is_active") is False:
                skipped += 1
                continue
            # is_active'e dokunma (kullanıcı gizlediyse scraper açmaz).
            patch = dict(payload_core)
            if cover:
                patch["image_url"] = cover
            db.patch_etkinlik(int(row["id"]), patch)
            updated += 1
            continue
        next_sort += 1
        inserts.append(
            {
                **payload_core,
                "image_url": cover or "",
                "source": SOURCE_TAG,
                "external_id": eid,
                "user_edited": False,
                "is_active": True,
                "sort_order": next_sort,
                "sort_index": next_sort,
                "created_by": "avm_scraper",
            }
        )
    inserted = db.insert_etkinlikler(inserts)
    return inserted, updated, skipped


def load_sources() -> list[dict[str, str]]:
    raw = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    out: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for item in raw:
        city = normalize_ws(str(item.get("city") or ""))
        avm = normalize_ws(str(item.get("avm_name") or ""))
        url = normalize_ws(str(item.get("events_url") or ""))
        if not city or not avm or not url:
            continue
        if not url.startswith("http://") and not url.startswith("https://"):
            continue
        key = (city, avm, url)
        if key in seen:
            continue
        seen.add(key)
        image = normalize_ws(str(item.get("image") or ""))
        if image and not image.startswith(("http://", "https://")):
            image = ""
        out.append(
            {
                "city": city,
                "avm_name": avm,
                "events_url": url,
                "image": image,
            }
        )
    return out


def harvest_covers(sources: list[dict[str, str]]) -> int:
    """Write official page photos into avm_sources.json `image` fields."""
    raw = json.loads(SOURCES_PATH.read_text(encoding="utf-8"))
    by_key: dict[tuple[str, str], dict[str, Any]] = {}
    for item in raw:
        if not isinstance(item, dict):
            continue
        city = normalize_ws(str(item.get("city") or ""))
        avm = normalize_ws(str(item.get("avm_name") or ""))
        if city and avm:
            by_key[(city, avm)] = item

    found = 0
    failed = 0
    with httpx.Client(http2=False, follow_redirects=True) as http:
        for i, src in enumerate(sources, 1):
            city, avm, url = src["city"], src["avm_name"], src["events_url"]
            label = f"{city}/{avm}"
            print(f"[{i}/{len(sources)}] kapak {label}")
            fetched = fetch_html(
                http, url, require_text=False, use_playwright=False
            )
            time.sleep(0.4)
            cover = ""
            if fetched and fetched.cover:
                cover = fetched.cover
            elif src.get("image"):
                cover = src["image"]
            item = by_key.get((city, avm))
            if cover and item is not None:
                item["image"] = cover
                found += 1
                print(f"  {cover[:90]}")
            else:
                failed += 1
                print("  kapak yok")

    SOURCES_PATH.write_text(
        json.dumps(raw, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Kapak yazıldı: {found}; boş: {failed}")
    return 0 if found else 1


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="AVM çocuk/aile etkinlik scraper")
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Supabase'e yazma; yalnızca çıkarımı yazdır",
    )
    p.add_argument(
        "--max-sources",
        type=int,
        default=0,
        help="En fazla N AVM dene (yerel test)",
    )
    p.add_argument(
        "--harvest-covers",
        action="store_true",
        help="Gemini/DB yok; her AVM sayfasından kapak URL'sini avm_sources.json'a yaz",
    )
    return p.parse_args()


def main() -> int:
    _load_dotenv()
    args = parse_args()
    sources = load_sources()
    if args.max_sources and args.max_sources > 0:
        sources = sources[: args.max_sources]
    if not sources:
        print("avm_sources.json boş.", file=sys.stderr)
        return 1

    if args.harvest_covers:
        return harvest_covers(sources)

    supabase_url = _normalize_supabase_url(_env("SUPABASE_URL"))
    supabase_key = _env(
        "SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SERVICE_KEY"
    )
    gemini_key = _env("GEMINI_API_KEY")
    if not gemini_key:
        print("GEMINI_API_KEY gerekli.", file=sys.stderr)
        return 1
    if not args.dry_run and (not supabase_url or not supabase_key):
        print(
            "SUPABASE_URL ve SUPABASE_SERVICE_ROLE_KEY gerekli.",
            file=sys.stderr,
        )
        return 1

    today_label = _today_tr()

    all_events: list[dict[str, str]] = []
    covers: dict[tuple[str, str], str] = {}
    seen_keys: set[tuple[str, str, str, str]] = set()

    # Per-source stats for summary
    stats_ok: list[str] = []
    stats_empty: list[str] = []
    stats_fail: list[str] = []

    with httpx.Client(http2=False, follow_redirects=True) as http:
        gemini = GeminiClient(gemini_key, http)
        db = None
        if not args.dry_run:
            db = Supabase(supabase_url, supabase_key, http)
            db.require_etkinlikler_columns()

        for i, src in enumerate(sources, 1):
            city, avm, url = src["city"], src["avm_name"], src["events_url"]
            label = f"{city}/{avm}"
            print(f"[{i}/{len(sources)}] {label}")
            fetched = fetch_page(http, url)
            polite_sleep()
            if not fetched:
                stats_fail.append(label)
                continue
            mall_cover = fetched.cover or src.get("image") or ""
            if mall_cover:
                covers[(city, avm)] = mall_cover
            candidates = extract_image_candidates(fetched.html, fetched.final_url)
            try:
                events = gemini.extract_events(city, avm, today_label, fetched.text)
            except Exception as exc:  # noqa: BLE001 — skip mall, keep going
                print(f"  parse atlandı: {_redact_error(str(exc))}", file=sys.stderr)
                stats_fail.append(label)
                continue
            kept = 0
            for event in events:
                key = (
                    event["city"],
                    event["avm_name"],
                    event["event_name"],
                    event["event_date"],
                )
                if key in seen_keys:
                    continue
                seen_keys.add(key)
                if not event.get("image_url"):
                    event["image_url"] = pick_event_image(
                        event["event_name"], candidates, mall_cover
                    )
                all_events.append(event)
                kept += 1
            print(f"  {kept} etkinlik" + (f" · kapak var" if mall_cover else ""))
            if kept > 0:
                stats_ok.append(f"{label} ({kept})")
            else:
                stats_empty.append(label)

        # --- Coverage summary ---
        total = len(sources)
        print(f"\n{'='*60}")
        print(f"KAYNAK ÖZETİ: {total} AVM")
        print(f"  ✓ Etkinlik bulunan: {len(stats_ok)}")
        print(f"  ○ Sayfa alındı, etkinlik yok: {len(stats_empty)}")
        print(f"  ✗ Sayfa alınamadı/hata: {len(stats_fail)}")
        if stats_fail:
            print(f"  Başarısız kaynaklar: {', '.join(stats_fail[:20])}")
            if len(stats_fail) > 20:
                print(f"    … ve {len(stats_fail)-20} daha")
        print(f"{'='*60}\n")
        if stats_fail:
            print(
                f"Uyarı: {len(stats_fail)} kaynak alınamadı; "
                "bu kısmi başarısızlık işi düşürmez (exit 0).",
                flush=True,
            )

        if args.dry_run:
            print(json.dumps(all_events, ensure_ascii=False, indent=2))
            print(f"Toplam {len(all_events)} (dry-run, yazılmadı)")
            return 0

        assert db is not None
        try:
            n_events = db.upsert_events(all_events)
            inserted, updated, skipped = sync_etkinlikler(
                db, all_events, covers
            )
        except Exception as exc:  # noqa: BLE001 — true fatal: DB write
            print(
                f"Supabase yazma başarısız: {_redact_error(str(exc))}",
                file=sys.stderr,
            )
            return 1
        print(
            f"events upsert={n_events}; "
            f"etkinlikler insert={inserted} update={updated} skip={skipped}"
        )
    # Partial source failures are warnings only. Exit 0 when the scrape
    # loop finished and (if not dry-run) Supabase write succeeded —
    # including 0 events.
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        print(f"Ölümcül hata: {_redact_error(str(exc))}", file=sys.stderr)
        raise SystemExit(1) from exc
