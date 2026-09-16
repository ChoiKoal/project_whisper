import unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
class StoryArt(unittest.TestCase):
    def test_authored_perch_and_cairn_are_runtime_sprites(self):
        for name,size in [('l1_listening_perch',(128,160)),('l1_story_cairn',(128,112)),('l1_response_nest',(96,96))]:
            path=ROOT/'assets/objects'/f'{name}.png'
            self.assertTrue(path.is_file(),name)
            with Image.open(path) as im:
                self.assertEqual(im.size,size)
                self.assertEqual(set(im.getchannel('A').getdata()),{0,255})
                small=im.resize((size[0]//2,size[1]//2),Image.Resampling.NEAREST)
                self.assertEqual(im.tobytes(),small.resize(size,Image.Resampling.NEAREST).tobytes())
                self.assertGreater(len(im.getcolors(512) or []),6)
