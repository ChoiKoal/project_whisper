"""FDN14 v2 flower studies: authored contour/plane paths at logical 28x32.
No image sampling, random noise, gradient, ellipse primitives or AI downsampling.
Exports three distinct growth silhouettes. Mechanical compliance != art acceptance.
"""
from pathlib import Path
from PIL import Image, ImageDraw
import sys,json,hashlib
ROOT=Path(__file__).resolve().parent
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'assets/foundation/flowers'
OUT.mkdir(parents=True,exist_ok=True)
P=dict(ink='#393b3a',soil='#575144',stem='#657253',leafdark='#44544b',leaf='#708769',leaflight='#a1af7a',seam='#434443',petalshadow='#744858',petal='#ba7086',petallight='#e2a1a4',petalrim='#f1cab3',heart='#876b49',pollen='#d7b36a')
def poly(d,pts,key):d.polygon(pts,fill=P.get(key,key))
def line(d,pts,key,width=1):d.line(pts,fill=P.get(key,key),width=width)
def bloom(d,x,y,kind=0):
    def path(pts,key):poly(d,[(x+a,y+b) for a,b in pts],key)
    if kind==0: # Open, oblique cup: five unequal overlapping folds, dark centre.
        path([(-6,0),(-5,-3),(-2,-3),(-1,-5),(2,-5),(3,-3),(6,-2),(6,1),(4,3),(1,5),(-2,4),(-5,3)],'petalshadow')
        path([(-5,-1),(-4,-3),(-2,-2),(0,0),(-2,2),(-5,1)],'petallight')
        path([(-1,-4),(1,-4),(3,-2),(1,0),(-1,-1)],'petalrim')
        path([(3,-2),(5,-1),(5,1),(2,2),(1,0)],'petal')
        path([(-3,2),(-1,1),(1,2),(2,4),(-1,4)],'petal')
        path([(2,2),(5,1),(4,3),(2,4)],'petallight')
        path([(-1,0),(1,-1),(2,0),(1,2),(-1,2)],'heart')
        line(d,[(x-1,y),(x+1,y)],'pollen')
        line(d,[(x-5,y),(x-3,y+1)],'petalrim')
    elif kind==1: # Side-on folded bell; uneven calyx supports the cup.
        path([(-4,-3),(-1,-5),(2,-4),(4,-1),(3,2),(1,4),(-2,3),(-4,0)],'petalshadow')
        path([(-3,-3),(-1,-4),(1,-3),(1,1),(-1,2),(-3,0)],'petallight')
        path([(1,-3),(3,-1),(2,2),(1,3),(0,1)],'petal')
        line(d,[(x-2,y-3),(x-2,y)],'petalrim')
        path([(-2,3),(0,2),(1,3),(3,2),(1,5)],'leafdark')
    else: # Closed bud on a bent lateral stem, not a shrunk open flower.
        path([(-2,-2),(0,-4),(2,-3),(3,0),(1,2),(-1,1)],'petalshadow')
        path([(-1,-2),(0,-3),(1,-2),(1,0),(-1,0)],'petallight')
        path([(-2,0),(0,1),(2,0),(1,3),(-1,2)],'leaf')

def author(variant):
    im=Image.new('RGBA',(28,32));d=ImageDraw.Draw(im)
    # Broken contact wedge follows stems, not the old oval pedestal.
    poly(d,[(7,27),(11,26),(15,26),(18,27),(23,28),(19,29),(13,29),(8,28)],'soil')
    line(d,[(10,27),(15,27),(20,28)],'ink')
    if variant==0:
        # Upright main blossom with a lower right bud; three swept basal leaves.
        line(d,[(13,27),(14,22),(12,16),(11,12)],'leafdark',2)
        line(d,[(13,26),(13,22),(11,16),(11,12)],'stem')
        line(d,[(14,23),(18,20),(20,15)],'leafdark',2)
        line(d,[(15,22),(18,19),(19,15)],'leaf')
        poly(d,[(13,24),(9,20),(4,19),(6,23),(10,25)],'leafdark')
        poly(d,[(5,20),(10,22),(12,24),(8,23)],'leaf')
        line(d,[(6,20),(10,22)],'leaflight')
        poly(d,[(14,26),(18,22),(24,22),(22,25),(18,27)],'leafdark')
        poly(d,[(16,25),(21,23),(23,23),(20,25)],'leaf')
        poly(d,[(12,27),(10,25),(8,26),(6,28),(10,28)],'leaf')
        bloom(d,11,10,0);bloom(d,20,13,2)
    elif variant==1:
        # Two unequal side-facing blossoms, a continuous S-shaped support.
        line(d,[(14,27),(12,23),(13,18),(17,13),(18,9)],'leafdark',2)
        line(d,[(13,26),(11,23),(12,18),(16,13),(17,10)],'stem')
        line(d,[(13,21),(9,18),(8,14)],'leafdark',2)
        line(d,[(12,20),(8,17),(8,14)],'leaf')
        poly(d,[(14,24),(17,18),(23,17),(22,21),(18,24)],'leafdark')
        poly(d,[(16,22),(20,18),(22,18),(20,21)],'leaf')
        line(d,[(17,21),(20,19)],'leaflight')
        poly(d,[(12,26),(8,22),(3,22),(5,25),(9,27)],'leafdark')
        poly(d,[(4,23),(8,24),(10,26),(7,26)],'leaf')
        poly(d,[(14,27),(18,25),(22,26),(24,28),(19,28)],'leaf')
        line(d,[(16,27),(21,27)],'leaflight')
        bloom(d,18,8,1);bloom(d,7,13,1)
    else:
        # Low spread, tilted open bloom and tall unopened bud: no recolour clone.
        line(d,[(14,27),(17,23),(18,18),(16,14)],'leafdark',2)
        line(d,[(14,26),(16,23),(17,18),(15,15)],'stem')
        line(d,[(14,25),(11,20),(8,15),(9,10)],'leafdark',2)
        line(d,[(13,24),(10,19),(7,15),(8,10)],'leaf')
        poly(d,[(15,25),(21,20),(25,20),(23,24),(18,26)],'leafdark')
        poly(d,[(18,24),(22,21),(24,21),(21,24)],'leaf')
        line(d,[(19,23),(23,21)],'leaflight')
        poly(d,[(12,26),(7,21),(3,22),(5,26),(9,28)],'leafdark')
        poly(d,[(4,23),(8,24),(10,27),(6,25)],'leaf')
        poly(d,[(13,27),(15,24),(18,26),(20,28),(15,29)],'leaf')
        line(d,[(15,26),(17,27)],'leaflight')
        bloom(d,17,13,0);bloom(d,8,8,2)
    return im.resize((56,64),Image.Resampling.NEAREST)
records=[]
for index in range(3):
    im=author(index);name=f'flower_{index}.png';path=OUT/name;im.save(path)
    colors=im.getcolors()
    assert colors is not None and len(colors)<=14 and set(im.getchannel('A').tobytes())=={0,255}
    assert im.tobytes()==im.resize((28,32),Image.Resampling.NEAREST).resize(im.size,Image.Resampling.NEAREST).tobytes()
    records.append(dict(file=name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),size=im.size,colors=len(colors),bbox=im.getbbox()))
assert len({Image.open(OUT/r['file']).getchannel('A').tobytes() for r in records})==3
(OUT/'manifest.json').write_text(json.dumps({'method':'authored pixel contour and material planes, no sampled source','scope':'v2 F / I5 only; rare flower user-regression identity not yet confirmed','aesthetic':'HOLD pending actual root review','assets':records},indent=2))
print(json.dumps(records,indent=2))
