"""AVM/etkinlik tarih parse ve durum — Europe/Istanbul, uydurma yok.

Tarih yoksa veya belirsizse (Devam ediyor / her hafta sonu) kayıt canlı sayılmaz.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone

try:
    from zoneinfo import ZoneInfo
except ImportError:  # pragma: no cover
    ZoneInfo = None  # type: ignore[misc, assignment]

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


def _ascii_fold(value: str) -> str:
    table = str.maketrans("çğıöşüÇĞİÖŞÜâîû", "cgiosuCGIOSUaiu")
    return value.translate(table)


_MONTH_NUM: dict[str, int] = {}
for _i, _name in enumerate(_TR_MONTHS):
    if not _name:
        continue
    _MONTH_NUM[_name.lower()] = _i
    folded = _ascii_fold(_name).lower()
    _MONTH_NUM[folded] = _i
    if len(folded) >= 3:
        _MONTH_NUM.setdefault(folded[:3], _i)

_RECURRING_RE = re.compile(
    r"her\s+(?:hafta(?:\s+sonu)?|g[uü]n|ay|cumartesi|pazar|cuma)|"
    r"s[uü]rekli|devam\s+ediyor|devam\s+etmekte|"
    r"belirsiz|yak[iı]nda|\btba\b|\btbd\b",
    re.I,
)

_ISO_RE = re.compile(r"\b(20\d{2})-(\d{1,2})-(\d{1,2})\b")
_DOT_RE = re.compile(r"\b(\d{1,2})[./](\d{1,2})[./](20\d{2})\b")
_RANGE_SAME_MONTH_RE = re.compile(
    r"\b(\d{1,2})\s*[-–—/]\s*(\d{1,2})\s+"
    r"([A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû]+)"
    r"(?:\s+(20\d{2}))?",
    re.I,
)
_RANGE_TWO_MONTHS_RE = re.compile(
    r"\b(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû]+)"
    r"(?:\s+(20\d{2}))?"
    r"\s*[-–—/]\s*"
    r"(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû]+)"
    r"(?:\s+(20\d{2}))?",
    re.I,
)
_SINGLE_RE = re.compile(
    r"\b(\d{1,2})\s+([A-Za-zÇĞİÖŞÜçğıöşüÂÎÛâîû]+)(?:\s+(20\d{2}))?",
    re.I,
)

_ACCESS_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = (
    ("rampa", re.compile(r"\brampa\b", re.I)),
    ("asansor", re.compile(r"asans[oö]r", re.I)),
    ("isaret_dili", re.compile(r"i[sş]aret\s+dili", re.I)),
    ("sesli_betimleme", re.compile(r"sesli\s+betimleme", re.I)),
    ("sakin_saat", re.compile(r"sakin\s+saat", re.I)),
    ("engelli_tuvaleti", re.compile(r"engelli\s+tuvalet", re.I)),
    ("refakatci_ucretsiz", re.compile(r"refakat[cç]i.{0,20}[uü]cretsiz", re.I)),
    ("erisilebilir", re.compile(r"eri[sş]ilebilir", re.I)),
    ("engelli", re.compile(r"\bengelli\b", re.I)),
)


def today_istanbul(now: datetime | None = None) -> date:
    """GitHub Actions UTC olsa da takvim günü Europe/Istanbul."""
    if now is not None:
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        try:
            tz = ZoneInfo("Europe/Istanbul") if ZoneInfo else timezone(
                timedelta(hours=3)
            )
        except Exception:
            tz = timezone(timedelta(hours=3))
        return now.astimezone(tz).date()
    try:
        tz = ZoneInfo("Europe/Istanbul") if ZoneInfo else timezone(
            timedelta(hours=3)
        )
        return datetime.now(tz).date()
    except Exception:
        return datetime.now(timezone(timedelta(hours=3))).date()


def today_tr_label(day: date | None = None) -> str:
    d = day or today_istanbul()
    return f"{d.day} {_TR_MONTHS[d.month]} {d.year}"


def _month_num(raw: str) -> int | None:
    key = _ascii_fold((raw or "").strip()).lower()
    if not key:
        return None
    return _MONTH_NUM.get(key) or _MONTH_NUM.get(key[:3])


def _safe_date(year: int, month: int, day: int) -> date | None:
    try:
        return date(year, month, day)
    except ValueError:
        return None


def _apply_year(
    month: int,
    day: int,
    today: date,
    *,
    given_year: int | None,
    end_month: int | None = None,
    end_day: int | None = None,
) -> tuple[date, date, bool] | None:
    inferred = given_year is None
    year = given_year or today.year
    start = _safe_date(year, month, day)
    if not start:
        return None
    if end_month and end_day:
        end = _safe_date(year, end_month, end_day)
        if not end:
            return None
        if end < start:
            end = _safe_date(year + 1, end_month, end_day)
            if not end:
                return None
    else:
        end = start
    # Geçmişe 3+ ay ve tarih yılın başındaysa (Ekim–Aralık'ta Ocak–Mart)
    # gelecek yıl. Yaz etkinliği sonbaharda past kalır.
    if inferred and end < today and start.month <= 3 and today.month >= 10:
        start = _safe_date(year + 1, month, day)
        if end_month and end_day:
            end = _safe_date(year + 1, end_month, end_day)
            if start and end and end < start:
                end = _safe_date(year + 2, end_month, end_day)
        else:
            end = start
        if not start or not end:
            return None
    return start, end, inferred


@dataclass(frozen=True)
class ParsedSpan:
    start: date
    end: date
    year_inferred: bool = False

    def status(self, today: date) -> str:
        if self.end < today:
            return "past"
        if self.start <= today <= self.end:
            return "ongoing"
        return "upcoming"


def parse_event_span(
    raw: str,
    *,
    today: date,
) -> tuple[date, date] | None:
    parsed = parse_event_details(raw, today=today)
    if parsed is None:
        return None
    return parsed.start, parsed.end


def parse_event_details(raw: str, *, today: date) -> ParsedSpan | None:
    text = re.sub(r"\s+", " ", (raw or "").strip())
    if not text:
        return None
    if _RECURRING_RE.search(text):
        return None

    iso = list(_ISO_RE.finditer(text))
    if len(iso) >= 2:
        a = _safe_date(int(iso[0][1]), int(iso[0][2]), int(iso[0][3]))
        b = _safe_date(int(iso[1][1]), int(iso[1][2]), int(iso[1][3]))
        if a and b:
            start, end = (a, b) if a <= b else (b, a)
            return ParsedSpan(start, end, False)
    if len(iso) == 1:
        d = _safe_date(int(iso[0][1]), int(iso[0][2]), int(iso[0][3]))
        if d:
            return ParsedSpan(d, d, False)

    dotted = list(_DOT_RE.finditer(text))
    if len(dotted) >= 2:
        a = _safe_date(int(dotted[0][3]), int(dotted[0][2]), int(dotted[0][1]))
        b = _safe_date(int(dotted[1][3]), int(dotted[1][2]), int(dotted[1][1]))
        if a and b:
            start, end = (a, b) if a <= b else (b, a)
            return ParsedSpan(start, end, False)
    if len(dotted) == 1:
        d = _safe_date(
            int(dotted[0][3]), int(dotted[0][2]), int(dotted[0][1])
        )
        if d:
            return ParsedSpan(d, d, False)

    two = _RANGE_TWO_MONTHS_RE.search(text)
    if two:
        m1 = _month_num(two.group(2))
        m2 = _month_num(two.group(5))
        if m1 and m2:
            y2 = int(two.group(6)) if two.group(6) else None
            y1 = int(two.group(3)) if two.group(3) else y2
            applied = _apply_year(
                m1,
                int(two.group(1)),
                today,
                given_year=y1,
                end_month=m2,
                end_day=int(two.group(4)),
            )
            if applied:
                start, end, inferred = applied
                if y2:
                    end2 = _safe_date(y2, m2, int(two.group(4)))
                    if end2:
                        end = end2
                        inferred = False
                return ParsedSpan(start, end, inferred)

    same = _RANGE_SAME_MONTH_RE.search(text)
    if same:
        month = _month_num(same.group(3))
        if month:
            year = int(same.group(4)) if same.group(4) else None
            applied = _apply_year(
                month,
                int(same.group(1)),
                today,
                given_year=year,
                end_month=month,
                end_day=int(same.group(2)),
            )
            if applied:
                start, end, inferred = applied
                return ParsedSpan(start, end, inferred)

    one = _SINGLE_RE.search(text)
    if one:
        month = _month_num(one.group(2))
        if month:
            year = int(one.group(3)) if one.group(3) else None
            applied = _apply_year(
                month, int(one.group(1)), today, given_year=year
            )
            if applied:
                start, end, inferred = applied
                return ParsedSpan(start, end, inferred)
    return None


def parse_event_blob(*parts: str, today: date) -> ParsedSpan | None:
    for part in parts:
        parsed = parse_event_details(part, today=today)
        if parsed is not None:
            return parsed
    return None


def event_status(event_date: str, today: date) -> str:
    parsed = parse_event_details(event_date, today=today)
    if parsed is None:
        return "unknown"
    return parsed.status(today)


def event_is_live(event_date: str, today: date) -> bool:
    """Yeni kayıt: parse edilebilir ve bitiş bugün veya gelecek."""
    status = event_status(event_date, today)
    return status in {"ongoing", "upcoming"}


def event_has_ended(event_date: str, today: date) -> bool:
    return event_status(event_date, today) == "past"


def date_text_from_row(row: dict) -> str:
    direct = str(row.get("event_date") or "").strip()
    if direct:
        return direct
    desc = str(row.get("description") or "")
    first = desc.split("\n", 1)[0].strip()
    return first


def row_date_texts(row: dict) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for raw in (
        str(row.get("event_date") or "").strip(),
        str(row.get("title") or "").strip(),
        str(row.get("event_name") or "").strip(),
        str(row.get("description") or "").strip(),
        str(row.get("source_url") or "").strip(),
    ):
        if raw and raw not in seen:
            seen.add(raw)
            out.append(raw)
    return out


def row_span(row: dict, today: date) -> ParsedSpan | None:
    return parse_event_blob(*row_date_texts(row), today=today)


def row_has_ended(row: dict, today: date) -> bool:
    parsed = row_span(row, today)
    return parsed is not None and parsed.status(today) == "past"


def row_is_unknown(row: dict, today: date) -> bool:
    return row_span(row, today) is None


def normalize_title(value: str) -> str:
    folded = _ascii_fold(value or "").lower()
    folded = re.sub(r"[^a-z0-9]+", " ", folded)
    return re.sub(r"\s+", " ", folded).strip()


def make_dedupe_key(source_id: str, title: str, start: date | None) -> str:
    start_s = start.isoformat() if start else ""
    raw = f"{source_id}|{normalize_title(title)}|{start_s}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def accessibility_tags(*parts: str) -> list[str]:
    blob = " ".join(parts)
    if not blob.strip():
        return []
    found: list[str] = []
    for tag, pattern in _ACCESS_PATTERNS:
        if pattern.search(blob) and tag not in found:
            found.append(tag)
    return found
