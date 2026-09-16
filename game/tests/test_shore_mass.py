"""Technical limits for connected cliff material; NEVER aesthetic acceptance."""
from pathlib import Path
import unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class ShoreMass(unittest.TestCase):
    def test_non_squashed_mass_field(self):
        im=Image.open(ROOT/'assets/tiles/grove_rock_field.png').convert('RGBA')
        self.assertEqual(im.size,(2048,1024),'retain source mass aspect instead of a shallow repeated stripe')
        self.assertLessEqual(len(set(im.getdata())),18)
        self.assertEqual(im.getchannel('A').getextrema(),(255,255))
        tiny=im.resize((1024,512),Image.Resampling.NEAREST)
        self.assertEqual(tiny.resize(im.size,Image.Resampling.NEAREST).tobytes(),im.tobytes(),'exact 2px clusters')
    def test_soil_banks_preserve_land_mask_and_reproduce(self):
        import sys
        sys.path.insert(0,str(ROOT))
        from tools_author_soil_bank import assets
        generated=assets()
        self.assertEqual(len(generated),4)
        for name,im in generated.items():
            side=Path(name).stem.rsplit('_',1)[-1]
            live=Image.open(ROOT/'assets'/name).convert('RGBA')
            grass=Image.open(ROOT/'assets/tiles'/f'edge_water_{side}.png').convert('RGBA')
            self.assertEqual(im.size,(128,64))
            self.assertEqual(im.tobytes(),live.tobytes())
            self.assertEqual(im.getchannel('A').tobytes(),grass.getchannel('A').tobytes(),'same safe land footprint')
            self.assertTrue(all(a in (0,255) for a in im.getchannel('A').getdata()))
    def test_runtime_reproducibility(self):
        import sys
        sys.path.insert(0,str(ROOT))
        from tools_author_shore import rock_field
        actual=Image.open(ROOT/'assets/tiles/grove_rock_field.png').convert('RGBA')
        self.assertEqual(rock_field().tobytes(),actual.tobytes())
if __name__=='__main__':unittest.main()
