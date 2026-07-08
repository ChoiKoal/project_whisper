'use strict';
// L1A-2 — 시작의 숲 (Layer 1 nature) ORGANIC OBJECT art generator. Regenerates ALL
// Layer-1 organic objects (trees, sapling, bush, rock, flowers, rest stump, WORLD TREE)
// in the SAME procedural iso grammar as the L2~L5 object generators — replacing the older,
// flatter output that tools_gen_art.js baked. Deliverable L1A-2.
//
//   REPLACES (identical dims, same bottom-center ground origin — save/anchoring safe):
//     tree_a 226×232  tree_b 191×244  tree_c 214×222  young_tree 126×150
//     bush_green 64×46  rock 84×70  flower/flower_violet/flower_pink 56×64
//     rest_stump 108×96  world_tree 490×470  world_tree_glow 512×512
//   NEW (unwired, pre-purification dead variant): world_tree_dormant 490×470
//   NOT TOUCHED: bush_dry / bush_bloom (gate thornbush harness → tools_gen_art.js owns them).
//
// Anchoring invariant (art-guide §1: "오브젝트 기준점 = 바닥 다이아몬드 중심, 접지면을 캔버스
// 하단 중앙에 맞출 것"): every silhouette is horizontally centred on the canvas and its lowest
// opaque row sits at the canvas bottom (contact = bottom-center). The .gd scripts anchor each
// sprite centered() with a fixed Vector2(0,-h/2)-style offset, so keeping the same canvas dims
// + bottom-center contact means objects plant on the same ground line as before.
//
// Palette = docs/project-whisper-art-style-guide.md §3 (Layer-1 Nature 22색 ONLY, no new colours).
//   초록 #1b3a2a #2e5d3b #4d8b4f #7ab567 #a8d982
//   갈색 #3a2a20 #5c4433 #8a6a4a #b59268
//   파랑 #1e3a5c #2e6b8a #4aa3b8 #8fd4d9
//   보라 #3a2a5c #6b4a9e #9e7ad9 #d9b8ff
//   중성 #2a2a33 #6e6e7a #b8b4a8 #e8dfc8 #faf5e6
//   (flower pink family also uses the T2B/T2D grass-blossom accents #c96a7a #f0a8b8 already
//    established in tools_gen_l1_tiles.js — same-scene existing colours, not new to the game.)
// Lighting: 우상단(NE) 고정. 3-tone shading (top brightest, right-lit mid, left shadow).
// selout outline = same-hue 2 steps darker, NEVER pure black. Deterministic (fixed seeds →
// identical output every run → save reproducibility). Pure Node.js zlib PNG encoder, no deps.
// Produces into assets/objects/. Run: node tools_gen_l1_objects.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');
fs.mkdirSync(OUT, { recursive: true });

// ---- PNG encoder (shared idiom with tools_gen_l1_tiles.js / tools_gen_l2_objects.js) ----
function crc32(buf){let c=~0;for(let i=0;i<buf.length;i++){c^=buf[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(type,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const t=Buffer.from(type,'ascii');const body=Buffer.concat([t,data]);const crc=Buffer.alloc(4);crc.writeUInt32BE(crc32(body),0);return Buffer.concat([len,body,crc]);}
function encodePNG(w,h,pixels){const sig=Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;ihdr[10]=0;ihdr[11]=0;ihdr[12]=0;const stride=w*4;const raw=Buffer.alloc((stride+1)*h);for(let y=0;y<h;y++){raw[y*(stride+1)]=0;pixels.copy(raw,y*(stride+1)+1,y*stride,y*stride+stride);}const idat=zlib.deflateSync(raw,{level:9});return Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]);}
function makeCanvas(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hexToRGB(hex){const s=hex.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function setPx(cv,x,y,rgb,a=255){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;if(a>=255){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=255;return;}if(a<=0)return;const af=a/255,ia=1-af;if(cv.data[i+3]===0){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
const blendPx = setPx; // setPx already alpha-composites when a<255
function save(cv,name){const png=encodePNG(cv.w,cv.h,cv.data);fs.writeFileSync(path.join(OUT,name),png);console.log('wrote',name,cv.w+'x'+cv.h,png.length,'bytes');}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function darker(c,t){return mix(c,[0,0,0],t);}
function lighter(c,t){return mix(c,[255,255,255],t);}
function clamp(v,lo,hi){return v<lo?lo:(v>hi?hi:v);}
function det(seed){let s=seed>>>0||1;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}

// ---- palette (art-guide §3 Layer-1 Nature) ----
const G0='#1b3a2a', G1='#2e5d3b', G2='#4d8b4f', G3='#7ab567', G4='#a8d982';  // 초록
const B0='#3a2a20', B1='#5c4433', B2='#8a6a4a', B3='#b59268';                // 갈색
const W0='#1e3a5c', W1='#2e6b8a', W2='#4aa3b8', W3='#8fd4d9';                // 파랑
const V0='#3a2a5c', V1='#6b4a9e', V2='#9e7ad9', V3='#d9b8ff';                // 보라
const N0='#2a2a33', N1='#6e6e7a', N2='#b8b4a8', N3='#e8dfc8', N4='#faf5e6';  // 중성
// pink blossom accents already used by the L1 grass-flower tiles (same-scene, not new colours)
const PK0='#c96a7a', PK1='#f0a8b8';
const rgb = hexToRGB;

// ── organic primitives ─────────────────────────────────────────────────────
// Soft AO contact ellipse baked into the sprite bottom is NOT baked (art-guide §2: shadows are
// an engine blob). But a faint self-occlusion darkening at the trunk base helps it seat; kept subtle.

// Filled iso-lit blob (foliage clump / boulder mass). Center (cx,cy), radii rx,ry. Colours are a
// 3-tone ramp {sh,mid,hi}; NE light picks hi on the upper-right, sh on the lower-left, and a
// value-noise mottle breaks the fill. `salt` makes it deterministic; `outline` (or null) rims it.
function blob(cv,cx,cy,rx,ry,ramp,salt,opts){
  opts=opts||{};
  const {sh,mid,hi}=ramp;
  const jitter=opts.jitter||0; // 0..1 wobble of the silhouette edge
  const noiseAmt=opts.noise==null?0.24:opts.noise;
  const outline=opts.outline||darker(sh,0.30);
  const alpha=opts.alpha==null?255:opts.alpha;
  const x0=Math.floor(cx-rx-2),x1=Math.ceil(cx+rx+2),y0=Math.floor(cy-ry-2),y1=Math.ceil(cy+ry+2);
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
    const nx=(x-cx)/rx, ny=(y-cy)/ry;
    let d=nx*nx+ny*ny;
    // wobble the boundary with low-freq noise so clumps aren't perfect ellipses
    const wob=jitter?(smoothCell(x,y,Math.max(3,rx*0.4),salt+7)-0.5)*jitter:0;
    if(d>1.0+wob)continue;
    // NE light term: brighter toward upper-right (+nx, -ny), darker lower-left
    const lightT=clamp(0.5-(nx*0.5)-(ny*0.55),0,1); // 0=lit(UR) .. 1=shadow(LL)
    let c;
    if(lightT<0.34)c=mix(hi,mid,lightT/0.34);
    else if(lightT<0.7)c=mix(mid,sh,(lightT-0.34)/0.36);
    else c=mix(sh,darker(sh,0.28),(lightT-0.7)/0.30);
    // mottle
    const n=smoothCell(x,y,Math.max(3,rx*0.32),salt+31);
    if(n>0.70)c=mix(c,hi,noiseAmt*0.7);
    else if(n<0.30)c=mix(c,sh,noiseAmt);
    // soft edge falloff for a rounded read + selout rim on the outer 1px band
    if(d>0.90){c=outline;}
    setPx(cv,x,y,c,alpha);
  }
}

// tapered trunk from (bx,by0) base up to (tx,by1) with a slight lean; 3-tone bark, selout sides.
function trunk(cv,bx,byBottom,byTop,wBottom,wTop,leanX,ramp,salt){
  const {sh,mid,hi}=ramp;
  const H=byBottom-byTop;
  for(let y=byTop;y<=byBottom;y++){
    const t=(byBottom-y)/H;            // 0 at base .. 1 at top
    const w=wBottom+(wTop-wBottom)*t;
    const cx=bx+leanX*(1-t);           // lean: base fixed, top offset
    const hw=w/2;
    for(let x=Math.floor(cx-hw);x<=Math.ceil(cx+hw);x++){
      const nx=(x-cx)/hw;
      let c;
      if(nx>0.25)c=mix(mid,hi,clamp(nx,0,1));      // right = lit
      else if(nx<-0.35)c=sh;                        // left = shadow
      else c=mid;
      // bark grain
      const n=smoothCell(x,y,4,salt+3);
      if(n<0.32)c=mix(c,sh,0.35);
      setPx(cv,x,y,c);
    }
    // selout sides
    setPx(cv,cx-hw,y,darker(sh,0.25));
    setPx(cv,cx+hw,y,darker(sh,0.25));
  }
}

// a root that spreads from (bx,by) outward+down to (ex,ey), tapering, 3-tone bark.
function root(cv,bx,by,ex,ey,w0,ramp,salt){
  const {sh,mid,hi}=ramp;
  const steps=Math.round(Math.hypot(ex-bx,ey-by))+1;
  for(let i=0;i<=steps;i++){
    const t=i/steps;
    // ease outward with a slight downward sag
    const x=bx+(ex-bx)*t;
    const y=by+(ey-by)*t + Math.sin(t*Math.PI)*3;
    const w=Math.max(1,w0*(1-t*0.8));
    for(let k=-w;k<=w;k++){
      const nx=k/w;
      let c = nx>0.2?mix(mid,hi,clamp(nx,0,1)) : (nx<-0.4?sh:mid);
      setPx(cv,x+k,y,c);
    }
    setPx(cv,x-w,y,darker(sh,0.25));
    setPx(cv,x+w,y,darker(sh,0.25));
  }
}

const BARK={sh:rgb(B0),mid:rgb(B1),hi:rgb(B2)};
const BARK_LT={sh:rgb(B1),mid:rgb(B2),hi:rgb(B3)};

// ════════════════════════════════════════════════════════════════════════════
// TREES — 3 variants. Silhouette centred on canvasCX, trunk contact at canvas bottom.
// ════════════════════════════════════════════════════════════════════════════

// tree_a — big rounded broadleaf, deep greens (226×232).
(function treeA(){
  const W=226,H=232,cv=makeCanvas(W,H);const cx=W/2;const s=1010;
  const ramp={sh:rgb(G0),mid:rgb(G2),hi:rgb(G3)};
  trunk(cv,cx,H-1,H-92,26,15,-2,BARK,s);
  // a couple of low root flares for a grounded base
  root(cv,cx-8,H-6,cx-30,H-1,5,BARK,s+1);
  root(cv,cx+8,H-6,cx+30,H-1,5,BARK,s+2);
  // canopy: one big crown + satellite clumps for a bold rounded silhouette
  blob(cv,cx,90,104,86,ramp,s+10,{jitter:0.22,noise:0.26});
  blob(cv,cx-58,120,52,44,ramp,s+11,{jitter:0.25});
  blob(cv,cx+62,116,50,42,ramp,s+12,{jitter:0.25});
  blob(cv,cx-14,46,66,52,ramp,s+13,{jitter:0.2});
  blob(cv,cx+30,58,58,48,ramp,s+14,{jitter:0.2});
  // NE rim-light highlight clumps on the upper-right
  blob(cv,cx+44,50,30,24,{sh:rgb(G2),mid:rgb(G3),hi:rgb(G4)},s+15,{jitter:0.2,noise:0.2});
  blob(cv,cx+70,86,24,20,{sh:rgb(G2),mid:rgb(G3),hi:rgb(G4)},s+16,{jitter:0.2,noise:0.2});
  save(cv,'tree_a.png');
})();

// tree_b — lighter-green broadleaf, taller/narrower (191×244).
(function treeB(){
  const W=191,H=244,cv=makeCanvas(W,H);const cx=W/2;const s=2020;
  const ramp={sh:rgb(G1),mid:rgb(G3),hi:rgb(G4)};
  trunk(cv,cx,H-1,H-104,22,12,3,BARK_LT,s);
  root(cv,cx-6,H-5,cx-24,H-1,4,BARK_LT,s+1);
  root(cv,cx+6,H-5,cx+24,H-1,4,BARK_LT,s+2);
  blob(cv,cx,96,84,90,ramp,s+10,{jitter:0.24,noise:0.24});
  blob(cv,cx-46,132,44,40,ramp,s+11,{jitter:0.26});
  blob(cv,cx+50,126,42,38,ramp,s+12,{jitter:0.26});
  blob(cv,cx-8,44,58,54,ramp,s+13,{jitter:0.2});
  blob(cv,cx+26,60,48,44,ramp,s+14,{jitter:0.2});
  blob(cv,cx+40,52,26,22,{sh:rgb(G3),mid:rgb(G4),hi:lighter(rgb(G4),0.25)},s+15,{jitter:0.2,noise:0.18});
  save(cv,'tree_b.png');
})();

// tree_c — taller conifer, layered triangular tiers of dark green (214×222).
(function treeC(){
  const W=214,H=222,cv=makeCanvas(W,H);const cx=W/2;const s=3030;
  const ramp={sh:rgb(G0),mid:rgb(G1),hi:rgb(G2)};
  trunk(cv,cx,H-1,H-40,20,14,0,BARK,s);
  root(cv,cx-6,H-5,cx-22,H-1,4,BARK,s+1);
  root(cv,cx+6,H-5,cx+22,H-1,4,BARK,s+2);
  // conifer tiers: stacked flattened blobs, widest at bottom, small crown on top.
  const tiers=[
    [H-40, 100, 44],
    [H-96, 84, 40],
    [H-146, 62, 34],
    [H-186, 38, 26],
  ];
  for(let i=0;i<tiers.length;i++){
    const [ty,rx,ry]=tiers[i];
    blob(cv,cx,ty,rx,ry,ramp,s+20+i,{jitter:0.18,noise:0.22});
    // needle-lit fringe on the upper-right of each tier
    blob(cv,cx+rx*0.42,ty-ry*0.3,rx*0.34,ry*0.5,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+40+i,{jitter:0.16,noise:0.16});
  }
  // pointed crown tip
  blob(cv,cx,H-206,16,18,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+60,{jitter:0.14,noise:0.16});
  save(cv,'tree_c.png');
})();

// young_tree — small sapling with the "잎 기울임 훅": a leaning-leaf silhouette so the
// gatherable tilt cue reads. (126×150). Contact ~gap 17 like the old asset (kept slim base).
(function youngTree(){
  const W=126,H=150,cv=makeCanvas(W,H);const cx=W/2;const s=4040;
  const contactGap=17; const baseY=H-1-contactGap;
  const ramp={sh:rgb(G1),mid:rgb(G2),hi:rgb(G4)};
  // a slim trunk that LEANS to the right (the tilt cue)
  trunk(cv,cx-4,baseY,baseY-72,10,6,14,BARK_LT,s);
  // small foliage tuft, biased up-right along the lean → reads as "tipping over" leaves
  blob(cv,cx+14,baseY-84,40,34,ramp,s+10,{jitter:0.24,noise:0.22});
  blob(cv,cx-4,baseY-70,28,24,ramp,s+11,{jitter:0.26});
  blob(cv,cx+30,baseY-96,22,18,ramp,s+12,{jitter:0.22});
  // a couple of individual leaning leaf blades poking from the tuft (the explicit tilt hook)
  const leafR=det(s+99);
  for(let i=0;i<4;i++){
    const bx=cx+8+i*6, by=baseY-92-i*3;
    for(let k=0;k<10;k++){const lx=bx+k*1.1, ly=by-k*0.5;setPx(cv,lx,ly,i%2?rgb(G3):rgb(G4));setPx(cv,lx,ly+1,rgb(G2));}
  }
  save(cv,'young_tree.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// BUSH / ROCK
// ════════════════════════════════════════════════════════════════════════════

// bush_green — rounded green shrub (64×46).
(function bushGreen(){
  const W=64,H=46,cv=makeCanvas(W,H);const cx=W/2;const s=5050;
  const ramp={sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)};
  blob(cv,cx,H-18,30,20,ramp,s+1,{jitter:0.24,noise:0.24});
  blob(cv,cx-16,H-14,18,14,ramp,s+2,{jitter:0.26});
  blob(cv,cx+16,H-16,18,15,ramp,s+3,{jitter:0.26});
  blob(cv,cx-2,H-30,20,16,ramp,s+4,{jitter:0.22});
  // NE lit crown
  blob(cv,cx+12,H-28,12,10,{sh:rgb(G2),mid:rgb(G3),hi:rgb(G4)},s+5,{jitter:0.2,noise:0.18});
  // a few bright leaf specks
  const r=det(s+9);
  for(let i=0;i<8;i++){const px=14+Math.floor(r()*36),py=6+Math.floor(r()*24);if(cv.data[(py*W+px)*4+3]>16)setPx(cv,px,py,rgb(G4),220);}
  save(cv,'bush_green.png');
})();

// rock — grey-brown boulder with mossy top (84×70).
(function rock(){
  const W=84,H=70,cv=makeCanvas(W,H);const cx=W/2;const s=6060;
  const stone={sh:rgb(N0),mid:rgb(N1),hi:rgb(N2)};
  // faceted boulder mass
  blob(cv,cx,H-22,36,26,stone,s+1,{jitter:0.16,noise:0.2});
  blob(cv,cx-14,H-14,20,14,stone,s+2,{jitter:0.16});
  blob(cv,cx+16,H-16,18,13,stone,s+3,{jitter:0.16});
  // hard facet planes: a lit upper-right plane + a shadow lower-left plane
  for(let y=8;y<H-6;y++)for(let x=6;x<W-6;x++){
    if(cv.data[(y*W+x)*4+3]<16)continue;
    const nx=(x-cx)/36,ny=(y-(H-22))/26;
    const i=(y*W+x)*4; const cur=[cv.data[i],cv.data[i+1],cv.data[i+2]];
    if(nx-ny>0.55)setPx(cv,x,y,mix(cur,rgb(N2),0.28));
    else if(nx-ny<-0.75)setPx(cv,x,y,darker(cur,0.22));
  }
  // mossy top cap (NE-lit green on the crown)
  const moss={sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)};
  const r=det(s+40);
  for(let x=cx-30;x<cx+30;x++){
    const topY=H-40-Math.round(smoothCell(x,0,7,s+7)*8);
    for(let y=topY;y<topY+7;y++){
      if(cv.data[(y*W+x)*4+3]<16)continue;
      const mn=smoothCell(x,y,4,s+9);
      if(mn>0.5){const nx=(x-cx)/30;const c=nx>0?mix(moss.mid,moss.hi,clamp(nx,0,1)):moss.mid;setPx(cv,x,y,c);}
    }
  }
  // mossy speck highlights
  for(let i=0;i<10;i++){const px=cx-26+Math.floor(r()*52),py=H-42+Math.floor(r()*6);if(cv.data[(py*W+px)*4+3]>16)setPx(cv,px,py,rgb(G4),200);}
  save(cv,'rock.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// FLOWERS — 56×64. A slender stem rising to a blossom head; 3 colour families.
// ════════════════════════════════════════════════════════════════════════════
function flower(name,petalRamp,coreHex,seed){
  const W=56,H=64,cv=makeCanvas(W,H);const cx=W/2;const s=seed;
  const stem={sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)};
  // small leaf clump at the base
  blob(cv,cx,H-8,14,8,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+1,{jitter:0.22,noise:0.2});
  // stem (slight lean)
  for(let y=H-10;y>18;y--){const t=(H-10-y)/(H-28);const x=cx+Math.sin(t*1.4)*2;setPx(cv,x,y,mix(stem.mid,stem.sh,0.2));setPx(cv,x+1,y,mix(stem.mid,stem.hi,0.3));}
  // a leaf blade off the stem
  for(let k=0;k<8;k++){setPx(cv,cx-2-k,H-30-k*0.6,rgb(G2));setPx(cv,cx-2-k,H-29-k*0.6,rgb(G3));}
  // blossom head: a ring of petals around a bright core (NE-lit)
  const hx=cx+2,hy=18;
  const petals=6;
  for(let p=0;p<petals;p++){
    const ang=(p/petals)*Math.PI*2 - Math.PI/2;
    const pxc=hx+Math.cos(ang)*7, pyc=hy+Math.sin(ang)*6;
    // petal lightness by NE facing
    const lit=clamp(0.5+Math.cos(ang-(-Math.PI/4))*0.5,0,1);
    const pc=mix(petalRamp.sh,petalRamp.hi,lit);
    blob(cv,pxc,pyc,6,5,{sh:petalRamp.sh,mid:pc,hi:petalRamp.hi},s+10+p,{jitter:0.18,noise:0.16,outline:darker(petalRamp.sh,0.28)});
  }
  // bright core
  blob(cv,hx,hy,5,4,{sh:mix(coreHex,rgb(B1),0.3),mid:coreHex,hi:lighter(coreHex,0.35)},s+40,{jitter:0.1,noise:0.1});
  setPx(cv,hx+1,hy-1,lighter(coreHex,0.5),230);
  save(cv,name);
}
// flower.png — pink family (#d9b8ff/#c96a7a per task): warm-pink petals, violet-tinged, gold core.
flower('flower.png', {sh:rgb(PK0),mid:rgb(PK1),hi:lighter(rgb(PK1),0.2)}, rgb(N4), 7101);
// flower_violet.png — #9e7ad9 / #6b4a9e
flower('flower_violet.png', {sh:rgb(V1),mid:rgb(V2),hi:rgb(V3)}, rgb(N3), 7202);
// flower_pink.png — light pink
flower('flower_pink.png', {sh:rgb(PK0),mid:rgb(PK1),hi:lighter(rgb(PK1),0.35)}, rgb(N4), 7303);

// ════════════════════════════════════════════════════════════════════════════
// REST STUMP — cut tree stump with growth rings on the sawn top, mossy (108×96).
// ════════════════════════════════════════════════════════════════════════════
(function restStump(){
  const W=108,H=96,cv=makeCanvas(W,H);const cx=W/2;const s=8080;
  const contactGap=5;const baseY=H-1-contactGap;
  const bark={sh:rgb(B0),mid:rgb(B1),hi:rgb(B2)};
  // barrel body: a short wide iso cylinder (front wall + elliptical top)
  const topY=baseY-52, rx=30, ry=15, wallH=44;
  // side wall (3-tone by column)
  for(let x=-rx;x<=rx;x++){
    const xr=x/rx;if(xr*xr>1)continue;
    const edgeY=topY+ry*Math.sqrt(1-xr*xr);
    const face = xr>0.15?mix(bark.mid,bark.hi,clamp(xr,0,1)) : (xr<-0.4?bark.sh:bark.mid);
    for(let y=0;y<wallH;y++){
      const t=y/wallH;
      let c=mix(face,darker(face,0.30),t*0.5);
      const n=smoothCell(cx+x,edgeY+y,4,s+3);
      if(n<0.34)c=mix(c,bark.sh,0.3);        // vertical bark grooves
      setPx(cv,cx+x,edgeY+y,c);
    }
    setPx(cv,cx+x,edgeY+wallH,darker(bark.sh,0.25)); // bottom selout
  }
  for(let y=0;y<wallH;y++){setPx(cv,cx-rx,topY+y,darker(bark.sh,0.25));setPx(cv,cx+rx,topY+y,darker(bark.sh,0.25));}
  // sawn top ellipse with growth rings (lighter heartwood)
  const wood={sh:rgb(B1),mid:rgb(B3),hi:lighter(rgb(B3),0.25)};
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){
    const d=(x/rx)**2+(y/ry)**2;if(d>1)continue;
    const nx=x/rx,ny=y/ry;
    const lit=clamp(0.5+nx*0.4-ny*0.4,0,1);
    let c=mix(wood.sh,wood.hi,lit);
    // concentric growth rings
    const rr=Math.sqrt((x/rx)**2+(y/ry)**2);
    if((Math.round(rr*7))%2===0)c=mix(c,wood.sh,0.28);
    setPx(cv,cx+x,topY+y,c);
  }
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*rx,y=Math.sin(a*Math.PI/180)*ry;setPx(cv,cx+x,topY+y,darker(bark.sh,0.3));}
  // moss creeping over the left/lower rim and a patch on the top edge
  const moss={sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)};
  const r=det(s+50);
  for(let i=0;i<70;i++){
    const a=r()*Math.PI*2, rad=0.7+r()*0.35;
    const x=cx+Math.cos(a)*rx*rad, y=topY+Math.sin(a)*ry*rad;
    if(Math.sin(a)>-0.2){ // bias toward lower/side rim
      setPx(cv,x,y,r()<0.5?moss.mid:moss.hi,200);
      setPx(cv,x,y+1,moss.sh,180);
    }
  }
  // a small mushroom on the shadow side for charm
  setPx(cv,cx-rx+6,baseY-10,rgb(N3));setPx(cv,cx-rx+7,baseY-10,rgb(N2));
  for(let y=-3;y<=0;y++)for(let x=-3;x<=3;x++){if(x*x/9+y*y/2<=1)setPx(cv,cx-rx+6+x,baseY-13+y,x>0?rgb(PK1):rgb(PK0));}
  save(cv,'rest_stump.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// WORLD TREE — 490×470 ceremonial tree: big canopy + spreading ROOTS at the base.
// Purified/luminous version (base world_tree.png) + dormant dead version
// (world_tree_dormant.png) + separate additive violet glow (world_tree_glow.png, 512×512).
// All share the SAME bottom-center ground origin so world_tree.gd's offset/scale/glow-child
// line up. glow is 512×512 (larger canvas) but the trunk base still lands on the canvas
// bottom-center so it composites correctly under the same offset.
// ════════════════════════════════════════════════════════════════════════════
function worldTreeBody(dormant){
  const W=490,H=470,cv=makeCanvas(W,H);const cx=W/2;const s=9090;
  // colour ramps: purified = living green + violet-lit; dormant = desaturated 중성/갈색, no violet.
  const bark = dormant ? {sh:rgb(N0),mid:rgb(B0),hi:rgb(N1)} : {sh:rgb(B0),mid:rgb(B1),hi:rgb(B2)};
  const foliage = dormant
    ? {sh:rgb(N0),mid:darker(rgb(N1),0.1),hi:rgb(N1)}
    : {sh:rgb(G0),mid:rgb(G2),hi:rgb(G3)};
  // ── spreading roots at the base (visible, radiating from the trunk foot) ──
  const rootDefs=[
    [cx-30,H-40, cx-176,H-2, 12],
    [cx-12,H-30, cx-96,H-1, 10],
    [cx+30,H-40, cx+178,H-2, 12],
    [cx+14,H-30, cx+104,H-1, 10],
    [cx-2,H-24, cx-40,H-1, 8],
    [cx+4,H-24, cx+52,H-1, 8],
  ];
  for(let i=0;i<rootDefs.length;i++){const[bx,by,ex,ey,w]=rootDefs[i];root(cv,bx,by,ex,ey,w,bark,s+i);}
  // ── massive trunk ──
  trunk(cv,cx,H-30,H-300,68,40,-4,bark,s+20);
  // trunk bark ridges
  for(let y=H-300;y<H-30;y+=1){const n=smoothCell(cx,y,6,s+21);if(n<0.28){for(let x=cx-24;x<cx+24;x++)if(cv.data[(y*W+x)*4+3]>16&&smoothCell(x,y,3,s+22)<0.4)setPx(cv,x,y,darker(bark.sh,0.2));}}
  // ── big ceremonial canopy: one huge crown + orbiting clumps ──
  const cyTop=170;
  blob(cv,cx,cyTop,208,176,foliage,s+30,{jitter:0.18,noise:0.22});
  const clumps=[
    [cx-150,240,86,74],[cx+156,232,84,72],
    [cx-90,86,96,84],[cx+96,96,92,80],
    [cx,40,110,90],[cx-180,140,60,54],[cx+186,150,58,52],
  ];
  for(let i=0;i<clumps.length;i++){const[bx,by,rx,ry]=clumps[i];blob(cv,bx,by,rx,ry,foliage,s+40+i,{jitter:0.2,noise:0.2});}
  // NE rim-lit foliage highlights on the upper-right (purified only picks the brightest green)
  const litRamp = dormant ? {sh:rgb(N1),mid:rgb(N2),hi:rgb(N2)} : {sh:rgb(G2),mid:rgb(G3),hi:rgb(G4)};
  const litClumps=[[cx+120,70,52,44],[cx+70,30,44,38],[cx+170,140,36,30],[cx+40,110,40,34]];
  for(let i=0;i<litClumps.length;i++){const[bx,by,rx,ry]=litClumps[i];blob(cv,bx,by,rx,ry,litRamp,s+60+i,{jitter:0.18,noise:0.16});}
  if(!dormant){
    // purified: violet mystic accent blossoms glinting in the canopy edges + on the roots
    const r=det(s+80);
    for(let i=0;i<90;i++){
      const a=r()*Math.PI*2, rad=0.6+r()*0.5;
      const bx=cx+Math.cos(a)*208*rad, by=cyTop+Math.sin(a)*176*rad;
      if(bx<4||bx>W-4||by<4||by>H-4)continue;
      if(cv.data[((by|0)*W+(bx|0))*4+3]>16){setPx(cv,bx,by,r()<0.5?rgb(V2):rgb(V3),220);setPx(cv,bx,by-1,rgb(V3),160);}
    }
    // faint violet uplight where roots meet ground (glimmer at the base)
    for(let i=0;i<rootDefs.length;i++){const[,,ex,ey]=rootDefs[i];setPx(cv,ex+ (ex<cx?4:-4),ey-2,rgb(V3),160);}
  } else {
    // dormant: a few bare cracked branches poking through the thin dead canopy
    for(let i=0;i<5;i++){const bx=cx-120+i*60, by=120;for(let k=0;k<40;k++){const x=bx+Math.sin(i)*k*0.4, y=by-k;setPx(cv,x,y,rgb(B0));setPx(cv,x+1,y,rgb(N0));}}
  }
  save(cv, dormant?'world_tree_dormant.png':'world_tree.png');
}
worldTreeBody(false);   // purified / luminous
worldTreeBody(true);    // dormant / dead (pre-purification)

// world_tree_glow.png — 512×512 soft additive violet bloom on transparent bg, aligned to the
// SAME bottom-center ground origin as world_tree.png so the GlowSprite child (same offset/scale)
// registers over the canopy + roots. Blooms concentrated on canopy edges and the spreading roots.
(function worldTreeGlow(){
  const W=512,H=512,cv=makeCanvas(W,H);const cx=W/2;const s=9191;
  // The body's bottom-center sits at the canvas bottom-center. world_tree.png is 490×470 and its
  // trunk base is at its own bottom-center; here we align the base to (cx, H-1) and offset the
  // body-space coordinates by the same delta so glow lands on canopy/roots.
  const bodyH=470, bodyW=490;
  const ox=cx-bodyW/2, oy=(H-1)-(bodyH-1); // map body(x,y) → glow canvas (x+ox, y+oy)
  function bloom(bx,by,r,col,peak){
    const gx=bx+ox, gy=by+oy;
    for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1)setPx(cv,gx+x,gy+y,col,Math.round((1-d)*(1-d)*peak));}
  }
  // canopy-edge glow (ring of violet blooms around the crown)
  const r=det(s+1);
  const cyTop=170, crx=208, cry=176;
  for(let i=0;i<46;i++){
    const a=(i/46)*Math.PI*2;
    const bx=490/2+Math.cos(a)*crx*0.92, by=cyTop+Math.sin(a)*cry*0.92;
    bloom(bx,by,64,rgb(V2),70);
    bloom(bx,by,34,rgb(V3),90);
  }
  // soft overall canopy halo
  bloom(490/2,cyTop,240,rgb(V1),40);
  bloom(490/2,cyTop-20,150,rgb(V2),46);
  // root glow at the base spread
  const rootTips=[[490/2-176,468],[490/2-96,469],[490/2+178,468],[490/2+104,469],[490/2,469]];
  for(const [bx,by] of rootTips){bloom(bx,by,90,rgb(V2),60);bloom(bx,by,48,rgb(V3),80);}
  // trunk seam uplight
  bloom(490/2,470-160,70,rgb(V2),50);
  save(cv,'world_tree_glow.png');
})();

console.log('L1 organic objects done.');
