'use strict';
// L1A-1 (cliffs) — 시작의 숲 rock CLIFF FACES / RIDGE WALLS / SKIRTS / EDGE overlays.
// Procedural natural-stone cross-sections in the L1 nature palette (mossy green-topped
// grey-brown rock). REPLACES the CC0 realistic photo cliffs whose black backgrounds left
// "검은 구멍" holes and let the violet backdrop bleed through the top edge.
// Geometry mirrors ridge_rock/cliff_face (128×230) + skirts (128×112) so the map_loader
// drops them into the same slots with no code change. Fully OPAQUE stone on a transparent
// background → no black void, no backdrop bleed. NE-lit, selout rims. Deterministic.
// Palette = art-guide §3 Layer-1: this is the "L5 상아 에이프런 문법의 자연 버전" — a natural
// mossy-stone apron rather than L5's ivory.
// Produces into assets/tiles/. Run: node tools_gen_l1_cliffs.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');
fs.mkdirSync(OUT, { recursive: true });

function crc32(buf){let c=~0;for(let i=0;i<buf.length;i++){c^=buf[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(type,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const t=Buffer.from(type,'ascii');const body=Buffer.concat([t,data]);const crc=Buffer.alloc(4);crc.writeUInt32BE(crc32(body),0);return Buffer.concat([len,body,crc]);}
function encodePNG(w,h,pixels){const sig=Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;ihdr[10]=0;ihdr[11]=0;ihdr[12]=0;const stride=w*4;const raw=Buffer.alloc((stride+1)*h);for(let y=0;y<h;y++){raw[y*(stride+1)]=0;pixels.copy(raw,y*(stride+1)+1,y*stride,y*stride+stride);}const idat=zlib.deflateSync(raw,{level:9});return Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]);}
function makeCanvas(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hexToRGB(hex){const s=hex.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function setPx(cv,x,y,rgb,a=255){if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;}
function blendPx(cv,x,y,rgb,a){if(a>=255)return setPx(cv,x,y,rgb,255);if(a<=0)return;if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;const af=a/255,ia=1-af;if(cv.data[i+3]===0){setPx(cv,x,y,rgb,a);return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function save(cv,name){const png=encodePNG(cv.w,cv.h,cv.data);fs.writeFileSync(path.join(OUT,name),png);console.log('wrote',name,cv.w+'x'+cv.h,png.length,'bytes');}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function clamp(v,lo,hi){return v<lo?lo:(v>hi?hi:v);}
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}

// palette (art-guide §3 Layer-1)
const G0='#1b3a2a',G1='#2e5d3b',G2='#4d8b4f',G3='#7ab567';
const B0='#3a2a20',B1='#5c4433',B2='#8a6a4a',B3='#b59268';
const N0='#2a2a33',N1='#6e6e7a',N2='#b8b4a8';
const W2='#4aa3b8';  // 파랑 (water edge bleed)
// rock body ramp (grey-brown natural stone)
const R_SH='#33302c', R_MID='#5a544c', R_HI='#847c70', R_DK='#26241f';

// ── ROCK CLIFF FACE (128×230): natural mossy stone cross-section, fully opaque, NO black bg.
//    Grass-topped rim, chunky faceted stone strata, moss patches on the lit ledges, NE-lit.
function makeCliff(name, salt) {
  const W=128,H=230,cv=makeCanvas(W,H);
  const sh=hexToRGB(R_SH),mid=hexToRGB(R_MID),hi=hexToRGB(R_HI),dk=hexToRGB(R_DK);
  const grassTop=hexToRGB(G2),grassLo=hexToRGB(G1),moss=hexToRGB(G1),mossHi=hexToRGB(G3);
  const capH=26;   // grass cap band on the top rim
  for(let y=0;y<H;y++){
    // organic left/right rock silhouette: gentle barrel + jagged edge noise (opaque within)
    const t=y/H;
    const barrel=Math.round(4*Math.sin(t*Math.PI));
    const jagL=Math.round((smoothCell(0,y,9,salt)-0.5)*10);
    const jagR=Math.round((smoothCell(99,y,9,salt+3)-0.5)*10);
    const x0=Math.max(0,barrel+jagL), x1=Math.min(W,W-barrel+jagR);
    for(let x=x0;x<x1;x++){
      const isLeft=x<W/2;
      let c;
      if(y<capH){
        // grass cap: lit green rim rounding over the top
        const gt=y/capH;
        c=mix(grassTop,grassLo,gt*0.6);
        if(y<3)c=mix(c,hexToRGB(G3),0.4);
      } else {
        // faceted stone strata: quantized horizontal bands + facet noise
        const yy=y-capH;
        const strat=Math.floor(yy/26);
        const bandBase=(strat%2===0)?mid:sh;
        const vshade=1-0.20*t;               // darken downward
        c=[Math.round(bandBase[0]*vshade),Math.round(bandBase[1]*vshade),Math.round(bandBase[2]*vshade)];
        // ledge highlight at the top of each strata (a lit shelf)
        if(yy%26<3)c=mix(c,hi,0.32);
        const n=smoothCell(x,y,7,salt+11);
        if(n>0.70)c=mix(c,hi,0.20);
        else if(n<0.30)c=mix(c,dk,0.34);
        // moss creeping down from the cap onto lit ledges (upper third, right/lit side)
        const mn=smoothCell(x,y,5,salt+21);
        if(y<capH+70 && mn>0.72 && !isLeft) c=mix(c,mossHi,0.30);
        else if(y<capH+95 && mn>0.80) c=mix(c,moss,0.35);
      }
      // side lighting: NE — left face shaded, right face lit
      c = isLeft ? mix(c,dk,0.26) : mix(c,hi,0.10);
      setPx(cv,x,y,c,255);
    }
    // selout rim on the silhouette edges (2 steps darker than mid, not pure black)
    if(x1>x0){setPx(cv,x0,y,hexToRGB(R_DK));setPx(cv,x1-1,y,hexToRGB(R_DK));}
  }
  // a couple of vertical crack seams for chunkiness
  const nCracks=3;
  for(let k=0;k<nCracks;k++){
    let cx=24+Math.floor(smoothCell(k*40,0,3,salt+55)*(W-48));
    for(let y=capH+6;y<H-8;y++){cx+=Math.round((smoothCell(cx,y,4,salt+77)-0.5)*1.6);blendPx(cv,cx,y,hexToRGB(R_DK),150);blendPx(cv,cx+1,y,hexToRGB(R_HI),60);}
  }
  save(cv,name);
}
makeCliff('cliff_face_a.png', 0x0A1);
makeCliff('cliff_face_b.png', 0x0B2);
makeCliff('cliff_face_c.png', 0x0C3);
makeCliff('cliff_face_d.png', 0x0D4);
// ridge walls (interior impassable rock bands) — same grammar, slightly different seeds so the
// wall band breaks up. 128×230 to match the loader's base-anchoring.
makeCliff('ridge_rock.png', 0x1E5);
makeCliff('ridge_rock_b.png', 0x2F6);

// ── CLIFF SKIRT (128×112): a shorter apron hung on the diamond's lower rim (the diorama
//    slab edge). Top row = the diamond's lower rim; opaque stone tapering down. Variants s/e/se
//    differ only by which screen face is emphasised (lighting), matching the old geometry.
function makeSkirt(name, lit) {
  const W=128,H=112,cv=makeCanvas(W,H);
  const sh=hexToRGB(R_SH),mid=hexToRGB(R_MID),hi=hexToRGB(R_HI),dk=hexToRGB(R_DK);
  const HALF=32; // iso half-height; the apron top follows the two lower diamond edges
  for(let y=0;y<H;y++){
    for(let x=0;x<W;x++){
      // top boundary = lower silhouette of the diamond: |x-64|/64 maps to a rim depth
      const rimY = HALF - Math.abs(x-64)*HALF/64;   // 0..32 (the diamond's lower V)
      if(y < rimY) continue;                        // above the rim = transparent (the tile sits here)
      const t=(y-rimY)/(H-rimY);
      const isLeft = x<W/2;
      const strat=Math.floor((y-rimY)/22);
      const bandBase=(strat%2===0)?mid:sh;
      const vshade=1-0.24*t;
      let c=[Math.round(bandBase[0]*vshade),Math.round(bandBase[1]*vshade),Math.round(bandBase[2]*vshade)];
      if((y-rimY)%22<2)c=mix(c,hi,0.30);
      const n=smoothCell(x,y,6,0x5C1);
      if(n>0.72)c=mix(c,hi,0.18);else if(n<0.30)c=mix(c,dk,0.30);
      // face emphasis: 's' lights the left(SW) half, 'e' the right(SE) half, 'se' both fronts
      if(lit==='s')c=isLeft?mix(c,hi,0.08):mix(c,dk,0.18);
      else if(lit==='e')c=isLeft?mix(c,dk,0.18):mix(c,hi,0.08);
      else c=mix(c,hi,0.04);
      // fade the very bottom into shadow so it reads as depth, and taper alpha at the point
      let a=255;
      if(t>0.8)a=Math.round(255*(1-(t-0.8)/0.2*0.35));
      setPx(cv,x,y,c,a);
      if(y===Math.ceil(rimY)) setPx(cv,x,y,mix(c,hexToRGB(G1),0.4),a); // mossy rim line where grass meets rock
    }
  }
  save(cv,name);
}
makeSkirt('cliff_skirt_s.png','s');
makeSkirt('cliff_skirt_e.png','e');
makeSkirt('cliff_skirt_se.png','se');

// ── EDGE OVERLAYS (128×64): thin material-bleed crescents where grass borders dirt/water/mud.
//    Drawn on the grass cell, one per bordering diamond edge (br/bl/tl/tr). Semi-transparent
//    so the base grass shows through; the neighbour material feathers a few px over the seam.
function edgeOverlay(name, matHex, dir) {
  const W=128,H=64,cv=makeCanvas(W,H);
  const cx=(W-1)/2,cy=(H-1)/2, col=hexToRGB(matHex);
  // dir picks which of the 4 diamond edges to feather along.
  // br: lower-right edge (+col), bl: lower-left (+row), tl: upper-left (-col), tr: upper-right (-row)
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const dx=(x-cx)/(W/2), dy=(y-cy)/(H/2);
    const d=Math.abs(dx)+Math.abs(dy);
    if(d>1.0)continue;
    // signed edge coordinate for the chosen quadrant
    let edgeDist;
    if(dir==='br') edgeDist = (dx>0&&dy>0)? (1-(dx+dy)) : 99;
    else if(dir==='bl') edgeDist = (dx<0&&dy>0)? (1-(-dx+dy)) : 99;
    else if(dir==='tl') edgeDist = (dx<0&&dy<0)? (1-(-dx-dy)) : 99;
    else edgeDist = (dx>0&&dy<0)? (1-(dx-dy)) : 99;  // tr
    if(edgeDist>0.34)continue;                 // only a thin band near that edge
    const feather=1-edgeDist/0.34;             // 1 at the very edge → 0 inward
    const wob=0.85+smoothCell(x,y,4,name.length*13)*0.3;
    const a=Math.round(clamp(feather*wob*150,0,150));
    blendPx(cv,x,y,col,a);
  }
  save(cv,name);
}
for(const [mat,hex] of [['dirt',B2],['water',W2],['mud',B1]]){
  for(const dir of ['br','bl','tl','tr']) edgeOverlay(`edge_${mat}_${dir}.png`, hex, dir);
}

console.log('L1 cliffs/skirts/edges done.');
