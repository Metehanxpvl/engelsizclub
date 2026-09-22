import unittest
from generate_images import imagen_prompt, paper_date, paper_stem, slugify


class GenerateImagesHelpersTest(unittest.TestCase):
    def test_slugify_turkish(self):
        self.assertEqual(slugify("Serebral palsi yürüyüş"), "serebral-palsi-yuruyus")
        self.assertEqual(slugify(""), "makale")

    def test_paper_date_and_stem(self):
        paper = {
            "title": "Faz 2 yürüme denemesi",
            "publication_date": "2026-03-01T00:00:00Z",
            "pmid": "12345678",
        }
        self.assertEqual(paper_date(paper), "2026-03-01")
        self.assertEqual(paper_stem(paper), "2026-03-01_faz-2-yurume-denemesi_12345678")

    def test_prompt_forbids_faces(self):
        prompt = imagen_prompt({"title": "SMA gen tedavisi", "summary": "Faz 3"})
        self.assertIn("No text", prompt)
        self.assertIn("no children", prompt)
        self.assertIn("SMA gen tedavisi", prompt)


if __name__ == "__main__":
    unittest.main()
