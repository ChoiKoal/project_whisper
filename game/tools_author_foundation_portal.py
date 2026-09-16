"""FDN12 authored pixel paths. 112x144 working grid, exact2x, no noise/AI/downsample.
Quiet limestone planes, broken radial arch joints, asymmetric root/moss clusters.
This is a representative candidate, never an automatic SANABI quality claim.
"""
from pathlib import Path
from PIL import Image, ImageDraw
R=Path(__file__).resolve().parent
OUT=R/'assets/foundation';OUT.mkdir(parents=True,exist_ok=True)
P={'ink':'#293c3a','deep':'#3a4c48','shadow':'#50625a','side':'#687469','stone':'#929c83','light':'#b2b99a','edge':'#d1cdb0','warm':'#aaa888','chip':'#c1bc9f','joint':'#46594f','moss':'#47644b','leaf':'#688351','leaflight':'#90a663','root':'#796c54','rootlight':'#a28b63','accent':'#9cacbd'}
im=Image.new('RGBA',(112,144));d=ImageDraw.Draw(im)
def poly(points,c):d.polygon(points,fill=P.get(c,c))
def line(points,c,w=1):d.line(points,fill=P.get(c,c),width=w)
# Isometric threshold: deep front riser, broken slab on top, separate inner step.
poly([(10,126),(34,115),(88,118),(106,131),(94,138),(62,143),(21,138),(7,131)],'ink')
poly([(9,128),(56,132),(105,128),(105,134),(88,140),(60,144),(20,139),(9,134)],'deep')
poly([(11,125),(37,114),(86,118),(104,129),(78,138),(32,136)],'stone')
poly([(13,126),(34,119),(86,122),(98,128),(75,133),(34,132)],'light')
poly([(18,133),(34,138),(59,140),(59,143),(21,138)],'side')
poly([(61,138),(88,134),(99,130),(103,132),(88,138),(61,142)],'shadow')
line([(17,126),(35,119),(49,120)],'edge');line([(71,122),(85,123),(95,128)],'edge')
line([(40,121),(39,126),(43,128),(41,133)],'joint');line([(73,126),(76,129),(74,133)],'side')
poly([(29,121),(39,116),(80,117),(90,123),(79,129),(42,128)],'deep')
poly([(29,118),(42,112),(79,114),(91,121),(78,125),(41,124)],'warm')
line([(31,118),(42,114),(78,115)],'edge')
# Jamb feet and irregular structural silhouette, kept separate from material marks.
poly([(15,125),(15,84),(12,75),(16,61),(16,47),(23,27),(39,14),(54,10),(69,12),(88,23),(98,43),(99,60),(96,81),(99,94),(97,126),(87,133),(75,126),(76,64),(72,51),(63,42),(51,42),(42,49),(36,64),(36,126),(25,131)],'ink')
# Outer right reveal shows actual mass, not a flat arch icon.
poly([(81,31),(91,32),(98,45),(98,64),(94,80),(98,94),(96,125),(87,130),(87,82),(88,60)],'deep')
poly([(84,46),(91,46),(94,59),(91,80),(93,96),(91,123),(87,126),(87,80)],'shadow')
# Authored left front plane and distinct planes around broken corners.
poly([(17,122),(18,84),(15,74),(19,62),(19,48),(27,29),(39,19),(52,14),(56,28),(43,34),(35,49),(31,64),(32,86),(30,124),(25,127)],'stone')
poly([(19,47),(27,29),(39,19),(51,15),(49,21),(37,25),(31,34),(24,51),(22,66),(19,80),(19,120),(17,120)],'light')
poly([(26,77),(30,65),(30,89),(28,99),(30,122),(25,125),(24,110),(26,94)],'side')
poly([(16,71),(20,64),(25,65),(23,73),(25,81),(19,85)],'warm')
# Inner reveal, a dark edge exactly around the clear aperture.
poly([(31,124),(33,64),(39,48),(48,36),(57,33),(58,41),(49,44),(42,51),(37,65),(37,125)],'shadow')
poly([(33,86),(35,67),(37,63),(37,124),(34,124)],'deep')
# Right stone face has a heavier broken shoulder, different block proportions.
poly([(61,14),(71,16),(84,24),(93,44),(90,61),(87,82),(90,96),(88,127),(77,123),(79,91),(78,66),(72,48),(62,38)],'stone')
poly([(64,16),(70,18),(81,26),(88,39),(87,45),(81,40),(75,29),(64,27)],'light')
poly([(82,61),(88,55),(86,81),(89,96),(86,111),(87,125),(82,126),(82,98),(80,80)],'side')
poly([(74,48),(80,54),(82,67),(80,88),(78,91),(77,65)],'deep')
# Keystone and upper arch bearing stones.
poly([(49,12),(59,10),(68,15),(67,29),(63,40),(51,41),(47,28)],'joint')
poly([(51,14),(59,12),(65,16),(64,29),(60,37),(53,37),(50,27)],'light')
poly([(59,14),(64,17),(62,29),(59,35),(60,21)],'stone')
line([(52,15),(57,14)],'edge')
# Deliberate masonry joints: radial at arch, offset and partly eroded down jambs.
for pts in [[(25,32),(32,36),(37,38)],[(19,50),(24,51),(31,55)],[(17,84),(24,83),(31,86)],[(18,105),(24,103),(30,106)],[(71,22),(67,29)],[(85,35),(78,41)],[(89,58),(83,60),(78,58)],[(87,82),(83,85),(80,84)],[(89,109),(84,110),(79,108)]]:line(pts,'joint')
for pts in [[(23,31),(28,27),(34,25)],[(20,49),(24,38)],[(19,87),(23,86)],[(18,107),(23,106)],[(84,36),(80,31)],[(83,63),(87,61)],[(82,112),(86,112)]]:line(pts,'chip')
# Damage clustered into a split/chip event, not even speckle.
poly([(19,61),(24,62),(23,67),(18,70),(16,75),(15,70)],'shadow')
line([(25,48),(27,52),(24,58),(25,63),(22,68)],'joint')
line([(26,49),(28,53),(26,58)],'chip')
poly([(90,44),(94,44),(92,51),(87,52)],'chip')
poly([(89,46),(92,45),(90,50)],'side')
line([(85,94),(82,98),(84,102),(81,105)],'joint')
# Roots curl around feet; grouped ivy follows masonry seams rather than a noise mask.
for pts,w in [([(16,94),(18,103),(16,114),(20,123),(31,130),(34,134)],2), ([(17,112),(12,121),(14,129),(23,132)],2), ([(91,89),(88,97),(91,108),(88,120),(82,127)],2)]:line(pts,'root',w)
for pts in [[(16,96),(17,104),(15,113)],[(17,115),(20,122),(29,128)],[(89,100),(90,109),(87,119)]]:line(pts,'rootlight')
for points in [[(20,31),(25,27),(33,25),(31,29),(25,31),(22,37),(18,40)],[(17,84),(20,79),(25,81),(24,87),(19,90)],[(84,116),(91,113),(94,117),(91,123),(85,125),(80,123)],[(14,122),(19,119),(23,123),(22,128),(17,130),(11,129)]]:
    poly(points,'moss')
for points in [[(20,33),(24,30),(28,30),(25,33),(20,37)],[(18,85),(21,83),(24,84),(21,87)],[(85,120),(90,116),(92,117),(90,121),(84,123)],[(14,124),(17,122),(20,124),(17,126)]]:
    poly(points,'leaf')
for pts in [[(21,32),(24,31)],[(86,120),(89,118)],[(15,124),(17,123)]]:line(pts,'leaflight')
# Restrained chisel traces on quiet planes, no random texture scatter.
for pts in [[(21,91),(24,90)],[(20,115),(23,114)],[(82,72),(84,70)],[(26,42),(28,40)],[(72,33),(74,34)],[(25,97),(27,96)]]:line(pts,'warm')
im.resize((224,288),Image.Resampling.NEAREST).save(OUT/'nature_gate.png')
# Crest has an incised leaf, not a floating neon badge. Separate lit line uses same pixels.
for lit in [False,True]:
    crest=Image.new('RGBA',(22,20));c=ImageDraw.Draw(crest)
    if not lit:
        c.polygon([(4,2),(12,0),(19,4),(20,12),(14,18),(4,17),(1,11)],fill=P['shadow'])
        c.polygon([(5,3),(12,2),(17,5),(18,11),(13,16),(5,15),(3,10)],fill=P['stone'])
    color='#c0d3b3' if lit else P['deep']
    if not lit:c.polygon([(7,14),(4,10),(5,7),(10,4),(17,3),(16,8),(13,12)],fill=P['shadow'])
    c.line([(5,16),(9,11),(13,7),(16,4)],fill=color,width=1)
    c.line([(9,11),(7,8),(8,6)],fill=color,width=1)
    c.line([(11,9),(14,9),(15,7)],fill=color,width=1)
    crest.resize((44,40),Image.Resampling.NEAREST).save(OUT/('nature_crest_lit.png' if lit else 'nature_crest.png'))
# Discrete mineral inlays at jamb and threshold; no soft vertical glow bars.
inlay=Image.new('RGBA',(112,144));il=ImageDraw.Draw(inlay)
for pts in [[(25,67),(27,71),(25,76)],[(83,92),(85,96),(83,100)],[(49,122),(56,119),(63,122)]]:
    il.line(pts,fill='#b6c9a8',width=1)
inlay.resize((224,288),Image.Resampling.NEAREST).save(OUT/'nature_inlay.png')
# Three discrete aperture silhouettes: dormant scattered dust, flicker broken arcs,
# open nested leaf-like directional strokes. Their changing shapes are not just alpha.
for state in ['dormant','flicker','open']:
    veil=Image.new('RGBA',(52,80));v=ImageDraw.Draw(veil)
    if state=='dormant':
        v.line([(16,68),(19,68)],fill='#637573');v.line([(34,61),(35,59)],fill='#637573')
    else:
        arcs=[([(10,61),(8,48),(10,32),(15,21),(24,15)],'#667f85'), ([(31,13),(39,24),(43,40),(40,57),(32,68)],'#8dafa4'), ([(18,62),(24,68),(32,62),(36,50)],'#bad0b2')]
        if state=='open':arcs += [([(24,15),(32,20),(36,31),(34,44),(28,51),(21,48),(19,36),(23,29),(28,31)],'#bdd1b7'), ([(11,58),(17,69),(27,73),(37,66),(43,56)],'#678681')]
        for pts,col in arcs:v.line(pts,fill=col,width=2)
        if state=='flicker':
            v.rectangle((6,38,13,44),fill=(0,0,0,0));v.rectangle((37,24,46,31),fill=(0,0,0,0))
        for x,y in [(17,17),(36,64),(30,40)]:v.rectangle((x,y,x+1,y+1),fill='#d6dcbd')
    veil.resize((104,160),Image.Resampling.NEAREST).save(OUT/f'nature_veil_{state}.png')
# Human-inspectable native and integer-scale source receipt.
board=Image.new('RGBA',(640,340),'#303c3c');board.alpha_composite(Image.open(OUT/'nature_gate.png'),(20,30))
board.alpha_composite(Image.open(OUT/'nature_crest.png'),(110,50))
for i,state in enumerate(['dormant','flicker','open']):board.alpha_composite(Image.open(OUT/f'nature_veil_{state}.png'),(280+i*114,100))
board.convert('RGB').save(R.parent/'evidence/12-foundation-scene/portal-source-native.png')
board.resize((1280,680),Image.Resampling.NEAREST).convert('RGB').save(R.parent/'evidence/12-foundation-scene/portal-source-2x.png')
print('Authored nature gate + crest2 + veil3 written; visual review required.')
