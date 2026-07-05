'use strict';
// L4-1 — Magic-world (Layer 4) 「봉인이 풀린 마탑」 TILE generator. Deterministic 128×64 iso
// diamonds, hybrid recolor of the L3 machine tiles into 자수정 보라 + 금색 룬 발광
// (design Part C §C-1). L3 was 구리/황동 base + 주황 증기 발광; L4 hue-shifts to arcane:
//   base 자수정 보라 #2a1f3d, 보라 램프 hi #7a5cae / mid #4a3670 / shadow #2a1f3d,
//   금색 룬 발광 #f2c14e (주황 → 금색 hue).
// Produces (into assets/tiles/):
//   l4_amethyst.png (A 자수정 포장/봉인탑 기단) l4_pipe.png (p 룬 도관)
//   l4_rune.png (R 룬 회랑 석판) l4_platform.png (M 부유 파편 +1)
//   l4_chamber.png (O 최심부 봉인실 +2) l4_dark.png (게이트 STATIC-CLOSED + 갈라진 허공)
//   l4_ramp.png (/ 경사로) l4_crack.png (x 균열 타일) l4_cliff.png (자수정 절벽 단면)
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l4_tiles.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');

// ---- PNG encoder (copied from tools_gen_l3_tiles.js, unchanged) ----
function crc32(buf){let c=~0;for(let i=0;i<buf.length;i++){c^=buf[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(type,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const t=Buffer.from(type,'ascii');const body=Buffer.concat([t,data]);const crc=Buffer.alloc(4);crc.writeUInt32BE(crc32(body),0);return Buffer.concat([len,body,crc]);}
function encodePNG(w,h,pixels){const sig=Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;ihdr[10]=0;ihdr[11]=0;ihdr[12]=0;const stride=w*4;const raw=Buffer.alloc((stride+1)*h);for(let y=0;y<h;y++){raw[y*(stride+1)]=0;pixels.copy(raw,y*(stride+1)+1,y*stride,y*stride+stride);}const idat=zlib.deflateSync(raw,{level:9});return Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]);}
function makeCanvas(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hexToRGB(hex){const s=hex.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function setPx(cv,x,y,rgb,a=255){if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;}
function blendPx(cv,x,y,rgb,a){if(a>=255)return setPx(cv,x,y,rgb,255);if(a<=0)return;if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;const af=a/255,ia=1-af;if(cv.data[i+3]===0){setPx(cv,x,y,rgb,a);return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function save(cv,name){const png=encodePNG(cv.w,cv.h,cv.data);fs.writeFileSync(path.join(OUT,name),png);console.log('wrote',name,cv.w+'x'+cv.h,png.length,'bytes');}
function inDiamond(x,y,w,h){const cx=(w-1)/2,cy=(h-1)/2;return Math.abs(x-cx)/(w/2)+Math.abs(y-cy)/(h/2)<=1.0+1e-6;}
function onDiamondEdge(x,y,w,h){const cx=(w-1)/2,cy=(h-1)/2;const d=Math.abs(x-cx)/(w/2)+Math.abs(y-cy)/(h/2);return d>0.88&&d<=1.0+1e-6;}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function clamp(v,lo,hi){return v<lo?lo:(v>hi?hi:v);}
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}

// ---- palette (Part C §C-1: 자수정 보라 base + 금색 룬 발광) ----
const AMETHYST = '#2a1f3d';    // base 자수정/짙은 남보라
const P_HI     = '#7a5cae';    // 밝은 자수정 하이라이트
const P_MID    = '#4a3670';    // 자수정 미드
const P_SH     = '#221830';    // 자수정 섀도
const GOLD     = '#f2c14e';    // 금색 룬 발광
const GOLD_DK  = '#c99a34';    // 어두운 금색 (잔열/음영 금)
const STONE    = '#3a2f4e';    // 룬 회랑 석판 회보라
const IRON     = '#5a4a6a';    // 석판 미드
const DEEPDK   = '#0e0a18';    // 허공 어둠

function makeTile(name, fillHex, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const fill = hexToRGB(fillHex);
  const lo = hexToRGB(opts.loHex || P_SH);
  const hi = hexToRGB(opts.hiHex || P_HI);
  const edge = hexToRGB(opts.edgeHex || P_SH);
  const tex = opts.tex || 'amethyst';
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      if (!onDiamondEdge(x, y, W, H)) {
        if (tex === 'amethyst') {
          const n = smoothCell(x, y, 14, 0x2a1f);
          if (n > 0.66) c = mix(c, hi, 0.24);
          else if (n < 0.34) c = mix(c, lo, 0.26);
          if ((x + (H - y)) > 108) c = mix(c, hi, 0.12);   // upper-right sheen
        } else if (tex === 'rune') {
          const n = smoothCell(x, y, 10, 0x3a2f);
          if (n > 0.60) c = mix(c, hi, 0.14);
          else if (n < 0.36) c = mix(c, lo, 0.22);
        } else if (tex === 'platform') {
          const n = smoothCell(x, y, 13, 0x7a5c);
          if (n > 0.64) c = mix(c, hi, 0.26);
          else if (n < 0.34) c = mix(c, lo, 0.22);
          if ((x + (H - y)) > 104) c = mix(c, hi, 0.14);
        } else if (tex === 'chamber') {
          const n = smoothCell(x, y, 16, 0xf001);
          if (n > 0.62) c = mix(c, hi, 0.30);
          else if (n < 0.34) c = mix(c, lo, 0.18);
        }
      }
      if (onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, x, y, c, 255);
    }
  }
  if (opts.after) opts.after(cv, W, H);
  save(cv, name);
}

// Radial rune-seam overlay: iso seam lines + a small central golden rune ring.
function runeSeams(cv, W, H, seamHex, runeHex) {
  const seam = hexToRGB(seamHex), rune = hexToRGB(runeHex);
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
    if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
    const dx = (x - cx) / (W / 2), dy = (y - cy) / (H / 2);
    if (Math.abs(dy) < 0.045) blendPx(cv, x, y, seam, 130);
    if (Math.abs(dx) < 0.030) blendPx(cv, x, y, seam, 120);
  }
  // small golden rune ring at centre (a hint of the seal-magic beneath the pavement)
  for (let a = 0; a < 360; a += 30) {
    const rad = 12;
    const px = Math.round(cx + Math.cos(a * Math.PI / 180) * rad);
    const py = Math.round(cy + Math.sin(a * Math.PI / 180) * rad * 0.5);
    for (let b = 0; b < 2; b++) if (inDiamond(px, py + b, W, H)) blendPx(cv, px, py + b, rune, 150);
  }
}

// ---- A 자수정 포장(봉인탑 기단) : amethyst plate + golden rune ring seams ----
makeTile('l4_amethyst.png', AMETHYST, {
  loHex: P_SH, hiHex: P_HI, edgeHex: P_SH, tex: 'amethyst',
  after: (cv, W, H) => runeSeams(cv, W, H, P_SH, GOLD),
});

// ---- p 룬 도관 : amethyst + thick golden conduit decal ----
makeTile('l4_pipe.png', AMETHYST, {
  loHex: P_SH, hiHex: P_HI, edgeHex: P_SH, tex: 'amethyst',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const pipe = hexToRGB(P_MID), lit = hexToRGB(GOLD), sh = hexToRGB(P_SH);
    for (let x = 8; x < W - 8; x++) {
      const yb = cy + (x - cx) * 0.25;
      for (let t = -7; t <= 7; t++) {
        const y = Math.round(yb + t);
        if (!inDiamond(x, y, W, H)) continue;
        let c = pipe;
        if (t < -3) c = lit;
        else if (t > 3) c = sh;
        blendPx(cv, x, y, c, 235);
      }
    }
    for (let x = 18; x < W - 12; x += 28) {
      const yb = cy + (x - cx) * 0.25;
      for (let t = -7; t <= 7; t++) { const y = Math.round(yb + t); blendPx(cv, x, y, sh, 180); }
    }
  },
});

// ---- R 룬 회랑 석판 : stone plate + golden engraved rune glyph ----
makeTile('l4_rune.png', STONE, {
  loHex: '#241a30', hiHex: IRON, edgeHex: '#1c142a', tex: 'rune',
  after: (cv, W, H) => {
    const line = hexToRGB('#1c142a'), gold = hexToRGB(GOLD);
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    // iso stone seams: two families of parallel lines forming a diamond mesh
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dx = x - cx, dy = (y - cy) * 2.0;
      if (Math.abs(((dx + dy) % 22)) < 1.4) blendPx(cv, x, y, line, 120);
      if (Math.abs(((dx - dy) % 22)) < 1.4) blendPx(cv, x, y, line, 120);
    }
    // a single golden rune glyph engraved centre (each plank a different rune)
    for (let a = 0; a < 360; a += 60) {
      const px = Math.round(cx + Math.cos(a * Math.PI / 180) * 9);
      const py = Math.round(cy + Math.sin(a * Math.PI / 180) * 4.5);
      blendPx(cv, px, py, gold, 130); blendPx(cv, px, py + 1, gold, 80);
    }
    // central golden dot
    blendPx(cv, cx, cy, gold, 160);
  },
});

// ---- M 부유 파편 상부 플랫폼(+1) : bright amethyst + panel rivets ----
makeTile('l4_platform.png', '#33254a', {
  loHex: P_SH, hiHex: P_HI, edgeHex: P_SH, tex: 'platform',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const rivet = hexToRGB(GOLD), seam = hexToRGB(P_SH);
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dy = (y - cy) / (H / 2);
      if (Math.abs(dy) < 0.04) blendPx(cv, x, y, seam, 110);
    }
    for (const [rx, ry] of [[0.5, 0.5], [-0.5, 0.5], [0.5, -0.5], [-0.5, -0.5]]) {
      const px = Math.round(cx + rx * (W / 2) * 0.5), py = Math.round(cy + ry * (H / 2) * 0.5);
      for (let a = 0; a < 2; a++) for (let b = 0; b < 2; b++) if (inDiamond(px + a, py + b, W, H)) blendPx(cv, px + a, py + b, rivet, 200);
    }
  },
});

// ---- O 최심부 봉인실(+2) : bright amethyst + radial golden seal-rune circle decal ----
makeTile('l4_chamber.png', '#332448', {
  loHex: P_SH, hiHex: P_HI, edgeHex: P_MID, tex: 'chamber',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const ring = hexToRGB(P_HI), tick = hexToRGB(GOLD);
    // faint radial seal-rune circle: 12 rune ticks around a golden centre ring
    for (let a = 0; a < 360; a += 30) {
      for (let r = 16; r < 26; r++) {
        const px = Math.round(cx + Math.cos(a * Math.PI / 180) * r);
        const py = Math.round(cy + Math.sin(a * Math.PI / 180) * r * 0.5);
        if (inDiamond(px, py, W, H)) blendPx(cv, px, py, tick, 90);
      }
    }
    for (let a = 0; a < 360; a += 6) {
      const px = Math.round(cx + Math.cos(a * Math.PI / 180) * 14);
      const py = Math.round(cy + Math.sin(a * Math.PI / 180) * 7);
      if (inDiamond(px, py, W, H)) blendPx(cv, px, py, ring, 80);
    }
  },
});

// ---- / 경사로(ramp) : amethyst with directional tread lines (climbing read) ----
makeTile('l4_ramp.png', '#2f2342', {
  loHex: P_SH, hiHex: P_MID, edgeHex: P_SH, tex: 'amethyst',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const tread = hexToRGB(GOLD), sh = hexToRGB(P_SH);
    for (let k = -4; k <= 4; k++) {
      const yb = cy + k * 6;
      for (let x = 0; x < W; x++) { const y = Math.round(yb + (x - cx) * 0.02); if (inDiamond(x, y, W, H) && !onDiamondEdge(x, y, W, H)) { blendPx(cv, x, y, tread, 110); blendPx(cv, x, y + 1, sh, 90); } }
    }
  },
});

// ---- x 균열 타일 : amethyst floor with a black jagged crack (그 너머 별하늘 비침) ----
(function crackTile() {
  const W = 128, H = 64, cv = makeCanvas(W, H);
  const fill = hexToRGB(AMETHYST), lo = hexToRGB(P_SH), hi = hexToRGB(P_HI), edge = hexToRGB(P_SH);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = fill;
    if (!onDiamondEdge(x, y, W, H)) {
      const n = smoothCell(x, y, 14, 0x2a1f);
      if (n > 0.66) c = mix(c, hi, 0.20);
      else if (n < 0.34) c = mix(c, lo, 0.26);
    } else c = edge;
    setPx(cv, x, y, c, 255);
  }
  // a jagged black crack running across the diamond (그 너머 어둠 + 별빛 점)
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  const black = hexToRGB('#050308'), starA = hexToRGB('#cfd4ff'), starB = hexToRGB(GOLD);
  let s = 991; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let x = 16; x < W - 16; x++) {
    const t = (x - cx) / (W / 2);
    const y = Math.round(cy + Math.sin(x * 0.28) * 5 + t * 3);
    const w = 3 + Math.round(rnd() * 2);
    for (let d = -w; d <= w; d++) {
      const yy = y + d;
      if (inDiamond(x, yy, W, H)) blendPx(cv, x, yy, black, 230 - Math.abs(d) * 30);
    }
    // occasional star point deep inside the crack
    if (rnd() < 0.06) blendPx(cv, x, y, rnd() < 0.5 ? starA : starB, 200);
  }
  save(cv, 'l4_crack.png');
})();

// ---- l4_dark : STATIC-CLOSED gate cells + 갈라진 허공(부유 파편 사이). Deep void with a
// jagged crack silhouette + a few distant star points (부서진 공간). ----
(function darkSeal() {
  const W = 128, H = 64, cv = makeCanvas(W, H);
  const base = hexToRGB(DEEPDK), edge = hexToRGB('#080510'), dead = hexToRGB('#1a1230'), star = hexToRGB('#aeb4ff');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = base;
    const n = smoothCell(x, y, 12, 0x0e0a);
    if (n > 0.66) c = mix(c, dead, 0.25);
    if (onDiamondEdge(x, y, W, H)) c = edge;
    setPx(cv, x, y, c, 255);
  }
  // distant star points inside the void
  let s = 313; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let n = 0; n < 8; n++) {
    const px = 24 + Math.floor(rnd() * (W - 48)), py = 12 + Math.floor(rnd() * (H - 24));
    if (inDiamond(px, py, W, H)) blendPx(cv, px, py, star, 120 + Math.floor(rnd() * 80));
  }
  save(cv, 'l4_dark.png');
})();

// ---- L4 cliff face : amethyst cross-section (128×230, mirrors l2_cliff geometry so it
// drops into the same ridge/apron slot). Amethyst cap band + purple strata + gold weep. ----
(function cliff() {
  const W = 128, H = 230;
  const cv = makeCanvas(W, H);
  const capC = hexToRGB(P_MID), pHi = hexToRGB(P_HI), pMid = hexToRGB(P_MID),
    pSh = hexToRGB(P_SH), pipe = hexToRGB('#4a3670'), gold = hexToRGB(GOLD), amethyst = hexToRGB(AMETHYST);
  const capH = 40;
  for (let y = 0; y < H; y++) {
    const t = y / H;
    const inset = Math.round(6 * Math.sin(t * Math.PI));
    const x0 = inset, x1 = W - inset;
    for (let x = x0; x < x1; x++) {
      const isLeft = x < W / 2;
      let c;
      if (y < capH) {
        c = mix(capC, pHi, clamp(1 - y / capH, 0, 1) * 0.4);
      } else {
        const yy = y - capH;
        const strat = Math.floor(yy / 22);
        const bandBase = (strat % 2 === 0) ? mix(amethyst, pMid, 0.4) : mix(amethyst, pSh, 0.5);
        const vshade = 1 - 0.22 * t;
        c = [Math.round(bandBase[0] * vshade), Math.round(bandBase[1] * vshade), Math.round(bandBase[2] * vshade)];
        if (yy % 22 < 2) c = mix(c, pHi, 0.35);      // amethyst rivet line per strata
        const n = smoothCell(x, y, 10, 0x7a5c);
        if (n > 0.70) c = mix(c, pHi, 0.16);
        else if (n < 0.30) c = mix(c, pSh, 0.30);
      }
      c = isLeft ? mix(c, pSh, 0.28) : mix(c, pHi, 0.10);
      setPx(cv, x, y, c, 255);
    }
  }
  // a rune-conduit seam + faint golden weep under the cap (금색 룬 잔광)
  let s = 71; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  const pipeX = Math.round(W * 0.62);
  for (let y = capH + 10; y < H - 6; y++) {
    blendPx(cv, pipeX, y, pipe, 200);
    blendPx(cv, pipeX - 1, y, pipe, 90);
    blendPx(cv, pipeX + 1, y, pipe, 90);
  }
  for (let x = 12; x < W - 12; x++) if (rnd() < 0.25) blendPx(cv, x, capH + Math.floor(rnd() * 8), gold, 70);
  save(cv, 'l4_cliff.png');
})();

console.log('L4 tiles done.');
