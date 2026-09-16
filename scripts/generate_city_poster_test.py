import sys
import unittest
from datetime import date
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from generate_city_poster import (
    CITIES,
    cities_from_input,
    headline,
    is_all_cities,
    locative,
    poster_filename,
    resolve_city,
    slug_city,
    tr_upper,
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


if __name__ == "__main__":
    unittest.main()
