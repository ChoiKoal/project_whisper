"""Quiet authored earth and cobbled workshop apron on a uniform 2px lattice.
Runtime tile IDs/TileSet/alpha footprint are unchanged. No noise or gradients.
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent
EARTH=(133,123,105,255)
EARTH_D=(125,115,100,255)
EARTH_L=(142,132,113,255)
STONE=(153,150,132,255)
STONE_D=(98,105,101,255)
STONE_L=(181,175,150,255)
MOSS=(94,114,84,255)

def earth():
    im=Image.new('RGBA',(64,32),EARTH)
    d=ImageDraw.Draw(im)
    # Authored, low-contrast scuffs describe beaten earth; do not outline the tile.
    for points in [ [(13,11),(22,8),(29,9),(31,11),(26,12),(18,13)], [(32,18),(40,15),(48,17),(47,20),(42,22),(35,21)], [(20,23),(24,22),(29,24),(26,26)], [(41,8),(44,7),(47,9),(45,10)] ]:
        d.polygon(points,fill=EARTH_D)
    for pts in [[(19,13),(25,11),(28,11)],[(33,20),(38,19),(43,19)],[(29,15),(32,14),(34,15)]]:
        d.line(pts,fill=EARTH_L,width=1)
    # Three low-relief stone chips, purposeful clusters not per-pixel spray.
    d.polygon([(35,11),(38,10),(40,11),(38,13),(35,12)],fill=(143,138,121,255))
    d.line([(35,11),(38,10),(40,11)],fill=(158,149,128,255))
    d.line([(23,19),(25,18),(27,19)],fill=(151,141,120,255))
    large=im.resize((128,64),Image.Resampling.NEAREST)
    # Preserve exact original analytical footprint, including existing tile joins.
    for y in range(64):
        for x in range(128):
            if abs(x-63.5)/64+abs(y-31.5)/32 > 1+1e-6:
                large.putpixel((x,y),(0,0,0,0))
    return large

def apron():
    im=Image.new('RGBA',(448,160))
    d=ImageDraw.Draw(im)
    points=[(64,96),(160,80),(288,112),(384,128)]
    # Mortar ribbon, edges broken by hand-set stones; original four station anchors.
    d.line(points,fill=(83,87,82,255),width=23)
    for cx,cy in points:
        d.polygon([(cx,cy-18),(cx+39,cy+1),(cx+29,cy+10),(cx,cy+20),(cx-38,cy+1)],fill=STONE_D)
    # Hand-shaped fieldstone vocabulary. Repeated as masonry, never smooth shape shading.
    shape=[(-8,0),(-4,-3),(3,-4),(8,-1),(7,2),(1,4),(-6,3)]
    stones=[]
    for a,b in zip(points,points[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1]
        steps=max(1,int(abs(dx)/16))
        for k in range(1,steps):
            t=k/steps
            for row in (-1,0,1):
                stones.append((round(a[0]+dx*t)+row*2,round(a[1]+dy*t)+row*6,k+row))
    for cx,cy in points:
        for row in range(-2,3):
            for col in range(-2,3):
                if abs(col)+abs(row)>3: continue
                stones.append((cx+col*12+row*5,cy+row*6-col*2,row+col))
    for x,y,k in sorted(stones,key=lambda v:v[1]):
        pts=[(x+px,y+py) for px,py in shape]
        color=[STONE,(144,143,125,255),(161,156,135,255)][k%3]
        d.polygon(pts,fill=color)
        d.line([(x-7,y),(x-3,y-3),(x+3,y-3)],fill=STONE_L,width=1)
        if k%5==0: d.line([(x+2,y),(x+1,y+2),(x+4,y+3)],fill=STONE_D)
    # Only three restrained metal inlays imply the discovery/process direction.
    for x,y in [(114,87),(222,95),(339,120)]:
        d.line([(x-3,y-2),(x+2,y),(x-3,y+2)],fill=(172,141,92,255),width=1)
    # Moss lives in mortar crevices and apron edges, not across contact surfaces.
    for x,y in [(43,98),(86,106),(146,66),(174,94),(273,128),(307,113),(402,139),(369,111)]:
        d.polygon([(x,y),(x+4,y-2),(x+7,y),(x+3,y+2)],fill=MOSS)
        d.line([(x+1,y),(x+4,y-1)],fill=(132,143,95,255))
    return im.resize((896,320),Image.Resampling.NEAREST)

def main():
    earth().save(ROOT/'assets/tiles/t1_dirt.png')
    # Void remains exact size and footprint but no longer draws a ghost floor grid.
    old=Image.open(ROOT/'assets/tiles/t0_void.png').convert('RGBA')
    void=Image.new('RGBA',old.size,(19,19,27,255))
    void.putalpha(old.getchannel('A'))
    void.save(ROOT/'assets/tiles/t0_void.png')
    apron().save(ROOT/'assets/objects/home_maker_yard.png')
    print('AUTHORED t1_dirt=128x64 original analytical alpha; t0_void=original alpha; maker_yard=896x320 cobble apron')

if __name__=='__main__': main()
