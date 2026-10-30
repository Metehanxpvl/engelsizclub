"""Kaynak sağlık takibi (3 ardışık boş/hata → uyarı)."""

from __future__ import annotations

import json
from pathlib import Path

DEFAULT_PATH = Path(__file__).resolve().parent / ".health.json"


def load(path: Path | None = None) -> dict[str, int]:
    p = path or DEFAULT_PATH
    if not p.is_file():
        return {}
    try:
        data = json.loads(p.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    if not isinstance(data, dict):
        return {}
    out: dict[str, int] = {}
    for key, val in data.items():
        try:
            out[str(key)] = int(val)
        except (TypeError, ValueError):
            continue
    return out


def save(streaks: dict[str, int], path: Path | None = None) -> None:
    p = path or DEFAULT_PATH
    p.write_text(
        json.dumps(streaks, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def update(streaks: dict[str, int], source_id: str, failed_or_empty: bool) -> int:
    if failed_or_empty:
        streaks[source_id] = streaks.get(source_id, 0) + 1
    else:
        streaks[source_id] = 0
    return streaks[source_id]
