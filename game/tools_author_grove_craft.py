"""Direct pixel-path source for the grove craft revision.
Terrain uses pixel paths, without blur, random noise or circles. All four trees
retain inherited AI-assisted silhouettes and merge internal same-material
clusters; visually rejected direct-path prototypes remain below for audit.
Runtime art is exactly 2x. Canvas/root offsets and runtime IDs stay unchanged.
CLI writes only selected art assets; --out supports non-destructive reproduction.
"""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parent
# Cool leaf shadows against warm exposed heartwood; diffuse upper-left light.
PAL=['#253b3b','#314f48','#416652','#56815e','#73996a','#9bb47b','#c2ce94',
     '#383f42','#53514b','#75634e','#9c805d','#c3a579','#e0c393','#465447']
P=[tuple(bytes.fromhex(c[1:]))+(255,) for c in PAL]

class Pixel:
    def __init__(self,w,h):
        self.im=Image.new('RGBA',(w,h));self.d=ImageDraw.Draw(self.im)
    def shape(self,color,points):self.d.polygon(points,fill=P[color])
    def line(self,color,points,width=1):self.d.line(points,fill=P[color],width=width)
    def crown(self,points,planes):
        self.shape(0,points)
        for color,path in planes:self.shape(color,path)
    def leaf_lips(self,paths):
        # Short connected planes at lit crown edges, never isolated confetti.
        for path in paths:self.line(5,path)
    def finish(self,size):
        return self.im.resize((self.im.width*2,self.im.height*2),Image.Resampling.NEAREST).crop((0,0,*size))


def oak():
    p=Pixel(113,116)
    # Planted root fan, with a broad fork carrying the asymmetric crown.
    p.shape(7,[(40,110),(49,105),(51,95),(49,77),(41,63),(29,53),(30,48),(47,57),(55,70),(62,63),(69,48),(76,43),(73,55),(65,73),(63,95),(66,105),(77,111),(68,112),(57,109),(49,112)])
    p.shape(9,[(47,108),(54,103),(55,86),(53,73),(44,63),(34,54),(47,61),(57,76),(62,68),(72,51),(66,68),(60,81),(60,101),(67,107),(61,107),(57,104),(55,108)])
    p.shape(10,[(55,82),(57,78),(58,90),(57,103),(53,106),(54,100)])
    p.shape(11,[(34,51),(43,57),(51,64),(54,69),(49,64),(41,59)])
    p.line(8,[(61,83),(59,91),(60,101)],2)
    p.line(12,[(53,104),(50,107),(45,109)])
    p.line(10,[(61,103),(66,106),(71,108)])
    # Rear crown: one readable volume rather than droplet leaves.
    p.crown([(43,30),(48,21),(57,19),(62,15),(70,17),(75,22),(86,23),(90,29),(98,33),(102,43),(99,47),(100,54),(94,58),(86,59),(81,66),(70,64),(66,59),(57,58),(49,51)],[(1,[(51,29),(59,23),(68,23),(76,27),(85,28),(94,36),(96,43),(89,48),(77,47),(71,54),(62,49),(57,42)]),(2,[(59,23),(67,20),(75,25),(85,27),(91,32),(86,36),(78,33),(70,36),(62,32)]),(3,[(62,24),(69,22),(74,26),(82,28),(77,31),(68,29)])])
    # Left hanging mass, cut out below so trunk remains readable.
    p.crown([(10,42),(15,34),(24,31),(27,26),(38,25),(46,28),(50,36),(48,46),(53,49),(48,56),(42,59),(37,57),(33,63),(24,63),(20,59),(14,58),(15,52),(10,49)],[(1,[(14,42),(23,37),(31,32),(39,31),(44,36),(42,45),(47,49),(41,53),(33,51),(28,58),(22,56),(21,50),(15,50)]),(3,[(17,40),(25,35),(31,30),(38,30),(42,34),(37,39),(31,38),(28,45),(22,45)]),(4,[(22,37),(28,32),(36,30),(39,33),(34,35),(31,35),(28,40),(23,40)])])
    # Dominant upper crown, uneven outline with deliberate notches.
    p.crown([(28,29),(30,23),(36,21),(38,15),(45,14),(49,9),(59,10),(64,14),(70,13),(78,17),(79,23),(85,26),(84,33),(78,36),(75,42),(65,43),(59,40),(53,44),(43,42),(39,38),(32,37)],[(2,[(32,28),(39,24),(41,19),(50,17),(55,13),(62,17),(70,18),(76,22),(76,29),(81,30),(75,34),(66,33),(61,37),(53,35),(46,39),(41,34),(34,34)]),(3,[(39,24),(44,18),(51,18),(56,14),(63,18),(71,19),(74,23),(69,27),(60,26),(55,30),(46,29),(42,32),(38,29)]),(4,[(42,23),(46,19),(53,19),(57,16),(62,18),(66,21),(61,23),(55,23),(51,26),(44,26)]),(5,[(46,20),(51,20),(55,18),(58,18),(55,21),(51,22),(46,22)])])
    # Foreground crown rests on the fork rather than swallowing its whole trunk.
    p.crown([(48,45),(55,37),(66,35),(72,39),(79,38),(86,43),(85,51),(79,55),(72,56),(70,62),(61,63),(57,59),(50,58),(51,52),(46,50)],[(2,[(52,45),(60,40),(67,39),(72,43),(79,43),(82,47),(77,51),(68,51),(64,58),(59,55),(53,54)]),(3,[(55,44),(61,40),(66,40),(71,44),(77,44),(76,48),(68,47),(62,51),(56,49)]),(4,[(57,44),(62,42),(67,42),(69,45),(64,46),(60,47)])])
    p.leaf_lips([[(17,42),(20,40),(24,40)],[(34,31),(37,29),(41,29)],[(43,25),(47,24),(51,24)],[(60,20),(64,21)],[(71,27),(75,28)],[(82,32),(86,33)],[(59,44),(62,43),(65,43)],[(28,51),(31,49),(34,49)]])
    p.line(6,[(45,20),(48,19),(51,19)])
    # Two bark planes, not random bark chips.
    p.line(11,[(51,75),(54,81),(55,91)],1)
    p.line(8,[(57,95),(56,98),(57,101)],1)
    return p.finish((226,232))


def willow():
    p=Pixel(96,122)
    p.shape(7,[(33,118),(42,112),(44,100),(43,79),(38,59),(29,44),(31,38),(40,51),(47,65),(55,48),(64,37),(66,38),(59,52),(51,73),(50,96),(52,111),(61,118),(54,118),(47,115),(41,118)])
    p.shape(9,[(39,115),(46,107),(47,83),(44,67),(40,54),(46,63),(49,74),(51,67),(56,56),(52,73),(48,88),(49,108),(53,114),(48,112),(44,116)])
    p.line(11,[(45,76),(47,89),(46,105),(43,112)],2)
    p.line(10,[(52,66),(57,53),(62,45)],2)
    p.crown([(40,18),(50,12),(60,13),(66,18),(73,20),(78,28),(78,39),(84,48),(83,67),(79,71),(76,64),(75,47),(70,42),(70,63),(66,80),(61,86),(60,76),(63,56),(61,45),(55,41),(44,38)],[(1,[(49,23),(58,19),(66,23),(72,27),(74,37),(71,42),(65,36),(58,33),(51,34)]),(2,[(53,19),(59,17),(65,20),(69,24),(65,27),(56,25)]),(2,[(67,40),(70,41),(69,56),(65,74),(63,77),(65,58)]),(3,[(75,43),(78,48),(79,62),(77,60)])])
    p.crown([(13,40),(15,29),(23,23),(29,20),(38,20),(43,26),(47,30),(44,39),(37,44),(34,53),(34,70),(30,80),(27,82),(28,64),(26,49),(24,51),(22,72),(18,83),(16,79),(18,61),(16,52),(12,49)],[(1,[(17,37),(23,29),(30,25),(36,24),(41,29),(40,35),(33,37),(29,43),(23,43),(20,50),(19,59),(17,48)]),(2,[(21,33),(27,27),(34,26),(39,29),(36,32),(29,33),(26,37),(22,38)]),(3,[(26,29),(31,26),(35,27),(32,30),(27,32)]),(2,[(28,45),(31,43),(31,62),(29,72),(29,56)]),(3,[(20,51),(22,49),(21,65),(19,69)])])
    p.crown([(27,25),(30,16),(35,13),(38,8),(48,7),(54,11),(61,11),(66,17),(65,24),(58,29),(52,28),(48,33),(41,32),(36,29),(30,30)],[(2,[(32,23),(35,17),(42,15),(45,11),(51,13),(57,15),(61,18),(59,23),(52,22),(48,27),(40,27),(37,23)]),(3,[(37,18),(43,13),(48,12),(52,16),(58,17),(57,20),(49,20),(46,23),(41,23)]),(4,[(40,17),(45,14),(49,14),(50,17),(46,18),(44,20),(40,20)])])
    p.leaf_lips([[(24,32),(28,29),(31,29)],[(36,20),(39,18),(42,18)],[(44,15),(47,14),(50,15)],[(54,18),(58,19)],[(68,28),(71,31)],[(65,49),(65,56)],[(29,49),(29,54)]])
    p.line(10,[(49,109),(54,114),(57,115)])
    # Split the hanging sheets with a few tapered negative spaces. Avoid either
    # disconnected leaf confetti or a solid green curtain.
    for line in [[(18,81),(19,75),(20,69)],[(29,80),(30,70),(29,64)],[(62,82),(64,73),(64,66)],[(80,68),(80,59),(79,55)]]:
        p.d.line(line,fill=(0,0,0,0),width=1)
    p.line(3,[(26,44),(28,51),(27,59)],1)
    p.line(3,[(65,48),(64,56),(62,62)],1)
    return p.finish((191,244))


def leaning():
    p=Pixel(107,111)
    p.shape(7,[(40,107),(46,102),(48,94),(44,85),(37,75),(38,66),(45,57),(42,48),(35,44),(35,40),(44,45),(51,56),(55,53),(63,37),(68,34),(65,43),(58,57),(47,69),(46,76),(52,85),(56,95),(57,101),(66,107),(58,107),(52,105),(45,107)])
    p.shape(9,[(44,104),(51,101),(50,92),(46,83),(41,75),(42,69),(48,62),(50,60),(46,70),(44,76),(49,84),(54,94),(54,102),(58,105),(52,103),(48,106)])
    p.line(11,[(46,67),(43,72),(43,76),(48,85),(51,94)],2)
    p.line(10,[(49,63),(57,54),(63,44)],2)
    p.crown([(47,29),(55,20),(62,18),(69,16),(78,18),(84,24),(93,26),(97,34),(93,39),(95,46),(87,51),(81,50),(77,56),(69,55),(65,51),(58,52),(56,44),(49,40)],[(1,[(56,29),(62,23),(69,21),(76,23),(83,29),(90,30),(91,36),(85,40),(79,39),(74,46),(64,45),(58,39)]),(2,[(60,27),(67,23),(74,24),(78,27),(85,29),(84,33),(76,32),(70,37),(64,35)]),(3,[(64,26),(68,24),(73,25),(76,28),(71,29),(67,31)])])
    p.crown([(9,42),(14,33),(24,30),(29,25),(39,25),(44,31),(50,34),(51,42),(47,48),(40,48),(36,55),(27,55),(24,51),(17,53),(13,49),(9,48)],[(2,[(14,41),(20,36),(26,35),(31,30),(38,30),(43,35),(46,38),(42,43),(35,41),(31,48),(25,46),(20,48),(16,46)]),(3,[(18,38),(26,33),(32,29),(38,31),(40,34),(34,35),(30,39),(22,41)]),(4,[(23,35),(29,32),(34,31),(36,33),(30,35),(27,38),(22,39)])])
    p.crown([(29,27),(34,19),(42,17),(47,11),(56,10),(61,14),(68,15),(74,22),(73,28),(68,32),(60,33),(56,38),(48,36),(43,38),(38,33),(32,34)],[(2,[(34,26),(39,21),(47,20),(51,15),(56,14),(62,18),(67,19),(69,24),(65,27),(58,26),(54,31),(47,30),(42,33),(40,29)]),(3,[(41,23),(49,18),(53,15),(57,16),(60,20),(66,21),(64,24),(57,23),(52,27),(46,26)]),(4,[(44,23),(49,20),(53,17),(57,18),(58,21),(53,22),(50,24)])])
    p.crown([(40,45),(46,37),(54,35),(60,39),(68,39),(72,44),(70,50),(64,53),(60,52),(56,57),(48,56),(44,53),(38,51)],[(2,[(44,45),(50,40),(55,39),(61,43),(67,43),(68,47),(61,48),(55,53),(49,51),(44,51)]),(3,[(47,44),(52,40),(56,41),(61,44),(59,47),(53,49),(48,47)]),(4,[(49,43),(53,42),(55,44),(52,45)])])
    p.leaf_lips([[(17,40),(22,37),(25,37)],[(31,34),(34,33),(37,34)],[(44,23),(48,21)],[(52,18),(55,17),(58,19)],[(63,25),(66,25)],[(79,30),(83,31)],[(50,44),(53,43)]])
    p.line(12,[(49,96),(50,101),(46,104)])
    return p.finish((214,222))


def sapling():
    p=Pixel(63,75)
    # Young, flexible stem with three broad leaf sprays, NOT an adult resized down.
    p.shape(7,[(25,65),(29,61),(30,49),(27,41),(21,37),(22,35),(29,39),(32,46),(34,39),(39,30),(41,30),(37,40),(33,51),(33,61),(37,65),(32,65),(30,63),(28,65)])
    p.shape(10,[(29,62),(31,54),(31,46),(30,42),(33,46),(32,58),(32,63)])
    p.line(11,[(33,45),(35,38),(39,32)])
    p.crown([(11,31),(16,27),(22,27),(27,31),(28,36),(25,39),(19,39),(15,36),(11,35)],[(2,[(14,31),(18,29),(23,30),(25,33),(22,35),(18,34)]),(4,[(15,30),(19,29),(22,30),(20,32),(16,32)])])
    p.crown([(32,27),(36,22),(42,21),(49,24),(52,28),(50,33),(45,35),(38,34),(36,31)],[(2,[(36,27),(40,24),(45,24),(49,27),(48,30),(43,30),(39,32)]),(4,[(38,26),(41,24),(45,25),(47,27),(43,28),(39,29)])])
    p.crown([(20,21),(23,16),(28,13),(33,14),(37,19),(36,24),(31,27),(27,26),(24,24)],[(3,[(24,20),(28,16),(32,16),(34,20),(32,23),(28,24),(25,22)]),(5,[(25,19),(28,17),(31,17),(30,20),(27,21)])])
    p.line(9,[(30,43),(28,34),(28,26)])
    p.line(11,[(29,36),(28,29)])
    return p.finish((126,150))


def bank(direction,material='water'):
    # Front edges show a moist exposed bank. Back edges are turf invading water;
    # no luminous outline. All ink remains INSIDE the inherited land diamond.
    im=Image.new('RGBA',(64,32));d=ImageDraw.Draw(im)
    front=direction in ('bl','br')
    grass=(86,112,79,255);root=(105,92,69,255);wet=(65,76,69,255);lip=(137,124,90,255)
    # Canonical bottom-right edge: (63,16) to (32,31); ragged inward contour.
    outer=[(63,16),(59,18),(55,20),(51,22),(47,24),(43,26),(39,28),(35,30),(32,31)]
    inner=[(32,27),(36,26),(39,23),(43,23),(46,19),(50,19),(53,16),(57,16),(60,13)]
    d.polygon(outer+inner,fill=wet if material=='water' else (133,123,105,255))
    d.polygon([(60,14),(57,17),(53,17),(50,20),(46,20),(43,24),(39,24),(36,27),(33,28),(33,26),(37,24),(38,21),(43,21),(46,17),(51,17),(54,14),(58,14)],fill=root if front else grass)
    d.line([(60,13),(56,15),(52,15),(50,18),(46,18),(43,21),(39,21),(36,24),(32,26)],fill=grass,width=2)
    if front:
        for pts in [[(57,17),(54,19),(52,19)],[(47,22),(45,23),(43,23)],[(38,27),(36,28)]]:d.line(pts,fill=lip)
        d.line([(50,21),(49,23)],fill=wet)
        d.line([(41,25),(40,27)],fill=wet)
    if direction in ('bl','tl'):im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    if direction in ('tl','tr'):im=im.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
    out=im.resize((128,64),Image.Resampling.NEAREST)
    for y in range(64):
        for x in range(128):
            if abs(x-63.5)/64+abs(y-31.5)/32>1:out.putpixel((x,y),(0,0,0,0))
    return out


def cliff(variant):
    # Continuous rock volume with broad geological bedding. No disconnected
    # brick columns, black vertical silhouette gutters, or random stone noise.
    im=Image.new('RGBA',(64,115));d=ImageDraw.Draw(im)
    colors=['#333e42','#465156','#5b6563','#737a6e','#909582','#afb094','#667954','#879164']
    def poly(i,pts):d.polygon(pts,fill=colors[i])
    # Each face spans the whole width: adjacent slabs overlap without void slots.
    poly(1,[(0,0),(32,16),(63,0),(63,113),(48,114),(29,111),(15,114),(0,112)])
    poly(2,[(0,1),(32,17),(63,1),(63,37),(49,43),(33,39),(19,48),(0,39)])
    shift=[0,4,-3,7][variant]
    poly(3,[(0,8),(16,16),(29,22),(46,16),(63,8),(63,22),(50,27),(46,25),(33,31),(17,28),(0,21)])
    poly(4,[(0,9),(18,18),(31,24),(44,19),(63,10),(63,14),(45,23),(31,27),(17,22),(0,14)])
    poly(1,[(0,38+shift),(16,42+shift),(28,38+shift),(40,41+shift),(54,34+shift),(63,35+shift),(63,45+shift),(50,43+shift),(39,49+shift),(27,47+shift),(13,50+shift),(0,44+shift)])
    poly(3,[(0,47+shift),(16,54+shift),(29,52+shift),(43,54+shift),(53,48+shift),(63,49+shift),(63,66+shift),(52,71+shift),(40,67+shift),(27,70+shift),(15,65+shift),(0,64+shift)])
    poly(2,[(0,70+shift),(14,71+shift),(28,77+shift),(43,72+shift),(54,76+shift),(63,72+shift),(63,92),(47,95),(31,92),(15,98),(0,92)])
    poly(0,[(0,91),(17,97),(31,94),(43,97),(58,92),(63,91),(63,99),(46,101),(29,99),(15,103),(0,100)])
    # Faults have differing lengths and terminate in shelves, not full-height seams.
    for pts in [([(17,22),(18,30),(15,36),(18,41)],[(45,51+shift),(42,58+shift),(44,66+shift)],[(25,80),(28,86),(25,92)])]:
        for line in pts:d.line(line,fill=colors[1],width=2)
    for line in [[(2,49+shift),(17,56+shift),(27,54+shift)],[(43,55+shift),(53,50+shift),(61,51+shift)],[(2,72+shift),(13,73+shift)],[(31,80),(44,76),(52,79)]]:d.line(line,fill=colors[4],width=1)
    # Soil and moss belong only at the upper contact ledge.
    poly(6,[(0,0),(32,16),(63,0),(63,4),(47,12),(43,15),(32,21),(20,15),(15,15),(0,6)])
    for line in [[(2,3),(17,11),(22,12)],[(35,17),(44,13),(49,9)]]:d.line(line,fill=colors[7])
    return im.resize((128,230),Image.Resampling.NEAREST)


def rock_field():
    from tools_author_shore import rock_field as connected_shale
    return connected_shale()


def legacy_striped_rock_field():
    # 2048px-wide authored geology, sampled in WORLD coordinates at runtime.
    # Long beds cross tile boundaries. Faults are sparse and stop at bed changes.
    im=Image.new('RGBA',(1024,160),'#515d5e');d=ImageDraw.Draw(im)
    beds=[
        ('#6f7b73',[(0,8),(65,11),(119,5),(177,13),(249,15),(302,7),(349,10),(418,4),(501,12),(568,9),(643,17),(714,11),(799,14),(850,7),(923,12),(1023,8)]),
        ('#939b85',[(0,26),(71,29),(127,23),(191,31),(246,32),(309,26),(371,30),(429,24),(497,31),(574,28),(649,34),(717,31),(788,29),(861,25),(942,33),(1023,27)]),
        ('#68766e',[(0,35),(66,40),(134,34),(189,43),(260,42),(317,36),(377,40),(437,34),(505,39),(563,38),(638,46),(707,40),(781,42),(848,36),(931,43),(1023,36)]),
        ('#404e53',[(0,53),(75,56),(145,49),(208,61),(270,55),(329,50),(384,60),(451,52),(521,56),(598,52),(660,62),(728,56),(787,60),(875,51),(946,60),(1023,54)]),
        ('#63736c',[(0,65),(82,70),(139,62),(215,72),(278,66),(340,60),(398,68),(460,65),(538,71),(598,63),(670,73),(741,65),(809,70),(876,61),(949,73),(1023,66)]),
        ('#829080',[(0,90),(91,96),(158,86),(227,99),(293,91),(357,84),(416,95),(480,90),(548,96),(618,87),(689,97),(758,91),(822,94),(884,87),(956,97),(1023,91)]),
        ('#52615e',[(0,98),(87,103),(153,97),(223,109),(299,100),(368,93),(423,104),(484,97),(555,106),(624,98),(694,108),(762,99),(831,103),(892,96),(964,107),(1023,99)]),
        ('#35464c',[(0,131),(97,136),(167,126),(231,138),(308,132),(377,123),(434,136),(494,127),(561,136),(632,129),(708,139),(776,130),(844,135),(904,126),(970,138),(1023,130)])]
    for color,points in beds:
        d.polygon(points+[(1023,159),(0,159)],fill=color)
    # Broken foliation and oblique faults; never one crack per tile.
    for points in [[(83,12),(89,24),(84,37),(90,51)],[(288,44),(279,55),(287,70),(284,82)],[(462,11),(454,28),(460,37)],[(697,35),(705,49),(699,58)],[(849,70),(855,83),(848,93)],[(176,104),(184,116),(178,128)],[(571,105),(563,118),(570,132)],[(931,12),(925,24),(930,34)]]:
        d.line(points,fill='#404e53',width=2)
    for points in [[(18,27),(69,31),(93,28)],[(181,32),(208,34),(239,34)],[(344,29),(371,33),(393,29)],[(591,30),(616,33),(640,36)],[(801,31),(822,29),(841,29)],[(963,32),(1009,29)],[(107,92),(139,88),(156,90)],[(389,94),(413,97),(442,93)],[(713,96),(742,93),(761,95)]]:
        d.line(points,fill='#a7af96',width=1)
    # Deliberately local mineral shelves, each a connected plane rather than grain.
    for color,points in [('#758578',[(118,66),(143,63),(157,69),(144,74),(125,72)]),('#748479',[(477,70),(497,67),(517,72),(502,77),(484,76)]),('#485956',[(746,111),(769,105),(790,111),(782,118),(757,120)]),('#717e71',[(312,114),(337,110),(353,119),(339,125),(319,122)])]:d.polygon(points,fill=color)
    return im.resize((2048,320),Image.Resampling.NEAREST)


def natural_tree(name):
    # Retain the inherited organic silhouette; internally merge small SAME-material
    # color islands. This is cluster cleanup of prior AI-assisted art, not a claim
    # that these two trees were drawn from scratch in this pass.
    from collections import Counter
    source=Image.open(ROOT/'art/source/grove-craft-baseline'/f'{name}.png').convert('RGBA')
    logical_width=(source.width+1)//2
    small=source.crop((0,0,logical_width*2,source.height)).resize((logical_width,source.height//2),Image.Resampling.NEAREST)
    old_leaf={'202d30','293e3a','355145','46624b','597655','6d885c','8a9b68','a7ac79','c2bd8b','425e52','607863','7b9472','a1ab87'}
    material={}
    for y in range(small.height):
        for x in range(small.width):
            rgba=small.getpixel((x,y))
            if not rgba[3]:continue
            leaf=bytes(rgba[:3]).hex() in old_leaf
            choices=P[:7] if leaf else P[7:13]
            color=min(choices,key=lambda c:sum((a-b)**2 for a,b in zip(c[:3],rgba[:3])))
            small.putpixel((x,y),color);material[x,y]=leaf
    for threshold in ([3,7] if name=='young_tree' else [2,4]):
        seen=set();changes=[]
        for start,family in material.items():
            if start in seen:continue
            color=small.getpixel(start);region=[start];seen.add(start);border=Counter()
            for x,y in region:
                for q in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if q not in material or material[q]!=family:continue
                    c=small.getpixel(q)
                    if c==color:
                        if q not in seen:seen.add(q);region.append(q)
                    else:border[c]+=1
            if len(region)<=threshold and border:
                candidate=max(border,key=lambda c:border[c]*80-sum(abs(a-b) for a,b in zip(c[:3],color[:3])))
                changes.extend((q,candidate) for q in region)
        for q,color in changes:small.putpixel(q,color)
    out=small.resize((logical_width*2,source.height),Image.Resampling.NEAREST).crop((0,0,*source.size))
    out.putalpha(source.getchannel('A'))
    return out


def assets():
    result={'tiles/grove_rock_field.png':rock_field()}
    result.update({f'objects/{name}.png':natural_tree(name) for name in ['tree_a','tree_b','tree_c','young_tree']})
    for material in ['water','dirt']:
        for side in ['tl','tr','bl','br']:result[f'tiles/edge_{material}_{side}.png']=bank(side,material)
    # Legacy cliff_face_* is intentionally not overwritten: L1 alone uses the
    # continuous field. The four rejected prototypes remain evidence-only.
    return result


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=ROOT/'assets');args=parser.parse_args()
    for name,im in assets().items():
        path=args.out/name;path.parent.mkdir(parents=True,exist_ok=True);im.save(path)
        print('AUTHORED',name,im.size,im.getbbox(),'colors',len(im.getcolors(im.width*im.height) or []))

if __name__=='__main__':main()
