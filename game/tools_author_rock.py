"""Authored L1 boulder: explicit pixel clusters, no gradients/noise or copied art.
84x70 canvas and existing -22px offset retained. Ground root at (42,57),
contact spans x18..66; circular24px gameplay footprint remains logical, not ink bounds.
Usage: python3 game/tools_author_rock.py <output directory>
"""
from PIL import Image, ImageDraw
from pathlib import Path
import sys, json
P={'contact':'#292d31','deep':'#363d45','shade':'#47515a','cold':'#5a6870','body':'#758083','warm':'#939b92','light':'#b9bba4','edge':'#d3ccb0','soil':'#575746','mossdark':'#414d39','moss':'#5e6e47','mosslit':'#89925a','mossedge':'#a3a76c'}
im=Image.new('RGBA',(42,35)); d=ImageDraw.Draw(im)
def poly(c,xy): d.polygon(xy,fill=P[c])
def line(c,xy): d.line(xy,fill=P[c],width=1)
# Low asymmetrical contact wedge, not an ellipse cast around the whole object.
poly('contact',[(9,26),(16,26),(18,28),(16,29),(12,29),(10,28)])
poly('contact',[(23,26),(31,25),(34,27),(32,28),(26,29),(23,28)])
# Broken long shoulder; right overhang splits into a lower attached heel.
poly('deep',[(4,20),(5,15),(8,13),(9,10),(12,9),(14,6),(22,5),(24,6),(28,6),(30,9),(32,10),(33,14),(36,17),(37,22),(35,25),(32,27),(24,29),(16,29),(9,27),(6,24)])
# Three primary geological masses; warm top, muted frontal slab, cold receding flank.
poly('warm',[(7,15),(10,11),(13,10),(15,7),(22,6),(24,7),(27,7),(29,10),(27,13),(24,14),(19,16),(14,16),(11,18)])
poly('body',[(6,17),(10,18),(14,16),(20,17),(24,15),(26,18),(24,22),(25,25),(21,27),(15,27),(9,25),(7,22)])
poly('shade',[(28,12),(31,12),(32,16),(35,18),(35,22),(32,25),(27,27),(25,25),(25,21),(27,17)])
# Broad broken cleavage on the lit plane, subordinate chips only at silhouette/crease.
poly('light',[(10,12),(14,10),(16,8),(21,7),(24,8),(23,10),(19,11),(17,13),(13,14),(9,15)])
poly('warm',[(8,19),(11,19),(13,17),(17,18),(16,20),(13,21),(11,23),(8,22)])
poly('cold',[(17,18),(22,17),(24,16),(25,19),(22,22),(22,25),(19,26),(15,26),(15,24),(18,22)])
poly('body',[(28,16),(30,15),(32,17),(34,19),(33,21),(30,22),(27,24),(27,21)])
# One main dark fissure, tapering and changing direction; not a triangulated jewel.
line('shade',[(25,10),(25,12),(23,14),(23,16)])
line('deep',[(23,14),(23,16),(22,17)])
line('shade',[(22,19),(20,21),(20,23)])
line('light',[(24,12),(22,14),(21,14)])
# Scuffed bedding lip with interrupted highlights instead of a complete bright outline.
line('light',[(8,17),(11,18),(13,17)])
line('warm',[(8,24),(10,25)])
line('cold',[(28,25),(30,24),(32,23)])
poly('soil',[(9,26),(12,26),(14,28),(18,28),(18,29),(13,29),(10,27)])
poly('soil',[(23,27),(27,26),(30,26),(28,28),(24,28)])
# Moss is two connected mats following the upper seam, no random confetti.
poly('mossdark',[(8,12),(10,10),(13,10),(14,8),(17,7),(20,7),(20,9),(17,10),(15,12),(13,12),(12,15),(9,16),(7,15)])
poly('moss',[(9,12),(11,10),(14,10),(14,9),(17,8),(19,8),(18,9),(16,10),(14,11),(12,12),(12,14),(9,15),(8,14)])
poly('mosslit',[(10,11),(12,10),(15,9),(15,10),(13,11),(11,13),(9,13)])
line('mossedge',[(14,8),(15,8)])
poly('warm',[(15,10),(16,10),(15,12),(14,12)])
poly('mossdark',[(28,19),(31,18),(33,19),(33,21),(30,22),(28,23)])
poly('moss',[(30,18),(31,19),(31,20),(29,21),(28,21),(29,20)])
line('mosslit',[(30,19),(30,20)])
# Small top fracture step and mineral seams, deliberately not distributed texture.
line('edge',[(18,7),(20,7)])
line('warm',[(16,15),(18,14),(20,14)])
line('shade',[(10,22),(12,21)])
line('cold',[(31,13),(32,15)])
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
im.resize((84,70),Image.Resampling.NEAREST).save(out/'rock.png')
(out/'rock-authoring.json').write_text(json.dumps({'canvas':[84,70],'logical_canvas':[42,35],'palette':P,'root':[42,57],'method':'explicit authored pixel paths; no diffusion, gradient, random noise, or reference assets','collider_radius':24},indent=2))
print(out/'rock.png')
