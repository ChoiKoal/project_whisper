"""Mechanical sprite contracts, explicitly NOT aesthetic acceptance."""
import unittest, subprocess, sys
from pathlib import Path
from PIL import Image
W=Path(__file__).resolve().parents[2]
E=W/'evidence/09-rock-craft-collision'
class RockArtContracts(unittest.TestCase):
    def test_live_is_exact_authored_candidate(self):
        live=W/'game/assets/objects/rock.png'
        candidate=E/'art-r2/rock.png'
        self.assertEqual(live.read_bytes(),candidate.read_bytes())
    def test_canvas_palette_and_exact_two_pixel_clusters(self):
        im=Image.open(E/'art-r2/rock.png').convert('RGBA')
        self.assertEqual(im.size,(84,70))
        colors=im.getcolors(1000)
        assert colors is not None
        self.assertLessEqual(len(colors),14)
        self.assertEqual(set(im.getchannel('A').tobytes()),{0,255})
        low=im.resize((42,35),Image.Resampling.NEAREST)
        self.assertEqual(im.tobytes(),low.resize(im.size,Image.Resampling.NEAREST).tobytes())
    def test_root_and_contact_band(self):
        im=Image.open(E/'art-r2/rock.png').convert('RGBA')
        alpha=im.getchannel('A').tobytes()
        self.assertGreater(alpha[57*84+42],0)
        widths=[]
        for y in range(52,58):
            xs=[x for x in range(84) if alpha[y*84+x]]
            widths.append(max(xs)-min(xs)+1)
        self.assertGreaterEqual(max(widths),44)
        self.assertLessEqual(max(widths),64)
        bounds=im.getbbox()
        assert bounds is not None
        self.assertLessEqual(bounds[3],62)
    def test_reproducible_no_source_copy(self):
        staging=E/'art-repro'
        subprocess.run([sys.executable,str(W/'game/tools_author_rock.py'),str(staging)],check=True)
        self.assertEqual((staging/'rock.png').read_bytes(),(E/'art-r2/rock.png').read_bytes())
        old=W/'evidence/08-l1-home-story/repair-23955/entry-source/game/assets/objects/rock.png'
        self.assertNotEqual(old.read_bytes(),(E/'art-r2/rock.png').read_bytes())
if __name__=='__main__': unittest.main()
