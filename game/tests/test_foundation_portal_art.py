"""Production asset contracts only; never aesthetic approval."""
from pathlib import Path
import unittest
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class PortalArt(unittest.TestCase):
    def test_authored_gate_has_integer_lattice_and_open_aperture(self):
        p=ROOT/'assets/foundation/nature_gate.png'
        self.assertTrue(p.is_file(),'authored representative portal absent')
        im=Image.open(p).convert('RGBA')
        self.assertEqual(im.size,(224,288))
        self.assertEqual(set(im.getchannel('A').getdata()),{0,255})
        self.assertEqual(im.tobytes(),im.resize((112,144),Image.Resampling.NEAREST).resize(im.size,Image.Resampling.NEAREST).tobytes())
        colors={c for c in im.getdata() if c[3]}
        self.assertGreaterEqual(len(colors),10);self.assertLessEqual(len(colors),32)
        opening=im.crop((94,112,130,222))  # aperture above the stone threshold at y224
        self.assertFalse(opening.getbbox(),'stone must not fill walk-in aperture')
        self.assertGreater(im.crop((32,260,192,288)).getbbox()[2],100)
    def test_three_states_use_distinct_authored_shape_frames(self):
        paths=[ROOT/f'assets/foundation/nature_veil_{state}.png' for state in ['dormant','flicker','open']]
        for p in paths:self.assertTrue(p.exists(),str(p))
        self.assertEqual(len({p.read_bytes() for p in paths}),3)
        for p in paths:
            im=Image.open(p).convert('RGBA');self.assertEqual(im.size,(104,160))
            self.assertEqual(set(im.getchannel('A').getdata())-{0,255},set())
if __name__=='__main__':unittest.main()
