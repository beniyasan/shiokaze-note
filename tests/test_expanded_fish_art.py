"""Validation for the approved 25-fish asset bundle."""

from __future__ import annotations

import json
import struct
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APPROVED_STEMS = {
    "amber_anchovy",
    "aurora_koi",
    "coral_grouper",
    "coral_rabbitfish",
    "crystal_fish",
    "fire_scorpionfish",
    "ghost_fish",
    "harvest_puffer",
    "jellyfish_butterflyfish",
    "jellyfish_fish",
    "lantern_fish",
    "mint_wrasse",
    "moonfish",
    "night_angler",
    "pearl_seabass",
    "reef_butterflyfish",
    "sand_flatfish",
    "seahorse",
    "shadow_flounder",
    "starry_fish",
    "storm_tuna",
    "sunrise_bream",
    "tidepool_blenny",
    "tropical_angelfish",
    "twilight_salmon",
}


def png_metadata(path: Path) -> tuple[int, int, int, int]:
    """Read PNG dimensions and color type without a third-party image library."""

    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"not a PNG: {path}")
    offset = 8
    while offset + 8 <= len(data):
        length = struct.unpack(">I", data[offset : offset + 4])[0]
        kind = data[offset + 4 : offset + 8]
        payload = data[offset + 8 : offset + 8 + length]
        offset += 12 + length
        if kind == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", payload[:10])
            return width, height, bit_depth, color_type
    raise AssertionError(f"PNG has no IHDR: {path}")


class ApprovedFishArtTests(unittest.TestCase):
    def test_roster_has_exactly_the_approved_assets(self) -> None:
        portraits = {path.stem for path in (ROOT / "assets" / "fish").glob("*.png")}
        cards = {
            path.stem.removesuffix("_v2")
            for path in (ROOT / "assets" / "fish_cards").glob("*_v2.png")
        }
        self.assertEqual(portraits, APPROVED_STEMS)
        self.assertEqual(cards, APPROVED_STEMS)

    def test_assets_keep_the_game_contract(self) -> None:
        for stem in sorted(APPROVED_STEMS):
            portrait = ROOT / "assets" / "fish" / f"{stem}.png"
            card = ROOT / "assets" / "fish_cards" / f"{stem}_v2.png"
            self.assertEqual(png_metadata(portrait), (96, 64, 8, 6), portrait)
            self.assertEqual(png_metadata(card), (768, 512, 8, 6), card)

    def test_mapping_is_the_canonical_roster(self) -> None:
        mapping = json.loads((ROOT / "assets" / "fish_name_mapping.json").read_text())
        approved = mapping["approved_fish"]
        ids = [entry["fish_id"] for entry in approved]
        labels = [entry["label_ja"] for entry in approved]
        self.assertEqual(len(approved), 25)
        self.assertEqual(set(ids), APPROVED_STEMS)
        self.assertEqual(len(set(ids)), 25)
        self.assertEqual(len(set(labels)), 25)
        self.assertEqual(
            {entry["encyclopedia"].removesuffix("_v2.png") for entry in approved},
            {f"encyclopedia_fish_art/{stem}" for stem in APPROVED_STEMS},
        )
        self.assertEqual(
            {entry["pixel_portrait"].removesuffix(".png") for entry in approved},
            {f"fish_pixel_portraits/{stem}" for stem in APPROVED_STEMS},
        )


if __name__ == "__main__":
    unittest.main()
