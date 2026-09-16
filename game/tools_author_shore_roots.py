"""Directly authored 2px root-following contact clusters, not a blurred shadow.
Narrow representative shore-tree use; tree source silhouettes remain untouched.
The full contact ink fits inside one 128x64 ground diamond, so no water is painted land.
R1/R2's enclosing soil plate was rejected; R3 leaves ground visible between roots.
"""
from pathlib import Path
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent
COLORS={'soil':'#70694f','wet':'#575843','crease':'#3e4939','grass':'#67764e','tip':'#8a9361'}
def assets():
    im=Image.new('RGBA',(48,24));d=ImageDraw.Draw(im)
    # Left lateral roots: separated, low and long; no continuous base ellipse.
    d.polygon([(12,11),(17,10),(22,11),(21,12),(17,12),(15,14),(12,14)],fill=COLORS['soil'])
    d.polygon([(15,12),(19,11),(21,12),(18,12),(16,13)],fill=COLORS['wet'])
    # Compact fork crevice; leave the ground exposed in front and on both sides.
    d.polygon([(22,11),(24,10),(27,11),(26,13),(24,14),(22,13)],fill=COLORS['wet'])
    d.polygon([(23,11),(25,11),(26,12),(24,13)],fill=COLORS['crease'])
    d.polygon([(29,11),(32,12),(35,14),(33,15),(29,13),(27,13)],fill=COLORS['soil'])
    d.line([(29,12),(31,13),(33,14)],fill=COLORS['wet'])
    tips=Image.new('RGBA',(48,24));d=ImageDraw.Draw(tips)
    # Only distal grass tips occlude; never outline the whole foot.
    d.polygon([(12,13),(13,11),(14,13),(15,13),(14,14),(12,14)],fill=COLORS['grass'])
    d.point((13,12),fill=COLORS['tip'])
    d.polygon([(33,15),(34,13),(35,14),(35,15)],fill=COLORS['grass'])
    d.point((34,14),fill=COLORS['tip'])
    return {'objects/shore_root_contact.png':im.resize((96,48),Image.Resampling.NEAREST),'objects/shore_root_occlusion.png':tips.resize((96,48),Image.Resampling.NEAREST)}
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=ROOT/'assets');a=p.parse_args()
    for name,im in assets().items():
        path=a.out/name;path.parent.mkdir(parents=True,exist_ok=True);im.save(path);print(path)
