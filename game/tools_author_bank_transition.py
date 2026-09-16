"""One authored landform, not a repeating edge tile. Native 2px clusters.
Local shore coordinates (s along the shore, d inland) follow the measured
STACKED boundary. Engine clips this field against CURRENT walkable low tiles.
No reference pixels/AI generation, noise, blur or randomized detail used here.
"""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parent
ORIGIN=(1216,1056)
SIZE=(512,288)
# Deliberate warm silt / cool damp earth / dull sod hierarchy.
P={'grass':'#66785b','grass_dark':'#607155','grass_light':'#718262',
   'sod':'#53634a','earth':'#968a70','earth_light':'#a59a7e','earth_mid':'#897e66',
   'earth_dark':'#766f5c','wet':'#626e5d','wet_dark':'#4c6157',
   'stone':'#8a8e78','stone_light':'#a5a790','stone_dark':'#676e60'}
def asset():
    im=Image.new('RGBA',(SIZE[0]//2,SIZE[1]//2));d=ImageDraw.Draw(im)
    depth_scale=1.0
    def point(p):
        s,n=p
        n*=depth_scale
        return (round((64+s+n)/2),round((192-s/2+n/2)/2))
    def poly(color,points):d.polygon([point(p) for p in points],fill=P[color])
    def line(color,points,width=1):d.line([point(p) for p in points],fill=P[color],width=width)
    # Cover the old six soil diamonds with a continuous, nonrectangular sod field.
    # Water-facing excess is removed by the real TileMap, never by guessed math.
    poly('grass',[(-38,-24),(8,-24),(326,-24),(356,0),(336,36),(320,64),(296,92),(268,114),(240,146),(192,156),(144,164),(90,166),(40,156),(8,132),(-20,98),(-38,60)])
    # Quiet turf margin: renderer samples the live base grass for exact integration.
    # Only a few purposeful sod planes belong to the bank; no sticker-wide planes.
    depth_scale=0.65
    # A root shoulder, sheltered middle pocket, and separately tapered upper cap.
    contour=[(-18,0),(0,-5),(66,-5),(186,-5),(306,-5),(324,0),
             (316,8),(302,17),(283,24),(262,28),(251,38),(230,46),
             (214,47),(201,37),(184,36),(164,52),(149,65),(123,69),
             (107,62),(93,67),(80,83),(54,91),(34,83),(18,60),(-3,44),(-16,20)]
    poly('sod',contour)
    poly('earth',[(-16,0),(0,-4),(306,-4),(321,0),(313,7),(297,13),
                  (279,19),(258,21),(247,30),(228,39),(215,40),(201,29),
                  (182,30),(159,46),(143,57),(122,61),(105,55),(90,60),
                  (76,74),(53,81),(37,73),(22,53),(1,36),(-12,17)])
    # Dry, compacted soil planes follow drainage, not individual cell diamonds.
    poly('earth_mid',[(-12,4),(19,6),(50,17),(62,29),(96,32),(108,49),(88,57),(74,70),(54,76),(38,67),(23,48),(0,31)])
    poly('earth_light',[(39,15),(75,9),(116,12),(140,21),(165,18),(184,8),(211,8),(214,18),(184,26),(159,43),(144,49),(123,47),(102,33),(73,30)])
    poly('earth_mid',[(211,9),(244,8),(275,3),(311,0),(300,11),(279,17),(254,17),(238,29),(224,34),(212,29),(203,23)])
    poly('earth_light',[(5,18),(25,24),(35,39),(51,45),(67,43),(79,49),(66,62),(48,60),(31,49),(20,32)])
    # Wet band is narrow and nonuniform. Two recesses, never a full dark stripe.
    poly('wet',[(-15,0),(318,0),(303,4),(282,6),(264,5),(249,9),(225,8),
                (202,5),(176,8),(157,13),(132,11),(111,8),(88,12),(62,10),(43,6),(25,9),(5,9),(-9,5)])
    poly('wet_dark',[(6,0),(47,0),(38,3),(25,4),(16,3)])
    poly('wet_dark',[(115,0),(171,0),(156,3),(139,5),(126,3)])
    poly('wet_dark',[(233,0),(282,0),(263,3),(251,4),(242,2)])
    # Broken sediment seams end inside the earth. Unequal lengths / spacing.
    line('earth_dark',[(25,18),(38,20),(44,26),(56,30)])
    line('earth_dark',[(108,21),(124,24),(133,30),(141,31)])
    line('earth_mid',[(173,17),(185,13),(195,13)])
    line('earth_dark',[(235,15),(245,12),(261,12)])
    # Small embedded flat stone, not decorative circular pebble stamps.
    poly('stone_dark',[(70,26),(82,22),(98,25),(103,31),(92,38),(76,35)])
    poly('stone',[(70,26),(83,23),(97,26),(99,30),(91,34),(76,32)])
    line('stone_light',[(72,26),(84,24),(95,26)])
    poly('stone_dark',[(267,11),(279,8),(290,11),(286,16),(272,18)])
    poly('stone',[(268,11),(279,9),(288,11),(283,14),(272,15)])
    # Sod overlap: clustered fingers of different lengths, not repeated scallops.
    for pts in [ [(17,62),(25,62),(32,70),(36,78),(30,77)],
                 [(56,82),(61,74),(68,72),(68,83),(62,89)],
                 [(87,69),(91,57),(98,53),(102,60),(95,69)],
                 [(142,63),(144,52),(151,49),(156,53),(151,65)],
                 [(174,45),(175,35),(182,30),(186,37),(181,44)],
                 [(220,45),(226,35),(234,32),(235,38),(230,46)],
                 [(282,23),(288,15),(296,12),(298,18),(289,24)] ]:
        poly('grass_dark',pts)
    for pts in [[(19,66),(23,62),(26,65)],[(60,80),(61,75),(64,74)],
                [(93,63),(95,57),(98,56)],[(146,59),(149,52),(152,53)],
                [(179,40),(182,34)],[(226,40),(230,35)],[(288,20),(293,15)]]:
        line('grass_light',pts)
    # Lower root shoulder: open earth channels frame roots without a black plinth.
    line('earth_dark',[(-6,11),(8,18),(17,33),(31,42)],2)
    line('earth_light',[(1,12),(13,21),(21,34)],1)
    return im.resize(SIZE,Image.Resampling.NEAREST)
if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=ROOT/'assets/tiles/grove_bank_transition.png');args=parser.parse_args()
    args.out.parent.mkdir(parents=True,exist_ok=True);asset().save(args.out);print(args.out)
