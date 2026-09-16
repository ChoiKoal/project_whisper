"""Whisper workshop: AI-assisted concept -> fixed-grid sprite reauthoring.

The source sheet is CONCEPT ONLY. Runtime assets are transparent, fixed 2x lattice,
32-color sprites. Connected background removal, per-object cropping/composition,
limited palette, cluster cleanup and explicitly placed pixel corrections are applied.
No concept image is loaded by Godot. Use --out DIR for safe reproducibility checks.
"""
from pathlib import Path
from collections import deque
import argparse
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
PALETTE = [
    '#24232e', '#303440', '#454553', '#5b5865', '#797582', '#aaa4a1',
    '#332a2c', '#4d3530', '#624438', '#80583f', '#9f7451', '#c29766',
    '#dab988', '#f0d8a4', '#f7ead0', '#aaa68b', '#cbc5a6',
    '#3f4840', '#536647', '#71804f', '#9aa769', '#bbc47d',
    '#233e46', '#325b65', '#47818a', '#70a6aa', '#a1cbca', '#d0e7d7',
    '#354859', '#506879', '#7893a1', '#a7bdc0',
]
COLORS = [tuple(bytes.fromhex(c[1:])) for c in PALETTE]
TRANSPARENT = (0,0,0,0)
SPECS = {
    'home_maker_inputs.png': ((17,28,461,754), (80,80), (41,69), (40,73)),
    'home_maker_build.png': ((927,95,1574,740), (96,80), (69,68), (48,74)),
    'home_maker_whisper.png': ((1603,21,1959,707), (80,96), (43,81), (40,90)),
    'cauldron.png': ((506,189,905,688), (64,64), (43,53), (32,60)),
}

def remove_backdrop(image):
    image = image.convert('RGBA')
    w,h = image.size
    pix = image.load()
    # The generated source has a connected neutral backdrop. Remove only edge-connected
    # bright, neutral pixels: paper, seed light and glass enclosed by contour survive.
    queue = deque()
    seen = set()
    for x in range(w): queue.extend(((x,0),(x,h-1)))
    for y in range(h): queue.extend(((0,y),(w-1,y)))
    while queue:
        x,y = queue.popleft()
        if (x,y) in seen or not (0 <= x < w and 0 <= y < h): continue
        seen.add((x,y))
        r,g,b,a = pix[x,y]
        if min(r,g,b) < 180 or max(r,g,b)-min(r,g,b) > 20: continue
        pix[x,y] = TRANSPARENT
        queue.extend(((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
    return image

def nearest_palette(rgb):
    # Weighted distance favours value/hue families; no dithering / false fine detail.
    return min(COLORS, key=lambda c: 2*(c[0]-rgb[0])**2 + 3*(c[1]-rgb[1])**2 + (c[2]-rgb[2])**2)

def simplify_clusters(im):
    src = im.copy()
    p, old = im.load(), src.load()
    for y in range(1,im.height-1):
        for x in range(1,im.width-1):
            c = old[x,y]
            if c[3] == 0: continue
            n = [old[x-1,y],old[x+1,y],old[x,y-1],old[x,y+1]]
            # Preserve contour highlights; suppress isolated interior quantization grain.
            if all(v[3] for v in n) and all(v != c for v in n):
                match = max(n,key=n.count)
                if n.count(match)>=3: p[x,y]=match
    return im

def retouch(im, name):
    d = ImageDraw.Draw(im)
    def line(points,index,width=1): d.line(points,fill=COLORS[index]+(255,),width=width)
    if name == 'home_maker_build.png':
        # Reauthor the signature folded blueprint with connected planes, not noisy text.
        d.polygon([(52,34),(65,40),(64,54),(51,48)], fill=COLORS[29]+(255,))
        line([(52,34),(65,40),(64,53)],31)
        # Small bird assembly sketch: connected beak/body/tail, one construction baseline.
        line([(54,42),(57,40),(59,41),(59,44),(62,46)],26)
        line([(55,45),(61,48)],30)
        line([(54,47),(61,50)],30)
        # Vise screw: dark shaft with restrained metallic thread, readable handle.
        line([(22,40),(22,56)],0,2)
        line([(22,44),(22,54)],12)
        line([(19,55),(25,52)],5)
        # Selective end-grain and mortise highlights, not blanket speckle.
        line([(22,33),(28,36)],12)
        line([(28,59),(29,66)],10)
    elif name == 'home_maker_inputs.png':
        # Glass shoulder streak, paper label and lower board wear grouped at 1 logical px.
        line([(43,7),(43,12),(45,14)],26)
        line([(45,16),(45,20)],25)
        line([(25,39),(29,41)],12)
        line([(26,58),(31,60)],10)
    elif name == 'home_maker_whisper.png':
        # Two unambiguous suspension filaments and a coherent warm seed, shadow in glass.
        line([(27,18),(36,37)],11)
        line([(48,17),(43,37)],12)
        d.polygon([(39,41),(42,43),(42,48),(39,51),(36,47),(36,44)],fill=COLORS[10]+(255,))
        line([(39,42),(40,44),(39,47)],13)
        line([(37,45),(38,48)],11)
        # Light belongs to the nearest socket and inward-facing bracket, not a halo.
        line([(36,62),(40,64),(44,62)],13)
        line([(34,63),(34,66)],11)
    elif name == 'cauldron.png':
        # Reconstruct the liquid as a coherent 2:1 plane: no photographic noise.
        d.polygon([(20,12),(27,9),(35,9),(45,13),(45,16),(37,19),(27,19),(18,15)],fill=COLORS[23]+(255,))
        d.polygon([(20,12),(28,10),(36,10),(43,13),(39,15),(27,16)],fill=COLORS[24]+(255,))
        line([(23,12),(28,11),(32,11)],26)
        line([(32,16),(36,17),(40,16)],25)
        # Warm seedling plate is crisp at 1x and does not animate with the liquid.
        line([(30,36),(32,39),(32,44)],12)
        line([(32,39),(36,36)],13)
        line([(32,43),(29,45)],11)
    return im

def clean_detached_pixels(im):
    """Remove tiny disconnected opaque remnants; no intended particles in these props."""
    seen=set()
    for y in range(im.height):
        for x in range(im.width):
            if (x,y) in seen or im.getpixel((x,y))[3]==0: continue
            q=deque([(x,y)]); component=[]
            while q:
                a,b=q.popleft()
                if (a,b) in seen or not (0<=a<im.width and 0<=b<im.height): continue
                seen.add((a,b))
                if im.getpixel((a,b))[3]==0: continue
                component.append((a,b))
                q.extend((a+dx,b+dy) for dx,dy in [(-1,0),(1,0),(0,-1),(0,1)])
            if len(component)<=3:
                for point in component: im.putpixel(point,TRANSPARENT)
    return im

def contact_shadow(im, name):
    """Discrete low-profile occlusion under feet; shares sprite palette and native lattice."""
    layer=Image.new('RGBA',im.size)
    d=ImageDraw.Draw(layer)
    cx=im.width//2
    cy={'home_maker_inputs.png':73,'home_maker_build.png':74,'home_maker_whisper.png':90,'cauldron.png':60}[name]
    rx={'home_maker_inputs.png':17,'home_maker_build.png':30,'home_maker_whisper.png':20,'cauldron.png':19}[name]
    d.polygon([(cx-rx,cy-2),(cx-rx//2,cy-5),(cx+rx//2,cy-5),(cx+rx,cy-2),(cx+rx-4,cy),(cx-rx+4,cy)],fill=COLORS[0]+(255,))
    layer.alpha_composite(im)
    return layer

def sprite(source, name, spec):
    box, canvas_size, fitted, anchor = spec
    crop = remove_backdrop(source.crop(box))
    # Area-filter the conceptual shapes first, then explicitly snap coverage and palette.
    # Export NEVER uses interpolation: each authored source pixel becomes exactly 2x2.
    small = crop.resize(fitted, Image.Resampling.BOX)
    fixed = Image.new('RGBA',fitted)
    for y in range(fitted[1]):
        for x in range(fitted[0]):
            r,g,b,a = small.getpixel((x,y))
            if a >= 160:
                fixed.putpixel((x,y),nearest_palette((r,g,b))+(255,))
    fixed = simplify_clusters(fixed)
    canvas = Image.new('RGBA',canvas_size)
    canvas.alpha_composite(fixed,(anchor[0]-fitted[0]//2,anchor[1]-fitted[1]))
    canvas = clean_detached_pixels(retouch(canvas,name))
    canvas = contact_shadow(canvas,name)
    return canvas.resize((canvas.width*2,canvas.height*2),Image.Resampling.NEAREST)

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,default=ROOT/'assets'/'objects')
    args=parser.parse_args()
    source=Image.open(ROOT/'art'/'source'/'workshop-concept.png')
    args.out.mkdir(parents=True,exist_ok=True)
    for name,spec in SPECS.items():
        im=sprite(source,name,spec)
        im.save(args.out/name)
        print(f'AUTHORED {name} size={im.size} colors={len(im.getcolors(im.width*im.height))} bbox={im.getbbox()}')
        if name=='cauldron.png':
            bubble=im.resize((64,64),Image.Resampling.NEAREST)
            d=ImageDraw.Draw(bubble)
            for x,y in [(25,13),(35,14),(39,12)]:
                d.line([(x-1,y),(x,y-1),(x+1,y),(x,y+1)],fill=COLORS[26]+(255,))
                d.point((x,y),fill=COLORS[23]+(255,))
            bubble.resize((128,128),Image.Resampling.NEAREST).save(args.out/'cauldron_bubble.png')

if __name__ == '__main__': main()
