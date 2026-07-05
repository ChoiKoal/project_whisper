'use strict';
// L3-1 — Machine-world (Layer 3) 「태엽이 멈춘 도시」 TILE generator. Deterministic 128×64 iso
// diamonds, hybrid recolor of the L2 science tiles into copper/brass + orange steam glow
// (design Part C §C-1). L2 was 남색 base + 회색 metal + 시안 발광; L3 hue-shifts to warm:
//   base 구리/갈색 #3a2c1e, 황동 램프 hi #c8a24a / mid #8a6a34 / shadow #4a3820,
//   주황 증기 발광 #ff9a3c (시안 → 주황 180° hue).
// Produces (into assets/tiles/):
//   l3_brass.png (B 황동 포장/기어 플라자) l3_pipe.png (p 파이프라인)
//   l3_grate.png (G 격자 철판/보일러·용광로) l3_platform.png (M 황동 상부 +1)
//   l3_plaza.png (O 대시계 광장 +2) l3_dark.png (게이트 STATIC-CLOSED + 끊긴 동력선 협곡)
//   l3_ramp.png (/ 경사로) l3_cliff.png (구리/황동 절벽 단면, mirrors l2_cliff geometry)
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l3_tiles.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');

// ---- PNG encoder (copied from tools_gen_l2_tiles.js, unchanged) ----
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

// ---- palette (Part C §C-1: 구리/황동 base + 주황 증기 발광) ----
const COPPER = '#3a2c1e';    // base 구리/갈색
const B_HI   = '#c8a24a';    // 밝은 황동 하이라이트
const B_MID  = '#8a6a34';    // 황동 미드
const B_SH   = '#4a3820';    // 황동 섀도
const ORANGE = '#ff9a3c';    // 주황 증기 발광
const EMBER  = '#e8842c';    // 식어가는 화로 잔열
const GRATE  = '#5a4a34';    // 격자 철판 회갈
const IRON   = '#6a5a44';    // 철판 미드
const DEEPDK = '#1a1208';    // 협곡 어둠

function makeTile(name, fillHex, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const fill = hexToRGB(fillHex);
  const lo = hexToRGB(opts.loHex || B_SH);
  const hi = hexToRGB(opts.hiHex || B_HI);
  const edge = hexToRGB(opts.edgeHex || B_SH);
  const tex = opts.tex || 'brass';
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      if (!onDiamondEdge(x, y, W, H)) {
        if (tex === 'brass') {
          const n = smoothCell(x, y, 14, 0x3a2c);
          if (n > 0.66) c = mix(c, hi, 0.24);
          else if (n < 0.34) c = mix(c, lo, 0.26);
          if ((x + (H - y)) > 108) c = mix(c, hi, 0.12);   // upper-right sheen
        } else if (tex === 'grate') {
          const n = smoothCell(x, y, 10, 0x6a5a);
          if (n > 0.60) c = mix(c, hi, 0.14);
          else if (n < 0.36) c = mix(c, lo, 0.22);
        } else if (tex === 'platform') {
          const n = smoothCell(x, y, 13, 0xc8a2);
          if (n > 0.64) c = mix(c, hi, 0.26);
          else if (n < 0.34) c = mix(c, lo, 0.22);
          if ((x + (H - y)) > 104) c = mix(c, hi, 0.14);
        } else if (tex === 'plaza') {
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

// Radial gear-seam overlay: iso seam lines + a small central gear-teeth ring (황동 이음새).
function gearSeams(cv, W, H, seamHex, teethHex) {
  const seam = hexToRGB(seamHex), teeth = hexToRGB(teethHex);
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
    if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
    const dx = (x - cx) / (W / 2), dy = (y - cy) / (H / 2);
    if (Math.abs(dy) < 0.045) blendPx(cv, x, y, seam, 130);
    if (Math.abs(dx) < 0.030) blendPx(cv, x, y, seam, 120);
  }
  // small gear-teeth ring at centre (a hint of the clockwork underneath the pavement)
  for (let a = 0; a < 360; a += 30) {
    const rad = 12;
    const px = Math.round(cx + Math.cos(a * Math.PI / 180) * rad);
    const py = Math.round(cy + Math.sin(a * Math.PI / 180) * rad * 0.5);
    for (let b = 0; b < 2; b++) if (inDiamond(px, py + b, W, H)) blendPx(cv, px, py + b, teeth, 150);
  }
}

// ---- B 황동 포장(기어 플라자) : brass plate + gear seams ----
makeTile('l3_brass.png', COPPER, {
  loHex: B_SH, hiHex: B_HI, edgeHex: B_SH, tex: 'brass',
  after: (cv, W, H) => gearSeams(cv, W, H, B_SH, B_MID),
});

// ---- p 황동 파이프라인 : brass + thick horizontal conduit decal ----
makeTile('l3_pipe.png', COPPER, {
  loHex: B_SH, hiHex: B_HI, edgeHex: B_SH, tex: 'brass',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const pipe = hexToRGB(B_MID), lit = hexToRGB(B_HI), sh = hexToRGB(B_SH);
    // a fat iso pipe running SW→NE across the diamond middle
    for (let x = 8; x < W - 8; x++) {
      const yb = cy + (x - cx) * 0.25;   // iso slope
      for (let t = -7; t <= 7; t++) {
        const y = Math.round(yb + t);
        if (!inDiamond(x, y, W, H)) continue;
        let c = pipe;
        if (t < -3) c = lit;             // top of the cylinder lit
        else if (t > 3) c = sh;          // underside shaded
        blendPx(cv, x, y, c, 235);
      }
    }
    // flange rings every ~28px
    for (let x = 18; x < W - 12; x += 28) {
      const yb = cy + (x - cx) * 0.25;
      for (let t = -7; t <= 7; t++) { const y = Math.round(yb + t); blendPx(cv, x, y, sh, 180); }
    }
  },
});

// ---- G 격자 철판(보일러/용광로) : iron grating + orange ember specks ----
makeTile('l3_grate.png', GRATE, {
  loHex: '#33281a', hiHex: IRON, edgeHex: '#2a2012', tex: 'grate',
  after: (cv, W, H) => {
    const line = hexToRGB('#2a2012'), ember = hexToRGB(EMBER);
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    // iso grating: two families of parallel lines forming a diamond mesh
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dx = x - cx, dy = (y - cy) * 2.0;
      if (Math.abs(((dx + dy) % 20)) < 1.4) blendPx(cv, x, y, line, 130);
      if (Math.abs(((dx - dy) % 20)) < 1.4) blendPx(cv, x, y, line, 130);
    }
    // a few glowing orange embers between the grates (식은 용광로 잔열)
    let s = 611; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    for (let n = 0; n < 5; n++) {
      const px = 24 + Math.floor(rnd() * (W - 48)), py = 14 + Math.floor(rnd() * (H - 28));
      if (inDiamond(px, py, W, H)) { blendPx(cv, px, py, ember, 150); blendPx(cv, px + 1, py, ember, 90); }
    }
  },
});

// ---- M 황동 상부 플랫폼(+1) : bright brass + panel rivets ----
makeTile('l3_platform.png', '#4a3826', {
  loHex: B_SH, hiHex: B_HI, edgeHex: B_SH, tex: 'platform',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const rivet = hexToRGB(B_HI), seam = hexToRGB(B_SH);
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dy = (y - cy) / (H / 2);
      if (Math.abs(dy) < 0.04) blendPx(cv, x, y, seam, 110);
    }
    // rivets at the four sub-plate centres
    for (const [rx, ry] of [[0.5, 0.5], [-0.5, 0.5], [0.5, -0.5], [-0.5, -0.5]]) {
      const px = Math.round(cx + rx * (W / 2) * 0.5), py = Math.round(cy + ry * (H / 2) * 0.5);
      for (let a = 0; a < 2; a++) for (let b = 0; b < 2; b++) if (inDiamond(px + a, py + b, W, H)) blendPx(cv, px + a, py + b, rivet, 200);
    }
  },
});

// ---- O 대시계 광장(+2) : bright brass + radial clock-face decal ----
makeTile('l3_plaza.png', '#4a3624', {
  loHex: B_SH, hiHex: B_HI, edgeHex: B_MID, tex: 'plaza',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const ring = hexToRGB(B_HI), tick = hexToRGB(EMBER);
    // faint radial clock-face: 12 tick marks around a centre ring (the plaza is one big dial)
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

// ---- / 경사로(ramp) : brass with directional tread lines (climbing read) ----
makeTile('l3_ramp.png', '#43321f', {
  loHex: B_SH, hiHex: B_MID, edgeHex: B_SH, tex: 'brass',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const tread = hexToRGB(B_HI), sh = hexToRGB(B_SH);
    // horizontal tread rungs stepping up (a ramp, not flat plate)
    for (let k = -4; k <= 4; k++) {
      const yb = cy + k * 6;
      for (let x = 0; x < W; x++) { const y = Math.round(yb + (x - cx) * 0.02); if (inDiamond(x, y, W, H) && !onDiamondEdge(x, y, W, H)) { blendPx(cv, x, y, tread, 120); blendPx(cv, x, y + 1, sh, 90); } }
    }
  },
});

// ---- l3_dark : STATIC-CLOSED gate cells + 끊긴 동력선 협곡. Deep dark with a limp
// hanging cable silhouette (죽은 동력선, no flow animation). Reads as unpowered / a gap. ----
(function darkSeal() {
  const W = 128, H = 64, cv = makeCanvas(W, H);
  const base = hexToRGB(DEEPDK), edge = hexToRGB('#0d0904'), dead = hexToRGB('#2a2012'), cable = hexToRGB('#241a10');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = base;
    const n = smoothCell(x, y, 12, 0x1a12);
    if (n > 0.66) c = mix(c, dead, 0.25);
    if (onDiamondEdge(x, y, W, H)) c = edge;
    setPx(cv, x, y, c, 255);
  }
  // a limp severed power cable drooping across (catenary), dead — no glow
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  for (let x = 20; x < W - 20; x++) {
    const t = (x - cx) / (W / 2);
    const y = Math.round(cy - 4 + t * t * 18);   // sag down in the middle
    if (inDiamond(x, y, W, H)) { blendPx(cv, x, y, cable, 220); blendPx(cv, x, y + 1, cable, 140); }
  }
  save(cv, 'l3_dark.png');
})();

// ---- L3 cliff face : copper/brass cross-section (128×230, mirrors l2_cliff geometry so it
// drops into the same ridge/apron slot). Brass cap band + copper strata + one dead conduit. ----
(function cliff() {
  const W = 128, H = 230;
  const cv = makeCanvas(W, H);
  const capC = hexToRGB(B_MID), bHi = hexToRGB(B_HI), bMid = hexToRGB(B_MID),
    bSh = hexToRGB(B_SH), pipe = hexToRGB('#6a5030'), ember = hexToRGB(EMBER), copp = hexToRGB(COPPER);
  const capH = 40;
  for (let y = 0; y < H; y++) {
    const t = y / H;
    const inset = Math.round(6 * Math.sin(t * Math.PI));
    const x0 = inset, x1 = W - inset;
    for (let x = x0; x < x1; x++) {
      const isLeft = x < W / 2;
      let c;
      if (y < capH) {
        c = mix(capC, bHi, clamp(1 - y / capH, 0, 1) * 0.4);
      } else {
        const yy = y - capH;
        const strat = Math.floor(yy / 22);
        const bandBase = (strat % 2 === 0) ? mix(copp, bMid, 0.4) : mix(copp, bSh, 0.5);
        const vshade = 1 - 0.22 * t;
        c = [Math.round(bandBase[0] * vshade), Math.round(bandBase[1] * vshade), Math.round(bandBase[2] * vshade)];
        if (yy % 22 < 2) c = mix(c, bHi, 0.35);      // brass rivet line per strata
        const n = smoothCell(x, y, 10, 0x9a3a);
        if (n > 0.70) c = mix(c, bHi, 0.16);
        else if (n < 0.30) c = mix(c, bSh, 0.30);
      }
      c = isLeft ? mix(c, bSh, 0.28) : mix(c, bHi, 0.10);
      setPx(cv, x, y, c, 255);
    }
  }
  // a dead vertical pipe seam + faint orange ember weep under the cap (식어가는 잔열)
  let s = 71; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  const pipeX = Math.round(W * 0.62);
  for (let y = capH + 10; y < H - 6; y++) {
    blendPx(cv, pipeX, y, pipe, 200);
    blendPx(cv, pipeX - 1, y, pipe, 90);
    blendPx(cv, pipeX + 1, y, pipe, 90);
  }
  for (let x = 12; x < W - 12; x++) if (rnd() < 0.25) blendPx(cv, x, capH + Math.floor(rnd() * 8), ember, 70);
  save(cv, 'l3_cliff.png');
})();

console.log('L3 tiles done.');
