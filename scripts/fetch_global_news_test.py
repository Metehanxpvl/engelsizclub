#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fetch_global_news import (
    SOURCES,
    guess_category,
    item_id,
    merge_item,
    parse_rss,
    strip_html,
)


class GlobalNewsHelpersTest(unittest.TestCase):
    def test_ten_named_sources(self):
        ids = {s["id"] for s in SOURCES}
        self.assertIn("disability-scoop", ids)
        self.assertIn("bbc-disability", ids)
        self.assertIn("ieee-spectrum", ids)
        self.assertEqual(len(SOURCES), 9)

    def test_item_id_stable(self):
        a = item_id("https://www.disabilityscoop.com/foo")
        b = item_id("HTTPS://WWW.DISABILITYSCOOP.COM/FOO")
        self.assertEqual(a, b)
        self.assertEqual(len(a), 24)

    def test_parse_rss(self):
        xml = """<?xml version="1.0"?>
        <rss><channel>
          <item>
            <title>Stem cell trial for wheelchair users</title>
            <link>https://example.com/a</link>
            <description>&lt;p&gt;New recruiting study.&lt;/p&gt;</description>
          </item>
        </channel></rss>
        """
        items = parse_rss(xml)
        self.assertEqual(len(items), 1)
        self.assertEqual(items[0]["url"], "https://example.com/a")
        self.assertIn("recruiting", items[0]["summary"].lower())

    def test_guess_category(self):
        self.assertEqual(guess_category("WCAG 3 draft", ""), "erisilebilirlik")
        self.assertEqual(guess_category("CRISPR gene therapy", ""), "genetik")
        self.assertEqual(guess_category("Bionic arm neural implant", ""), "noroteknoloji")

    def test_merge_keeps_published(self):
        fresh = {
            "id": "x",
            "title": "New EN",
            "summary": "s",
            "status": "pending_review",
        }
        prev = {
            "id": "x",
            "title": "Onaylı TR başlık",
            "summary": "özet",
            "status": "published",
        }
        merged = merge_item(prev, fresh)
        self.assertEqual(merged["status"], "published")
        self.assertEqual(merged["title"], "Onaylı TR başlık")

    def test_strip_html(self):
        self.assertEqual(strip_html("<p>Hello &amp; x</p>"), "Hello &amp; x")


if __name__ == "__main__":
    unittest.main()
