"""First-region tree silhouettes and quiet grass, preserving runtime IDs and offsets.
Tree concept is kept only as source; runtime uses binary-alpha 2px clusters and
24-color material palette. Grass is directly pixel-authored, no noise/gradients.
"""
from pathlib import Path
from PIL import Image, ImageDraw
from tools_author_workshop import clean_detached_pixels, simplify_clusters

ROOT=Path(__file__).resolve().parent
HEX=['#202d30','#293e3a','#355145','#46624b','#597655','#6d885c','#8a9b68','#a7ac79','#c2bd8b',
     '#303137','#40403c','#545047','#6c6351','#87775e','#a28e6b','#c1aa80',
     '#686c64','#909184','#b6b6a0','#d6d2b6','#425e52','#607863','#7b9472','#a1ab87']
PAL=[tuple(bytes.fromhex(h[1:]))+(255,) for h in HEX]
SPECS=[('tree_a.png',(0,35,623,840),(226,232),110,113),
       ('tree_b.png',(623,20,1060,844),(191,244),116,119),
       ('tree_c.png',(1060,100,1774,840),(214,222),103,108),
       ('young_tree.png',(0,35,623,840),(126,150),58,66)]

def tree(source,spec):
    name,box,size,height,baseline=spec
    crop=source.crop(box).convert('RGBA')
    bounds=crop.getbbox()
    if bounds is None: raise ValueError('empty tree '+name)
    crop=crop.crop(bounds)
    maxw=size[0]//2-6
    scale=min(maxw/crop.width,height/crop.height)
    w,h=round(crop.width*scale),round(crop.height*scale)
    small=crop.resize((w,h),Image.Resampling.BOX)
    fixed=Image.new('RGBA',(w,h))
    for y in range(h):
        for x in range(w):
            r,g,b,a=small.getpixel((x,y))
            if a>=170:
                c=min(PAL,key=lambda c:2*(c[0]-r)**2+3*(c[1]-g)**2+(c[2]-b)**2)
                fixed.putpixel((x,y),c)
    # Keep coherent leaf masses; preserve large notches instead of filling silhouette gaps.
    fixed=simplify_clusters(simplify_clusters(fixed))
    fixed=clean_detached_pixels(fixed)
    # Root median is the anchor, NOT the asymmetric canopy bounding-box centre.
    root_x=[]
    for y in range(max(0,h-8),h):
        root_x.extend(x for x in range(w) if fixed.getpixel((x,y))[3])
    root_x.sort()
    anchor=root_x[len(root_x)//2] if root_x else w//2
    logical=Image.new('RGBA',((size[0]+1)//2,size[1]//2))
    offsetx=logical.width//2-anchor
    offsetx=max(2,min(offsetx,logical.width-w-2))
    logical.alpha_composite(fixed,(offsetx,baseline-h))
    # Baked sparse roots/contact follow a 2:1 footprint at the existing trunk collision origin.
    # The artwork is not permitted to move the collision or gather cell.
    d=ImageDraw.Draw(logical)
    cx=logical.width//2
    d.line([(cx-8,baseline-2),(cx-3,baseline-4),(cx+4,baseline-3),(cx+8,baseline-1)],fill=PAL[11])
    d.line([(cx-2,baseline-6),(cx,baseline-3),(cx+4,baseline-2)],fill=PAL[14])
    out=logical.resize((logical.width*2,logical.height*2),Image.Resampling.NEAREST)
    return out.crop((0,0,size[0],size[1]))


def grass(variant):
    base=(102,120,91,255);shade=(96,113,85,255);light=(113,130,98,255)
    im=Image.new('RGBA',(64,32),base);d=ImageDraw.Draw(im)
    # Only authored clusters, with continuous base at every diamond boundary.
    for pts in [[(15,13),(21,9),(27,10),(30,13),(24,16),(17,16)],[(33,20),(39,16),(47,18),(44,22),(37,24)]]:
        d.polygon(pts,fill=shade)
    for x,y in [(25,13),(37,18),(31,22)]:
        d.line([(x-3,y),(x,y-2),(x+2,y)],fill=light)
    if variant:
        if variant==2:
            for x,y in [(23,13),(38,18)]:
                d.polygon([(x-2,y),(x-1,y-2),(x+1,y-2),(x+2,y),(x,y+1)],fill=(126,140,99,255))
                d.point((x,y),fill=shade)
        else:
            places=[(24,13),(38,19)] if variant==1 else [(22,13),(34,19),(42,17)]
            for x,y in places:
                d.line([(x,y),(x-1,y+2)],fill=(76,98,76,255))
                d.line([(x-1,y-1),(x+1,y-1)],fill=(173,166,153,255) if variant==1 else (180,153,156,255))
                d.point((x,y-2),fill=(202,190,162,255))
    out=im.resize((128,64),Image.Resampling.NEAREST)
    for y in range(64):
        for x in range(128):
            if abs(x-63.5)/64+abs(y-31.5)/32>1+1e-6:out.putpixel((x,y),(0,0,0,0))
    return out


def water_frame(deep,phase):
    # Variant IDs remain distinct, but contiguous water is not a checkerboard.
    base=(65,96,104,255)
    shade=(60,91,99,255)
    light=(80,111,117,255)
    im=Image.new('RGBA',(64,32),base);d=ImageDraw.Draw(im)
    crests=[(21,14,12),(32,21,8)] if deep else [(18,12,13),(34,20,12),(35,11,5)]
    for x,y,length in crests:
        shift=phase*2
        d.line([(x+shift,y),(x+length//2+shift,y),(x+length//2+shift+2,y-1),(x+length+shift,y-1)],fill=light)
        d.line([(x+1+shift,y+2),(x+length-2+shift,y+2)],fill=shade)
    out=im.resize((128,64),Image.Resampling.NEAREST)
    for y in range(64):
        for x in range(128):
            distance=abs(x-63.5)/64+abs(y-31.5)/32
            if distance>.70: out.putpixel((x,y),base)
            if distance>1+1e-6:out.putpixel((x,y),(0,0,0,0))
    return out

def main():
    source=Image.open(ROOT/'art/source/trees-concept.png')
    for spec in SPECS:
        im=tree(source,spec);im.save(ROOT/'assets/objects'/spec[0])
        print('AUTHORED',spec[0],im.size,im.getbbox(),'colors',len(im.getcolors(im.width*im.height) or []))
    for i,name in enumerate(['t2a_grass.png','t2b_grass_flowers.png','t2c_grass_clover.png','t2d_flower_grass.png']):
        grass(i).save(ROOT/'assets/tiles'/name)
        print('AUTHORED',name,'128x64 continuous edge')
    for deep,name,static in [(False,'t5a_water_anim.png','t5a_water.png'),(True,'t5b_water2_anim.png','t5b_water2.png')]:
        atlas=Image.new('RGBA',(256,64))
        for phase in range(2):atlas.alpha_composite(water_frame(deep,phase),(phase*128,0))
        atlas.save(ROOT/'assets/tiles'/name)
        water_frame(deep,0).save(ROOT/'assets/tiles'/static)
        print('AUTHORED',name,'256x64 two frames, seamless boundary')

if __name__=='__main__':main()
