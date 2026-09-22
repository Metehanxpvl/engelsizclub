#!/usr/bin/env python3
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from fetch_valilikler import (
    PROVINCES,
    build_catalog,
    canonicalize_url,
    default_item,
    fold_slug,
    is_official_gov_tr,
    merge_item,
    verify_item,
)


class ValilikHelpersTest(unittest.TestCase):
    def test_eighty_one_plates_in_order(self):
        self.assertEqual(len(PROVINCES), 81)
        self.assertEqual(PROVINCES[0], ("01", "Adana"))
        self.assertEqual(PROVINCES[33], ("34", "İstanbul"))
        self.assertEqual(PROVINCES[-1], ("81", "Düzce"))
        plates = [p for p, _ in PROVINCES]
        self.assertEqual(plates, [f"{i:02d}" for i in range(1, 82)])

    def test_slug_folds_turkish(self):
        self.assertEqual(fold_slug("İstanbul"), "istanbul")
        self.assertEqual(fold_slug("Şanlıurfa"), "sanliurfa")
        self.assertEqual(fold_slug("Ağrı"), "agri")
        self.assertEqual(fold_slug("Kahramanmaraş"), "kahramanmaras")

    def test_default_urls_are_gov_tr(self):
        item = default_item("06", "Ankara")
        self.assertEqual(item["url"], "https://www.ankara.gov.tr")
        self.assertTrue(is_official_gov_tr(item["url"]))
        self.assertTrue(item["duyurular_url"].endswith("/duyurular"))

    def test_rejects_non_gov_hosts(self):
        self.assertFalse(is_official_gov_tr("https://example.com"))
        self.assertFalse(is_official_gov_tr("https://gov.tr"))
        self.assertFalse(is_official_gov_tr("javascript:alert(1)"))
        self.assertTrue(is_official_gov_tr("https://www.istanbul.gov.tr/duyurular"))

    def test_merge_keeps_working_custom_url(self):
        prev = {
            "plate": "16",
            "city": "Bursa",
            "url": "https://www.bursa.gov.tr",
            "duyurular_url": "https://www.bursa.gov.tr/haberler",
        }
        merged = merge_item(prev, default_item("16", "Bursa"))
        self.assertEqual(merged["duyurular_url"], "https://www.bursa.gov.tr/haberler")

    def test_merge_drops_non_gov_prev(self):
        prev = {"url": "https://phishing.example/bursa"}
        merged = merge_item(prev, default_item("16", "Bursa"))
        self.assertEqual(merged["url"], "https://www.bursa.gov.tr")

    def test_canonicalize_strips_slash(self):
        self.assertEqual(
            canonicalize_url("https://www.adana.gov.tr/"),
            "https://www.adana.gov.tr",
        )

    def test_verify_follows_official_redirect(self):
        def probe(url: str):
            if url.endswith("gov.tr"):
                return 301, "https://www.adana.gov.tr"
            if url.endswith("/duyurular"):
                return 200, url
            if url.endswith("/engelli"):
                return 404, url
            if url.endswith("/engelli-hizmetleri"):
                return 200, url
            return 404, url

        out = verify_item(default_item("01", "Adana"), probe)
        self.assertEqual(out["url"], "https://www.adana.gov.tr")
        self.assertTrue(out["duyurular_url"].endswith("/duyurular"))
        self.assertTrue(out["engelli_url"].endswith("/engelli-hizmetleri"))

    def test_offline_catalog_has_81(self):
        payload = build_catalog({}, probe=None)
        self.assertEqual(payload["count"], 81)
        self.assertEqual(len(payload["items"]), 81)
        self.assertEqual(payload["source"], "engelsiz-club-valilikler")
        self.assertTrue(payload["ok"])


if __name__ == "__main__":
    unittest.main()
