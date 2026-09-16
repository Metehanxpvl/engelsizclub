import json
import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_city_poster import (
    CITIES,
    IMAGE_MODELS,
    TEXT_MODELS,
    cities_from_input,
    extract_inline_image_bytes,
    headline,
    is_all_cities,
    locative,
    poster_filename,
    resolve_city,
    scan_output_posters,
    slug_city,
    tr_upper,
    write_index,
)


class CityPosterHelpersTest(unittest.TestCase):
    def test_eighty_one_cities_kcitynames_order(self):
        self.assertEqual(len(CITIES), 81)
        self.assertEqual(len(set(CITIES)), 81)
        self.assertEqual(CITIES[0], "Adana")
        self.assertEqual(CITIES[1], "Adıyaman")
        self.assertEqual(CITIES[-2], "Aksaray")
        self.assertEqual(CITIES[-1], "Ardahan")
        self.assertEqual(CITIES.index("Gaziantep"), 30)

    def test_all_cities_tokens(self):
        for token in ("", "ALL", "all", "*", "81", "tüm", "hepsi"):
            self.assertTrue(is_all_cities(token), token)
            cities = cities_from_input(token)
            self.assertEqual(cities, list(CITIES))
        self.assertFalse(is_all_cities("Gaziantep"))

    def test_single_city_override(self):
        self.assertEqual(cities_from_input("Gaziantep"), ["Gaziantep"])
        self.assertEqual(cities_from_input("Antep"), ["Gaziantep"])
        self.assertEqual(cities_from_input("istanbul"), ["İstanbul"])

    def test_resolve_city_aliases(self):
        self.assertEqual(resolve_city("gaziantep"), "Gaziantep")
        self.assertEqual(resolve_city("Antep"), "Gaziantep")
        self.assertEqual(resolve_city("istanbul"), "İstanbul")
        self.assertEqual(resolve_city("İZMİR"), "İzmir")
        with self.assertRaises(ValueError):
            resolve_city("")

    def test_reject_unknown(self):
        with self.assertRaises(ValueError):
            resolve_city("Londra")
        with self.assertRaises(ValueError):
            cities_from_input("Londra")

    def test_locative(self):
        self.assertEqual(locative("Gaziantep"), "Gaziantep'te")
        self.assertEqual(locative("İstanbul"), "İstanbul'da")
        self.assertEqual(locative("Ankara"), "Ankara'da")
        self.assertEqual(locative("İzmir"), "İzmir'de")
        self.assertEqual(locative("Uşak"), "Uşak'ta")

    def test_headline_and_filename(self):
        self.assertEqual(tr_upper("Gaziantep"), "GAZİANTEP")
        self.assertEqual(headline("Gaziantep"), "GAZİANTEP'TE MÜZE GEZİSİ")
        self.assertEqual(slug_city("Gaziantep"), "gaziantep")
        self.assertEqual(
            poster_filename("Gaziantep", when=date(2026, 9, 16)),
            "gaziantep_muze_gezisi_2026-09-16.jpg",
        )

    def test_current_model_names(self):
        self.assertEqual(TEXT_MODELS[0], "gemini-2.5-flash")
        self.assertNotIn("gemini-2.0-flash", TEXT_MODELS)
        self.assertEqual(IMAGE_MODELS[0], "gemini-2.5-flash-image")
        self.assertIn("gemini-3.1-flash-image", IMAGE_MODELS)
        self.assertNotIn("imagen-3.0-generate-002", IMAGE_MODELS)
        self.assertNotIn("gemini-2.0-flash-preview-image-generation", IMAGE_MODELS)
        src = Path(__file__).with_name("generate_city_poster.py").read_text(encoding="utf-8")
        self.assertIn('["IMAGE"]', src)
        self.assertIn("index.json", src)
        self.assertIn("scan_output_posters", src)

    def test_no_legacy_imagen_calls(self):
        src = Path(__file__).with_name("generate_city_poster.py").read_text(encoding="utf-8")
        self.assertNotIn(".generate_images(", src)
        self.assertNotIn("IMAGEN_REST", src)
        self.assertNotIn("imagen-3.0-generate-002", src)
        self.assertIn("generate_content", src)
        self.assertIn(":generateContent", src)

    def test_extract_inline_image_bytes(self):
        png = b"\x89PNG\r\n\x1a\n" + b"fake"

        class Obj:
            def __init__(self, **kw):
                self.__dict__.update(kw)

        part = Obj(inline_data=Obj(data=png, mime_type="image/png"), text=None)
        resp = Obj(parts=[part], candidates=[Obj(content=Obj(parts=[part]))])
        self.assertEqual(extract_inline_image_bytes(resp), png)

        rest = {
            "candidates": [
                {
                    "content": {
                        "parts": [
                            {"inlineData": {"mimeType": "image/png", "data": png}},
                        ]
                    }
                }
            ]
        }
        self.assertEqual(extract_inline_image_bytes(rest), png)

    def test_index_latest_date_wins(self):
        import tempfile

        with tempfile.TemporaryDirectory() as raw:
            out = Path(raw)
            (out / "adana_muze_gezisi_2026-09-01.jpg").write_bytes(b"old")
            (out / "adana_muze_gezisi_2026-09-16.jpg").write_bytes(b"new")
            (out / "gaziantep_muze_gezisi_2026-09-16.png").write_bytes(b"g")
            (out / "index.json").write_text("{}", encoding="utf-8")
            posters = scan_output_posters(out)
            by_slug = {row["slug"]: row for row in posters}
            self.assertEqual(by_slug["adana"]["date"], "2026-09-16")
            self.assertEqual(by_slug["adana"]["file"], "adana_muze_gezisi_2026-09-16.jpg")
            self.assertTrue(by_slug["gaziantep"]["file"].endswith(".png"))
            path = write_index(out, ok=2, fail=0, skip=0, total=81)
            payload = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(payload["ok"], 2)
            self.assertEqual(len(payload["posters"]), 2)
            self.assertEqual(payload["posters"][0]["city"], "Adana")


if __name__ == "__main__":
    unittest.main()
