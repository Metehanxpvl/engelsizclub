import json
import sys
import unittest
from datetime import date
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SCRIPT_DIR))

from avm_event_dates import event_is_live, make_dedupe_key
from events.jsonld import extract_jsonld_events
from events.schema import EventDraft
from events.sources.html_cards import harvest_html
from events.health import update as update_health

FIXTURE = Path(__file__).resolve().parent / "fixtures" / "jsonld_event.html"
TODAY = date(2026, 10, 30)


class JsonLdFixtureTest(unittest.TestCase):
    def test_extracts_schema_event(self):
        html = FIXTURE.read_text(encoding="utf-8")
        rows = extract_jsonld_events(html)
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["event_name"], "Çocuk Atölyesi")
        self.assertTrue(str(rows[0]["event_date"]).startswith("2026-11-10"))
        self.assertEqual(rows[0]["date_source"], "jsonld")

    def test_harvest_prefers_jsonld(self):
        html = FIXTURE.read_text(encoding="utf-8")
        drafts = harvest_html(
            html,
            city="İstanbul",
            venue="İstanbul Modern",
            source_type="muze",
            source_id="istanbul-modern",
            page_url="https://example.org/etkinlikler",
            today=TODAY,
        )
        self.assertGreaterEqual(len(drafts), 1)
        self.assertEqual(drafts[0].title, "Çocuk Atölyesi")
        self.assertEqual(drafts[0].date_source, "jsonld")
        row = drafts[0].enriched(TODAY)
        self.assertEqual(row["date_status"], "upcoming")
        self.assertIn("rampa", row["accessibility_tags"])
        self.assertTrue(event_is_live(row["event_date"], TODAY))
        self.assertEqual(len(row["dedupe_key"]), 64)


class SchemaTest(unittest.TestCase):
    def test_unknown_needs_review(self):
        draft = EventDraft(
            title="Animasyon",
            city="Adana",
            venue_name="M1 Adana",
            event_date="Devam ediyor",
            source_type="avm",
        )
        row = draft.enriched(TODAY)
        self.assertEqual(row["date_status"], "unknown")
        self.assertTrue(row["needs_review"])
        self.assertIsNone(row["end_date"])

    def test_dedupe_stable(self):
        a = make_dedupe_key("avm:Adana:M1", "Oyun Akademisi", date(2026, 6, 26))
        b = make_dedupe_key("avm:Adana:M1", "oyun akademisi", date(2026, 6, 26))
        self.assertEqual(a, b)

    def test_health_streak(self):
        streaks: dict[str, int] = {}
        self.assertEqual(update_health(streaks, "ibb", True), 1)
        self.assertEqual(update_health(streaks, "ibb", True), 2)
        self.assertEqual(update_health(streaks, "ibb", True), 3)
        self.assertEqual(update_health(streaks, "ibb", False), 0)


class RegistryImportTest(unittest.TestCase):
    def test_registry_loads(self):
        from events.registry import SKIPPED_SOURCES, SOURCES

        self.assertGreaterEqual(len(SOURCES), 5)
        self.assertTrue(any(s["name"].startswith("Biletix") for s in SKIPPED_SOURCES))
        payload = json.dumps(
            [{"id": s.id, "type": s.source_type} for s in SOURCES]
        )
        self.assertIn("ibb-kultur", payload)


if __name__ == "__main__":
    unittest.main()
