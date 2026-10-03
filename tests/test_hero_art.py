"""Regression checks for the 32x48 authored fisherman sprite sheet."""
from pathlib import Path
import unittest

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


class HeroArtTests(unittest.TestCase):
    def test_sheet_keeps_runtime_contract(self):
        with Image.open(ROOT / "assets" / "hero.png") as hero:
            self.assertEqual(hero.size, (128, 192))
            self.assertEqual(hero.mode, "RGBA")
            for face in range(4):
                for frame in range(4):
                    crop = hero.crop((frame * 32, face * 48, frame * 32 + 32, face * 48 + 48))
                    # The walk renderer samples every cell directly. A blank or
                    # clipped cell would make one direction disappear in-game.
                    self.assertGreater(sum(1 for px in crop.getdata() if px[3]), 360)

    def test_each_facing_has_reference_scale_proportions(self):
        with Image.open(ROOT / "assets" / "hero.png") as hero:
            for face in range(4):
                cell = hero.crop((0, face * 48, 32, face * 48 + 48))
                # Cap/brim and boots should be separated by a readable body.
                self.assertTrue(any(cell.getpixel((x, 10))[3] for x in range(6, 27)))
                self.assertTrue(any(cell.getpixel((x, 42))[3] for x in range(8, 25)))
                # The teal vest and warm cap band are the stable authored cues.
                self.assertTrue(any(cell.getpixel((x, 27))[:3] == (52, 116, 119) for x in range(8, 24)))
                self.assertTrue(any(cell.getpixel((x, 11))[:3] == (208, 172, 99) for x in range(6, 27)))

            # Rod tips point away from the body in all directional silhouettes.
            self.assertGreater(hero.getpixel((31, 3))[3], 0)       # front
            self.assertGreater(hero.getpixel((1, 48 + 3))[3], 0)   # back
            self.assertGreater(hero.getpixel((0, 96 + 3))[3], 0)   # left
            self.assertGreater(hero.getpixel((31, 144 + 3))[3], 0) # right


if __name__ == "__main__":
    unittest.main()
