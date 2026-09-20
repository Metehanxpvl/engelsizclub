#!/usr/bin/env python3
"""81 il valilik resmi .gov.tr bağlantıları → web/valilikler.json.

Useful content collector bu kataloğu okur; uygulama il dizinini buradan yükler.
Ağ yoksa --offline ile plaka listesinden yeniden üretir; mevcut özel URL'ler korunur.
"""
from __future__ import annotations

import argparse
import json
import ssl
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable
from urllib.parse import urljoin, urlparse

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUT = REPO_ROOT / "web" / "valilikler.json"

PROVINCES: list[tuple[str, str]] = [
    ("01", "Adana"),
    ("02", "Adıyaman"),
    ("03", "Afyonkarahisar"),
    ("04", "Ağrı"),
    ("05", "Amasya"),
    ("06", "Ankara"),
    ("07", "Antalya"),
    ("08", "Artvin"),
    ("09", "Aydın"),
    ("10", "Balıkesir"),
    ("11", "Bilecik"),
    ("12", "Bingöl"),
    ("13", "Bitlis"),
    ("14", "Bolu"),
    ("15", "Burdur"),
    ("16", "Bursa"),
    ("17", "Çanakkale"),
    ("18", "Çankırı"),
    ("19", "Çorum"),
    ("20", "Denizli"),
    ("21", "Diyarbakır"),
    ("22", "Edirne"),
    ("23", "Elazığ"),
    ("24", "Erzincan"),
    ("25", "Erzurum"),
    ("26", "Eskişehir"),
    ("27", "Gaziantep"),
    ("28", "Giresun"),
    ("29", "Gümüşhane"),
    ("30", "Hakkari"),
    ("31", "Hatay"),
    ("32", "Isparta"),
    ("33", "Mersin"),
    ("34", "İstanbul"),
    ("35", "İzmir"),
    ("36", "Kars"),
    ("37", "Kastamonu"),
    ("38", "Kayseri"),
    ("39", "Kırklareli"),
    ("40", "Kırşehir"),
    ("41", "Kocaeli"),
    ("42", "Konya"),
    ("43", "Kütahya"),
    ("44", "Malatya"),
    ("45", "Manisa"),
    ("46", "Kahramanmaraş"),
    ("47", "Mardin"),
    ("48", "Muğla"),
    ("49", "Muş"),
    ("50", "Nevşehir"),
    ("51", "Niğde"),
    ("52", "Ordu"),
    ("53", "Rize"),
    ("54", "Sakarya"),
    ("55", "Samsun"),
    ("56", "Siirt"),
    ("57", "Sinop"),
    ("58", "Sivas"),
    ("59", "Tekirdağ"),
    ("60", "Tokat"),
    ("61", "Trabzon"),
    ("62", "Tunceli"),
    ("63", "Şanlıurfa"),
    ("64", "Uşak"),
    ("65", "Van"),
    ("66", "Yozgat"),
    ("67", "Zonguldak"),
    ("68", "Aksaray"),
    ("69", "Bayburt"),
    ("70", "Karaman"),
    ("71", "Kırıkkale"),
    ("72", "Batman"),
    ("73", "Şırnak"),
    ("74", "Bartın"),
    ("75", "Ardahan"),
    ("76", "Iğdır"),
    ("77", "Yalova"),
    ("78", "Karabük"),
    ("79", "Kilis"),
    ("80", "Osmaniye"),
    ("81", "Düzce"),
]

_FOLD = str.maketrans(
    {
        "ı": "i",
        "İ": "i",
        "ğ": "g",
        "Ğ": "g",
        "ü": "u",
        "Ü": "u",
        "ş": "s",
        "Ş": "s",
        "ö": "o",
        "Ö": "o",
        "ç": "c",
        "Ç": "c",
    }
)

ProbeFn = Callable[[str], tuple[int | None, str | None]]

_SSL = ssl.create_default_context()
_UA = "EngelsizClub-ValilikBot/1.0 (+https://www.engelsizclub.com)"


def fold_slug(city: str) -> str:
    s = (city or "").translate(_FOLD).lower()
    return "".join(ch for ch in s if ch.isalnum())


def default_origin(city: str) -> str:
    return f"https://www.{fold_slug(city)}.gov.tr"


def canonicalize_url(url: str) -> str:
    raw = (url or "").strip()
    if not raw:
        return ""
    parsed = urlparse(raw)
    if not parsed.scheme:
        raw = "https://" + raw.lstrip("/")
        parsed = urlparse(raw)
    path = parsed.path or ""
    if path != "/" and path.endswith("/"):
        path = path.rstrip("/")
    query = f"?{parsed.query}" if parsed.query else ""
    netloc = parsed.netloc
    return f"{parsed.scheme}://{netloc}{path or ''}{query}".rstrip("/") or raw


def is_official_gov_tr(url: str) -> bool:
    try:
        parsed = urlparse(url)
    except ValueError:
        return False
    if parsed.scheme not in ("http", "https"):
        return False
    host = (parsed.hostname or "").lower()
    if host.startswith("www."):
        host = host[4:]
    if not host.endswith(".gov.tr"):
        return False
    if host in ("gov.tr", "www.gov.tr"):
        return False
    return True


def default_item(plate: str, city: str) -> dict[str, str]:
    origin = default_origin(city)
    return {
        "plate": plate,
        "city": city,
        "slug": fold_slug(city),
        "url": origin,
        "duyurular_url": f"{origin}/duyurular",
        "engelli_url": f"{origin}/engelli",
    }


def load_catalog(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def items_by_plate(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for raw in payload.get("items") or []:
        if not isinstance(raw, dict):
            continue
        plate = str(raw.get("plate") or "").zfill(2)
        if plate:
            out[plate] = raw
    return out


def pick_url(prev: dict[str, Any] | None, key: str, fallback: str) -> str:
    if not prev:
        return fallback
    candidate = canonicalize_url(str(prev.get(key) or ""))
    return candidate if is_official_gov_tr(candidate) else fallback


def merge_item(prev: dict[str, Any] | None, fresh: dict[str, Any]) -> dict[str, str]:
    plate = str(fresh.get("plate") or "")
    city = str(fresh.get("city") or "")
    base = default_item(plate, city)
    return {
        "plate": plate,
        "city": city,
        "slug": str(fresh.get("slug") or base["slug"]),
        "url": pick_url(prev, "url", str(fresh.get("url") or base["url"])),
        "duyurular_url": pick_url(
            prev, "duyurular_url", str(fresh.get("duyurular_url") or base["duyurular_url"])
        ),
        "engelli_url": pick_url(
            prev, "engelli_url", str(fresh.get("engelli_url") or base["engelli_url"])
        ),
    }


def _request(url: str, method: str, timeout: float) -> tuple[int | None, str | None]:
    req = urllib.request.Request(
        url,
        method=method,
        headers={"User-Agent": _UA, "Accept": "text/html,application/xhtml+xml,*/*;q=0.8"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=_SSL) as res:
            final = canonicalize_url(res.geturl() or url)
            return int(getattr(res, "status", 200) or 200), final
    except urllib.error.HTTPError as e:
        final = canonicalize_url(getattr(e, "url", None) or url)
        return int(e.code), final
    except (urllib.error.URLError, TimeoutError, OSError, ValueError):
        return None, None


def probe_url(url: str, timeout: float = 12.0) -> tuple[int | None, str | None]:
    target = canonicalize_url(url)
    if not target:
        return None, None
    status, final = _request(target, "HEAD", timeout)
    if status in (405, 501, 403) or status is None:
        status, final = _request(target, "GET", timeout)
    if status and 200 <= status < 400 and final and is_official_gov_tr(final):
        return status, final
    if status and 200 <= status < 400:
        return status, None
    return status, None


def prefer_working(current: str, probed: str | None, status: int | None) -> str:
    if probed and is_official_gov_tr(probed) and status and 200 <= status < 400:
        return canonicalize_url(probed)
    if is_official_gov_tr(current):
        return canonicalize_url(current)
    return canonicalize_url(current) or current


def join_path(origin: str, path: str) -> str:
    base = canonicalize_url(origin) + "/"
    return canonicalize_url(urljoin(base, path.lstrip("/")))


def verify_item(item: dict[str, str], probe: ProbeFn) -> dict[str, str]:
    home_status, home_final = probe(item["url"])
    url = prefer_working(item["url"], home_final, home_status)
    origin = url

    duy_default = join_path(origin, "duyurular")
    duy_status, duy_final = probe(item.get("duyurular_url") or duy_default)
    duyurular = prefer_working(item.get("duyurular_url") or duy_default, duy_final, duy_status)
    if not (duy_status and 200 <= duy_status < 400):
        alt_status, alt_final = probe(duy_default)
        duyurular = prefer_working(duyurular, alt_final, alt_status)

    eng_default = join_path(origin, "engelli")
    eng_status, eng_final = probe(item.get("engelli_url") or eng_default)
    engelli = prefer_working(item.get("engelli_url") or eng_default, eng_final, eng_status)
    if not (eng_status and 200 <= eng_status < 400):
        for path in ("engelli-hizmetleri", "engelsiz"):
            alt_status, alt_final = probe(join_path(origin, path))
            if alt_status and 200 <= alt_status < 400 and alt_final:
                engelli = canonicalize_url(alt_final)
                break

    return {
        **item,
        "url": url,
        "duyurular_url": duyurular,
        "engelli_url": engelli,
    }


def build_catalog(
    previous: dict[str, Any] | None = None,
    *,
    probe: ProbeFn | None = None,
    now: datetime | None = None,
) -> dict[str, Any]:
    prev_map = items_by_plate(previous or {})
    items: list[dict[str, str]] = []
    for plate, city in PROVINCES:
        merged = merge_item(prev_map.get(plate), default_item(plate, city))
        if probe is not None:
            merged = verify_item(merged, probe)
        items.append(merged)
    stamp = (now or datetime.now(timezone.utc)).replace(microsecond=0).isoformat()
    if stamp.endswith("+00:00"):
        stamp = stamp[:-6] + "Z"
    return {
        "source": "engelsiz-club-valilikler",
        "updatedAt": stamp,
        "ok": True,
        "count": len(items),
        "items": items,
    }


def write_catalog(payload: dict[str, Any], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="81 il valilik .gov.tr katalog güncelleyici")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument(
        "--offline",
        action="store_true",
        help="Ağ yok; plaka listesi + mevcut JSON birleşimi yazılır.",
    )
    parser.add_argument("--workers", type=int, default=8)
    args = parser.parse_args(argv)

    previous = load_catalog(args.out)
    probe: ProbeFn | None = None
    if not args.offline:
        def probe(url: str) -> tuple[int | None, str | None]:
            return probe_url(url)

        workers = max(1, min(args.workers, 12))
        prev_map = items_by_plate(previous)
        seeds = [
            merge_item(prev_map.get(plate), default_item(plate, city))
            for plate, city in PROVINCES
        ]
        verified: dict[str, dict[str, str]] = {}
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futs = {pool.submit(verify_item, item, probe): item["plate"] for item in seeds}
            for fut in as_completed(futs):
                plate = futs[fut]
                try:
                    verified[plate] = fut.result()
                except Exception as e:  # pragma: no cover - ağ hatası
                    print(f"valilik {plate} doğrulanamadı, önceki URL kaldı: {e}", file=sys.stderr)
                    verified[plate] = next(i for i in seeds if i["plate"] == plate)
        items = [verified[plate] for plate, _ in PROVINCES]
        stamp = datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        payload = {
            "source": "engelsiz-club-valilikler",
            "updatedAt": stamp,
            "ok": True,
            "count": len(items),
            "items": items,
        }
    else:
        payload = build_catalog(previous, probe=None)

    if payload.get("count") != 81 or len(payload.get("items") or []) != 81:
        print("valilik kataloğu 81 il değil; yazılmadı.", file=sys.stderr)
        return 1
    write_catalog(payload, args.out)
    print(f"valilikler: {payload['count']} il → {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
