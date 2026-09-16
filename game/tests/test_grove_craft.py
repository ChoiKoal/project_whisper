"""Raster/anchor contracts for authored grove assets, NOT aesthetic acceptance."""
from pathlib import Path
import unittest
from PIL import Image
A=Path(__file__).resolve().parents[1]/'assets'

class GroveCraft(unittest.TestCase):
    def test_tree_material_clusters_and_anchor(self):
        for name,size,baseline in [('tree_a',(226,232),226),('tree_b',(191,244),238),('tree_c',(214,222),216),('young_tree',(126,150),132)]:
            with self.subTest(name=name):
                im=Image.open(A/'objects'/f'{name}.png').convert('RGBA')
                self.assertEqual(im.size,size)
                self.assertLessEqual(len(set(im.getdata())),15,'restricted material ramps, not 24-color downsampled confetti')
                self.assertEqual(im.getbbox()[3],baseline,'preserve existing planted root baseline')
                self.assertTrue(all(a in (0,255) for r,g,b,a in im.getdata()))
                for y in range(0,size[1],2):
                    for x in range(0,size[0]-1,2):
                        self.assertEqual(im.getpixel((x,y)),im.getpixel((x+1,y)))
                        self.assertEqual(im.getpixel((x,y)),im.getpixel((x,y+1)))
                # Root must include the inherited collision axis, not canopy-centred.
                self.assertTrue(any(im.getpixel((size[0]//2,y))[3] for y in range(baseline-12,baseline)))

    def test_oaks_preserve_baseline_winding_silhouette(self):
        # The simplified r1 silhouettes were visually rejected. Preserve the
        # accepted structural individuality while cleaning INTERNAL clusters.
        for name in ['tree_a','tree_c']:
            source=Image.open(A.parent/'art/source/grove-craft-baseline'/f'{name}.png').convert('RGBA')
            live=Image.open(A/'objects'/f'{name}.png').convert('RGBA')
            self.assertEqual(source.getchannel('A').tobytes(),live.getchannel('A').tobytes(),name)

    def test_generated_assets_match_runtime_and_all_tree_masks(self):
        import sys
        sys.path.insert(0,str(A.parent))
        import tools_author_grove_craft as author
        generated=author.assets()
        self.assertEqual(len(generated),13)
        for name,image in generated.items():
            live=Image.open(A/name).convert('RGBA')
            self.assertEqual(image.size,live.size,name)
            self.assertEqual(image.tobytes(),live.tobytes(),name)
        for name in ['tree_a','tree_b','tree_c','young_tree']:
            baseline=Image.open(A.parent/'art/source/grove-craft-baseline'/f'{name}.png').convert('RGBA')
            live=generated[f'objects/{name}.png']
            self.assertEqual(live.getchannel('A').tobytes(),baseline.getchannel('A').tobytes(),name)
        for material in ['water','dirt']:
            for side in ['tl','tr','bl','br']:
                im=generated[f'tiles/edge_{material}_{side}.png']
                for y in range(64):
                    for x in range(128):
                        if abs(x-63.5)/64+abs(y-31.5)/32>1:
                            self.assertEqual(im.getpixel((x,y))[3],0,'bank ink stays inside land diamond')

    def test_banks_binary_alpha_and_material_not_cyan_glow(self):
        for direction in ['tl','tr','bl','br']:
            im=Image.open(A/'tiles'/f'edge_water_{direction}.png').convert('RGBA')
            self.assertEqual(im.size,(128,64))
            self.assertTrue(all(a in (0,255) for r,g,b,a in im.getdata()),'physical bank has no alpha gradient')
            self.assertLessEqual(len(set(im.getdata())),12)

if __name__=='__main__':unittest.main()
