"""schema.org Event çıkarımı (JSON-LD + yaygın meta etiketleri)."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

_SCRIPTS = Path(__file__).resolve().parents[1]
if str(_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(_SCRIPTS))

from bs4 import BeautifulSoup

from avm_event_dates import parse_event_details, today_istanbul


def _as_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def _type_names(node: dict[str, Any]) -> set[str]:
    out: set[str] = set()
    for raw in _as_list(node.get("@type")):
        name = str(raw).split("/")[-1].strip()
        if name:
            out.add(name.lower())
    return out


def _text(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, str):
        return value.strip()
    if isinstance(value, dict):
        for key in ("name", "title", "@value"):
            if value.get(key):
                return str(value.get(key)).strip()
    return str(value).strip()


def _iso_day(value: str) -> str:
    text = (value or "").strip()
    if not text:
        return ""
    m = re.match(r"(\d{4}-\d{2}-\d{2})", text)
    return m.group(1) if m else text


def _walk_jsonld(node: Any) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    if isinstance(node, list):
        for item in node:
            out.extend(_walk_jsonld(item))
        return out
    if not isinstance(node, dict):
        return out
    if "@graph" in node:
        out.extend(_walk_jsonld(node.get("@graph")))
    types = _type_names(node)
    if "event" in types or types.intersection(
        {"eventseries", "childrensevent", "educationevent", "theatersevent", "musicEvent".lower()}
    ):
        start = _text(node.get("startDate") or node.get("start_date"))
        end = _text(node.get("endDate") or node.get("end_date") or start)
        loc = node.get("location") if isinstance(node.get("location"), dict) else {}
        image = node.get("image")
        if isinstance(image, list) and image:
            image = image[0]
        if isinstance(image, dict):
            image = image.get("url") or image.get("contentUrl")
        out.append(
            {
                "event_name": _text(node.get("name") or node.get("headline")),
                "event_date": _iso_day(start) or start,
                "end_date_raw": _iso_day(end) or end,
                "description": _text(node.get("description")),
                "image_url": _text(image),
                "source_url": _text(node.get("url")),
                "venue_name": _text(loc.get("name") if isinstance(loc, dict) else ""),
                "date_source": "jsonld",
            }
        )
    for key, val in node.items():
        if key in {"@graph", "@context"}:
            continue
        if isinstance(val, (dict, list)):
            out.extend(_walk_jsonld(val))
    return out


def extract_jsonld_events(html: str) -> list[dict[str, Any]]:
    if not html:
        return []
    soup = BeautifulSoup(html, "html.parser")
    found: list[dict[str, Any]] = []
    seen: set[tuple[str, str]] = set()
    for script in soup.find_all("script"):
        script_type = (script.get("type") or "").lower()
        if "ld+json" not in script_type:
            continue
        raw = script.string or script.get_text() or ""
        raw = raw.strip()
        if not raw:
            continue
        try:
            data = json.loads(raw)
        except json.JSONDecodeError:
            continue
        for item in _walk_jsonld(data):
            key = (item.get("event_name") or "", item.get("event_date") or "")
            if not key[0] or key in seen:
                continue
            seen.add(key)
            found.append(item)
    return found


def extract_meta_dates(html: str) -> list[str]:
    if not html:
        return []
    soup = BeautifulSoup(html, "html.parser")
    out: list[str] = []
    keys = {
        "event:start_time",
        "event:end_time",
        "startdate",
        "enddate",
        "date",
        "article:published_time",
    }
    for tag in soup.find_all("meta"):
        name = (tag.get("property") or tag.get("name") or "").strip().lower()
        if name not in keys:
            continue
        content = (tag.get("content") or "").strip()
        if content:
            out.append(content)
    return out


def prefer_structured_date(*parts: str, html: str = "", today=None) -> tuple[str, str]:
    """(date_text, date_source) — JSON-LD > meta > verilen metin."""
    day = today or today_istanbul()
    for item in extract_jsonld_events(html):
        blob = " ".join(
            filter(
                None,
                [
                    str(item.get("event_date") or ""),
                    str(item.get("end_date_raw") or ""),
                ],
            )
        )
        if parse_event_details(blob, today=day):
            return blob, "jsonld"
    for meta in extract_meta_dates(html):
        if parse_event_details(meta, today=day):
            return meta, "meta"
    for part in parts:
        if parse_event_details(part, today=day):
            return part, "html"
    return (parts[0] if parts else ""), "html"
