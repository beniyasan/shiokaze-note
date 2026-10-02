"""Focused regression checks for generated expanded fish art."""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import generate_expanded_fish_art as generator  # noqa: E402


class ExpandedFishArtTests(unittest.TestCase):
    def test_night_sailfish_geometry_stays_inside_card(self):
        card = generator.draw_fish(generator.STYLES["night_sailfish"])
        generator.validate_sailfish_bounds(card)

    def test_night_sailfish_assets_keep_expected_sizes_and_bounds(self):
        with Image.open(ROOT / "assets" / "fish_cards" / "night_sailfish_v2.png") as card:
            self.assertEqual(card.size, (generator.W, generator.H))
            generator.validate_sailfish_bounds(card)
        with Image.open(ROOT / "assets" / "fish" / "night_sailfish.png") as portrait:
            self.assertEqual(portrait.size, (96, 64))


if __name__ == "__main__":
    unittest.main()
