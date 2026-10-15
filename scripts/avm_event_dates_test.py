import sys
import unittest
from datetime import date, datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from avm_event_dates import (
    date_text_from_row,
    event_has_ended,
    event_is_live,
    parse_event_span,
    today_istanbul,
    today_tr_label,
)

TODAY = date(2026, 10, 15)


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

    def test_recurring_is_uncertain(self):
        self.assertIsNone(parse_event_span("Her hafta sonu", today=TODAY))
        self.assertIsNone(parse_event_span("Devam ediyor", today=TODAY))
        self.assertIsNone(parse_event_span("Sürekli", today=TODAY))

    def test_does_not_invent_next_year(self):
        span = parse_event_span("1 Ağustos", today=TODAY)
        self.assertEqual(span, (date(2026, 8, 1), date(2026, 8, 1)))


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

    def test_uncertain_dates_follow_safe_keep_rule(self):
        self.assertTrue(event_is_live("Her hafta sonu", TODAY))
        self.assertTrue(event_is_live("Devam ediyor", TODAY))
        self.assertTrue(event_is_live("AVM animasyon saati", TODAY))

    def test_archive_only_when_span_clearly_ended(self):
        self.assertTrue(event_has_ended("14 Ekim 2026", TODAY))
        self.assertFalse(event_has_ended("14–16 Ekim 2026", TODAY))
        self.assertFalse(event_has_ended("Her hafta sonu", TODAY))

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


if __name__ == "__main__":
    unittest.main()
