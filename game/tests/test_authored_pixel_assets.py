"""Technical pixel-art constraints, explicitly NOT an aesthetic approval.
Run python3 -m unittest discover -s game/tests -p test_authored_pixel_assets.py -v
"""
from pathlib import Path
import unittest
from PIL import Image

ASSETS = Path(__file__).resolve().parents[1] / 'assets' / 'objects'
EXPECTED = {'home_maker_inputs.png': (160, 160), 'home_maker_build.png': (192, 160), 'home_maker_whisper.png': (160, 192), 'cauldron.png': (128,128), 'cauldron_bubble.png': (128,128)}

class AuthoredPixelAssets(unittest.TestCase):
    def test_native_2x_pixel_lattice_and_palette(self):
        for filename, size in EXPECTED.items():
            with self.subTest(asset=filename):
                im = Image.open(ASSETS / filename).convert('RGBA')
                self.assertEqual(im.size, size, 'existing offsets/dimensions preserved')
                small = im.resize((size[0]//2, size[1]//2), Image.Resampling.NEAREST)
                self.assertEqual(im.tobytes(), small.resize(size, Image.Resampling.NEAREST).tobytes(), 'asset must be explicitly authored on uniform 2x lattice, not mixed-size noise')
                colors = set(im.getdata())
                self.assertLessEqual(len(colors), 33, 'shared limited opaque palette plus transparency')
                self.assertTrue(all(c[3] in (0, 255) for c in colors), 'no airbrushed alpha glow in physical sprite')
                box = im.getbbox()
                self.assertIsNotNone(box)
                self.assertGreaterEqual(box[0], 2)
                self.assertGreaterEqual(box[1], 2)
                self.assertLessEqual(box[2], size[0]-2)
                self.assertLessEqual(box[3], size[1]-4, 'keep inherited bottom clearance')

class WaterAssets(unittest.TestCase):
    def test_two_frame_water_preserves_mask_and_calm_boundary(self):
        # Variant IDs share one connected-water base; alpha and motion unchanged.
        for name,base in [('t5a_water_anim.png',(65,96,104,255)),('t5b_water2_anim.png',(65,96,104,255))]:
            im=Image.open(ASSETS.parent/'tiles'/name).convert('RGBA')
            self.assertEqual(im.size,(256,64))
            frames=[]
            for f in range(2):
                frame=im.crop((f*128,0,(f+1)*128,64));frames.append(frame.tobytes())
                for y in range(64):
                    for x in range(128):
                        distance=abs(x-63.5)/64+abs(y-31.5)/32
                        rgba=frame.getpixel((x,y))
                        self.assertEqual(rgba[3],255 if distance<=1+1e-6 else 0)
                        if .95<distance<=1:self.assertEqual(rgba,base,'no internal cyan grid border')
            self.assertNotEqual(frames[0],frames[1],'surface motion retained')

class GroveAssets(unittest.TestCase):
    def test_tree_palette_and_canvas_contract(self):
        for name,size in [('tree_a.png',(226,232)),('tree_b.png',(191,244)),('tree_c.png',(214,222))]:
            with self.subTest(tree=name):
                im=Image.open(ASSETS/name).convert('RGBA')
                self.assertEqual(im.size,size)
                colors=im.getcolors(im.width*im.height)
                self.assertIsNotNone(colors)
                self.assertLessEqual(len(colors or []),25,'limited authored tree palette, not gradients')
                self.assertTrue(all(c[3] in (0,255) for count,c in colors or []))
                box=im.getbbox()
                self.assertIsNotNone(box)
                if box:
                    self.assertGreaterEqual(box[1],2)
                    self.assertLessEqual(box[3],size[1]-2)

    def test_continuous_grass_boundary(self):
        for name in ['t2a_grass.png','t2b_grass_flowers.png','t2c_grass_clover.png','t2d_flower_grass.png']:
            im=Image.open(ASSETS.parent/'tiles'/name).convert('RGBA')
            self.assertEqual(im.size,(128,64))
            edges=set()
            for y in range(64):
                for x in range(128):
                    dist=abs(x-63.5)/64+abs(y-31.5)/32
                    self.assertEqual(im.getpixel((x,y))[3],255 if dist<=1+1e-6 else 0)
                    if .95<dist<=1:edges.add(im.getpixel((x,y)))
            self.assertEqual(edges,{(102,120,91,255)},'grass has no dark diamond seam')

class CharacterAssets(unittest.TestCase):
    def test_body_contact_anchor_without_shadow(self):
        import sys
        import inspect
        sys.path.insert(0,str(ASSETS.parents[1]))
        import tools_author_traveler as author
        self.assertIn('include_shadow',inspect.signature(author.frame).parameters,'body contact must be testable independently of the fixed shadow')
        source=Image.open(ASSETS.parents[1]/'art/source/traveler-concept.png')
        bases=[author.neutral(source,i) for i in range(5)]
        for row,(index,mirror) in enumerate(author.DIRECTIONS):
            for phase in range(3):
                body=author.frame(bases[index],index,phase,mirror,include_shadow=False)
                self.assertEqual(body.getbbox()[3],90,f'body-only planted foot row={row} phase={phase}')

    def test_all_24_frames_have_uniform_grid_and_foot_anchor(self):
        im = Image.open(ASSETS.parent / 'character/character_sheet.png').convert('RGBA')
        self.assertEqual(im.size, (288,768))
        for row in range(8):
            frames=[]
            for col in range(3):
                frame=im.crop((col*96,row*96,(col+1)*96,(row+1)*96))
                frames.append(frame.tobytes())
                low=frame.resize((48,48),Image.Resampling.NEAREST)
                self.assertEqual(frame.tobytes(),low.resize((96,96),Image.Resampling.NEAREST).tobytes(), 'each frame uses same 2x grid')
                box=frame.getbbox()
                self.assertIsNotNone(box)
                if box:
                    self.assertEqual(box[3],94,'shared foot shadow anchor, no animation drift')
                    self.assertGreaterEqual(box[1],2)
            self.assertEqual(len(set(frames)),3,'idle and two authored stride frames are distinct')

class GroundAssets(unittest.TestCase):
    def test_dirt_preserves_analytical_footprint_without_dark_border(self):
        im = Image.open(ASSETS.parent / 'tiles/t1_dirt.png').convert('RGBA')
        self.assertEqual(im.size, (128, 64))
        edge_colors = set()
        for y in range(64):
            for x in range(128):
                distance = abs(x-63.5)/64 + abs(y-31.5)/32
                self.assertEqual(im.getpixel((x,y))[3], 255 if distance <= 1+1e-6 else 0)
                if 0.95 < distance <= 1:
                    edge_colors.add(im.getpixel((x,y)))
        self.assertEqual(edge_colors, {(133,123,105,255)}, 'earth boundary is continuous base, not dark isometric grid')

if __name__ == '__main__':
    unittest.main()
