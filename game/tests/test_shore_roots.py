from pathlib import Path
import sys,unittest
from typing import cast
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools_author_shore_roots import assets
class ShoreRootArt(unittest.TestCase):
    def test_exact_live_reproduction(self):
        outputs=assets();self.assertEqual(len(outputs),2)
        for name,image in outputs.items():
            with self.subTest(asset=name):
                live=Image.open(ROOT/'assets'/name).convert('RGBA')
                self.assertEqual(live.size,(96,48));self.assertEqual(live.tobytes(),image.tobytes())
    def test_palette_alpha_lattice_and_ground_footprint(self):
        for name,im in assets().items():
            with self.subTest(asset=name):
                colors=im.getcolors(im.width*im.height)
                self.assertIsNotNone(colors)
                self.assertLessEqual(len(colors or []),8)
                self.assertEqual(set(im.getchannel('A').tobytes()),{0,255})
                for y in range(0,im.height,2):
                    for x in range(0,im.width,2):
                        px=im.getpixel((x,y))
                        self.assertTrue(all(im.getpixel((x+dx,y+dy))==px for dx in range(2) for dy in range(2)))
                for y in range(im.height):
                    for x in range(im.width):
                        if cast(tuple[int,int,int,int],im.getpixel((x,y)))[3]: self.assertLess(abs(x+.5-48)/64+abs(y+.5-24)/32,1)
if __name__=='__main__':unittest.main()
