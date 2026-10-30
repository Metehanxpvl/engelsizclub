import sys
import unittest
from datetime import date, datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from avm_event_dates import (
    accessibility_tags,
    date_text_from_row,
    event_has_ended,
    event_is_live,
    event_status,
    make_dedupe_key,
    normalize_title,
    parse_event_details,
    parse_event_span,
    row_has_ended,
    row_is_unknown,
    today_istanbul,
    today_tr_label,
)

TODAY = date(2026, 10, 15)
TODAY_30_OCT = date(2026, 10, 30)


class IstanbulTodayTest(unittest.TestCase):
    def test_utc_morning_is_still_15_october_in_istanbul(self):
        utc = datetime(2026, 10, 15, 1, 30, tzinfo=timezone.utc)
        self.assertEqual(today_istanbul(utc), date(2026, 10, 15))

    def test_utc_evening_rolls_to_istanbul_next_day(self):
        utc = datetime(2026, 10, 14, 21, 30, tzinfo=timezone.utc)
        self.assertEqual(today_istanbul(utc), date(2026, 10, 15))

    def test_label_matches_istanbul_calendar(self):
        self.assertEqual(today_tr_label(TODAY), "15 Ekim 2026")


class ParseSpanTest(unittest.TestCase):
    def test_single_turkish_date(self):
        self.assertEqual(
            parse_event_span("15 Ekim 2026", today=TODAY),
            (date(2026, 10, 15), date(2026, 10, 15)),
        )

    def test_same_month_range(self):
        self.assertEqual(
            parse_event_span("14–16 Ekim 2026", today=TODAY),
            (date(2026, 10, 14), date(2026, 10, 16)),
        )

    def test_range_with_clock(self):
        self.assertEqual(
            parse_event_span("5-6 Eylül 2026, 14:00", today=TODAY),
            (date(2026, 9, 5), date(2026, 9, 6)),
        )

    def test_iso_date(self):
        self.assertEqual(
            parse_event_span("2026-10-14", today=TODAY),
            (date(2026, 10, 14), date(2026, 10, 14)),
        )

    def test_iso_range(self):
        self.assertEqual(
            parse_event_span("2026-06-26 / 2026-07-05", today=TODAY_30_OCT),
            (date(2026, 6, 26), date(2026, 7, 5)),
        )

    def test_dotted_range(self):
        self.assertEqual(
            parse_event_span("26.06.2026 - 05.07.2026", today=TODAY_30_OCT),
            (date(2026, 6, 26), date(2026, 7, 5)),
        )

    def test_range_without_year_uses_today_year(self):
        self.assertEqual(
            parse_event_span("14-16 Ekim", today=TODAY),
            (date(2026, 10, 14), date(2026, 10, 16)),
        )

    def test_two_month_range(self):
        self.assertEqual(
            parse_event_span("25 Ekim - 10 Kasım 2026", today=TODAY),
            (date(2026, 10, 25), date(2026, 11, 10)),
        )

    def test_m1_adana_poster_range_is_past_on_30_october(self):
        parsed = parse_event_details("26 Haziran - 5 Temmuz", today=TODAY_30_OCT)
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.start, date(2026, 6, 26))
        self.assertEqual(parsed.end, date(2026, 7, 5))
        self.assertEqual(parsed.status(TODAY_30_OCT), "past")
        self.assertFalse(event_is_live("26 Haziran - 5 Temmuz", TODAY_30_OCT))

    def test_abbreviated_month_and_turkish_i(self):
        self.assertEqual(
            parse_event_span("26 HAZİRAN - 5 TEMMUZ", today=TODAY_30_OCT),
            (date(2026, 6, 26), date(2026, 7, 5)),
        )
        self.assertEqual(
            parse_event_span("15 Eki 2026", today=TODAY),
            (date(2026, 10, 15), date(2026, 10, 15)),
        )

    def test_same_month_range_with_year(self):
        self.assertEqual(
            parse_event_span("26-28 Haziran 2026", today=TODAY_30_OCT),
            (date(2026, 6, 26), date(2026, 6, 28)),
        )

    def test_recurring_is_uncertain(self):
        self.assertIsNone(parse_event_span("Her hafta sonu", today=TODAY))
        self.assertIsNone(parse_event_span("Devam ediyor", today=TODAY))
        self.assertIsNone(parse_event_span("Sürekli", today=TODAY))
        self.assertIsNone(parse_event_span("Her Cumartesi", today=TODAY))

    def test_does_not_invent_next_year_for_summer_in_autumn(self):
        span = parse_event_span("1 Ağustos", today=TODAY)
        self.assertEqual(span, (date(2026, 8, 1), date(2026, 8, 1)))

    def test_january_in_november_rolls_to_next_year(self):
        parsed = parse_event_details("15 Ocak", today=date(2026, 11, 2))
        self.assertIsNotNone(parsed)
        self.assertEqual(parsed.start, date(2027, 1, 15))
        self.assertTrue(parsed.year_inferred)


class LiveFilterTest(unittest.TestCase):
    def test_user_examples_on_15_october_2026(self):
        self.assertFalse(event_is_live("14 Ekim 2026", TODAY))
        self.assertTrue(event_is_live("15 Ekim 2026", TODAY))
        self.assertTrue(event_is_live("16 Ekim 2026", TODAY))
        self.assertTrue(event_is_live("25 Ekim 2026", TODAY))
        self.assertTrue(event_is_live("10 Kasım 2026", TODAY))
        self.assertTrue(event_is_live("14–16 Ekim", TODAY))

    def test_future_months_are_kept(self):
        self.assertTrue(event_is_live("10 Aralık 2026", TODAY))
        self.assertTrue(event_is_live("3 Ocak 2027", TODAY))

    def test_ended_range_is_rejected(self):
        self.assertFalse(event_is_live("10-12 Ekim 2026", TODAY))

    def test_uncertain_dates_are_not_live(self):
        self.assertFalse(event_is_live("Her hafta sonu", TODAY))
        self.assertFalse(event_is_live("Devam ediyor", TODAY))
        self.assertFalse(event_is_live("AVM animasyon saati", TODAY))
        self.assertEqual(event_status("Devam ediyor", TODAY), "unknown")

    def test_ongoing_range_on_boundary(self):
        self.assertEqual(event_status("14–16 Ekim 2026", TODAY), "ongoing")
        self.assertEqual(event_status("16 Ekim 2026", TODAY), "upcoming")
        self.assertEqual(event_status("14 Ekim 2026", TODAY), "past")

    def test_archive_when_ended_or_unknown(self):
        self.assertTrue(event_has_ended("14 Ekim 2026", TODAY))
        self.assertFalse(event_has_ended("14–16 Ekim 2026", TODAY))
        self.assertFalse(event_has_ended("Her hafta sonu", TODAY))
        self.assertTrue(row_is_unknown({"event_date": "Devam ediyor"}, TODAY))

    def test_date_text_prefers_event_date_column(self):
        self.assertEqual(
            date_text_from_row(
                {"event_date": "16 Ekim 2026", "description": "eski\nmetin"}
            ),
            "16 Ekim 2026",
        )
        self.assertEqual(
            date_text_from_row({"description": "16 Ekim 2026\nMasal saati"}),
            "16 Ekim 2026",
        )

    def test_row_ended_reads_description_when_event_date_empty(self):
        self.assertTrue(
            row_has_ended(
                {"event_date": "", "description": "14 Ekim 2026\nMasal saati"},
                TODAY,
            )
        )
        self.assertFalse(
            row_has_ended(
                {"event_date": "", "description": "16 Ekim 2026\nMasal saati"},
                TODAY,
            )
        )

    def test_row_ended_reads_poster_range_from_title(self):
        self.assertTrue(
            row_has_ended(
                {
                    "event_date": "Devam ediyor",
                    "title": "Oyun Akademisi 26 Haziran - 5 Temmuz",
                },
                TODAY_30_OCT,
            )
        )


class DedupeAndAccessTest(unittest.TestCase):
    def test_title_normalize_folds_turkish(self):
        self.assertEqual(normalize_title("Oyun  Akademisi!"), "oyun akademisi")
        self.assertEqual(normalize_title("İŞARET DİLİ"), "isaret dili")

    def test_dedupe_key_stable(self):
        a = make_dedupe_key("m1-adana", "Oyun Akademisi", date(2026, 6, 26))
        b = make_dedupe_key("m1-adana", "oyun   akademisi", date(2026, 6, 26))
        self.assertEqual(a, b)
        c = make_dedupe_key("m1-adana", "Oyun Akademisi", date(2026, 7, 5))
        self.assertNotEqual(a, c)

    def test_accessibility_tags_from_copy(self):
        tags = accessibility_tags(
            "Rampa ve asansör var. İşaret dili tercümanı, sesli betimleme."
        )
        self.assertIn("rampa", tags)
        self.assertIn("asansor", tags)
        self.assertIn("isaret_dili", tags)
        self.assertIn("sesli_betimleme", tags)


if __name__ == "__main__":
    unittest.main()
