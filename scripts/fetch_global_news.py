#!/usr/bin/env python3
"""Küresel engelsiz yaşam / haklar / tedavi haberleri → web/engelsiz-haberler.json.

RSS + ClinicalTrials.gov. Yeni kayıtlar pending_review.
Mevcut JSON'daki status / düzenlenmiş başlık-özet korunur (admin override).
Çeviri: GEMINI_API_KEY (yoksa AI_API_KEY). Anahtar loglanmaz.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import time
import traceback
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "web" / "engelsiz-haberler.json"
GEMINI_GENERATE = (
    "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
)
TEXT_MODELS = (
    "gemini-2.5-flash",
    "gemini-flash-latest",
    "gemini-2.5-flash-lite",
)
MAX_ITEMS = 180
MAX_PER_SOURCE = 10
USER_AGENT = "EngelsizClubBot/1.0 (+https://engelsizclub.com)"

CATEGORIES = (
    "erisilebilirlik",
    "haklar",
    "tedavi",
    "genetik",
    "noroteknoloji",
    "klinik",
    "diger",
)

SOURCES: tuple[dict[str, Any], ...] = (
    {
        "id": "disability-scoop",
        "name": "Disability Scoop",
        "rss": ("https://www.disabilityscoop.com/feed/",),
    },
    {
        "id": "disabled-world",
        "name": "Disabled World",
        "rss": (
            "https://www.disabled-world.com/rss.xml",
            "https://www.disabled-world.com/disability/rss.xml",
        ),
    },
    {
        "id": "w3c-wai",
        "name": "W3C WAI",
        "rss": (
            "https://www.w3.org/WAI/feed.xml",
            "https://www.w3.org/blog/news/feed",
        ),
    },
    {
        "id": "wbu",
        "name": "World Blind Union",
        "rss": (
            "https://worldblindunion.org/feed/",
            "https://www.wbu.ngo/feed/",
        ),
    },
    {
        "id": "the-mighty",
        "name": "The Mighty",
        "rss": ("https://themighty.com/feed/",),
    },
    {
        "id": "bbc-disability",
        "name": "BBC Disability",
        "rss": (
            "https://feeds.bbci.co.uk/news/disability/rss.xml",
            "https://feeds.bbci.co.uk/news/health/rss.xml",
        ),
    },
    {
        "id": "sciencedaily-genetics",
        "name": "ScienceDaily Genetics",
        "rss": (
            "https://www.sciencedaily.com/rss/health_medicine/genetics.xml",
            "https://www.sciencedaily.com/rss/health_medicine/stem_cells.xml",
        ),
    },
    {
        "id": "mnt",
        "name": "Medical News Today",
        "rss": ("https://www.medicalnewstoday.com/rss",),
    },
    {
        "id": "ieee-spectrum",
        "name": "IEEE Spectrum",
        "rss": (
            "https://spectrum.ieee.org/feeds/topic/biomedical.xml",
            "https://spectrum.ieee.org/rss/full.xml",
        ),
    },
)

_TR_CHARS = re.compile(r"[çğıöşüÇĞİÖŞÜ]")
_TAG_RE = re.compile(r"<[^>]+>")
_WS_RE = re.compile(r"\s+")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def item_id(url: str) -> str:
    return hashlib.sha256(url.strip().lower().encode("utf-8")).hexdigest()[:24]


def strip_html(raw: str) -> str:
    text = _TAG_RE.sub(" ", raw or "")
    return _WS_RE.sub(" ", text).strip()


def looks_turkish(text: str) -> bool:
    return bool(_TR_CHARS.search(text or ""))


def guess_category(title: str, summary: str) -> str:
    hay = f"{title} {summary}".lower()
    if any(k in hay for k in ("clinical trial", "nct0", "recruiting", "klinik")):
        return "klinik"
    if any(k in hay for k in ("stem cell", "kök hücre", "genetic", "genetik", "crispr")):
        return "genetik"
    if any(
        k in hay
        for k in ("bionic", "neural", "neuro", "prosthetic", "biyonik", "nöro")
    ):
        return "noroteknoloji"
    if any(k in hay for k in ("wai", "wcag", "accessibility", "erişilebilir")):
        return "erisilebilirlik"
    if any(k in hay for k in ("rights", "law", "hak", "discrimination", "un crpd")):
        return "haklar"
    if any(k in hay for k in ("treatment", "therapy", "tedavi", "breakthrough")):
        return "tedavi"
    return "diger"


def _local(tag: str) -> str:
    if "}" in tag:
        return tag.rsplit("}", 1)[-1]
    return tag


def parse_rss(xml_text: str) -> list[dict[str, str]]:
    out: list[dict[str, str]] = []
    try:
        root = ET.fromstring(xml_text)
    except ET.ParseError:
        return out
    nodes = list(root.iter())
    items = [n for n in nodes if _local(n.tag).lower() in ("item", "entry")]
    for node in items:
        title = ""
        link = ""
        summary = ""
        published = ""
        for child in list(node):
            tag = _local(child.tag).lower()
            text = (child.text or "").strip()
            if tag == "title" and not title:
                title = strip_html(text)
            elif tag in ("link", "id") and not link:
                href = (child.attrib.get("href") or text).strip()
                if href.startswith("http"):
                    link = href
            elif tag in ("description", "summary", "content") and not summary:
                summary = strip_html(text)
            elif tag in ("pubdate", "published", "updated", "date") and not published:
                published = text
        if not link:
            for child in list(node):
                if _local(child.tag).lower() == "guid":
                    g = (child.text or "").strip()
                    if g.startswith("http"):
                        link = g
                        break
        if title and link:
            out.append(
                {
                    "title": title[:280],
                    "url": link,
                    "summary": summary[:800],
                    "published": published,
                }
            )
    return out


def http_get(url: str, timeout: int = 25) -> tuple[int, str]:
    try:
        import requests
    except ImportError:
        print("requests yok", file=sys.stderr)
        return 0, ""
    try:
        res = requests.get(
            url,
            headers={
                "User-Agent": USER_AGENT,
                "Accept": (
                    "application/rss+xml, application/xml, text/xml, "
                    "application/json, */*"
                ),
            },
            timeout=timeout,
        )
        return res.status_code, res.text or ""
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        return 0, ""


def fetch_rss_source(source: dict[str, Any]) -> list[dict[str, str]]:
    for url in source.get("rss") or ():
        status, body = http_get(url)
        if status >= 400 or not body.strip():
            print(f"{source['id']} RSS HTTP {status} {url}", file=sys.stderr)
            continue
        items = parse_rss(body)
        if items:
            print(f"{source['id']}: {len(items)} rss {url}")
            return items[:MAX_PER_SOURCE]
    return []


def fetch_clinical_trials() -> list[dict[str, str]]:
    url = (
        "https://clinicaltrials.gov/api/v2/studies"
        "?query.term=disability+OR+%22stem+cell%22+OR+bionic+OR+neuroprosthetic"
        "+OR+wheelchair+OR+accessibility"
        "&filter.overallStatus=RECRUITING"
        "&pageSize=12"
        "&fields=NCTId,BriefTitle,BriefSummary,OverallStatus"
    )
    status, body = http_get(url, timeout=40)
    if status >= 400 or not body.strip():
        print(f"clinicaltrials HTTP {status}", file=sys.stderr)
        return []
    try:
        payload = json.loads(body)
    except json.JSONDecodeError:
        return []
    out: list[dict[str, str]] = []
    for study in payload.get("studies") or []:
        proto = study.get("protocolSection") or {}
        ident = proto.get("identificationModule") or {}
        desc = proto.get("descriptionModule") or {}
        nct = (ident.get("nctId") or "").strip()
        title = (ident.get("briefTitle") or "").strip()
        summary = (desc.get("briefSummary") or "").strip()
        if not nct or not title:
            continue
        out.append(
            {
                "title": title[:280],
                "url": f"https://clinicaltrials.gov/study/{nct}",
                "summary": strip_html(summary)[:800],
                "published": "",
            }
        )
        if len(out) >= MAX_PER_SOURCE:
            break
    print(f"clinicaltrials: {len(out)}")
    return out


def api_key() -> str:
    return (
        os.environ.get("GEMINI_API_KEY") or os.environ.get("AI_API_KEY") or ""
    ).strip()


def gemini_translate(key: str, title: str, summary: str) -> dict[str, str]:
    if not key:
        return {}
    if looks_turkish(title) and (not summary or looks_turkish(summary)):
        return {
            "title": title,
            "summary": summary,
            "category": guess_category(title, summary),
        }
    brief = (
        "Translate this disability/accessibility/medical news into Turkish. "
        "Return ONLY compact JSON: "
        '{"title":"...","summary":"...","category":'
        '"erisilebilirlik|haklar|tedavi|genetik|noroteknoloji|klinik|diger"}. '
        "Summary max 400 characters, factual, no medical advice.\n"
        f"Title: {title}\nSummary: {summary}"
    )
    try:
        import requests
    except ImportError:
        return {}
    for model in TEXT_MODELS:
        try:
            res = requests.post(
                GEMINI_GENERATE.format(model=model),
                headers={
                    "x-goog-api-key": key,
                    "Content-Type": "application/json",
                },
                json={
                    "contents": [{"role": "user", "parts": [{"text": brief}]}],
                    "generationConfig": {
                        "temperature": 0.2,
                        "maxOutputTokens": 500,
                    },
                },
                timeout=45,
            )
            if res.status_code >= 400:
                print(f"çeviri HTTP {res.status_code} {model}", file=sys.stderr)
                continue
            payload = res.json() if res.content else {}
            cands = payload.get("candidates") or []
            parts = ((cands[0] or {}).get("content") or {}).get("parts") or []
            text = "\n".join(
                str(p.get("text") or "") for p in parts if isinstance(p, dict)
            )
            text = re.sub(r"^```(?:json)?\s*|\s*```$", "", text.strip())
            data = json.loads(text)
            tr_title = str(data.get("title") or "").strip()
            tr_sum = str(data.get("summary") or "").strip()
            cat = str(data.get("category") or "").strip().lower()
            if cat not in CATEGORIES:
                cat = guess_category(title, summary)
            if len(tr_title) > 4:
                return {
                    "title": tr_title[:280],
                    "summary": tr_sum[:800],
                    "category": cat,
                }
        except Exception:  # noqa: BLE001
            print(f"çeviri hata {model}", file=sys.stderr)
            traceback.print_exc()
    return {}


def load_existing(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        return {}
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    items = payload.get("items") if isinstance(payload, dict) else payload
    by_id: dict[str, dict[str, Any]] = {}
    if isinstance(items, list):
        for raw in items:
            if not isinstance(raw, dict):
                continue
            nid = str(raw.get("id") or "").strip()
            url = str(raw.get("source_url") or raw.get("url") or "").strip()
            if not nid and url:
                nid = item_id(url)
            if nid:
                by_id[nid] = raw
    return by_id


def merge_item(
    existing: dict[str, Any] | None, fresh: dict[str, Any]
) -> dict[str, Any]:
    if not existing:
        return fresh
    prev_status = (
        str(existing.get("status") or "pending_review").strip() or "pending_review"
    )
    out = dict(fresh)
    out["status"] = prev_status
    if prev_status in ("published", "rejected"):
        if str(existing.get("title") or "").strip():
            out["title"] = existing["title"]
        if str(existing.get("summary") or "").strip():
            out["summary"] = existing["summary"]
    return out


def build_record(
    source_name: str,
    raw: dict[str, str],
    translated: dict[str, str],
) -> dict[str, Any]:
    url = raw["url"]
    title_en = raw["title"]
    sum_en = raw.get("summary") or ""
    title = translated.get("title") or title_en
    summary = translated.get("summary") or sum_en
    return {
        "id": item_id(url),
        "title": title,
        "title_original": title_en,
        "summary": summary,
        "summary_original": sum_en,
        "category": translated.get("category")
        or guess_category(title_en, sum_en),
        "source_name": source_name,
        "source_url": url,
        "image_url": "",
        "published_at": raw.get("published") or utc_now(),
        "status": "pending_review",
        "lang": "tr" if looks_turkish(title) else "en",
    }


def run(argv: list[str] | None = None) -> int:
    del argv
    out_path = Path(os.environ.get("GLOBAL_NEWS_OUT") or DEFAULT_OUT)
    key = api_key()
    if not key:
        print("GEMINI_API_KEY yok; İngilizce başlıklarla devam", file=sys.stderr)
    existing = load_existing(out_path)
    collected: list[dict[str, Any]] = []
    seen: set[str] = set()

    def add_raw(source_name: str, rows: list[dict[str, str]]) -> None:
        for raw in rows:
            url = (raw.get("url") or "").strip()
            if not url or not url.startswith("http"):
                continue
            nid = item_id(url)
            if nid in seen:
                continue
            seen.add(nid)
            prev = existing.get(nid)
            if prev and str(prev.get("status") or "") in ("published", "rejected"):
                collected.append(
                    merge_item(
                        prev,
                        build_record(
                            source_name,
                            raw,
                            {
                                "title": str(prev.get("title") or raw["title"]),
                                "summary": str(
                                    prev.get("summary") or raw.get("summary") or ""
                                ),
                                "category": str(
                                    prev.get("category")
                                    or guess_category(
                                        raw["title"], raw.get("summary") or ""
                                    )
                                ),
                            },
                        ),
                    )
                )
                continue
            translated = gemini_translate(key, raw["title"], raw.get("summary") or "")
            if translated:
                time.sleep(0.8)
            rec = merge_item(prev, build_record(source_name, raw, translated))
            collected.append(rec)

    for source in SOURCES:
        try:
            add_raw(str(source["name"]), fetch_rss_source(source))
        except Exception:  # noqa: BLE001
            print(f"kaynak hata: {source.get('id')}", file=sys.stderr)
            traceback.print_exc()
    try:
        add_raw("ClinicalTrials.gov", fetch_clinical_trials())
    except Exception:  # noqa: BLE001
        traceback.print_exc()

    for nid, prev in existing.items():
        if nid not in seen:
            collected.append(prev)

    collected.sort(key=lambda e: str(e.get("published_at") or ""), reverse=True)
    collected = collected[:MAX_ITEMS]
    payload = {
        "source": "engelsiz-club-global-news",
        "fetchedAt": utc_now(),
        "ok": True,
        "count": len(collected),
        "items": collected,
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"yazildi {out_path} count={len(collected)}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(run())
    except Exception:  # noqa: BLE001
        traceback.print_exc()
        raise SystemExit(0)
