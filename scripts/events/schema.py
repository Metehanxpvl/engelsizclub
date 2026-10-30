"""Ortak etkinlik taslağı — mevcut kolon adlarını korur, yenileri ekler."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime, timezone
from typing import Any

from avm_event_dates import (
    accessibility_tags,
    make_dedupe_key,
    parse_event_blob,
    today_istanbul,
)


SCRAPER_SOURCE_TYPES = frozenset(
    {"avm", "belediye", "platform", "muze", "dernek"}
)
USER_SOURCE_TYPE = "kullanici"
AVM_SOURCE_TAG = "avm_scrape"


@dataclass
class EventDraft:
    title: str
    city: str
    venue_name: str
    event_date: str
    description: str = ""
    image_url: str = ""
    source_url: str = ""
    source_type: str = "avm"
    source_id: str = ""
    start_time: str = ""
    district: str = ""
    category: str = ""
    is_free: bool | None = None
    price_info: str = ""
    date_source: str = "html"
    accessibility_text: str = ""

    def enriched(self, today: date | None = None) -> dict[str, Any]:
        day = today or today_istanbul()
        parsed = parse_event_blob(
            self.event_date,
            self.title,
            self.description,
            self.source_url,
            today=day,
        )
        start = parsed.start if parsed else None
        end = parsed.end if parsed else None
        if parsed and end is None:
            end = start
        status = parsed.status(day) if parsed else "unknown"
        needs_review = parsed is None
        tags = accessibility_tags(
            self.title, self.description, self.accessibility_text
        )
        source_id = self.source_id or f"{self.source_type}:{self.city}:{self.venue_name}"
        key = make_dedupe_key(source_id, self.title, start)
        now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
        row: dict[str, Any] = {
            "city": self.city[:120],
            "avm_name": self.venue_name[:160],
            "event_name": self.title[:240],
            "event_date": (self.event_date or (start.isoformat() if start else ""))[:160],
            "description": self.description[:2000],
            "image_url": self.image_url[:500],
            "source_url": self.source_url[:500],
            "source_type": self.source_type,
            "start_date": start.isoformat() if start else None,
            "end_date": end.isoformat() if end else (start.isoformat() if start else None),
            "start_time": self.start_time[:16],
            "district": self.district[:80],
            "category": self.category[:80],
            "is_free": self.is_free,
            "price_info": self.price_info[:160],
            "accessibility_tags": tags,
            "date_status": status,
            "date_source": self.date_source,
            "year_inferred": bool(parsed.year_inferred) if parsed else False,
            "needs_review": needs_review,
            "last_seen_at": now,
            "dedupe_key": key,
            "scraped_at": now,
        }
        return row
