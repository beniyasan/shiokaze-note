"""Regression checks for the generated fisherman sprite sheet."""
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


class HeroArtTests(unittest.TestCase):
    def test_sheet_keeps_runtime_contract(self):
        with Image.open(ROOT / "assets" / "hero.png") as hero:
            self.assertEqual(hero.size, (64, 96))
            self.assertEqual(hero.mode, "RGBA")
            for face in range(4):
                for frame in range(4):
                    crop = hero.crop((frame * 16, face * 24, frame * 16 + 16, face * 24 + 24))
                    # The walk renderer samples every cell directly; a blank or
                    # clipped cell would make one direction disappear in-game.
                    self.assertGreater(sum(1 for px in crop.getdata() if px[3]), 70)

    def test_each_facing_retains_fisherman_silhouette_cues(self):
        with Image.open(ROOT / "assets" / "hero.png") as hero:
            # The brim and vest occupy stable local rows across all directions.
            for face in range(4):
                cell = hero.crop((0, face * 24, 16, face * 24 + 24))
                self.assertTrue(any(cell.getpixel((x, 4))[3] for x in range(3, 14)))
                self.assertTrue(any(cell.getpixel((x, 14))[:3] == (61, 113, 114) for x in range(4, 12)))
            # Rod tips point away from the body in each directional silhouette.
            self.assertGreater(hero.getpixel((15, 3))[3], 0)  # front
            self.assertGreater(hero.getpixel((1, 24 + 3))[3], 0)  # back
            self.assertGreater(hero.getpixel((0, 48 + 3))[3], 0)  # left
            self.assertGreater(hero.getpixel((15, 72 + 3))[3], 0)  # right


if __name__ == "__main__":
    unittest.main()
