"""Authored wet-soil bank continuation at the grass/soil/water junction.
Reuse the shared hand-authored contour; separate soil colors from grass.
Only four edge_soil_water assets are written. Terrain footprint is unchanged.
"""
from pathlib import Path
from PIL import Image
from tools_author_grove_craft import bank
ROOT=Path(__file__).resolve().parent

def assets():
    recolor={(86,112,79,255):(137,124,94,255),
             (105,92,69,255):(112,94,69,255),
             (65,76,69,255):(65,74,65,255),
             (137,124,90,255):(158,142,105,255)}
    result={}
    for side in ('bl','br','tl','tr'):
        im=bank(side,'water')
        im.putdata([recolor.get(pixel,pixel) for pixel in im.getdata()])
        result[f'tiles/edge_soil_water_{side}.png']=im
    return result
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,default=ROOT/'assets');a=p.parse_args()
    for name,im in assets().items():
        path=a.out/name;path.parent.mkdir(parents=True,exist_ok=True);im.save(path);print(path)
