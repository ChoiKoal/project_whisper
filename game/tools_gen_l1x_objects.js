'use strict';
// EX-L1 — 확장 자연 구역 (고요의 화원 l1g + 생명의 심장 l1h) OBJECT art generator.
// Follows the tools_gen_l1_objects.js structure and reuses the shared iso grammar
// (tools_iso_lib.js: NE light 3-tone, ground-contact AO ellipse, iso box/cylinder,
// organic blob). Produces the NEW object PNGs the l1g/l1h map legends reference —
// gatherables, gate off/opened pairs, offering/placement targets, landmark
// silhouettes, remnant-NPC statues, tutorial clusters.
//
// Naming: every PNG is named after the legend `scene` basename (rare_flower.tscn →
// rare_flower.png) or `object_id` / landmark id, plus variant suffixes
// (_open / _lit / _bloom) for gate opened/lit states. cauldron.png already exists
// (reused, NOT regenerated).
//
// Anchoring invariant (art-guide §1): every silhouette is horizontally centred on the
// canvas and its ground-contact ellipse sits near the canvas bottom, so the loader
// plants them on the cell centre exactly like the L1 grove objects.
//
// Palettes (docs/project-whisper-expansion-l1-design-v1.md §A-1 / §A-4 / §C-3):
//   화원(garden) = 시작의 숲 초록 base 위 바랜 파스텔(잿빛 섞인 분홍·연보라). 정화 전
//     오브젝트는 채도 낮게(잿빛), 정화/개화/점등 variant는 채도 복귀(무지개·선명).
//   심장(heart) = 심부 어둠 + 뿌리 보라 발광 + 최심부 심장 코어의 따뜻한 발광.
// The runtime CanvasModulate tint (§C-3) does the zone-wide desaturation/darkening;
// these sprites carry the object-local read (form + the lit/opened deltas).
// Lighting NE 고정. selout outline = same-hue 2 steps darker, never pure black.
// Deterministic (fixed seeds → identical output). Pure Node.js, no deps.
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l1x_objects.js
const fs = require('fs');
const path = require('path');
const ISO = require('./tools_iso_lib.js');
const {
  C, hex, px, rect, mix, darker, lighter, deterministic,
  ao, glow, isoBox, isoCylinder, isoEllipseTop, topDiamond, diamondOutline, selout, saver,
} = ISO;

const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');
const save = saver(OUT);
const rgb = hex;

// value-noise mottle (idiom shared with tools_gen_l1_objects.js)
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}
function clamp(v,lo,hi){return v<lo?lo:(v>hi?hi:v);}

// Filled iso-lit organic blob (foliage/petal/moss/root mass). Same shading model as
// tools_gen_l1_objects.js blob(): NE light picks hi upper-right, sh lower-left.
function blob(cv,cx,cy,rx,ry,ramp,salt,opts){
  opts=opts||{};
  const {sh,mid,hi}=ramp;
  const jitter=opts.jitter||0;
  const noiseAmt=opts.noise==null?0.24:opts.noise;
  const outline=opts.outline||darker(sh,0.30);
  const alpha=opts.alpha==null?255:opts.alpha;
  const x0=Math.floor(cx-rx-2),x1=Math.ceil(cx+rx+2),y0=Math.floor(cy-ry-2),y1=Math.ceil(cy+ry+2);
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
    const nx=(x-cx)/rx, ny=(y-cy)/ry;
    let d=nx*nx+ny*ny;
    const wob=jitter?(smoothCell(x,y,Math.max(3,rx*0.4),salt+7)-0.5)*jitter:0;
    if(d>1.0+wob)continue;
    const lightT=clamp(0.5-(nx*0.5)-(ny*0.55),0,1);
    let c;
    if(lightT<0.34)c=mix(hi,mid,lightT/0.34);
    else if(lightT<0.7)c=mix(mid,sh,(lightT-0.34)/0.36);
    else c=mix(sh,darker(sh,0.28),(lightT-0.7)/0.30);
    const n=smoothCell(x,y,Math.max(3,rx*0.32),salt+31);
    if(n>0.70)c=mix(c,hi,noiseAmt*0.7);
    else if(n<0.30)c=mix(c,sh,noiseAmt);
    if(d>0.90){c=outline;}
    px(cv,x,y,c,alpha);
  }
}

// a root/vine that spreads from (bx,by) to (ex,ey), tapering, 3-tone bark, sagging.
function rootStroke(cv,bx,by,ex,ey,w0,ramp,salt){
  const {sh,mid,hi}=ramp;
  const steps=Math.round(Math.hypot(ex-bx,ey-by))+1;
  for(let i=0;i<=steps;i++){
    const t=i/steps;
    const x=bx+(ex-bx)*t;
    const y=by+(ey-by)*t + Math.sin(t*Math.PI)*3;
    const w=Math.max(1,w0*(1-t*0.8));
    for(let k=-w;k<=w;k++){
      const nx=k/w;
      let c = nx>0.2?mix(mid,hi,clamp(nx,0,1)) : (nx<-0.4?sh:mid);
      const n=smoothCell(x+k,y,4,salt+3);if(n<0.3)c=mix(c,sh,0.35);
      px(cv,x+k,y,c);
    }
    px(cv,x-w,y,darker(sh,0.28));px(cv,x+w,y,darker(sh,0.28));
  }
}

// ── palettes ─────────────────────────────────────────────────────────────────
// L1 nature ramp (shared, art-guide §3) for the green base + bark + violet mystic.
const G0='#1b3a2a', G1='#2e5d3b', G2='#4d8b4f', G3='#7ab567', G4='#a8d982';
const B0='#3a2a20', B1='#5c4433', B2='#8a6a4a', B3='#b59268';
const V0='#3a2a5c', V1='#6b4a9e', V2='#9e7ad9', V3='#d9b8ff';
const N0='#2a2a33', N1='#6e6e7a', N2='#b8b4a8', N3='#e8dfc8', N4='#faf5e6';
const PK0='#c96a7a', PK1='#f0a8b8';
const BARK={sh:rgb(B0),mid:rgb(B1),hi:rgb(B2)};
const BARK_LT={sh:rgb(B1),mid:rgb(B2),hi:rgb(B3)};

// 화원 바랜 파스텔: 잿빛 섞인 분홍/연보라/연노랑/연파랑 (faded) + 정화 후 선명 삼원색.
// Faded family = the L1 pastel accents desaturated toward the 중성 회 ramp; vivid family =
// the primary red/yellow/blue that returns after purification (색맞춤 화단 / 무지개).
const FADE_PINK  ={sh:mix(rgb(PK0),rgb(N1),0.5),mid:mix(rgb(PK1),rgb(N2),0.45),hi:mix(rgb(N3),rgb(PK1),0.35)};
const FADE_LILAC ={sh:mix(rgb(V1),rgb(N1),0.45),mid:mix(rgb(V2),rgb(N2),0.45),hi:mix(rgb(N3),rgb(V3),0.3)};
const STONE_PALE ={sh:rgb(N1),mid:rgb(N2),hi:rgb(N3)};
const VIV_RED='#d95a52', VIV_YEL='#e8c84a', VIV_BLU='#4a86d9';

// 심장 심부: 뿌리 바크는 어두운 갈/보라 틴트, 심장 코어는 따뜻한 앰버/핑크.
const ROOTBARK ={sh:mix(rgb(B0),rgb(V0),0.4),mid:mix(rgb(B1),rgb(V0),0.25),hi:mix(rgb(B2),rgb(V1),0.2)};
const HEARTMOSS={sh:rgb(G0),mid:mix(rgb(G1),rgb(V1),0.25),hi:mix(rgb(G2),rgb(V2),0.2)};
const CORE_WARM='#f0a860', CORE_HOT='#ffd8a0', CORE_PINK='#f08a8a';
const RGLOW='#9e7ad9', RGLOW_HI='#d9b8ff';

// ════════════════════════════════════════════════════════════════════════════
// 화원 GATHERABLES — I10 rare_flower, I11 dew, I12 color_sand, I13 pollen
// ════════════════════════════════════════════════════════════════════════════

// rare_flower.png (f / I10) — 희귀 꽃. A faded pastel bloom on a slender stem; one petal
// still holds a hint of returning colour. 56×64 (matches L1 flower dims). Five gather-scatter
// variants O1A..O1E vary the accent-petal colour + petal count so the field reads varied.
function rareFlower(name,accentRamp,petals,seed){
  const W=56,H=64,cv=C(W,H),cx=W/2,s=seed;
  ao(cv,cx,H-3,14,4,54);
  blob(cv,cx,H-9,13,7,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+1,{jitter:0.22,noise:0.2});
  const stem={sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)};
  for(let y=H-11;y>20;y--){const t=(H-11-y)/(H-31);const x=cx+Math.sin(t*1.3)*2;px(cv,x,y,mix(stem.mid,stem.sh,0.2));px(cv,x+1,y,mix(stem.mid,stem.hi,0.3));}
  for(let k=0;k<8;k++){px(cv,cx-2-k,H-30-k*0.6,rgb(G2));px(cv,cx-2-k,H-29-k*0.6,rgb(G3));}
  const hx=cx+2,hy=20;
  for(let p=0;p<petals;p++){
    const ang=(p/petals)*Math.PI*2 - Math.PI/2;
    const pxc=hx+Math.cos(ang)*8, pyc=hy+Math.sin(ang)*7;
    const vivid = (p===1);  // the up-right petal keeps colour
    const ramp = vivid?accentRamp:FADE_LILAC;
    blob(cv,pxc,pyc,7,6,ramp,s+10+p,{jitter:0.16,noise:0.14,outline:darker(ramp.sh,0.26)});
  }
  blob(cv,hx,hy,5,4,{sh:mix(rgb(N4),rgb(B1),0.3),mid:rgb(N4),hi:lighter(rgb(N4),0.3)},s+40,{jitter:0.1,noise:0.1});
  px(cv,hx+1,hy-1,lighter(rgb(N4),0.5),230);
  save(cv,name);
}
const PINK_ACC={sh:rgb(PK0),mid:rgb(PK1),hi:lighter(rgb(PK1),0.25)};
rareFlower('rare_flower.png', PINK_ACC, 8, 71010);          // base (required)
rareFlower('rare_flower_O1A.png', PINK_ACC, 8, 71011);
rareFlower('rare_flower_O1B.png', {sh:rgb('#c9a04a'),mid:rgb('#e8c84a'),hi:rgb('#f8e488')}, 6, 71012);
rareFlower('rare_flower_O1C.png', {sh:rgb('#4a86d9'),mid:rgb('#7fb0f0'),hi:rgb('#b8d8ff')}, 7, 71013);
rareFlower('rare_flower_O1D.png', {sh:rgb(V1),mid:rgb(V2),hi:rgb(V3)}, 8, 71014);
rareFlower('rare_flower_O1E.png', {sh:rgb('#3a9a6a'),mid:rgb('#5ac98a'),hi:rgb('#9ae8b8')}, 5, 71015);

// dew.png (d / I11) — 꽃 이슬. A dewdrop cradled in a small leaf, faint highlight. 48×48.
(function dew(){
  const W=48,H=48,cv=C(W,H),cx=W/2,s=71020;
  ao(cv,cx,H-4,12,4,50);
  // cupped leaf
  blob(cv,cx,H-12,16,9,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+1,{jitter:0.2,noise:0.18});
  blob(cv,cx-8,H-10,8,5,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+2,{jitter:0.24});
  // droplet — translucent pale blue teardrop with NE specular
  const dcx=cx+2,dcy=H-20;
  for(let y=-11;y<=6;y++)for(let x=-8;x<=8;x++){
    const ny=y/(y<0?11:6), nx=x/8; const d=nx*nx+ny*ny;
    if(d<=1){const a=170-Math.round(d*70);const c=mix(rgb('#8fd4d9'),rgb('#d8f2f4'),clamp(0.5-nx*0.5-ny*0.4,0,1));px(cv,dcx+x,dcy+y,c,Math.max(70,a));}
  }
  // rim + specular glint
  for(let a=0;a<360;a+=8){const x=Math.cos(a*Math.PI/180)*8,y=Math.sin(a*Math.PI/180)*(a<180?6:11);px(cv,dcx+x,dcy+y,rgb('#5aa8b0'),140);}
  px(cv,dcx+3,dcy-5,rgb('#ffffff'),230);px(cv,dcx+4,dcy-4,rgb('#e8f8fa'),180);
  save(cv,'dew.png');
})();

// color_sand.png (z / I12) — 색 모래. A small conical pile of pastel-speckled sand
// (벽화가 가루가 되어 흩어진 색 모래). 56×48.
(function colorSand(){
  const W=56,H=48,cv=C(W,H),cx=W/2,s=71030;
  ao(cv,cx,H-4,20,6,58);
  // sand mound — greyed base with drifting pastel grains
  const base={sh:mix(rgb(N1),rgb(B1),0.3),mid:rgb(N2),hi:rgb(N3)};
  blob(cv,cx,H-13,20,11,base,s+1,{jitter:0.12,noise:0.22});
  blob(cv,cx-9,H-9,10,6,base,s+2,{jitter:0.14});
  blob(cv,cx+10,H-10,9,6,base,s+3,{jitter:0.14});
  // coloured grains scattered on the lit upper-right face (faded rainbow дуст)
  const grains=[rgb('#c98a8a'),rgb('#c9c07a'),rgb('#8aa8c9'),FADE_LILAC.mid,rgb('#8ac99a')];
  const r=deterministic(s+9);
  for(let i=0;i<70;i++){
    const gx=cx-18+Math.floor(r()*36), gy=H-24+Math.floor(r()*18);
    if(cv.data[(gy*W+gx)*4+3]<16)continue;
    const g=grains[Math.floor(r()*grains.length)];
    px(cv,gx,gy,mix(g,rgb(N3),0.35),r()<0.5?200:140);
  }
  save(cv,'color_sand.png');
})();

// pollen.png (y / I13) — 꽃가루. A drift of glowing pale-gold pollen motes over a tiny
// seed-head tuft. 48×56.
(function pollen(){
  const W=48,H=56,cv=C(W,H),cx=W/2,s=71040;
  ao(cv,cx,H-4,12,4,48);
  // stem + fuzzy seed head (dandelion-like)
  for(let y=H-6;y>26;y--)px(cv,cx,y,rgb(G2));
  for(let y=H-6;y>26;y--)px(cv,cx+1,y,rgb(G3));
  glow(cv,cx,20,18,rgb('#f0e0a0'),70);
  const puff={sh:mix(rgb(N3),rgb('#e8d888'),0.4),mid:rgb('#f0e6b8'),hi:rgb(N4)};
  blob(cv,cx,20,13,12,puff,s+1,{jitter:0.3,noise:0.3});
  // pollen motes drifting up-right
  const r=deterministic(s+9);
  for(let i=0;i<40;i++){
    const t=i/40, mx=cx+Math.round(Math.sin(t*7+r())*12)+Math.floor(t*10), my=24-Math.floor(t*20);
    px(cv,mx,my,r()<0.5?rgb('#f8ecb0'):rgb(N4),Math.round(200*(1-t*0.7)));
  }
  save(cv,'pollen.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// 화원 GATES / OFFERING / PLACEMENT
// ════════════════════════════════════════════════════════════════════════════

// wilted_arch.png (A / GA2 use-target) + wilted_arch_bloom.png (개화 개방 variant).
// 시든 아치 병목: a ruined flower arch, grey & bare when wilted; the bloom variant bursts
// back into vivid blossoms. 128×160 (2-wide bottleneck landmark).
function wiltedArch(name,bloomed){
  const W=128,H=160,cv=C(W,H),cx=W/2,s=71100;
  ao(cv,cx,H-10,40,11,64);
  // two stone/vine posts + a spanning arch (broken on the left = 반쯤 무너진)
  const post={sh:mix(rgb(N0),rgb(B0),0.5),mid:rgb(N1),hi:rgb(N2)};
  rect(cv,24,44,40,H-14,mix(post.mid,post.sh,0.3));rect(cv,24,44,32,H-14,post.mid);rect(cv,32,44,40,H-14,mix(post.mid,post.hi,0.3));
  rect(cv,88,30,104,H-14,mix(post.mid,post.sh,0.3));rect(cv,88,30,96,H-14,post.mid);rect(cv,96,30,104,H-14,mix(post.mid,post.hi,0.3));
  // left post is cracked short (반쯤 무너진): chip the top
  rect(cv,24,44,40,60,0,0); // clear — actually redraw a jagged broken top below
  for(let x=24;x<40;x++){const top=52+Math.round(smoothCell(x,0,5,s+2)*10);for(let y=top;y<H-14;y++){const c= x<32?post.mid:mix(post.mid,post.hi,0.3);px(cv,x,y,c);}px(cv,x,top,darker(post.sh,0.2));}
  // arch span (curved) from right post over to the broken left
  for(let t=0;t<=60;t++){const u=t/60;const ax=96-Math.round(u*(96-32)); const ay=30 - Math.round(Math.sin(u*Math.PI)*22) + Math.round(u*u*14);const w=6;for(let k=-w;k<=w;k++){const c=k<0?post.sh:mix(post.mid,post.hi,0.3);px(cv,ax,ay+k,c);}}
  // selout post edges
  for(let y=44;y<H-14;y++){px(cv,24,y,darker(post.sh,0.3));px(cv,40,y,darker(post.sh,0.3));}
  for(let y=30;y<H-14;y++){px(cv,88,y,darker(post.sh,0.3));px(cv,104,y,darker(post.sh,0.3));}
  // vines climbing the posts
  const vine=bloomed?{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)}:{sh:mix(rgb(G1),rgb(N1),0.5),mid:mix(rgb(G2),rgb(N2),0.5),hi:mix(rgb(G3),rgb(N2),0.4)};
  for(let y=H-16;y>40;y-=3){const wob=Math.sin(y*0.2)*3;px(cv,96+wob,y,vine.mid);px(cv,96+wob+1,y,vine.hi);}
  for(let t=0;t<=50;t++){const u=t/50;const ax=96-Math.round(u*(96-34));const ay=32-Math.round(Math.sin(u*Math.PI)*20)+Math.round(u*u*12)+Math.round(Math.sin(t*0.9)*3);px(cv,ax,ay-8,vine.mid);px(cv,ax,ay-7,vine.hi);}
  if(bloomed){
    // 개화: vivid blossoms burst along the arch + colour returns
    glow(cv,cx,40,50,rgb('#ffe0c8'),40);
    const r=deterministic(s+30);
    const cols=[{sh:rgb(PK0),mid:rgb(PK1),hi:lighter(rgb(PK1),0.3)},{sh:rgb(V1),mid:rgb(V2),hi:rgb(V3)},{sh:rgb('#c9a04a'),mid:rgb('#e8c84a'),hi:rgb('#f8e488')},{sh:rgb('#4a86d9'),mid:rgb('#7fb0f0'),hi:rgb('#b8d8ff')}];
    for(let i=0;i<26;i++){
      const u=i/26;const ax=34+Math.round(u*(96-34)); const ay=32-Math.round(Math.sin(u*Math.PI)*20)+Math.round((1-u)*(1-u)*12);
      const bx=ax+Math.round((r()-0.5)*10), by=ay-6+Math.round((r()-0.5)*10);
      const cc=cols[Math.floor(r()*cols.length)];
      blob(cv,bx,by,5,4,cc,s+40+i,{jitter:0.2,noise:0.14,outline:darker(cc.sh,0.24)});
      px(cv,bx,by,rgb(N4),200);
    }
  } else {
    // 시든: a few grey dead buds hanging
    const r=deterministic(s+50);
    for(let i=0;i<10;i++){const u=i/10;const ax=34+Math.round(u*(96-34));const ay=32-Math.round(Math.sin(u*Math.PI)*18)+8;px(cv,ax,ay,rgb(N1),200);px(cv,ax,ay+1,rgb(N0),180);}
  }
  save(cv,name);
}
wiltedArch('wilted_arch.png',false);
wiltedArch('wilted_arch_open.png',true);   // bloomed/open variant (lead-confirmed name)

// color_bed.png (x / GA3 empty placement slot) + color_bed_{red,yellow,blue}.png (filled
// variants). A small square planter; empty it is grey soil, and once its matching colour
// paint is placed it blooms in that vivid colour. 64×64.
function colorBed(name,vivHex){
  const W=64,H=64,cv=C(W,H),cx=W/2,s=71200+(vivHex?vivHex.length:0);
  ao(cv,cx,H-6,22,7,60);
  // iso planter box (stone rim, dark soil top)
  const rx=20,h=16,ry=rx/2,topY=H-8-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(rgb(N2),rgb(N3),0.3),rgb(N2),rgb(N1));
  // soil surface (dark diamond inset)
  for(let y=-ry+2;y<=ry-2;y++)for(let x=-rx+4;x<=rx-4;x++){const d=Math.abs(x)/(rx-4)+Math.abs(y)/(ry-2);if(d<=1)px(cv,cx+x,topY+y,mix(rgb(B0),rgb(N0),0.4),255);}
  if(!vivHex){
    // empty slot — a faint dashed "place here" ring + a bare grey sprout stub
    for(let a=0;a<360;a+=30){const x=cx+Math.cos(a*Math.PI/180)*9,y=topY+Math.sin(a*Math.PI/180)*4;px(cv,x,y,rgb(N2),150);}
    px(cv,cx,topY-2,rgb(N1),200);px(cv,cx,topY-4,rgb(N2),180);
    save(cv,name);return;
  }
  // vivid bloom filling the bed (the "solved" colour)
  const v=rgb(vivHex);
  const ramp={sh:darker(v,0.3),mid:v,hi:lighter(v,0.35)};
  glow(cv,cx,topY-4,20,lighter(v,0.2),50);
  const petalC=[[0,-6],[-6,-2],[6,-2],[-4,4],[4,4]];
  for(let i=0;i<petalC.length;i++){const [dx,dy]=petalC[i];blob(cv,cx+dx,topY-4+dy,6,5,ramp,s+i+1,{jitter:0.16,noise:0.14,outline:darker(ramp.sh,0.25)});}
  blob(cv,cx,topY-4,4,3,{sh:rgb(N3),mid:rgb(N4),hi:lighter(rgb(N4),0.3)},s+9,{jitter:0.1,noise:0.1});
  save(cv,name);
}
colorBed('color_bed.png',null);          // empty slot (lead-confirmed base name)
colorBed('color_bed_red.png',VIV_RED);
colorBed('color_bed_yellow.png',VIV_YEL);
colorBed('color_bed_blue.png',VIV_BLU);

// rainbow_font.png (H / GA4 무지개 분수 봉헌 target, object_id `rainbow_font`, DIM/unlit) +
// rainbow_font_lit.png (purified/lit). The 색의 봉헌 목 = a ruined stone fountain; dim it is
// grey & dry, lit it sprays a rainbow. 176×160 (2×3 landmark). (Lead-confirmed names.)
function colorFont(name,lit){
  const W=176,H=160,cv=C(W,H),cx=W/2,s=71300;
  ao(cv,cx,H-8,46,11,72);
  // 3-tier iso stone basin (faded pale stone)
  const st={base:mix(rgb(N2),rgb(N3),0.3)};
  isoCylinder(cv,cx,H-46,52,26,mix(rgb(N3),rgb(N4),0.2),rgb(N2),rgb(N1),0.96);
  isoCylinder(cv,cx,H-74,38,24,mix(rgb(N3),rgb(N4),0.2),rgb(N2),rgb(N1),0.96);
  isoCylinder(cv,cx,H-100,24,22,mix(rgb(N3),rgb(N4),0.2),rgb(N2),rgb(N1),0.96);
  isoCylinder(cv,cx,54,9,H-152,mix(rgb(N3),rgb(N4),0.15),rgb(N2),rgb(N1),1.0);
  const wcx=cx,wcy=H-58;
  if(lit){
    // rainbow spray + coloured pool + colour returning to the stone
    const bands=['#d95a52','#e8944a','#e8c84a','#5ac96a','#4a86d9','#8a6ad9'];
    glow(cv,cx,60,44,rgb('#ffffff'),60);
    // arcing rainbow jets from the top spout
    for(let b=0;b<bands.length;b++){
      const col=rgb(bands[b]);
      for(let t=0;t<=40;t++){const u=t/40;const dir=(b%2?1:-1);const jx=cx+dir*Math.round(u*40);const jy=58+Math.round(u*u*40)-Math.round(Math.sin(u*Math.PI)*30)+b*2;px(cv,jx,jy,col,Math.round(210*(1-u*0.4)));px(cv,jx,jy+1,darker(col,0.2),160);}
    }
    // coloured pool in the basin
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1){const band=bands[Math.abs(Math.round(x/12))%bands.length];px(cv,wcx+x,wcy+y,mix(rgb(band),rgb('#ffffff'),0.2),215);}}
    glow(cv,wcx,wcy,30,rgb('#f0c8e0'),80);
    // colour-return sparkles on the pillar
    const r=deterministic(s+11);for(let n=0;n<24;n++){const t=n/24;const mx=cx+Math.round(Math.sin(t*7+r())*16);const my=100-Math.floor(t*80);px(cv,mx,my,rgb(bands[Math.floor(r()*bands.length)]),Math.round(180*(1-t)));}
  } else {
    // dry cracked grey basin, white water-line stain
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1)px(cv,wcx+x,wcy+y,mix(rgb(N1),rgb(N2),0.4),210);}
    const r=deterministic(s+3);for(let n=0;n<12;n++){const mx=cx-28+Math.floor(r()*56),my=wcy-4+Math.floor(r()*8);for(let i=0;i<6;i++)px(cv,mx+i,my+Math.round(Math.sin(i)*2),rgb(N2),140);}
    for(let x=-30;x<30;x++)px(cv,cx+x,wcy-6,rgb(N3),120);
  }
  save(cv,name);
}
colorFont('rainbow_font.png',false);      // GA4 봉헌 target, dim (unlit base state)
colorFont('rainbow_font_lit.png',true);   // purified/lit ceremonial state

// ════════════════════════════════════════════════════════════════════════════
// 화원 NPC REMNANT + LANDMARKS
// ════════════════════════════════════════════════════════════════════════════

// npc_remnant.png (shared remnant scene) + gardener_statue.png (object_id, 화원 N) —
// 색을 잃은 정원사 석상: a petrified gardener, brush still in hand, greyed. 90×150.
function gardenerStatue(name){
  const W=90,H=150,cv=C(W,H),cx=W/2,s=71400;
  ao(cv,cx,H-6,24,8,60);
  const st={sh:rgb(N0),mid:rgb(N1),hi:rgb(N2)};
  // pedestal
  isoBox(cv,cx,H-24,22,14,mix(st.hi,st.mid,0.4),st.mid,st.sh);
  // body — a slightly hunched standing figure (working pose)
  // legs
  rect(cv,cx-11,H-72,cx-2,H-24,st.mid);rect(cv,cx+1,H-72,cx+10,H-24,mix(st.mid,st.hi,0.2));
  // torso leaning forward
  blob(cv,cx,H-92,17,24,st,s+1,{jitter:0.08,noise:0.12});
  // right arm reaching out with a brush (the halted gesture)
  for(let i=0;i<22;i++){px(cv,cx+8+i,H-96+Math.round(i*0.3),st.mid);px(cv,cx+8+i,H-95+Math.round(i*0.3),mix(st.mid,st.hi,0.3));}
  // brush tip (a dry grey bristle — no colour left)
  blob(cv,cx+30,H-90,4,5,{sh:rgb(N0),mid:rgb(N1),hi:rgb(N2)},s+2,{jitter:0.2});
  // head bowed
  blob(cv,cx-2,H-116,11,12,st,s+3,{jitter:0.06,noise:0.1});
  // stone cracks (석화)
  const r=deterministic(s+9);for(let i=0;i<14;i++){const bx=cx-14+Math.floor(r()*28),by=H-118+Math.floor(r()*80);for(let k=0;k<5;k++)px(cv,bx+k,by+Math.round(Math.sin(k)*2),darker(st.sh,0.2),150);}
  save(cv,name);
}
gardenerStatue('npc_remnant.png');       // generic remnant scene texture
gardenerStatue('gardener_statue.png');   // object_id used by legend objects.N

// gardener_statue_silhouette.png (landmark '2') — a distant silhouette of the statue
// against the temple, for the landmark marker. 96×140, flat dark violet-grey silhouette.
(function gardenerStatueSilhouette(){
  const W=96,H=140,cv=C(W,H),cx=W/2,s=71410;
  const sil=mix(rgb(N0),rgb(V0),0.4);
  // simplified statue silhouette (pedestal + hunched figure + outstretched arm)
  rect(cv,cx-16,H-16,cx+16,H-4,sil);
  rect(cv,cx-11,H-64,cx+11,H-16,sil);
  blob(cv,cx,H-84,16,22,{sh:sil,mid:sil,hi:sil},s+1,{jitter:0.06,noise:0});
  for(let i=0;i<24;i++)px(cv,cx+6+i,H-90+Math.round(i*0.3),sil);
  blob(cv,cx-2,H-108,10,11,{sh:sil,mid:sil,hi:sil},s+2,{jitter:0.05,noise:0});
  // faint back-light rim (colour beginning to return behind it)
  for(let y=H-120;y<H-4;y++){for(let x=0;x<W;x++){if(cv.data[(y*W+x)*4+3]>16){px(cv,x+1,y,mix(rgb(V2),rgb(N3),0.5),60);break;}}}
  save(cv,'gardener_statue_silhouette.png');
})();

// rainbow_fountain.png (landmark '1') — the distant rainbow-fountain landmark silhouette
// glimmer (goal marker). 120×120 soft rainbow bloom over a pale fountain shape.
(function rainbowFountain(){
  const W=120,H=120,cv=C(W,H),cx=W/2,s=71420;
  const bands=['#d95a52','#e8944a','#e8c84a','#5ac96a','#4a86d9','#8a6ad9'];
  // soft fountain body suggestion
  const st=mix(rgb(N2),rgb(N3),0.4);
  isoCylinder(cv,cx,H-40,26,18,rgb(N3),rgb(N2),rgb(N1),0.95);
  isoCylinder(cv,cx,H-58,16,14,rgb(N3),rgb(N2),rgb(N1),0.95);
  // rainbow arc bloom above
  glow(cv,cx,44,40,rgb('#ffffff'),50);
  for(let b=0;b<bands.length;b++){
    const col=rgb(bands[b]);const rad=42-b*4;
    for(let a=200;a<=340;a+=2){const x=cx+Math.cos(a*Math.PI/180)*rad,y=64+Math.sin(a*Math.PI/180)*rad*0.7;px(cv,x,y,col,180);px(cv,x,y+1,darker(col,0.15),140);}
  }
  save(cv,'rainbow_fountain.png');
})();

// tutorial_flower.png (landmark '4') — a small bright tutorial flower cluster that stayed
// colourful (the "이렇게 채집해" 예시). 72×64. Vivid so it stands out as the tutorial cue.
(function tutorialFlower(){
  const W=72,H=64,cv=C(W,H),cx=W/2,s=71430;
  ao(cv,cx,H-4,22,6,54);
  blob(cv,cx,H-10,18,9,{sh:rgb(G1),mid:rgb(G2),hi:rgb(G3)},s+1,{jitter:0.2,noise:0.2});
  glow(cv,cx,26,20,rgb('#fff0d0'),40);
  const cols=[{sh:rgb(PK0),mid:rgb(PK1),hi:lighter(rgb(PK1),0.3)},{sh:rgb('#c9a04a'),mid:rgb('#e8c84a'),hi:rgb('#f8e488')},{sh:rgb('#4a86d9'),mid:rgb('#7fb0f0'),hi:rgb('#b8d8ff')}];
  const heads=[[cx-12,30],[cx+12,28],[cx,20]];
  for(let i=0;i<heads.length;i++){
    const [hx,hy]=heads[i], cc=cols[i];
    for(let y=H-12;y>hy;y--){px(cv,hx,y,rgb(G2));px(cv,hx+1,y,rgb(G3));}
    for(let p=0;p<6;p++){const ang=(p/6)*Math.PI*2-Math.PI/2;const pxc=hx+Math.cos(ang)*6,pyc=hy+Math.sin(ang)*5;blob(cv,pxc,pyc,5,4,cc,s+10+i*7+p,{jitter:0.16,noise:0.14,outline:darker(cc.sh,0.24)});}
    blob(cv,hx,hy,3,3,{sh:rgb(N3),mid:rgb(N4),hi:lighter(rgb(N4),0.3)},s+50+i,{jitter:0.1,noise:0.1});
  }
  save(cv,'tutorial_flower.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// 생명의 심장 GATHERABLES — I15 root_sap, I16 tree_bud, I17 heart_moss
// ════════════════════════════════════════════════════════════════════════════

// root_sap.png (j / I15) — 뿌리 수액. A glob of glowing violet sap oozing from a cut root. 56×56.
(function rootSap(){
  const W=56,H=56,cv=C(W,H),cx=W/2,s=71500;
  ao(cv,cx,H-4,16,5,52);
  // a stub of cut root
  blob(cv,cx,H-14,16,10,ROOTBARK,s+1,{jitter:0.14,noise:0.22});
  // cut face (lighter heartwood ellipse)
  isoEllipseTop(cv,cx+2,H-20,9,mix(rgb(B3),rgb(V2),0.2),255,darker(ROOTBARK.sh,0.3));
  // sap glob welling out + dripping — violet, glowing
  glow(cv,cx+2,H-22,16,rgb(RGLOW),80);
  for(let y=-10;y<=8;y++)for(let x=-9;x<=9;x++){const ny=y/(y<0?10:8),nx=x/9;const d=nx*nx+ny*ny;if(d<=1){const c=mix(rgb(V1),rgb(RGLOW_HI),clamp(0.5-nx*0.5-ny*0.4,0,1));px(cv,cx+2+x,H-24+y,c,Math.max(160,220-Math.round(d*60)));}}
  // a drip below
  for(let i=0;i<8;i++)px(cv,cx+2,H-16+i,mix(rgb(V1),rgb(V2),i/8),200);
  px(cv,cx+5,H-27,rgb(RGLOW_HI),240);
  save(cv,'root_sap.png');
})();

// tree_bud.png (e / I16) — 세계수 씨눈. A luminous seed-bud on a short root stem,
// pale green-gold with a violet-lit tip (a nascent world-tree seed). 48×64.
(function treeBud(){
  const W=48,H=64,cv=C(W,H),cx=W/2,s=71510;
  ao(cv,cx,H-3,12,4,50);
  // short gnarled root stem
  rootStroke(cv,cx,H-8,cx,H-30,4,ROOTBARK,s+1);
  // bud — teardrop, pale life-green with a warm glow, violet halo
  glow(cv,cx,26,16,rgb(V2),50);
  const bud={sh:rgb(G1),mid:mix(rgb(G3),rgb('#e8e0a0'),0.4),hi:rgb('#f0f0c0')};
  for(let y=-14;y<=8;y++)for(let x=-9;x<=9;x++){const ny=y/(y<0?14:8),nx=x/9;const d=nx*nx+ny*ny;if(d<=1){const c=mix(bud.sh,bud.hi,clamp(0.5-nx*0.5-ny*0.5,0,1));px(cv,cx+x,26+y,c,255);}}
  // seam lines on the bud
  for(let y=-12;y<=6;y+=1){px(cv,cx-3,26+y,mix(rgb(G1),rgb(G2),0.5),120);px(cv,cx+3,26+y,mix(rgb(G2),rgb(G3),0.5),120);}
  // glowing tip
  px(cv,cx,26-14,rgb('#fff8d0'),240);glow(cv,cx,12,6,rgb('#fff0c0'),100);
  save(cv,'tree_bud.png');
})();

// heart_moss.png (q / I17) — 심장 이끼. A patch of luminescent moss, deep green tinged
// violet, glowing softly. 56×44.
(function heartMoss(){
  const W=56,H=44,cv=C(W,H),cx=W/2,s=71520;
  ao(cv,cx,H-4,20,6,50);
  glow(cv,cx,H-16,22,rgb(RGLOW),40);
  blob(cv,cx,H-14,20,11,HEARTMOSS,s+1,{jitter:0.24,noise:0.26});
  blob(cv,cx-10,H-10,10,6,HEARTMOSS,s+2,{jitter:0.26});
  blob(cv,cx+11,H-11,9,6,HEARTMOSS,s+3,{jitter:0.26});
  // glowing spore specks
  const r=deterministic(s+9);
  for(let i=0;i<18;i++){const gx=cx-16+Math.floor(r()*32),gy=H-22+Math.floor(r()*14);if(cv.data[(gy*W+gx)*4+3]>16)px(cv,gx,gy,r()<0.5?rgb(RGLOW_HI):rgb('#c8f0b8'),210);}
  save(cv,'heart_moss.png');
})();

// ════════════════════════════════════════════════════════════════════════════
// 생명의 심장 UNIQUE / SPRING / GATES / NPC / LANDMARKS
// ════════════════════════════════════════════════════════════════════════════

// world_tree_heart.png (O / I14 unique + GH2 봉헌 대상) — 세계수 심장(생명의 정수):
// a great pulsing heart-shaped core nested in a cradle of roots, warm+violet glow. 220×220.
(function worldTreeHeart(){
  const W=220,H=220,cv=C(W,H),cx=W/2,s=71600;
  ao(cv,cx,H-12,64,16,72);
  // root cradle spreading around the base
  const cradle=[
    [cx-30,H-40,cx-92,H-8,16],[cx+34,H-42,cx+96,H-8,17],
    [cx-14,H-30,cx-48,H-4,11],[cx+16,H-30,cx+52,H-4,11],
    [cx,H-24,cx,H-2,9],
  ];
  for(let i=0;i<cradle.length;i++){const[bx,by,ex,ey,w]=cradle[i];rootStroke(cv,bx,by,ex,ey,w,ROOTBARK,s+i);}
  // roots arcing UP around the heart (a protective nest)
  for(let i=0;i<6;i++){const ang=-Math.PI/2 + (i-2.5)*0.42;const bx=cx+Math.cos(ang)*20,by=100+Math.sin(ang)*8;const ex=cx+Math.cos(ang)*74,ey=96+Math.sin(ang)*70;rootStroke(cv,bx,by,ex,ey,10-i*0.6,ROOTBARK,s+20+i);}
  // the heart core — big warm-glowing heart shape
  const hcx=cx,hcy=96;
  glow(cv,hcx,hcy,84,rgb(CORE_WARM),70);
  glow(cv,hcx,hcy,54,rgb(CORE_PINK),80);
  function heartPix(px_,py,scale,col,a){
    // parametric heart fill: (x^2+y^2-1)^3 - x^2 y^3 <= 0
    for(let y=-scale;y<=scale;y++)for(let x=-scale;x<=scale;x++){
      const nx=x/scale, ny=-y/scale;
      const v=Math.pow(nx*nx+ny*ny-1,3)-nx*nx*ny*ny*ny;
      if(v<=0){const lit=clamp(0.5-nx*0.5-ny*0.4,0,1);const c=mix(darker(col,0.25),lighter(col,0.35),lit);px(cv,px_+x,py+y,c,a);}
    }
  }
  heartPix(hcx,hcy,58,rgb(CORE_PINK),255);
  heartPix(hcx,hcy-4,44,rgb(CORE_WARM),230);
  // inner bright pulse
  heartPix(hcx,hcy-8,26,rgb(CORE_HOT),240);
  px(cv,hcx,hcy-24,rgb('#fffef0'),255);glow(cv,hcx,hcy-6,20,rgb(CORE_HOT),110);
  // violet mystic motes rising from the heart
  const r=deterministic(s+40);
  for(let i=0;i<40;i++){const t=i/40;const mx=hcx+Math.round(Math.sin(t*7+r())*30);const my=hcy-30-Math.floor(t*60);px(cv,mx,my,r()<0.5?rgb(RGLOW_HI):rgb(CORE_HOT),Math.round(180*(1-t)));}
  save(cv,'world_tree_heart.png');
})();

// life_spring.png (E / heart_life_spring) — 생명의 샘물 (Vita 재획득처): a small root-well
// with clear luminous water welling up, green-gold life particles. 128×128.
(function lifeSpring(){
  const W=128,H=128,cv=C(W,H),cx=W/2,s=71610;
  ao(cv,cx,H-8,38,10,66);
  // root-rim well (twisted roots forming a basin)
  isoCylinder(cv,cx,H-40,42,22,mix(ROOTBARK.hi,rgb(B3),0.3),ROOTBARK.mid,ROOTBARK.sh,0.94);
  // gnarled root lip
  for(let a=0;a<360;a+=18){const x=cx+Math.cos(a*Math.PI/180)*40,y=(H-40)+Math.sin(a*Math.PI/180)*20;blob(cv,x,y,6,4,ROOTBARK,s+Math.round(a),{jitter:0.2,noise:0.2});}
  // luminous water pool
  const wcx=cx,wcy=H-46;
  glow(cv,wcx,wcy,34,rgb('#a8e0c8'),80);
  for(let y=-10;y<=8;y++)for(let x=-30;x<=30;x++){const d=(x/30)**2+(y/10)**2;if(d<=1){const c=mix(rgb('#8fd4c0'),rgb('#d8f4e4'),clamp(0.5-x/60-y/20,0,1));px(cv,wcx+x,wcy+y,c,215);}}
  // rising life particles (green-gold)
  const r=deterministic(s+9);
  for(let n=0;n<26;n++){const t=n/26;const mx=cx+Math.round(Math.sin(t*7+r())*16);const my=wcy-Math.floor(t*54);px(cv,mx,my,r()<0.5?rgb('#a8d0a0'):rgb('#e8f4d8'),Math.round(180*(1-t)));}
  // ripple rings
  for(let a=0;a<360;a+=8){const x=wcx+Math.cos(a*Math.PI/180)*20,y=wcy+Math.sin(a*Math.PI/180)*7;px(cv,x,y,rgb('#c8f0dc'),160);}
  save(cv,'life_spring.png');
})();

// root_gate.png (L / GH1 use-target) + root_gate_open.png (opened). 뒤엉킨 뿌리문:
// a dense tangle of interwoven roots blocking a passage; opened, the roots part with a
// violet-lit gap. 128×160 (2-wide bottleneck).
function rootGate(name,open){
  const W=128,H=160,cv=C(W,H),cx=W/2,s=71700;
  ao(cv,cx,H-10,42,11,64);
  // side root pillars
  rootStroke(cv,28,H-14,20,20,16,ROOTBARK,s+1);
  rootStroke(cv,100,H-14,108,20,16,ROOTBARK,s+2);
  if(open){
    // roots pulled aside — a violet-glowing gap in the middle
    glow(cv,cx,H/2,54,rgb(RGLOW),70);
    for(let y=24;y<H-14;y++){const t=(y-24)/(H-38);const gap=18+Math.round(Math.sin(t*Math.PI)*14);
      // parted roots curl toward the sides
      px(cv,cx-gap,y,ROOTBARK.mid);px(cv,cx-gap-1,y,ROOTBARK.hi);
      px(cv,cx+gap,y,ROOTBARK.mid);px(cv,cx+gap+1,y,ROOTBARK.hi);
    }
    // a few interwoven arcs now framing the top
    for(let t=0;t<=40;t++){const u=t/40;const ax=cx-40+Math.round(u*80);const ay=30-Math.round(Math.sin(u*Math.PI)*16);rootStroke(cv,ax,ay,ax,ay+4,3,ROOTBARK,s+30+t);}
    // violet motes in the opened passage
    const r=deterministic(s+40);for(let i=0;i<20;i++){const mx=cx-14+Math.floor(r()*28),my=40+Math.floor(r()*90);px(cv,mx,my,rgb(RGLOW_HI),180);}
  } else {
    // dense woven tangle filling the arch (blocking)
    const r=deterministic(s+50);
    for(let i=0;i<26;i++){
      const y0=24+Math.floor(r()*100);
      const bx=cx-44+Math.floor(r()*88);
      rootStroke(cv,bx,y0,bx+(r()<0.5?-1:1)*(30+Math.floor(r()*40)),y0+(r()-0.5)*40,4+Math.floor(r()*4),ROOTBARK,s+60+i);
    }
    // cross-weave the other diagonal for a knotted read
    for(let i=0;i<20;i++){const y0=30+Math.floor(r()*100);const bx=cx-40+Math.floor(r()*80);rootStroke(cv,bx,y0,bx+(r()<0.5?1:-1)*(24+Math.floor(r()*36)),y0-(r()-0.5)*36,3+Math.floor(r()*3),ROOTBARK,s+90+i);}
    // faint trapped glow leaking between the roots
    const r2=deterministic(s+120);for(let i=0;i<14;i++){const mx=cx-30+Math.floor(r2()*60),my=40+Math.floor(r2()*90);px(cv,mx,my,rgb(V1),120);}
  }
  save(cv,name);
}
rootGate('root_gate.png',false);
rootGate('root_gate_open.png',true);

// heart_seal.png (H / GH2 봉헌 목) + heart_seal_open.png (opened). 심장 봉인 목:
// a root-woven seal over a dormant heart glyph; opened, the seal splits and the heart
// glyph blazes warm. 96×112.
function heartSeal(name,open){
  const W=96,H=112,cv=C(W,H),cx=W/2,s=71800;
  ao(cv,cx,H-8,28,8,60);
  // stone mount
  const rx=22,h=26,ry=rx/2,topY=H-10-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(ROOTBARK.hi,rgb(N2),0.3),ROOTBARK.mid,ROOTBARK.sh);
  const gx=cx,gy=topY+2;
  if(open){
    // seal split — heart glyph blazing
    glow(cv,gx,gy,30,rgb(CORE_WARM),90);glow(cv,gx,gy,16,rgb(CORE_HOT),110);
    for(let y=-12;y<=12;y++)for(let x=-12;x<=12;x++){const nx=x/12,ny=-y/12;const v=Math.pow(nx*nx+ny*ny-1,3)-nx*nx*ny*ny*ny;if(v<=0)px(cv,gx+x,gy+y,mix(rgb(CORE_PINK),rgb(CORE_HOT),clamp(0.5-nx*0.4-ny*0.4,0,1)),255);}
    px(cv,gx,gy-4,rgb('#fffef0'),255);
    // parted seal roots to the sides
    rootStroke(cv,gx-14,gy-14,gx-30,gy+12,4,ROOTBARK,s+1);
    rootStroke(cv,gx+14,gy-14,gx+30,gy+12,4,ROOTBARK,s+2);
    // rising motes
    const r=deterministic(s+9);for(let i=0;i<18;i++){const t=i/18;const mx=gx+Math.round(Math.sin(t*7+r())*12);const my=gy-8-Math.floor(t*30);px(cv,mx,my,rgb(RGLOW_HI),Math.round(200*(1-t)));}
  } else {
    // dormant sealed heart glyph woven shut with roots
    for(let y=-12;y<=12;y++)for(let x=-12;x<=12;x++){const nx=x/12,ny=-y/12;const v=Math.pow(nx*nx+ny*ny-1,3)-nx*nx*ny*ny*ny;if(v<=0)px(cv,gx+x,gy+y,mix(rgb(V0),rgb(N0),0.4),255);}
    // faint trapped ember
    glow(cv,gx,gy,10,rgb(V1),60);px(cv,gx,gy-2,rgb(V1),140);
    // criss-crossing seal roots over the glyph
    rootStroke(cv,gx-16,gy-10,gx+16,gy+10,4,ROOTBARK,s+1);
    rootStroke(cv,gx+16,gy-10,gx-16,gy+10,4,ROOTBARK,s+2);
    rootStroke(cv,gx-4,gy-16,gx+4,gy+16,3,ROOTBARK,s+3);
  }
  save(cv,name);
}
heartSeal('heart_seal.png',false);
heartSeal('heart_seal_open.png',true);

// first_constructor_echo.png (N / 선배 컨스트럭터의 잔향) — a ghostly translucent figure
// of the first constructor, violet-lit, kneeling at the heart. 90×150.
(function firstConstructorEcho(){
  const W=90,H=150,cv=C(W,H),cx=W/2,s=71900;
  ao(cv,cx,H-8,22,7,44);
  glow(cv,cx,H-70,40,rgb(RGLOW),44);
  // translucent kneeling figure (violet ghost)
  const gh={sh:mix(rgb(V0),rgb(N0),0.3),mid:rgb(V1),hi:rgb(V2)};
  const A=150; // ghost alpha ceiling
  // kneeling: one leg folded (lower mass), torso upright, head bowed slightly
  blob(cv,cx,H-24,20,12,gh,s+1,{jitter:0.1,noise:0.12,alpha:A});          // folded lower body
  blob(cv,cx-2,H-58,15,22,gh,s+2,{jitter:0.1,noise:0.12,alpha:A});         // torso
  // an arm reaching toward the heart (up-right)
  for(let i=0;i<20;i++)px(cv,cx+6+i,H-70+Math.round(i*0.2),rgb(V2),A);
  blob(cv,cx-2,H-86,10,11,gh,s+3,{jitter:0.08,noise:0.1,alpha:A});         // head
  // dissolving wisp trails at the edges (잔향)
  const r=deterministic(s+9);
  for(let i=0;i<26;i++){const t=i/26;const mx=cx-14+Math.floor(r()*28),my=H-30-Math.floor(t*90);px(cv,mx,my,r()<0.5?rgb(V2):rgb(RGLOW_HI),Math.round(120*(1-t)));}
  // brighter core outline glints
  for(let y=H-98;y<H-14;y++){for(let x=0;x<W;x++){if(cv.data[(y*W+x)*4+3]>40){px(cv,x,y,rgb(RGLOW_HI),120);break;}}}
  save(cv,'first_constructor_echo.png');
})();

// tree_heart_core.png (landmark '1' tree_heart_core) — the pulsing core landmark glimmer
// (goal marker): a soft warm+violet pulse over a small heart. 120×120.
(function heartCore(){
  const W=120,H=120,cv=C(W,H),cx=W/2,cy=64,s=71910;
  glow(cv,cx,cy,52,rgb(RGLOW),50);
  glow(cv,cx,cy,40,rgb(CORE_WARM),70);
  glow(cv,cx,cy,22,rgb(CORE_HOT),90);
  for(let y=-24;y<=24;y++)for(let x=-24;x<=24;x++){const nx=x/24,ny=-y/24;const v=Math.pow(nx*nx+ny*ny-1,3)-nx*nx*ny*ny*ny;if(v<=0)px(cv,cx+x,cy+y,mix(rgb(CORE_PINK),rgb(CORE_HOT),clamp(0.5-nx*0.4-ny*0.4,0,1)),230);}
  px(cv,cx,cy-8,rgb('#fffef0'),255);
  // pulse rings
  for(const rr of [34,44,52]){for(let a=0;a<360;a+=6){const x=cx+Math.cos(a*Math.PI/180)*rr,y=cy+Math.sin(a*Math.PI/180)*rr;px(cv,x,y,rgb(CORE_WARM),Math.round(90*(1-(rr-34)/22)));}}
  save(cv,'tree_heart_core.png');
})();

// first_experiment_shard.png (landmark '3') — 첫 실험 흔적: a broken shard of an early
// constructor experiment — a cracked crystal-glyph tablet, cold violet, half-buried in
// roots (진상 조각). 72×80.
(function firstExperimentShard(){
  const W=72,H=80,cv=C(W,H),cx=W/2,s=71940;
  ao(cv,cx,H-6,22,7,56);
  // a couple of root tendrils half-burying it
  rootStroke(cv,cx-24,H-8,cx-6,H-26,6,ROOTBARK,s+1);
  rootStroke(cv,cx+24,H-8,cx+8,H-26,6,ROOTBARK,s+2);
  // the shard: a jagged crystalline tablet with faint etched glyphs, cold violet
  glow(cv,cx,H-40,20,rgb(V1),40);
  const shard={sh:rgb(V0),mid:mix(rgb(V1),rgb(N1),0.3),hi:mix(rgb(V2),rgb(N3),0.3)};
  const pts=[[cx-14,H-16],[cx-18,H-44],[cx-4,H-62],[cx+12,H-52],[cx+16,H-24],[cx+4,H-14]];
  // fill polygon (scanline) for the tablet
  let minY=H,maxY=0;for(const p of pts){minY=Math.min(minY,p[1]);maxY=Math.max(maxY,p[1]);}
  for(let y=minY;y<=maxY;y++){
    let xs=[];for(let i=0;i<pts.length;i++){const a=pts[i],b=pts[(i+1)%pts.length];if((a[1]<=y)!==(b[1]<=y)){xs.push(a[0]+(b[0]-a[0])*(y-a[1])/(b[1]-a[1]));}}
    xs.sort((p,q)=>p-q);
    for(let k=0;k+1<xs.length;k+=2)for(let x=Math.round(xs[k]);x<=Math.round(xs[k+1]);x++){const nx=(x-cx)/16,ny=(y-(H-38))/24;const lit=clamp(0.5-nx*0.4-ny*0.3,0,1);px(cv,x,y,mix(shard.sh,shard.hi,lit),255);}
  }
  // selout edges
  for(let i=0;i<pts.length;i++){const a=pts[i],b=pts[(i+1)%pts.length];const st=Math.round(Math.hypot(b[0]-a[0],b[1]-a[1]));for(let t=0;t<=st;t++){const u=t/st;px(cv,a[0]+(b[0]-a[0])*u,a[1]+(b[1]-a[1])*u,darker(shard.sh,0.3));}}
  // a crack running through + faint etched glyph rows
  for(let i=0;i<20;i++)px(cv,cx-6+Math.round(Math.sin(i*0.6)*4),H-52+i*1.6,darker(shard.sh,0.35),200);
  for(let ln=0;ln<3;ln++)for(let x=-8;x<=8;x+=2)px(cv,cx+x,H-46+ln*6,rgb(RGLOW),110);
  save(cv,'first_experiment_shard.png');
})();

// heart_silhouette.png (landmark '2') — distant silhouette of the great heart in its
// root cradle (landmark marker). 120×120 dark violet silhouette + faint core glow.
(function heartSilhouette(){
  const W=120,H=120,cv=C(W,H),cx=W/2,s=71920;
  const sil=mix(rgb(N0),rgb(V0),0.5);
  // root cradle arcs
  for(let i=0;i<5;i++){const ang=-Math.PI/2+(i-2)*0.5;const bx=cx+Math.cos(ang)*12,by=70+Math.sin(ang)*6;const ex=cx+Math.cos(ang)*46,ey=64+Math.sin(ang)*44;for(let t=0;t<=Math.hypot(ex-bx,ey-by);t++){const u=t/Math.hypot(ex-bx,ey-by);px(cv,bx+(ex-bx)*u,by+(ey-by)*u,sil);px(cv,bx+(ex-bx)*u+1,by+(ey-by)*u,sil);}}
  // heart silhouette
  for(let y=-26;y<=26;y++)for(let x=-26;x<=26;x++){const nx=x/26,ny=-y/26;const v=Math.pow(nx*nx+ny*ny-1,3)-nx*nx*ny*ny*ny;if(v<=0)px(cv,cx+x,64+y,sil,255);}
  // faint inner core glow leaking through
  glow(cv,cx,58,14,rgb(CORE_WARM),70);
  save(cv,'heart_silhouette.png');
})();

// tutorial_root.png (landmark '4') — a small highlighted root knot as the tutorial cue
// (이렇게 채집해 예시), glowing gently so it reads as the tutorial marker. 72×56.
(function tutorialRoot(){
  const W=72,H=56,cv=C(W,H),cx=W/2,s=71930;
  ao(cv,cx,H-4,22,6,50);
  glow(cv,cx,H-20,24,rgb(RGLOW),44);
  // a knotted root loop
  rootStroke(cv,cx-22,H-8,cx-2,H-30,7,ROOTBARK,s+1);
  rootStroke(cv,cx+22,H-8,cx+2,H-30,7,ROOTBARK,s+2);
  rootStroke(cv,cx-8,H-28,cx+8,H-28,6,ROOTBARK,s+3);
  // the knot bulge
  blob(cv,cx,H-26,12,8,ROOTBARK,s+4,{jitter:0.16,noise:0.2});
  // a couple glowing sap beads on it (the gather cue)
  px(cv,cx+4,H-30,rgb(RGLOW_HI),230);glow(cv,cx+4,H-30,5,rgb(RGLOW),90);
  px(cv,cx-6,H-24,rgb(RGLOW_HI),200);
  save(cv,'tutorial_root.png');
})();

console.log('EX-L1 (l1g 화원 + l1h 심장) objects done.');
