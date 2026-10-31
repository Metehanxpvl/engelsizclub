#!/usr/bin/env python3
"""AVM dışı kaynakları çek, ortak şemaya yaz.

AVM scraper (scripts/avm_scraper.py) ayrı çalışır; bu dosya ek kaynaklar içindir.
Boş sonuç veya hata diğer kaynakları durdurmaz.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from avm_event_dates import event_is_live, today_istanbul, today_tr_label  # noqa: E402
from avm_scraper import (  # noqa: E402
    SOURCE_TAG,
    Supabase,
    _env,
    _load_dotenv,
    _normalize_supabase_url,
    _redact_error,
    archive_past_etkinlikler,
    archive_same_image_etkinlikler,
    external_id,
    sync_etkinlikler,
    write_run_summary,
)
from events.health import load as load_health  # noqa: E402
from events.health import save as save_health
from events.health import update as update_health
from events.http_client import EventHttp, new_client
from events.registry import SKIPPED_SOURCES, SOURCES


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="AVM dışı etkinlik kaynakları")
    p.add_argument("--dry-run", action="store_true")
    return p.parse_args()


def main() -> int:
    _load_dotenv()
    args = parse_args()
    today = today_istanbul()
    health = load_health()
    warnings: list[str] = []
    rows_for_db: list[dict] = []
    summary: list[str] = [
        "## Ek etkinlik kaynakları",
        f"- bugün (Europe/Istanbul): `{today_tr_label(today)}`",
    ]

    with new_client() as raw_http:
        http = EventHttp(raw_http)
        for src in SOURCES:
            started = time.perf_counter()
            try:
                result = src.harvest(http, today)
            except Exception as exc:  # noqa: BLE001
                result_ok = False
                err = _redact_error(str(exc))
                summary.append(f"- **{src.name}**: hata `{err}`")
                streak = update_health(health, src.id, True)
                if streak >= 3:
                    warnings.append(f"{src.name}: art arda {streak} kez hata/boş")
                continue
            elapsed = time.perf_counter() - started
            failed = (not result.ok) or (result.ok and not result.events)
            streak = update_health(health, src.id, failed and not result.skipped)
            if streak >= 3:
                warnings.append(
                    f"{src.name}: art arda {streak} kez 0 sonuç veya hata"
                )
            if result.skipped:
                summary.append(f"- **{src.name}**: atlandı ({result.skipped})")
                continue
            if not result.ok:
                summary.append(f"- **{src.name}**: hata `{result.error}`")
                continue
            kept = 0
            for draft in result.events:
                payload = draft.enriched(today)
                if not event_is_live(payload.get("event_date") or "", today):
                    continue
                payload["source"] = SOURCE_TAG
                eid = external_id(
                    payload["city"],
                    payload["avm_name"],
                    payload["event_name"],
                    payload["event_date"],
                )
                payload["external_id"] = eid
                rows_for_db.append(payload)
                kept += 1
            summary.append(
                f"- **{src.name}**: {kept} etkinlik, "
                f"tarihsiz={result.undated}, {elapsed:.1f}s"
            )

    save_health(health)
    summary.append("")
    summary.append("### Atlanan kaynaklar")
    for skipped in SKIPPED_SOURCES:
        summary.append(f"- {skipped['name']}: {skipped['reason']}")
    if warnings:
        summary.append("")
        summary.append("### Uyarılar")
        for line in warnings:
            summary.append(f"- {line}")

    write_run_summary(summary)

    if args.dry_run:
        print(json.dumps(rows_for_db, ensure_ascii=False, indent=2, default=str))
        return 0

    url = _normalize_supabase_url(_env("SUPABASE_URL"))
    key = _env("SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SERVICE_KEY")
    if not url or not key:
        print("SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY yok; yazılmadı.", flush=True)
        return 0

    with new_client() as http:
        db = Supabase(url, key, http)
        db.require_etkinlikler_columns()
        covers: dict[tuple[str, str], str] = {}
        n = 0
        for i in range(0, len(rows_for_db), 500):
            chunk = rows_for_db[i : i + 500]
            n += db.upsert_events(chunk)
        inserted, updated, skipped = sync_etkinlikler(
            db, rows_for_db, covers, today=today
        )
        archived = archive_past_etkinlikler(db, today=today)
        archived += archive_same_image_etkinlikler(db)
        print(
            f"ek kaynak events upsert={n}; "
            f"insert={inserted} update={updated} skip={skipped} archive={archived}",
            flush=True,
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
    except Exception as exc:  # noqa: BLE001
        print(f"Ölümcül hata: {_redact_error(str(exc))}", file=sys.stderr)
        raise SystemExit(1) from exc
