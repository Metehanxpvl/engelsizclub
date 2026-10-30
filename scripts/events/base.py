"""Kaynak arayüzü — yeni kaynak = bir dosya + registry satırı."""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Protocol

from events.http_client import EventHttp
from events.schema import EventDraft


@dataclass
class SourceResult:
    source_id: str
    ok: bool
    events: list[EventDraft] = field(default_factory=list)
    error: str = ""
    skipped: str = ""
    undated: int = 0


class EventSource(Protocol):
    id: str
    name: str
    source_type: str
    start_url: str

    def harvest(self, http: EventHttp, today: date) -> SourceResult:
        ...
