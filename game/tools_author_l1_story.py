"""WH-L1H-01 authored pixel paths: wood grain, tensioned repair, layered cairn.
No random texture, blur, external asset copying, or procedural shape placeholders.
Logical 2px grid; art judgment is independent from deterministic export contracts.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import sys
OUT=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).parent/'assets/objects'
OUT.mkdir(parents=True,exist_ok=True)
INK='#302f35'; DEEP='#3d403c'; WOOD='#705542'; MID='#967250'; LIGHT='#c49a67'; BONE='#dfc791'; GOLD='#b29f67'; MOSS='#6f8654'; LEAF='#a4b26e'; STONE='#737a79'; FACE='#969e98'; EDGE='#c3c5ac'
def canvas(w,h):
    im=Image.new('RGBA',(w,h));return im,ImageDraw.Draw(im)
def save(im,name): im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST).save(OUT/(name+'.png'))
def poly(d,pts,col):d.polygon(pts,fill=col)
def line(d,pts,col,width=1):d.line(pts,fill=col,width=width)
# Bent upright, fork scar, offset splint: negative space is intentional.
im,d=canvas(64,80)
poly(d,[(17,73),(25,70),(40,70),(48,74),(41,77),(25,77)],DEEP)
poly(d,[(28,73),(28,57),(24,45),(23,30),(17,24),(10,19),(8,11),(11,10),(15,16),(25,20),(30,29),(32,37),(37,26),(42,23),(46,14),(51,8),(54,9),(50,17),(48,28),(40,34),(36,43),(35,54),(39,64),(38,71),(45,74),(38,75),(32,72),(23,76),(20,74)],INK)
poly(d,[(30,71),(30,56),(26,43),(26,30),(20,24),(12,18),(11,13),(15,18),(27,23),(32,35),(34,41),(39,29),(45,25),(48,15),(51,12),(46,29),(40,33),(35,45),(34,55),(37,65),(36,70),(39,73),(33,70),(26,74)],WOOD)
poly(d,[(29,58),(26,41),(28,32),(32,41),(32,55),(35,66),(33,70),(31,67)],MID)
poly(d,[(13,15),(18,19),(26,23),(29,30),(27,31),(23,26),(17,22)],LIGHT)
line(d,[(28,34),(29,43),(32,50),(31,57),(34,64)],LIGHT)
line(d,[(34,42),(39,31),(44,28),(48,20)],MID,2)
line(d,[(39,31),(44,27),(47,18)],LIGHT)
# Bark flakes/knots follow stress, never uniform noise.
line(d,[(27,46),(29,50),(28,54)],INK)
line(d,[(33,59),(35,64),(34,68)],INK)
poly(d,[(24,25),(26,25),(28,28),(28,30),(26,29)],BONE)
line(d,[(30,65),(30,70),(26,73)],LIGHT)
# Short severed fork extending behind tied seat.
poly(d,[(28,36),(21,33),(16,34),(15,31),(21,29),(30,32)],INK)
line(d,[(17,31),(22,31),(28,34)],MID,2)
# Weathered curved seat: broad front edge, hollow centre, split end.
poly(d,[(11,32),(16,29),(25,30),(35,28),(43,29),(49,27),(52,29),(48,35),(38,37),(24,38),(15,36),(11,35)],INK)
poly(d,[(13,32),(18,31),(26,32),(35,30),(44,31),(49,29),(47,33),(36,35),(23,35),(16,34)],MID)
line(d,[(14,32),(22,33),(30,33),(35,31),(44,32),(49,30)],LIGHT)
line(d,[(18,35),(27,36),(38,35),(45,34)],WOOD)
# Broad root flare and a connected front plane carry the upper load.
poly(d,[(28,55),(34,53),(38,63),(39,68),(43,71),(47,74),(43,76),(36,74),(31,72),(27,75),(21,76),(20,74),(26,69)],INK)
poly(d,[(29,55),(33,55),(35,62),(35,67),(39,71),(43,73),(40,73),(34,70),(30,70),(25,73),(27,69)],WOOD)
poly(d,[(29,56),(31,57),(33,64),(32,69),(28,71),(28,66)],MID)
line(d,[(29,58),(30,64),(29,68),(25,73)],LIGHT)
line(d,[(34,63),(34,68),(40,72)],MID)
# Three repairs: compact wrapped volumes with one free end separated from bark.
poly(d,[(24,36),(28,34),(35,50),(32,53)],INK)
poly(d,[(26,37),(28,38),(33,49),(32,51),(29,43)],MID)
line(d,[(26,38),(31,49)],LIGHT)
for y,x in [(33,25),(43,28),(52,32)]:
    poly(d,[(x-2,y),(x+3,y-1),(x+5,y+2),(x+3,y+5),(x-1,y+4)],INK)
    poly(d,[(x-1,y),(x+3,y),(x+4,y+2),(x+2,y+4),(x,y+3)],GOLD)
    line(d,[(x-1,y),(x+2,y+1),(x+4,y)],BONE)
    line(d,[(x,y+2),(x+2,y+3),(x+4,y+2)],LIGHT)
# The oldest free end bows outside the upright; no tangled closed loops over grain.
line(d,[(35,55),(39,57),(40,61),(39,65),(37,68)],INK,3)
line(d,[(35,55),(38,57),(39,61),(38,65),(36,68)],GOLD)
line(d,[(38,58),(39,61),(38,64)],BONE)
# Pressed fibres, incomplete nest impression (no complete empty UI socket).
for pts in [[(17,30),(22,29),(28,31)],[(21,32),(26,31),(31,30)],[(31,32),(35,31),(41,31)]]:line(d,pts,GOLD)
for pts in [[(23,73),(21,69),(22,70)],[(40,73),(42,69)],[(26,75),(29,72)],[(20,74),(17,72)]]:line(d,pts,MOSS)
save(im,'l1_listening_perch')
# Only the free rope tip changes in frame two; stable structure/root.
idle=im.copy();di=ImageDraw.Draw(idle)
di.point((40,61),fill=(0,0,0,0));di.point((40,62),fill=INK)
di.point((39,61),fill=INK);di.point((39,62),fill=GOLD)
save(idle,'l1_listening_perch_idle')
# Cairn: five offset slabs, three periods, inclined chipped crown.
im,d=canvas(64,56)
poly(d,[(9,48),(19,44),(44,43),(55,48),(47,52),(20,53)],DEEP)
slabs=[
 ([(12,39),(24,36),(42,38),(50,44),(48,49),(30,52),(15,49),(10,45)],[(12,39),(25,37),(42,39),(47,43),(29,46),(13,43)]),
 ([(19,29),(32,27),(46,30),(50,35),(46,40),(26,42),(16,38)],[(19,29),(32,28),(45,31),(46,34),(30,36),(18,34)]),
 ([(13,24),(23,20),(38,22),(42,26),(38,31),(23,34),(14,30)],[(14,24),(24,21),(36,23),(39,25),(25,29),(15,27)]),
 ([(24,14),(39,13),(44,17),(40,23),(25,24),(21,20)],[(24,14),(38,14),(41,17),(29,19),(23,18)]),
 ([(29,10),(36,5),(43,7),(41,11),(33,16),(28,14)],[(30,10),(36,6),(41,8),(33,13),(29,13)])]
for i,(shape,top) in enumerate(slabs):
    poly(d,shape,INK);poly(d,[(x,y-1) for x,y in shape[1:-1]],STONE if i<3 else '#898984');poly(d,top,FACE if i<4 else EDGE)
line(d,[(15,40),(25,38),(33,40)],EDGE)
line(d,[(20,30),(31,29),(39,31)],EDGE)
line(d,[(16,25),(24,23),(29,24)],EDGE)
line(d,[(25,15),(30,15)],BONE)
line(d,[(37,6),(40,8)],BONE)
# Fractures obey planes, no field noise.
line(d,[(33,40),(31,43),(33,46),(29,49)],DEEP)
line(d,[(43,32),(42,35),(45,37)],DEEP)
line(d,[(23,22),(23,25),(26,27)],STONE)
poly(d,[(12,41),(18,41),(20,43),(26,44),(26,47),(20,46),(18,48),(14,46)],MOSS)
poly(d,[(14,41),(18,42),(18,44),(22,44),(20,45),(15,44)],LEAF)
line(d,[(26,48),(30,47),(33,48)],MOSS,2)
line(d,[(46,46),(44,49),(39,50)],MOSS,2)
save(im,'l1_story_cairn')
# Material-specific traces, all native 96x96, not palette variants of one mask.
for kind in ['nest','bouquet','moss','other','bare']:
    im,d=canvas(48,48)
    if kind=='nest':
        # One backwards straw with wrapped knot, split seed husk.
        line(d,[(15,36),(19,32),(24,24),(29,17),(31,10)],INK,3)
        line(d,[(15,35),(19,31),(24,23),(29,16),(30,10)],GOLD,2)
        line(d,[(16,34),(22,26),(28,17),(30,10)],BONE)
        poly(d,[(24,22),(21,22),(18,25),(20,27),(24,26),(27,23),(26,20)],WOOD)
        line(d,[(22,23),(20,25),(24,25),(26,22)],LIGHT)
        line(d,[(23,25),(23,30),(26,34)],MID)
        line(d,[(29,17),(32,16),(33,13)],LIGHT)
        poly(d,[(30,12),(29,8),(32,6),(34,8),(32,12)],MID)
        line(d,[(31,9),(32,7)],BONE)
        line(d,[(16,35),(12,36)],DEEP)
    elif kind=='bouquet':
        poly(d,[(14,32),(17,29),(23,29),(28,31),(31,35),(27,38),(20,37),(15,35)],INK)
        poly(d,[(15,32),(18,30),(23,30),(28,33),(27,36),(20,35)],'#a55e70')
        poly(d,[(18,30),(23,30),(26,32),(22,34),(17,33)],'#d9959b')
        line(d,[(17,32),(24,34),(28,35)],'#ecc2a7')
        line(d,[(27,35),(31,37)],WOOD)
        line(d,[(33,35),(33,31),(35,29)],MOSS)
        poly(d,[(34,28),(36,28),(37,30),(34,31)],LEAF)
    elif kind=='moss':
        poly(d,[(14,36),(16,30),(21,28),(22,23),(28,21),(28,17),(32,14),(34,16),(32,22),(29,27),(31,31),(27,36),(20,39)],DEEP)
        poly(d,[(16,35),(18,31),(23,29),(23,25),(28,24),(31,18),(32,19),(30,26),(28,30),(29,33),(25,36),(20,37)],MOSS)
        line(d,[(18,34),(22,33),(25,28),(28,27),(30,22)],LEAF,2)
        line(d,[(22,36),(25,34),(27,33)],'#ced0a0')
    else:
        # Explicit uniform notched tally/loop, never guesses a generic item silhouette.
        poly(d,[(19,18),(28,16),(32,21),(30,34),(24,38),(18,33),(17,24)],INK)
        line(d,[(20,20),(27,18),(30,22),(28,32),(24,35),(20,32),(19,24),(20,20)],GOLD,2)
        line(d,[(21,20),(27,19),(29,22)],BONE)
        line(d,[(28,29),(27,33),(24,35)],MID)
        if kind=='other':
            poly(d,[(18,27),(25,24),(31,28),(29,35),(22,37),(17,33)],WOOD)
            line(d,[(19,28),(25,26),(29,28)],LIGHT)
            line(d,[(22,30),(24,33),(26,29)],BONE)
    save(im,'l1_response_'+kind)
    save(im,'home_l1_trace_'+kind)
# Bird-shaped ground shadow: six deliberately stepped wing contours, no visible bird body.
strip=Image.new('RGBA',(32*6,16))
for frame in range(6):
    wing=[2,3,5,7,5,3][frame]
    bird,bd=canvas(32,16)
    poly(bd,[(3,wing),(8,wing+1),(14,7),(17,6),(19,7),(28,wing),(25,wing+4),(19,11),(16,12),(13,10),(7,8)],'#41463e')
    poly(bd,[(11,8),(15,8),(17,10),(16,12),(13,10)],'#555d4e')
    strip.paste(bird,(frame*32,0))
save(strip,'l1_bird_shadow_strip')
print('Authored story sprites exported to',OUT)
