"""AVM etkinlik tarih filtresi — Europe/Istanbul, uydurma yok.

Yeni kayıt: başlangıç bugün veya gelecek; çok günlüde bitiş bugün/gelecekse
hâlâ devam eder. Tarihi geçmiş tek günlük etkinlik eklenmez. Belirsiz tarih
(sürekli / her hafta sonu) mevcut güvenli kurala göre kabul edilir.
"""

from __future__ import annotations

import re
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
    r"her\s+hafta(?:\s+sonu)?|her\s+g[uü]n|her\s+ay|"
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


def parse_event_span(
    raw: str,
    *,
    today: date,
) -> tuple[date, date] | None:
    """(start, end) veya belirsizse None. Yıl/ay uydurulmaz; yıl yoksa today.year."""
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
            return (a, b) if a <= b else (b, a)
    if len(iso) == 1:
        d = _safe_date(int(iso[0][1]), int(iso[0][2]), int(iso[0][3]))
        if d:
            return d, d

    dotted = list(_DOT_RE.finditer(text))
    if len(dotted) >= 2:
        a = _safe_date(int(dotted[0][3]), int(dotted[0][2]), int(dotted[0][1]))
        b = _safe_date(int(dotted[1][3]), int(dotted[1][2]), int(dotted[1][1]))
        if a and b:
            return (a, b) if a <= b else (b, a)
    if len(dotted) == 1:
        d = _safe_date(
            int(dotted[0][3]), int(dotted[0][2]), int(dotted[0][1])
        )
        if d:
            return d, d

    two = _RANGE_TWO_MONTHS_RE.search(text)
    if two:
        m1 = _month_num(two.group(2))
        m2 = _month_num(two.group(5))
        if m1 and m2:
            y2 = int(two.group(6) or today.year)
            y1 = int(two.group(3) or y2)
            a = _safe_date(y1, m1, int(two.group(1)))
            b = _safe_date(y2, m2, int(two.group(4)))
            if a and b:
                return (a, b) if a <= b else (b, a)

    same = _RANGE_SAME_MONTH_RE.search(text)
    if same:
        month = _month_num(same.group(3))
        if month:
            year = int(same.group(4) or today.year)
            a = _safe_date(year, month, int(same.group(1)))
            b = _safe_date(year, month, int(same.group(2)))
            if a and b:
                return (a, b) if a <= b else (b, a)

    one = _SINGLE_RE.search(text)
    if one:
        month = _month_num(one.group(2))
        if month:
            year = int(one.group(3) or today.year)
            d = _safe_date(year, month, int(one.group(1)))
            if d:
                return d, d
    return None


def event_is_live(event_date: str, today: date) -> bool:
    """Yeni kayıt / yayın: bugün, gelecek veya hâlâ devam eden."""
    span = parse_event_span(event_date, today=today)
    if span is None:
        return True
    _start, end = span
    return end >= today


def event_has_ended(event_date: str, today: date) -> bool:
    """Yalnız açıkça bitmiş takvim tarihi. Belirsizse arşivlenmez."""
    span = parse_event_span(event_date, today=today)
    if span is None:
        return False
    _start, end = span
    return end < today


def date_text_from_row(row: dict) -> str:
    direct = str(row.get("event_date") or "").strip()
    if direct:
        return direct
    desc = str(row.get("description") or "")
    first = desc.split("\n", 1)[0].strip()
    return first
