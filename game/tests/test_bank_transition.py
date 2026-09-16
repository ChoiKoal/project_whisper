"""Authored bank artifact contracts; none of these certify aesthetic quality."""
from pathlib import Path
import sys,unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools_author_bank_transition import asset,SIZE
class BankArt(unittest.TestCase):
    def test_generated_live_pixel_identity(self):
        live=Image.open(ROOT/'assets/tiles/grove_bank_transition.png').convert('RGBA')
        self.assertEqual(live.size,SIZE)
        self.assertEqual(live.tobytes(),asset().tobytes())
    def test_authored_binary_alpha_two_pixel_lattice(self):
        image=asset()
        self.assertEqual(set(image.getchannel('A').tobytes()),{0,255})
        self.assertLessEqual(len(image.getcolors(image.width*image.height) or []),14)
        # Compare each 2x2 block without resampling a potentially odd canvas.
        for y in range(0,image.height,2):
            for x in range(0,image.width,2):
                px=image.getpixel((x,y))
                self.assertTrue(all(image.getpixel((x+dx,y+dy))==px for dx in range(2) for dy in range(2)))
if __name__=='__main__':unittest.main()
