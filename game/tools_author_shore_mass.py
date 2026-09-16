"""Connected shale study, AI-assisted source + explicit palette/cluster cleanup.
Not all-hand-pixel art. Original study retained with provenance; no reference game
asset is sampled. Preserve mass aspect, remove diffuse small marks, retain broad
fractures and interrupted shelves. Runtime acceptance requires gameplay review.
"""
from pathlib import Path
from collections import Counter,deque
from PIL import Image,ImageFilter
ROOT=Path(__file__).resolve().parent
PALETTE=['#414b48','#525b55','#626b60','#727a6b','#838a78','#929783',
 '#a0a28b','#abb097','#686350','#756e57','#847b60','#918867',
 '#5b6548','#717954','#858a60','#96966d']

def remove_small_clusters(im,maximum=7):
    w,h=im.size;data=list(im.getdata());seen=bytearray(w*h);original=data[:]
    for start in range(w*h):
        if seen[start]:continue
        color=original[start];seen[start]=1;region=[start];edge=Counter();q=deque([start])
        while q:
            n=q.popleft();x=n%w;y=n//w
            neighbours=[]
            if x:neighbours.append(n-1)
            if x+1<w:neighbours.append(n+1)
            if y:neighbours.append(n-w)
            if y+1<h:neighbours.append(n+w)
            for k in neighbours:
                if original[k]==color:
                    if not seen[k]:seen[k]=1;q.append(k);region.append(k)
                else:edge[original[k]]+=1
        if len(region)<=maximum and edge:
            replacement=edge.most_common(1)[0][0]
            for n in region:data[n]=replacement
    out=Image.new('P',im.size);out.putpalette(im.getpalette());out.putdata(data)
    return out

def rock_field():
    source=Image.open(ROOT/'art/source/shore/slate-study.png').convert('RGB')
    # Two-to-one source framing remains two-to-one. Filtering consolidates
    # high-frequency AI texture before hand-selected material palette assignment.
    reduced=source.resize((1024,512),Image.Resampling.BOX).filter(ImageFilter.MedianFilter(5))
    palette=Image.new('P',(1,1))
    colors=[tuple(bytes.fromhex(c[1:])) for c in PALETTE]
    palette.putpalette([v for rgb in colors for v in rgb]+list(colors[0])*(256-len(colors)))
    indexed=reduced.quantize(palette=palette,dither=Image.Dither.NONE)
    cleaned=remove_small_clusters(indexed,24)
    cleaned=remove_small_clusters(cleaned,12)
    return cleaned.convert('RGBA').resize((2048,1024),Image.Resampling.NEAREST)

if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);args=p.parse_args()
    image=rock_field();args.out.parent.mkdir(parents=True,exist_ok=True);image.save(args.out)
    print(args.out,image.size,'colors',len(image.getcolors(256) or []))
