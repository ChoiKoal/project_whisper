"""AI-assisted traveler concept, reauthored into the existing 8x3 atlas contract.

Five neutral direction studies are simplified to 48px logical frames. Leftward
views mirror the corresponding rightward silhouette; mirrored accessory laterality
is an explicit WIP art compromise, NOT a gameplay facing change. Walking frames
are separately pixel-authored split-tail / alternating-boot poses, not concept art.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
from tools_author_workshop import remove_backdrop, nearest_palette, simplify_clusters, clean_detached_pixels, COLORS

ROOT=Path(__file__).resolve().parent
BOXES=[(62,38,373,735),(445,38,735,736),(810,38,1079,735),(1191,38,1502,735),(1616,38,1943,735)]
# Source sheet contract: S, SE, E, NE, N, NW, W, SW. No SpriteFrames edits.
DIRECTIONS=[(0,False),(1,False),(2,False),(3,False),(4,False),(3,True),(2,True),(1,True)]
CLOTH_D=(43,43,65,255)
CLOTH=(75,74,104,255)
CLOTH_L=(128,122,153,255)
CLOTH_RIM=(177,166,188,255)
TEAL=(99,150,147,255)
SHADOW=(36,35,46,255)
BOOT=(83,61,54,255)
BOOT_L=(143,109,78,255)
EYE=(244,223,169,255)


def neutral(source,index):
    crop=remove_backdrop(source.crop(BOXES[index]))
    # Slightly broaden the coat relative to the tall concept so it reads at iso scale.
    small=crop.resize((26,41),Image.Resampling.BOX)
    im=Image.new('RGBA',(48,48))
    for y in range(41):
        for x in range(26):
            r,g,b,a=small.getpixel((x,y))
            if a<160: continue
            c=nearest_palette((r,g,b))
            # Consolidate cool cloth planes; retain leather, teal and tiny brass accents.
            if b>r*1.08 and b>g*1.02:
                v=(r+g+b)//3
                c=(CLOTH_D if v<55 else CLOTH if v<100 else CLOTH_L if v<160 else CLOTH_RIM)[:3]
            im.putpixel((x+11,y+3),c+(255,))
    im=simplify_clusters(im)
    d=ImageDraw.Draw(im)
    # Re-author eyes and hood rim on logical pixels. Back views do not get eyes.
    if index==0:
        d.polygon([(20,7),(24,6),(28,8),(28,13),(19,13),(18,10)],fill=SHADOW)
        d.point((22,10),fill=EYE);d.point((25,10),fill=EYE)
        d.line([(17,9),(18,6),(22,4),(25,4)],fill=CLOTH_RIM)
        d.line([(18,15),(23,17),(29,15)],fill=TEAL)
    elif index==1:
        d.polygon([(25,7),(30,8),(31,12),(25,13),(23,11)],fill=SHADOW)
        d.point((27,10),fill=EYE);d.point((29,10),fill=EYE)
        d.line([(21,5),(25,4),(29,6)],fill=CLOTH_RIM)
        d.line([(20,15),(24,17),(30,15)],fill=TEAL)
    elif index==2:
        d.line([(30,7),(32,9),(32,12)],fill=SHADOW,width=2)
        d.point((32,10),fill=EYE)
        d.line([(23,4),(27,4),(30,6)],fill=CLOTH_L)
    else:
        d.line([(20,5),(24,4),(28,6)],fill=CLOTH_L)
        d.line([(24,7),(25,12)],fill=CLOTH)
    return clean_detached_pixels(im)


def frame(base,index,phase,mirror,include_shadow=True):
    im=base.copy()
    d=ImageDraw.Draw(im)
    # All poses have separately formed boots, with stable ground anchor. W0/W1 swap stride.
    d.rectangle((12,38,37,46),fill=(0,0,0,0))
    stride=0 if phase==0 else (1 if phase==1 else -1)
    if index in (2,3):
        feet=[(21-stride*2,43-(1 if stride<0 else 0)),(28+stride*2,43-(1 if stride>0 else 0))]
    else:
        feet=[(19-stride,43-(1 if stride<0 else 0)),(28+stride,43-(1 if stride>0 else 0))]
    # Cloth tails taper over boots rather than solid triangle robe.
    d.polygon([(17,32),(24,34),(22,41),(17,42)],fill=CLOTH)
    d.polygon([(25,33),(31,31),(32,40),(27,42)],fill=CLOTH_D)
    d.line([(17,34),(18,39),(21,40)],fill=CLOTH_L)
    d.line([(30,34),(30,39)],fill=CLOTH)
    for x,y in feet:
        d.polygon([(x-2,y-5),(x+2,y-5),(x+2,y-1),(x+4,y),(x+3,y+1),(x-2,y+1)],fill=SHADOW)
        d.line([(x-1,y-4),(x+1,y-4),(x+1,y-1),(x+3,y)],fill=BOOT)
        d.line([(x-1,y-3),(x+1,y-3)],fill=BOOT_L)
    # Minor sleeve swing is drawn separately, never stretches body or root transform.
    if phase:
        side=16 if phase==1 else 31
        d.line([(side,22),(side+(-1 if phase==1 else 1),27)],fill=CLOTH_L)
    if mirror: im=ImageOps.mirror(im)
    if not include_shadow:
        return im.resize((96,96),Image.Resampling.NEAREST)
    shadow=Image.new('RGBA',(48,48));sd=ImageDraw.Draw(shadow)
    sd.polygon([(14,44),(19,42),(29,42),(34,44),(31,46),(17,46)],fill=SHADOW)
    shadow.alpha_composite(im)
    return shadow.resize((96,96),Image.Resampling.NEAREST)


def main():
    source=Image.open(ROOT/'art/source/traveler-concept.png')
    bases=[neutral(source,i) for i in range(5)]
    sheet=Image.new('RGBA',(288,768))
    for row,(index,mirror) in enumerate(DIRECTIONS):
        for col in range(3): sheet.alpha_composite(frame(bases[index],index,col,mirror),(col*96,row*96))
    sheet.save(ROOT/'assets/character/character_sheet.png')
    print('AUTHORED traveler 288x768, 8 directions x 3 poses, fixed 2x grid, 94px foot-anchor')

if __name__=='__main__': main()
