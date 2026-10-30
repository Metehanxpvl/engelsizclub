"""JSON-LD + kart HTML'inden EventDraft listesi."""

from __future__ import annotations

import re
from datetime import date
from urllib.parse import urljoin

from bs4 import BeautifulSoup

from avm_event_dates import parse_event_details
from events.jsonld import extract_jsonld_events
from events.schema import EventDraft


def drafts_from_jsonld(
    html: str,
    *,
    city: str,
    venue: str,
    source_type: str,
    source_id: str,
    page_url: str,
    today: date,
) -> list[EventDraft]:
    out: list[EventDraft] = []
    for item in extract_jsonld_events(html):
        title = str(item.get("event_name") or "").strip()
        if not title:
            continue
        start = str(item.get("event_date") or "").strip()
        end = str(item.get("end_date_raw") or "").strip()
        event_date = " - ".join(x for x in (start, end) if x and x != start) or start
        if not event_date:
            continue
        image = str(item.get("image_url") or "")
        if image and not image.startswith("http"):
            image = urljoin(page_url, image)
        url = str(item.get("source_url") or page_url)
        out.append(
            EventDraft(
                title=title,
                city=city,
                venue_name=str(item.get("venue_name") or venue),
                event_date=event_date,
                description=str(item.get("description") or ""),
                image_url=image,
                source_url=url,
                source_type=source_type,
                source_id=source_id,
                date_source="jsonld",
            )
        )
    return out


_CARD_RE = re.compile(
    r"etkinlik|event|aktivite|gosteri|gösteri|konser|atolye|atölye|tiyatro",
    re.I,
)


def drafts_from_cards(
    html: str,
    *,
    city: str,
    venue: str,
    source_type: str,
    source_id: str,
    page_url: str,
    today: date,
) -> list[EventDraft]:
    soup = BeautifulSoup(html, "html.parser")
    out: list[EventDraft] = []
    seen: set[str] = set()
    for tag in soup.find_all(["article", "li", "div", "section"]):
        text = " ".join(tag.stripped_strings)
        if len(text) < 24 or len(text) > 900:
            continue
        if not _CARD_RE.search(text):
            continue
        heading = tag.find(["h1", "h2", "h3", "h4", "a"])
        title = heading.get_text(" ", strip=True) if heading else ""
        if not title or title.lower() in seen:
            continue
        parsed = parse_event_details(text, today=today)
        if parsed is None:
            continue
        seen.add(title.lower())
        href = ""
        link = tag.find("a", href=True)
        if link:
            href = urljoin(page_url, link["href"])
        img = tag.find("img")
        image = ""
        if img and img.get("src"):
            image = urljoin(page_url, img.get("src"))
        out.append(
            EventDraft(
                title=title[:240],
                city=city,
                venue_name=venue,
                event_date=f"{parsed.start.isoformat()} - {parsed.end.isoformat()}",
                description=text[:2000],
                image_url=image,
                source_url=href or page_url,
                source_type=source_type,
                source_id=source_id,
                date_source="html",
                accessibility_text=text,
            )
        )
    return out


def harvest_html(
    html: str,
    *,
    city: str,
    venue: str,
    source_type: str,
    source_id: str,
    page_url: str,
    today: date,
) -> list[EventDraft]:
    rows = drafts_from_jsonld(
        html,
        city=city,
        venue=venue,
        source_type=source_type,
        source_id=source_id,
        page_url=page_url,
        today=today,
    )
    if rows:
        return rows
    return drafts_from_cards(
        html,
        city=city,
        venue=venue,
        source_type=source_type,
        source_id=source_id,
        page_url=page_url,
        today=today,
    )
