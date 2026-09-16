"""R3 night flower: widened cup/throat, lifted material planes, rooted leaves.
Hand-authored discrete contours, no primitive ellipses/noise/gradient or sampled art.
"""
from pathlib import Path
from PIL import Image,ImageDraw
import sys,json,hashlib
O=Path(sys.argv[1]);O.mkdir(parents=True,exist_ok=True)
P=dict(soil='#49483f',dark='#43554c',green='#6a876b',sage='#94a781',rim='#b4bb98',stem='#99aa80',outer='#88758d',fold='#a18ba5',petal='#d0bbcd',lit='#ead8d8',tip='#f1e5d0',seam='#6e566f',heart='#ad8980',gold='#d6b482')
def p(d,pts,k):d.polygon(pts,fill=P[k])
def l(d,pts,k,w=1):d.line(pts,fill=P[k],width=w)
def base(d):
    p(d,[(24,61),(28,59),(32,59),(37,60),(40,61),(36,62),(27,62)],'soil')
    # Bent single stalk, one continuous light plane and narrow shadow side.
    p(d,[(30,61),(30,54),(32,46),(34,38),(34,32),(35,28),(38,27),(37,33),(37,39),(35,47),(33,54),(33,61)],'dark')
    p(d,[(31,59),(31,54),(33,46),(35,39),(35,33),(36,29),(37,29),(36,35),(36,40),(34,47),(32,55),(32,61)],'stem')
    # Left broad basal leaf: rolls down at tip, no repeated triangular geometry.
    p(d,[(31,57),(28,51),(24,47),(20,45),(15,45),(12,44),(13,47),(16,51),(21,54),(26,56),(29,59)],'dark')
    p(d,[(28,55),(25,51),(21,48),(17,47),(13,45),(15,48),(19,51),(24,53)],'green')
    l(d,[(14,46),(19,48),(23,50),(27,54)],'sage')
    p(d,[(14,47),(16,49),(18,51),(17,48)],'dark')
    # Right leaf curls at the tip rather than ending in a symmetric lance.
    p(d,[(33,58),(36,53),(39,50),(44,49),(48,50),(50,49),(49,52),(46,55),(42,56),(37,58),(34,61)],'dark')
    p(d,[(35,57),(39,53),(43,51),(46,51),(49,50),(47,52),(43,54),(39,54)],'green')
    l(d,[(36,56),(40,53),(44,52),(47,52)],'sage')
    # Front basal fold is short: ground remains visible around the root.
    p(d,[(31,60),(27,57),(23,58),(20,60),(24,61),(28,62),(33,62)],'dark')
    p(d,[(30,60),(26,58),(23,59),(25,60),(28,61)],'green')
    l(d,[(23,59),(26,59),(29,61)],'sage')
    p(d,[(33,61),(36,58),(38,58),(41,60),(39,61),(35,62)],'green')
    l(d,[(34,61),(37,59),(39,60)],'sage')
def bud(d):
    # Three wrapped lobes: rear crest, broad near fold, narrow far fold.
    p(d,[(34,31),(30,28),(29,24),(29,19),(31,15),(34,12),(38,11),(40,9),(42,10),(43,13),(44,16),(44,21),(42,26),(39,30),(37,32)],'outer')
    p(d,[(30,24),(30,20),(32,16),(35,14),(38,13),(40,11),(41,12),(40,15),(37,17),(34,20),(33,24),(34,29),(32,28)],'petal')
    p(d,[(31,21),(32,17),(35,15),(39,13),(39,14),(35,17),(33,20),(32,23)],'lit')
    p(d,[(35,29),(35,24),(36,20),(39,17),(41,13),(42,14),(43,18),(42,23),(40,27),(37,30)],'fold')
    p(d,[(37,27),(37,23),(39,20),(41,17),(42,17),(41,22),(39,26)],'petal')
    l(d,[(34,26),(35,22),(37,19)],'outer')
    # Calyx overlaps the closed corolla, not a separate holder.
    p(d,[(33,31),(31,28),(31,26),(34,29),(37,30),(40,28),(40,30),(37,33),(35,34)],'dark')
    p(d,[(34,31),(33,29),(36,31),(38,30),(37,32),(35,33)],'green')
    l(d,[(34,31),(35,32),(36,32)],'sage')
def bloom(d):
    # Rear petal is the closed bud's high crest unfurled, broad and rolled back.
    p(d,[(31,25),(29,22),(28,18),(28,14),(30,11),(33,10),(37,10),(40,8),(43,8),(45,10),(45,12),(43,15),(40,17),(37,21),(35,25)],'outer')
    p(d,[(30,20),(29,17),(30,14),(32,12),(36,12),(40,10),(43,9),(44,10),(43,12),(39,14),(36,17),(34,21),(33,24)],'petal')
    p(d,[(30,16),(31,13),(34,12),(38,12),(41,10),(43,10),(41,12),(37,14),(34,15)],'lit')
    p(d,[(29,18),(30,16),(33,15),(35,15),(33,18),(32,21),(32,23)],'fold')
    # Narrow far-side lobe: mostly occluded, not a repeated full petal.
    p(d,[(37,26),(40,21),(44,18),(48,17),(50,18),(52,17),(52,20),(49,23),(44,26),(40,28)],'outer')
    p(d,[(40,25),(43,22),(47,19),(50,19),(51,18),(50,20),(47,22),(44,24)],'petal')
    l(d,[(45,21),(48,19),(50,19)],'lit')
    # Visible throat is attached to the flared lip, no isolated central dot/ring.
    p(d,[(31,23),(34,19),(38,17),(42,17),(44,19),(44,23),(41,28),(37,32),(34,30),(32,27)],'seam')
    p(d,[(33,25),(35,21),(39,19),(41,19),(42,21),(40,26),(37,30),(34,28)],'heart')
    p(d,[(33,25),(34,22),(36,20),(36,23),(35,26)],'fold')
    l(d,[(35,28),(36,25),(38,23),(40,22)],'gold',2)
    l(d,[(37,24),(40,21)],'tip')
    # Broad near lip rolls lower, exposing the throat instead of a closed hood.
    # One broad highlight plane replaces the fragmented high zig-zag of R2.
    p(d,[(28,24),(30,25),(33,29),(36,32),(39,31),(42,29),(45,26),(48,23),(50,24),(49,28),(46,32),(43,34),(39,36),(35,37),(32,35),(30,32),(29,28),(27,26)],'outer')
    p(d,[(29,25),(31,28),(34,31),(37,33),(40,32),(44,29),(48,25),(49,25),(47,29),(44,32),(40,34),(36,35),(33,33),(31,30),(30,27)],'petal')
    p(d,[(29,25),(31,27),(34,30),(37,32),(40,31),(44,28),(48,24),(49,25),(46,28),(43,31),(39,33),(36,34),(33,32),(31,29)],'lit')
    p(d,[(33,34),(36,35),(40,34),(42,33),(40,35),(37,36),(35,36)],'fold')
    l(d,[(46,31),(48,28),(49,26)],'fold')
    p(d,[(33,35),(35,37),(38,36),(40,35),(39,37),(36,38),(34,37)],'dark')
    l(d,[(34,36),(36,38),(38,37)],'green')
records=[]
for state,draw in [('closed',bud),('open',bloom)]:
    im=Image.new('RGBA',(64,64));d=ImageDraw.Draw(im);base(d);draw(d)
    im=im.resize((128,128),Image.Resampling.NEAREST);path=O/f'night_bud_{state}.png';im.save(path)
    records.append(dict(file=path.name,sha256=hashlib.sha256(path.read_bytes()).hexdigest(),size=im.size,bbox=im.getbbox(),colors=len(im.getcolors() or [])))
em=Image.new('RGBA',(64,64));d=ImageDraw.Draw(em)
l(d,[(35,28),(36,25),(38,23),(40,22)],'gold',2);l(d,[(37,24),(40,21)],'tip')
em.resize((128,128),Image.Resampling.NEAREST).save(O/'night_bud_emission.png')
(O/'manifest.json').write_text(json.dumps({'method':'manually authored pixel paths, widened mouth, three mapped petal folds, shared plant base','aesthetic':'candidate R3 awaiting review','assets':records},indent=2))
B=Path(__file__).resolve().parent/'before'
sheet=Image.new('RGB',(1120,650),'#262d35');d=ImageDraw.Draw(sheet)
for i,(label,folder,s) in enumerate([('BEFORE CLOSED',B,'closed'),('BEFORE OPEN',B,'open'),('R3 CLOSED',O,'closed'),('R3 OPEN',O,'open')]):
    im=Image.open(folder/f'night_bud_{s}.png').convert('RGBA');x=i*280
    d.text((x+8,8),label,fill='#e6ded0');sheet.paste(im,(x+76,30),im)
    z=im.resize((256,256),Image.Resampling.NEAREST);sheet.paste(z,(x+12,180),z)
    si=Image.new('RGBA',im.size,'#bec7c6');si.putalpha(im.getchannel('A'));sheet.paste(si,(x+76,490),si)
sheet.save(O/'comparison.png');print(json.dumps(records,indent=2))
