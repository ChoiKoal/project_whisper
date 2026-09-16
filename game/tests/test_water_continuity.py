"""Water continuity, not a visual-quality score."""
from pathlib import Path
import sys, unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import tools_author_grove as author
class WaterContinuity(unittest.TestCase):
    def test_connected_water_variants_share_their_boundary_colors(self):
        for phase in range(2):
            a=author.water_frame(False,phase)
            b=author.water_frame(True,phase)
            compared=0
            for y in range(64):
                for x in range(128):
                    distance=abs(x-63.5)/64+abs(y-31.5)/32
                    if .78<distance<.94 and a.getpixel((x,y))[3]:
                        self.assertEqual(a.getpixel((x,y)),b.getpixel((x,y)),(phase,x,y))
                        compared+=1
            self.assertGreater(compared,100)
if __name__=='__main__': unittest.main()
