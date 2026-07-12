#!/usr/bin/env node
// tools_overview_l1_ex.js — Extended L1 overview: 3 zones side-by-side.
//   Zone 1: starting_grove (시작의 숲) — unchanged render logic from tools_overview_l1.js
//   Zone 2: l1g (고요의 화원 — Quiet Garden)
//   Zone 3: l1h (생명의 심장 — Life's Heart, cavern mood: violet/dark tint)
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l1_ex.js
//
// Outputs:
//   /workspace/group/preview-l1.png        — 3-zone composite (left→right)
//   /workspace/group/preview-l1-hero.png   — hero crop on l1h world_tree_heart (or l1g rainbow_font)

"use strict";
const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const OUT_FULL = "/workspace/group/preview-l1.png";
const OUT_HERO = "/workspace/group/preview-l1-hero.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;
const ZONE_GAP = 80; // px between zones in the composite

// ── helpers ─────────────────────────────────────────────────────────────────
function readLines(p) {
  try { return fs.readFileSync(p, "utf8").split("\n").filter(l => l.length > 0); }
  catch (e) { return []; }
}
function loadPng(p) {
  try { return PNG.sync.read(fs.readFileSync(p)); }
  catch (e) { return null; }
}
const tileArt  = n => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt   = n => loadPng(`${GAME}/assets/objects/${n}.png`);

// Shared tile art (same tileset for all L1 zones)
const TILE_BY_SRC = {
  0:  tileArt("t0_void"),
  1:  tileArt("t1_dirt"),
  2:  tileArt("t2a_grass"),
  3:  tileArt("t2b_grass_flowers"),
  4:  tileArt("t2c_grass_clover"),
  5:  tileArt("t2d_flower_grass"),
  7:  tileArt("t4_mud"),
  8:  tileArt("t5a_water"),
  9:  tileArt("t5b_water2"),
  10: tileArt("t5m_mystic"),
};
const MYSTIC_GLOW   = tileArt("t5m_mystic_glow");
const VIOLET_POOL   = objArt("light_pool_violet");
const VIOLET_POOL_LG= objArt("light_pool_violet_lg");
const WORLD_GLOW    = objArt("world_tree_glow");
const GOLD_POOL     = objArt("light_pool_gold");
const AMBER_POOL    = objArt("light_pool_amber");

// ── deterministic hashes (mirror map_loader.gd) ──────────────────────────
const MAP_SEED = 0x9E3779B9;
function cellHash(c, r, salt) {
  let h = (BigInt(c) * 73856093n) ^ (BigInt(r) * 19349663n) ^ (BigInt(salt) * 83492791n) ^ BigInt(MAP_SEED);
  h = (h ^ (h >> 13n)) * 1274126177n;
  h = h ^ (h >> 16n);
  return Number(h & 0x7fffffffn);
}
function valueNoise(c, r, cellSize, salt) {
  const gx = c / cellSize, gy = r / cellSize;
  const x0 = Math.floor(gx), y0 = Math.floor(gy);
  let fx = gx - x0, fy = gy - y0;
  fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
  const nh = (a, b) => (cellHash(a, b, salt) & 0xffff) / 65535;
  const n00 = nh(x0, y0), n10 = nh(x0+1, y0), n01 = nh(x0, y0+1), n11 = nh(x0+1, y0+1);
  return (n00*(1-fx)+n10*fx)*(1-fy) + (n01*(1-fx)+n11*fx)*fy;
}
function variantSource(c, r) {
  const n = valueNoise(c, r, 5, 11)*0.7 + valueNoise(c, r, 2, 29)*0.3;
  if (n < 0.52) return 2;
  if (n < 0.68) return 4;
  if (n < 0.84) return 3;
  return 5;
}

// ── iso projection ──────────────────────────────────────────────────────────
function cellLocal(c, r) { return [(c + ((r & 1) ? 0.5 : 0)) * TW, r * HH]; }

// ── elevation helpers ────────────────────────────────────────────────────────
function makeElevation(layout, heightRows) {
  const H = layout.length;
  const symAt = (c, r) => {
    if (r < 0 || r >= H) return "";
    const row = layout[r]; if (c < 0 || c >= row.length) return "";
    return row[c];
  };
  const isVoid = (c, r) => { const s = symAt(c, r); return s === "" || s === "V"; };
  function rawHeight(c, r) {
    if (r < 0 || r >= heightRows.length) return 0;
    const row = heightRows[r]; if (c < 0 || c >= row.length) return 0;
    const ch = row[c]; return ch === "2" ? 2 : ch === "1" ? 1 : 0;
  }
  function heightChar(c, r) {
    if (r < 0 || r >= heightRows.length) return "0";
    const row = heightRows[r]; if (c < 0 || c >= row.length) return "0";
    return row[c];
  }
  const isRamp = (c, r) => heightChar(c, r) === "/" && !isVoid(c, r);
  function carriesHeight(c, r) {
    const s = symAt(c, r);
    return !(s === "" || s === "V" || s === "W" || s === "w" || s === "m" || s === "~");
  }
  function levelAt(c, r) {
    if (!carriesHeight(c, r)) return 0;
    if (isRamp(c, r)) return 0;
    return rawHeight(c, r);
  }
  function rampMidLevel(c, r) {
    let lo = 99, hi = 0;
    for (const [dc, dr] of [[1,0],[-1,0],[0,1],[0,-1]]) {
      const lv = levelAt(c+dc, r+dr);
      lo = Math.min(lo, lv); hi = Math.max(hi, lv);
    }
    if (lo === 99) return rawHeight(c, r);
    return (lo + hi) * 0.5;
  }
  function liftAt(c, r) {
    if (isRamp(c, r)) return LIFT * rampMidLevel(c, r);
    return LIFT * levelAt(c, r);
  }
  return { symAt, isVoid, isRamp, levelAt, liftAt, rawHeight, heightChar };
}

// ── cliff/ramp drawing (shared palette, grove style) ────────────────────────
const ROCK_BASE=[120,96,78],ROCK_DARK=[72,56,44],ROCK_LIGHT=[150,122,102],
      ROCK_SHADOW=[46,36,30],GRASS_LIP=[86,128,60],GRASS_LIP_DK=[58,92,42];
function hash2(c,r,s){ let h=(((c*73856093)^(r*19349663)^(s*83492791)^0x9E3779B9)>>>0); h=(Math.imul((h^(h>>>13))>>>0,1274126177)>>>0); return((h^(h>>>16))>>>0)&0x7FFFFFFF; }
function rockNoise(px,py,seed){ return(hash2(px|0,py|0,seed)&0xFFFF)/65535; }
function lerpC(a,b,t){ return[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t]; }
function rockCol(s) {
  s=Math.min(Math.max(s,0),1.4);
  if(s<0.7) return lerpC(ROCK_SHADOW,ROCK_DARK,s/0.7);
  if(s<1.0) return lerpC(ROCK_DARK,ROCK_BASE,(s-0.7)/0.3);
  return lerpC(ROCK_BASE,ROCK_LIGHT,Math.min((s-1.0)/0.4,1));
}

const DIRT=[150,120,84],DIRT_DK=[110,86,58],DIRT_LT=[178,146,104];
function rampGrad(x,y,dir) {
  if(dir==="se") return Math.min(Math.max(x/TW,0),1);
  if(dir==="nw") return Math.min(Math.max(1-x/TW,0),1);
  if(dir==="sw") return Math.min(Math.max(y/TH,0),1);
  return Math.min(Math.max(1-y/TH,0),1);
}

// ── Canvas: a PNG with per-pixel put/add/blit/glow ──────────────────────────
function makeCanvas(w, h) {
  const png = new PNG({ width: Math.ceil(w), height: Math.ceil(h) });
  // fill transparent black
  png.data.fill(0);

  function put(x, y, rgb, a) {
    x=Math.round(x); y=Math.round(y);
    if(x<0||y<0||x>=png.width||y>=png.height) return;
    const i=(y*png.width+x)<<2;
    const oa = png.data[i+3]/255;
    // alpha composite over existing (pre-multiplied blend for overlays)
    png.data[i  ]=Math.min(255,png.data[i  ]*(1-a)+rgb[0]*a);
    png.data[i+1]=Math.min(255,png.data[i+1]*(1-a)+rgb[1]*a);
    png.data[i+2]=Math.min(255,png.data[i+2]*(1-a)+rgb[2]*a);
    png.data[i+3]=255;
  }
  function add(x, y, rgb, a) {
    x=Math.round(x); y=Math.round(y);
    if(x<0||y<0||x>=png.width||y>=png.height) return;
    const i=(y*png.width+x)<<2;
    png.data[i  ]=Math.min(255,png.data[i  ]+rgb[0]*a);
    png.data[i+1]=Math.min(255,png.data[i+1]+rgb[1]*a);
    png.data[i+2]=Math.min(255,png.data[i+2]+rgb[2]*a);
    png.data[i+3]=255;
  }
  function blit(src, sx, sy, { alpha=1, additive=false, scale=1 }={}) {
    if(!src) return;
    if(scale===1) {
      for(let py=0;py<src.height;py++) for(let px=0;px<src.width;px++){
        const si=(py*src.width+px)<<2;
        const a=(src.data[si+3]/255)*alpha;
        if(a<=0.003) continue;
        const rgb=[src.data[si],src.data[si+1],src.data[si+2]];
        if(additive) add(sx+px,sy+py,rgb,a); else put(sx+px,sy+py,rgb,a);
      }
      return;
    }
    const dw=Math.round(src.width*scale),dh=Math.round(src.height*scale);
    for(let dy=0;dy<dh;dy++) for(let dx=0;dx<dw;dx++){
      const px=Math.min(src.width-1,Math.floor(dx/scale)),py=Math.min(src.height-1,Math.floor(dy/scale));
      const si=(py*src.width+px)<<2;
      const a=(src.data[si+3]/255)*alpha;
      if(a<=0.003) continue;
      const rgb=[src.data[si],src.data[si+1],src.data[si+2]];
      if(additive) add(sx+dx,sy+dy,rgb,a); else put(sx+dx,sy+dy,rgb,a);
    }
  }
  function glow(cx,cy,radius,rgb,strength) {
    for(let py=-radius;py<=radius;py++) for(let px=-radius;px<=radius;px++){
      const d=Math.hypot(px,py)/radius; if(d>1) continue;
      add(cx+px,cy+py,rgb,(1-d)*(1-d)*strength);
    }
  }
  // Draw text label (simple 5×7 pixel font, uppercase A-Z, 0-9, space, parentheses)
  function drawLabel(text, lx, ly, rgb=[255,255,220]) {
    const FONT = {
      ' ':[0,0,0,0,0,0,0],
      'A':[0b01110,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
      'B':[0b11110,0b10001,0b10001,0b11110,0b10001,0b10001,0b11110],
      'C':[0b01110,0b10001,0b10000,0b10000,0b10000,0b10001,0b01110],
      'D':[0b11110,0b10001,0b10001,0b10001,0b10001,0b10001,0b11110],
      'E':[0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b11111],
      'F':[0b11111,0b10000,0b10000,0b11110,0b10000,0b10000,0b10000],
      'G':[0b01110,0b10001,0b10000,0b10111,0b10001,0b10001,0b01111],
      'H':[0b10001,0b10001,0b10001,0b11111,0b10001,0b10001,0b10001],
      'I':[0b01110,0b00100,0b00100,0b00100,0b00100,0b00100,0b01110],
      'J':[0b00111,0b00010,0b00010,0b00010,0b00010,0b10010,0b01100],
      'K':[0b10001,0b10010,0b10100,0b11000,0b10100,0b10010,0b10001],
      'L':[0b10000,0b10000,0b10000,0b10000,0b10000,0b10000,0b11111],
      'M':[0b10001,0b11011,0b10101,0b10001,0b10001,0b10001,0b10001],
      'N':[0b10001,0b11001,0b10101,0b10011,0b10001,0b10001,0b10001],
      'O':[0b01110,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
      'P':[0b11110,0b10001,0b10001,0b11110,0b10000,0b10000,0b10000],
      'Q':[0b01110,0b10001,0b10001,0b10001,0b10101,0b10010,0b01101],
      'R':[0b11110,0b10001,0b10001,0b11110,0b10100,0b10010,0b10001],
      'S':[0b01111,0b10000,0b10000,0b01110,0b00001,0b00001,0b11110],
      'T':[0b11111,0b00100,0b00100,0b00100,0b00100,0b00100,0b00100],
      'U':[0b10001,0b10001,0b10001,0b10001,0b10001,0b10001,0b01110],
      'V':[0b10001,0b10001,0b10001,0b10001,0b10001,0b01010,0b00100],
      'W':[0b10001,0b10001,0b10001,0b10101,0b10101,0b11011,0b10001],
      'X':[0b10001,0b10001,0b01010,0b00100,0b01010,0b10001,0b10001],
      'Y':[0b10001,0b10001,0b01010,0b00100,0b00100,0b00100,0b00100],
      'Z':[0b11111,0b00001,0b00010,0b00100,0b01000,0b10000,0b11111],
      '0':[0b01110,0b10001,0b10011,0b10101,0b11001,0b10001,0b01110],
      '1':[0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110],
      '2':[0b01110,0b10001,0b00001,0b00110,0b01000,0b10000,0b11111],
      '3':[0b11111,0b00001,0b00010,0b00110,0b00001,0b10001,0b01110],
      '4':[0b00010,0b00110,0b01010,0b10010,0b11111,0b00010,0b00010],
      '5':[0b11111,0b10000,0b11110,0b00001,0b00001,0b10001,0b01110],
      '6':[0b00110,0b01000,0b10000,0b11110,0b10001,0b10001,0b01110],
      '7':[0b11111,0b00001,0b00010,0b00100,0b01000,0b01000,0b01000],
      '8':[0b01110,0b10001,0b10001,0b01110,0b10001,0b10001,0b01110],
      '9':[0b01110,0b10001,0b10001,0b01111,0b00001,0b00010,0b01100],
      '(':[0b00110,0b01000,0b10000,0b10000,0b10000,0b01000,0b00110],
      ')':[0b01100,0b00010,0b00001,0b00001,0b00001,0b00010,0b01100],
      '-':[0,0,0,0b11111,0,0,0],
      '.':[0,0,0,0,0,0,0b00100],
      '/':[0b00001,0b00010,0b00100,0b01000,0b10000,0,0],
      '1':[0b00100,0b01100,0b00100,0b00100,0b00100,0b00100,0b01110],
    };
    const scale=2;
    let cx=lx;
    for(const ch of text.toUpperCase()) {
      const rows=FONT[ch]||FONT[' '];
      for(let row=0;row<7;row++) {
        const bits=rows[row]||0;
        for(let col=0;col<5;col++) {
          if(bits&(1<<(4-col))) {
            for(let sy=0;sy<scale;sy++) for(let sx=0;sx<scale;sx++) {
              put(cx+col*scale+sx, ly+row*scale+sy, rgb, 1);
            }
          }
        }
      }
      cx += 6*scale;
    }
  }
  return { png, put, add, blit, glow, drawLabel };
}

// ── Render one zone into its own canvas ─────────────────────────────────────
// Returns { canvas, OX, OY, heroX, heroY } where heroX/Y are screen coords of
// the landmark in zone coordinates (or null if not found).
function renderZone(layout, legend, heightRows, opts={}) {
  const {
    tint = null,          // [r,g,b, strength] — overall tint for cavern mood
    glowColor = null,     // dominant glow color for mystic tiles
    isGrove = false,      // apply grove-specific logic (world tree, etc.)
  } = opts;

  const H = layout.length;
  const W = layout.reduce((m,r)=>Math.max(m,r.length),0);

  // Elevation helpers
  const { symAt, isVoid, isRamp, levelAt, liftAt, rawHeight, heightChar } = makeElevation(layout, heightRows);

  // ── Compute bounds ───────────────────────────────────────────────────────
  let minX=1e9,minY=1e9,maxX=-1e9,maxY=-1e9;
  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    if(symAt(c,r)==="") continue;
    const [lx,ly]=cellLocal(c,r);
    const lift=liftAt(c,r);
    minX=Math.min(minX,lx-HW); maxX=Math.max(maxX,lx+HW);
    minY=Math.min(minY,ly-lift-TH); maxY=Math.max(maxY,ly+TH*2);
  }
  if(isGrove) minY-=300; // world tree canopy headroom
  const PAD=60;
  const worldW=maxX-minX+PAD*2, worldH=maxY-minY+PAD*2;
  const OX=-minX+PAD, OY=-minY+PAD;

  const cv = makeCanvas(worldW, worldH);
  const { png, put, add, blit, glow, drawLabel } = cv;

  // ── Background: navy-void gradient + stars ───────────────────────────────
  function h32(a,b,s){ let h=(a*374761393+b*668265263+s*2147483647)>>>0; h=(h^(h>>13))*1274126177; return(h>>>0)/4294967295; }
  for(let y=0;y<png.height;y++) for(let x=0;x<png.width;x++){
    const t=y/png.height;
    let r=0x12+t*0x0c, g=0x12+t*0x08, b=0x1c+t*0x12;
    // cavern mood: darken + purple shift
    if(tint) {
      r=r*(1-tint[3])+tint[0]*tint[3]*255;
      g=g*(1-tint[3])+tint[1]*tint[3]*255;
      b=b*(1-tint[3])+tint[2]*tint[3]*255;
    }
    const i=(y*png.width+x)<<2;
    png.data[i]=r; png.data[i+1]=g; png.data[i+2]=b; png.data[i+3]=255;
  }
  for(let i=0;i<500;i++){
    const x=Math.floor(h32(i,7,11)*png.width),y=Math.floor(h32(i,13,5)*png.height);
    const br=80+h32(i,3,9)*100;
    const violet=h32(i,17,2)>0.65;
    put(x,y,violet?[br*0.85,br*0.7,br]:[br,br,br],0.8);
  }

  // ── Tile drawing helpers ─────────────────────────────────────────────────
  function tileScreen(c,r){ const[lx,ly]=cellLocal(c,r); return[OX+lx-HW,OY+ly-liftAt(c,r)-HH]; }

  // GRASS_VARIANT_SYMS: symbols that use cluster variants (g, G for new zones)
  const GRASS_VARIANT_SYMS = new Set(["g","G"]);
  // isGrove grove uses actual 'g' only; in garden/heart G is also cluster-variant

  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    const sym=symAt(c,r); if(sym==="") continue;
    const spec=legend.tiles[sym];
    let tileSource = spec ? spec.source : 2;
    // override ~ in l1h to mystic (source 10) — already in legend
    let src;
    if(GRASS_VARIANT_SYMS.has(sym)) src=TILE_BY_SRC[variantSource(c,r)];
    else src=TILE_BY_SRC[tileSource]||TILE_BY_SRC[2];
    if(!src) continue;
    const [sx,sy]=tileScreen(c,r);
    blit(src,sx,sy);

    // mystic glow
    if((sym==="m"||sym==="~")&&MYSTIC_GLOW){
      const[lx,ly]=cellLocal(c,r);
      const gcol=glowColor||[0x6b,0x4a,0x9e];
      blit(MYSTIC_GLOW,Math.round(OX+lx-MYSTIC_GLOW.width/2),Math.round(OY+ly-liftAt(c,r)-MYSTIC_GLOW.height/2),{additive:true,alpha:0.8});
    }
  }

  // ── Elevation: AO seats → cliff aprons → ramp slopes ────────────────────
  function drawApron(baseX,baseY,drop,exposeSE,exposeSW,salt){
    const wall=LIFT*drop;
    const x0=Math.round(baseX-HW),y0=Math.round(baseY-HH);
    for(let x=0;x<TW;x++){
      const isLeft=x<HW;
      const exposed=isLeft?exposeSW:exposeSE;
      if(!exposed) continue;
      const rim=isLeft?(HH+x*0.5):((TW-x)*0.5+HH);
      const rimY=Math.round(rim);
      const sideLight=isLeft?0.74:1.10;
      for(let y=rimY;y<rimY+wall;y++){
        const t=(y-rimY)/Math.max(1,wall);
        const vshade=1.0-0.30*t;
        const strata=Math.floor(rockNoise((x/6)|0,(y/5)|0,salt)*5.0)/5.0;
        const facet=(strata-0.4)*0.5;
        const crack=(rockNoise((x/3)|0,(y/7)|0,salt+5)<0.14)?-0.34:0.0;
        const n=rockNoise(x,y,salt)*0.12-0.06;
        const col=rockCol(sideLight*vshade+facet+crack+n);
        put(x0+x,y0+y,col,1);
      }
      const lipH=5,jag=Math.floor(rockNoise(x,7,salt)*3.0);
      for(let y=rimY;y<rimY+lipH-jag;y++){
        const g=((x+y)%3!==0)?GRASS_LIP:GRASS_LIP_DK;
        put(x0+x,y0+y,g,1);
      }
    }
  }
  function drawAoSeat(baseX,baseY){
    const x0=Math.round(baseX-HW),y0=Math.round(baseY-HH);
    for(let y=0;y<TH;y++) for(let x=0;x<TW;x++){
      const dx=Math.abs(x-HW)/HW,dy=Math.abs(y-HH)/HH;
      const d=dx+dy; if(d>1) continue;
      const a=Math.min(1,Math.max(0,(1-d)/0.62));
      put(x0+x,y0+y,[0,0,0],a*a*0.6);
    }
  }
  function rampDir(c,r){
    let best="ne",bestLv=-1;
    for(const [dc,dr,name] of [[1,0,"se"],[-1,0,"nw"],[0,1,"sw"],[0,-1,"ne"]]){
      const lv=levelAt(c+dc,r+dr);
      if(lv>bestLv){bestLv=lv;best=name;}
    }
    return best;
  }
  function drawRamp(baseX,baseY,dir,salt){
    const x0=Math.round(baseX-HW),y0=Math.round(baseY-HH);
    for(let y=0;y<TH;y++) for(let x=0;x<TW;x++){
      const dx=Math.abs(x-HW)/HW,dy=Math.abs(y-HH)/HH;
      if(dx+dy>1) continue;
      const g=rampGrad(x,y,dir);
      const band=(Math.floor(g*6)%2===0);
      const n=rockNoise(x,y,salt)*0.12-0.06;
      let base=band?lerpC(DIRT,DIRT_LT,g):lerpC(DIRT,DIRT_DK,1-g);
      base=[base[0]+n*255*0.6,base[1]+n*255*0.6,base[2]+n*255*0.6];
      put(x0+x,y0+y,base,1);
    }
    for(let x=0;x<TW;x++){
      const isLeft=x<HW;
      const rim=isLeft?(HH+x*0.5):((TW-x)*0.5+HH);
      const rimY=Math.round(rim);
      for(let y=rimY;y<rimY+LIFT;y++){
        const t=(y-rimY)/LIFT;
        put(x0+x,y0+y,lerpC(DIRT_DK,[74,58,40],t),1);
      }
    }
  }

  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    if(isRamp(c,r)) continue;
    const lv=levelAt(c,r); if(lv<=0) continue;
    for(const[dc,dr] of [[1,0],[0,1]]){
      const nc=c+dc,nr=r+dr;
      if(levelAt(nc,nr)<lv&&!isRamp(nc,nr)){
        const[lx,ly]=cellLocal(nc,nr);
        drawAoSeat(OX+lx,OY+ly-liftAt(nc,nr));
      }
    }
  }
  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    if(isRamp(c,r)) continue;
    const lv=levelAt(c,r); if(lv<=0) continue;
    const east=levelAt(c+1,r),south=levelAt(c,r+1);
    const seDrop=(east<lv&&!isRamp(c+1,r))?(lv-east):0;
    const swDrop=(south<lv&&!isRamp(c,r+1))?(lv-south):0;
    const drop=Math.max(seDrop,swDrop);
    if(drop<=0) continue;
    const[lx,ly]=cellLocal(c,r);
    drawApron(OX+lx,OY+ly-LIFT*lv,drop,seDrop>0,swDrop>0,hash2(c,r,611));
  }
  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    if(!isRamp(c,r)) continue;
    const[lx,ly]=cellLocal(c,r);
    drawRamp(OX+lx,OY+ly-liftAt(c,r),rampDir(c,r),hash2(c,r,41));
  }

  // ── Void fringe glow ─────────────────────────────────────────────────────
  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    if(!isVoid(c,r)) continue;
    let fringe=false;
    for(const[dc,dr] of [[1,0],[-1,0],[0,1],[0,-1]]){
      const s=symAt(c+dc,r+dr);
      if(s!==""&&s!=="V"){fringe=true;break;}
    }
    if(!fringe) continue;
    const[lx,ly]=cellLocal(c,r);
    const bx=OX+lx,by=OY+ly;
    const rc=tint?[0x2a,0x1a,0x4c]:[0x3a,0x2a,0x5c];
    glow(Math.round(bx),Math.round(by+HH*0.3),30,rc,0.22);
  }

  // ── Objects ──────────────────────────────────────────────────────────────
  // For l1xobj objects: read "art" and "offset" from legend generically.
  function treeArt(c,r){ const p=cellHash(c,r,7)%3; if(p===0)return["tree_a",[0,-110]]; if(p===1)return["tree_b",[0,-116]]; return["tree_c",[0,-105]]; }
  function flowerArt(c,r){ const p=cellHash(c,r,7)%3; if(p===0)return["flower",[0,-24]]; if(p===1)return["flower_violet",[0,-24]]; return["flower_pink",[0,-24]]; }

  const draws=[];
  let heroX=null,heroY=null; // landmark screen coords in zone space
  let missingArt=[];

  function pushObj(c,r,artName,off,extra={}){
    const src=objArt(artName);
    if(!src){ missingArt.push(artName); return; }
    const[lx,ly]=cellLocal(c,r);
    const baseX=OX+lx,baseY=OY+ly-liftAt(c,r);
    const scale=extra.scale||1;
    const sw=src.width*scale,sh=src.height*scale;
    const sx=Math.round(baseX-sw/2+off[0]);
    const sy=Math.round(baseY-sh+HH+off[1]);
    draws.push({depth:baseY,sx,sy,src,scale,gx:baseX,gy:baseY,...extra});
  }

  let worldTreeDone=false;

  for(let r=0;r<H;r++) for(let c=0;c<layout[r].length;c++){
    const sym=symAt(c,r);
    if(sym===""||sym==="V") continue;

    // Check if this symbol has an l1xobj entry in legend.objects
    const objSpec=legend.objects?legend.objects[sym]:null;
    if(objSpec&&objSpec.kind==="l1xobj"){
      const artName=objSpec.art;
      const off=objSpec.offset||[0,-20];
      const[lx,ly]=cellLocal(c,r);
      const baseX=OX+lx,baseY=OY+ly-liftAt(c,r);

      // glow pool under certain objects
      if(objSpec.glow==="gold"||objSpec.glow==="amber"){
        const pool=GOLD_POOL||AMBER_POOL;
        if(pool) blit(pool,Math.round(baseX-pool.width/2),Math.round(baseY-pool.height/2-8),{additive:true,alpha:0.7});
        glow(Math.round(baseX),Math.round(baseY-HH*0.3),120,[0xcc,0xaa,0x44],0.3);
      } else if(objSpec.glow==="violet"){
        if(VIOLET_POOL) blit(VIOLET_POOL,Math.round(baseX-VIOLET_POOL.width/2),Math.round(baseY-VIOLET_POOL.height/2-8),{additive:true,alpha:0.7});
      }

      const src=objArt(artName);
      if(!src){ missingArt.push(artName); continue; }
      const sw=src.width,sh=src.height;
      const sx=Math.round(baseX-sw/2+off[0]);
      const sy=Math.round(baseY-sh+HH+off[1]);
      draws.push({depth:baseY,sx,sy,src,scale:1,gx:baseX,gy:baseY,artName,objSpec});

      // Track hero landmark: world_tree_heart (l1h) preferred, rainbow_font (l1g) fallback
      if((artName==="world_tree_heart"||artName==="rainbow_font")&&heroX===null){
        heroX=baseX; heroY=baseY;
      }
      continue;
    }

    // Grove-style objects (and cauldron in any zone)
    switch(sym){
      case "T":{ const[a,o]=treeArt(c,r); pushObj(c,r,a,o); break; }
      case "F":{ const[a,o]=flowerArt(c,r); pushObj(c,r,a,o); break; }
      case "R": pushObj(c,r,"rock",[0,-22]); break;
      case "s": pushObj(c,r,"stone",[0,-14]); break;
      case "B": pushObj(c,r,"bush_dry",[0,-64]); break;
      case "N": pushObj(c,r,"night_bud_closed",[0,-60]); break;
      case "C":{
        const[lx,ly]=cellLocal(c,r);
        const yl=OY+ly-liftAt(c,r);
        if(VIOLET_POOL) blit(VIOLET_POOL,Math.round(OX+lx-VIOLET_POOL.width/2),Math.round(yl-VIOLET_POOL.height/2-8),{additive:true,alpha:0.7});
        pushObj(c,r,"cauldron",[0,-64]);
        break;
      }
      case "U": pushObj(c,r,"rest_stump",[0,-80]); break;
      case "O":{
        if(isGrove&&!worldTreeDone){
          worldTreeDone=true;
          const[lx,ly]=cellLocal(c,r);
          const cx=OX+lx,cy=OY+ly-liftAt(c,r)+32;
          if(VIOLET_POOL_LG) blit(VIOLET_POOL_LG,Math.round(cx-VIOLET_POOL_LG.width/2),Math.round(cy-VIOLET_POOL_LG.height/2),{additive:true,alpha:0.9});
          glow(Math.round(cx),Math.round(cy-HH*0.4),210,[0x6b,0x4a,0x9e],0.5);
          const body=objArt("world_tree")||objArt("world_tree_dormant");
          const sc=0.72,o=[0,-238];
          if(body){
            const sw=body.width*sc,sh=body.height*sc;
            draws.push({depth:cy+100,isWorldTree:true,src:body,scale:sc,
              sx:Math.round(cx-sw/2+o[0]*sc),sy:Math.round(cy-sh+HH+o[1]*sc),gx:cx,gy:cy});
          }
        }
        break;
      }
    }
  }

  draws.sort((a,b)=>a.depth-b.depth);
  for(const d of draws){
    blit(d.src,d.sx,d.sy,{scale:d.scale});
    if(d.isWorldTree&&WORLD_GLOW){
      const sc=0.72,o=[0,-238];
      const gw=WORLD_GLOW.width*sc,gh=WORLD_GLOW.height*sc;
      const gx=Math.round(d.gx-gw/2+o[0]*sc),gy=Math.round(d.gy-gh+HH+o[1]*sc);
      blit(WORLD_GLOW,gx,gy,{additive:true,alpha:0.9,scale:sc});
      const hsc=sc*1.18;
      const ccx=gx+gw/2,ccy=gy+gh/2;
      const hgw=WORLD_GLOW.width*hsc,hgh=WORLD_GLOW.height*hsc;
      blit(WORLD_GLOW,Math.round(ccx-hgw/2),Math.round(ccy-hgh/2),{additive:true,alpha:0.32,scale:hsc});
    }
  }

  // ── Cavern tint overlay for l1h ──────────────────────────────────────────
  if(tint){
    for(let y=0;y<png.height;y++) for(let x=0;x<png.width;x++){
      const i=(y*png.width+x)<<2;
      if(png.data[i+3]<255) continue;
      // darken + violet-shift
      const strength=tint[3]*0.35;
      png.data[i  ]=Math.round(png.data[i  ]*(1-strength)+tint[0]*255*strength);
      png.data[i+1]=Math.round(png.data[i+1]*(1-strength)+tint[1]*255*strength);
      png.data[i+2]=Math.round(png.data[i+2]*(1-strength)+tint[2]*255*strength);
    }
  }

  return { png, OX, OY, heroX, heroY, missingArt };
}

// ── Load zone data ──────────────────────────────────────────────────────────
console.log("Loading zone data...");

// Zone 0: Starting Grove
const groveLayout  = readLines(`${GAME}/data/map_layout.txt`);
const groveLegend  = JSON.parse(fs.readFileSync(`${GAME}/data/map_legend.json`,"utf8"));
const groveHeight  = readLines(`${GAME}/data/map_height.txt`);

// Zone 1: l1g — 고요의 화원
const l1gLayout  = readLines(`${GAME}/data/l1g_map_layout.txt`);
const l1gLegend  = JSON.parse(fs.readFileSync(`${GAME}/data/l1g_map_legend.json`,"utf8"));
const l1gHeight  = []; // no height file

// Zone 2: l1h — 생명의 심장
const l1hLayout  = readLines(`${GAME}/data/l1h_map_layout.txt`);
const l1hLegend  = JSON.parse(fs.readFileSync(`${GAME}/data/l1h_map_legend.json`,"utf8"));
const l1hHeight  = readLines(`${GAME}/data/l1h_map_height.txt`);

// ── Render each zone ────────────────────────────────────────────────────────
console.log("Rendering starting grove...");
const groveResult = renderZone(groveLayout, groveLegend, groveHeight, { isGrove: true });

console.log("Rendering l1g (고요의 화원)...");
const l1gResult = renderZone(l1gLayout, l1gLegend, l1gHeight, {
  tint: null, // pastel/natural — no tint
});

console.log("Rendering l1h (생명의 심장)...");
const l1hResult = renderZone(l1hLayout, l1hLegend, l1hHeight, {
  tint: [0.35, 0.15, 0.55, 0.55], // violet-dark cavern tint
  glowColor: [0x9e, 0x6b, 0xcc],
});

// ── Composite: grove | l1g | l1h left-to-right ──────────────────────────────
console.log("Compositing 3-zone overview...");

const LABEL_H = 36; // label strip at the bottom of each zone
const zones = [
  { result: groveResult, label: "STARTING GROVE" },
  { result: l1gResult,   label: "L1G QUIET GARDEN" },
  { result: l1hResult,   label: "L1H LIFES HEART" },
];

const totalW = zones.reduce((s,z)=>s+z.result.png.width,0) + ZONE_GAP*(zones.length-1);
const totalH = Math.max(...zones.map(z=>z.result.png.height)) + LABEL_H;

const composite = makeCanvas(totalW, totalH);
const { png: compPng, put: compPut, blit: compBlit, add: compAdd, drawLabel: compLabel, glow: compGlow } = composite;

// Fill background
for(let y=0;y<compPng.height;y++) for(let x=0;x<compPng.width;x++){
  const t=y/compPng.height;
  const i=(y*compPng.width+x)<<2;
  compPng.data[i]=Math.round(0x10+t*0x08);
  compPng.data[i+1]=Math.round(0x10+t*0x06);
  compPng.data[i+2]=Math.round(0x18+t*0x10);
  compPng.data[i+3]=255;
}

// Blit each zone and draw labels
let xOff=0;
const zoneOffsets=[]; // store xOff per zone for hero crop computation
for(const {result,label} of zones){
  const {png:zPng}=result;
  // center vertically
  const yOff=Math.floor((totalH-LABEL_H-zPng.height)/2);
  zoneOffsets.push({xOff,yOff});

  // blit zone pixels
  for(let y=0;y<zPng.height;y++) for(let x=0;x<zPng.width;x++){
    const si=(y*zPng.width+x)<<2;
    if(zPng.data[si+3]===0) continue;
    const di=((yOff+y)*compPng.width+(xOff+x))<<2;
    compPng.data[di  ]=zPng.data[si  ];
    compPng.data[di+1]=zPng.data[si+1];
    compPng.data[di+2]=zPng.data[si+2];
    compPng.data[di+3]=255;
  }

  // separator line between zones (skip after last)
  if(xOff+zPng.width<totalW-ZONE_GAP){
    const sepX=xOff+zPng.width+Math.floor(ZONE_GAP/2);
    for(let y=20;y<totalH-LABEL_H-20;y++){
      compPut(sepX,y,[0x4a,0x3a,0x6c],0.4);
      compPut(sepX+1,y,[0x4a,0x3a,0x6c],0.2);
    }
  }

  // zone label at bottom
  const labelY=totalH-LABEL_H+8;
  const labelX=xOff+Math.floor(zPng.width/2)-label.length*6; // approx center
  compLabel(label,labelX,labelY,[200,190,230]);

  xOff+=zPng.width+ZONE_GAP;
}

// Vignette
const vcx=compPng.width/2,vcy=compPng.height/2,vmax=Math.hypot(vcx,vcy);
for(let y=0;y<compPng.height;y++) for(let x=0;x<compPng.width;x++){
  const d=Math.hypot(x-vcx,y-vcy)/vmax;
  const v=Math.max(0,d-0.72)*0.4;
  if(v<=0) continue;
  const i=(y*compPng.width+x)<<2;
  compPng.data[i]*=(1-v); compPng.data[i+1]*=(1-v); compPng.data[i+2]*=(1-v);
}

fs.writeFileSync(OUT_FULL, PNG.sync.write(compPng));
console.log(`wrote ${OUT_FULL} (${compPng.width}x${compPng.height})`);

// ── Hero crop ────────────────────────────────────────────────────────────────
// Prefer l1h world_tree_heart, fallback to l1g rainbow_font, fallback to l1h center.
console.log("Generating hero crop...");

// Determine which zone has the landmark and its composite coordinates
let heroCX=null, heroCY=null, heroZoneName="";

// Zone index 2 = l1h, zone index 1 = l1g
const ZONE_PREF_ORDER = [2, 1]; // l1h first, l1g second
for(const zi of ZONE_PREF_ORDER){
  const r=zones[zi].result;
  if(r.heroX!==null&&r.heroY!==null){
    const {xOff,yOff}=zoneOffsets[zi];
    heroCX=xOff+r.heroX;
    heroCY=yOff+r.heroY;
    heroZoneName=zones[zi].label;
    break;
  }
}
// If still no hero, fall back to l1h center
if(heroCX===null){
  const zi=2;
  const {xOff,yOff}=zoneOffsets[zi];
  heroCX=xOff+l1hResult.png.width/2;
  heroCY=yOff+l1hResult.png.height/2;
  heroZoneName="L1H CENTER";
}

console.log(`  hero center: (${Math.round(heroCX)}, ${Math.round(heroCY)}) from ${heroZoneName}`);

const HERO_W=640, HERO_H=480;
const hx0=Math.round(Math.max(0,Math.min(compPng.width-HERO_W, heroCX-HERO_W/2)));
const hy0=Math.round(Math.max(0,Math.min(compPng.height-HERO_H, heroCY-HERO_H/2)));

const heroPng=new PNG({width:HERO_W,height:HERO_H});
for(let y=0;y<HERO_H;y++) for(let x=0;x<HERO_W;x++){
  const sx=hx0+x,sy=hy0+y;
  if(sx>=compPng.width||sy>=compPng.height){ const i=(y*HERO_W+x)<<2; heroPng.data[i]=heroPng.data[i+1]=heroPng.data[i+2]=0; heroPng.data[i+3]=255; continue; }
  const si=(sy*compPng.width+sx)<<2;
  const di=(y*HERO_W+x)<<2;
  heroPng.data[di]=compPng.data[si]; heroPng.data[di+1]=compPng.data[si+1];
  heroPng.data[di+2]=compPng.data[si+2]; heroPng.data[di+3]=255;
}
// Slight vignette on hero crop
const hvcx=HERO_W/2,hvcy=HERO_H/2,hvmax=Math.hypot(hvcx,hvcy);
for(let y=0;y<HERO_H;y++) for(let x=0;x<HERO_W;x++){
  const d=Math.hypot(x-hvcx,y-hvcy)/hvmax;
  const v=Math.max(0,d-0.62)*0.5;
  if(v<=0) continue;
  const i=(y*HERO_W+x)<<2;
  heroPng.data[i]*=(1-v); heroPng.data[i+1]*=(1-v); heroPng.data[i+2]*=(1-v);
}

fs.writeFileSync(OUT_HERO, PNG.sync.write(heroPng));
console.log(`wrote ${OUT_HERO} (${HERO_W}x${HERO_H})`);

// ── Summary ──────────────────────────────────────────────────────────────────
const allMissing=[...new Set([
  ...groveResult.missingArt,
  ...l1gResult.missingArt,
  ...l1hResult.missingArt,
])];
if(allMissing.length>0){
  console.log(`MISSING object art (skipped gracefully): ${allMissing.join(", ")}`);
} else {
  console.log("All object art found.");
}
console.log(`Hero zone: ${heroZoneName}`);
