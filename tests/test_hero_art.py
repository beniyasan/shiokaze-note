"""Regression checks for the native 96x128 traced fisherman atlas."""
from pathlib import Path
import unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class HeroArtTests(unittest.TestCase):
    def test_sheet_contract_and_alpha(self):
        with Image.open(ROOT/'assets/hero.png') as hero:
            self.assertEqual(hero.size,(384,512)); self.assertEqual(hero.mode,'RGBA')
            for face in range(4):
                for frame in range(4):
                    cell=hero.crop((frame*96,face*128,frame*96+96,face*128+128))
                    self.assertGreater(sum(1 for px in cell.getdata() if px[3]),900)
                    self.assertTrue(all(px[3] in (0,255) for px in cell.getdata()))
    def test_feet_anchor_and_facing_details(self):
        with Image.open(ROOT/'assets/hero.png') as hero:
            for face in range(4):
                cell=hero.crop((0,face*128,96,face*128+128))
                self.assertTrue(any(cell.getpixel((x,y))[3] for y in range(120,128) for x in range(18,79)))
                self.assertTrue(any(cell.getpixel((x,y))[:3] == (45,102,116) for y in range(54,88) for x in range(18,79)))
                self.assertTrue(any(cell.getpixel((x,y))[:3] == (159,73,56) for y in range(84,116) for x in range(18,79)))
    def test_source_region_contract(self):
        source=ROOT/'main.gd'; text=source.read_text()
        self.assertIn('Vector2(48,64)',text); self.assertIn('frame*96,face*128,96,128',text)
if __name__=='__main__': unittest.main()
