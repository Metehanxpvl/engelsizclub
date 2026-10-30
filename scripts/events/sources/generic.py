"""Tek URL'lik HTML/JSON-LD kaynağı."""

from __future__ import annotations

from datetime import date

from events.base import SourceResult
from events.http_client import EventHttp, FetchError
from events.sources.html_cards import harvest_html


class GenericHtmlSource:
    def __init__(
        self,
        *,
        source_id: str,
        name: str,
        source_type: str,
        start_url: str,
        city: str,
        venue: str,
    ) -> None:
        self.id = source_id
        self.name = name
        self.source_type = source_type
        self.start_url = start_url
        self.city = city
        self.venue = venue

    def harvest(self, http: EventHttp, today: date) -> SourceResult:
        try:
            fetched = http.get_text(self.start_url)
        except FetchError as exc:
            return SourceResult(self.id, False, error=str(exc))
        if fetched is None:
            return SourceResult(
                self.id, False, skipped="robots.txt bu yolu yasaklıyor"
            )
        url, html = fetched
        if not html:
            return SourceResult(self.id, True, events=[])
        drafts = harvest_html(
            html,
            city=self.city,
            venue=self.venue,
            source_type=self.source_type,
            source_id=self.id,
            page_url=url,
            today=today,
        )
        undated = 0
        live = []
        for draft in drafts:
            row = draft.enriched(today)
            if row["needs_review"] or row["date_status"] == "unknown":
                undated += 1
                continue
            if row["date_status"] == "past":
                continue
            live.append(draft)
        return SourceResult(self.id, True, events=live, undated=undated)
