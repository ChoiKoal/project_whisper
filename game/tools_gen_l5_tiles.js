'use strict';
// L5-1 — Divinity-world (Layer 5) 「응답 없는 대성당」 TILE generator. Deterministic 128×64 iso
// diamonds, hybrid DESATURATE recolor of the L4 magic tiles into 창백한 상아·백은 + 잿빛 +
// 희미한 호박빛 잔불 (design Part C §C-1). L4 was 자수정 보라 base + 금색 룬 발광; L5 shifts to
// the END of the saturation lineage — 채도를 뺀 세계:
//   base 창백한 상아 #e6e0d4, 상아 램프 hi #f2eee4 / mid #9a9385 / shadow #6b6459,
//   잿빛 악센트 #4a463f, 희미한 호박빛 발광 #e0a94a (꺼져가는 잔불 — L4 금색보다 약하게, 은은하게).
// Produces (into assets/tiles/):
//   l5_ivory.png (P 상아 포장/참배길) l5_silver.png (L 백은 수면 광장)
//   l5_quiet.png (Q 침묵의 회랑 +1) l5_choir.png (C 상부 성가 회랑 +1)
//   l5_altar.png (O 대제단 +2) l5_dark.png (게이트 STATIC-CLOSED + 바래 사라진 허공)
//   l5_ramp.png (/ 경사로) l5_cliff.png (상아 절벽 단면)
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l5_tiles.js
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');

// ---- PNG encoder (copied from tools_gen_l4_tiles.js, unchanged) ----
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

// ---- palette (Part C §C-1: 창백한 상아·백은 base + 잿빛 + 희미한 호박빛 잔불 발광) ----
const IVORY    = '#e6e0d4';    // base 창백한 상아
const I_HI     = '#f2eee4';    // 상아 하이라이트
const I_MID    = '#9a9385';    // 상아 미드 그림자
const I_SH     = '#6b6459';    // 상아 섀도
const SILVER   = '#cdd0d4';    // 백은 (수면 광장)
const SILVER_HI= '#eef0f3';    // 백은 하이라이트
const ASH       = '#4a463f';   // 잿빛 악센트 (돌·재)
const AMBER    = '#e0a94a';    // 희미한 호박빛 발광 (꺼져가는 잔불)
const AMBER_DK = '#b0852f';    // 어두운 호박빛
const STONE    = '#b7b0a2';    // 성가 회랑 석판 회상아
const IRON     = '#8b8577';    // 석판 미드
const DEEPDK   = '#141119';    // 바래 사라진 허공 (안개 낀 상아빛 어둠)

function makeTile(name, fillHex, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const fill = hexToRGB(fillHex);
  const lo = hexToRGB(opts.loHex || I_SH);
  const hi = hexToRGB(opts.hiHex || I_HI);
  const edge = hexToRGB(opts.edgeHex || I_SH);
  const tex = opts.tex || 'ivory';
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      if (!onDiamondEdge(x, y, W, H)) {
        if (tex === 'ivory') {
          const n = smoothCell(x, y, 14, 0xe6e0);
          if (n > 0.66) c = mix(c, hi, 0.22);
          else if (n < 0.34) c = mix(c, lo, 0.20);
          if ((x + (H - y)) > 108) c = mix(c, hi, 0.14);   // upper-right sheen (남은 빛)
        } else if (tex === 'silver') {
          const n = smoothCell(x, y, 12, 0xcdd0);
          if (n > 0.60) c = mix(c, hi, 0.20);
          else if (n < 0.36) c = mix(c, lo, 0.16);
          if ((x + (H - y)) > 100) c = mix(c, hi, 0.16);
        } else if (tex === 'quiet') {
          const n = smoothCell(x, y, 13, 0x9a93);
          if (n > 0.64) c = mix(c, hi, 0.18);
          else if (n < 0.34) c = mix(c, lo, 0.20);
        } else if (tex === 'choir') {
          const n = smoothCell(x, y, 10, 0xb7b0);
          if (n > 0.60) c = mix(c, hi, 0.12);
          else if (n < 0.36) c = mix(c, lo, 0.20);
        } else if (tex === 'altar') {
          const n = smoothCell(x, y, 16, 0xa001);
          if (n > 0.62) c = mix(c, hi, 0.24);
          else if (n < 0.34) c = mix(c, lo, 0.16);
        }
      }
      if (onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, x, y, c, 255);
    }
  }
  if (opts.after) opts.after(cv, W, H);
  save(cv, name);
}

// Faint seam overlay: iso seam lines + a small central amber ember dot (빛이 남은 자리만 하얗게).
function faintSeams(cv, W, H, seamHex, emberHex) {
  const seam = hexToRGB(seamHex), ember = hexToRGB(emberHex);
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
    if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
    const dx = (x - cx) / (W / 2), dy = (y - cy) / (H / 2);
    if (Math.abs(dy) < 0.045) blendPx(cv, x, y, seam, 90);
    if (Math.abs(dx) < 0.030) blendPx(cv, x, y, seam, 80);
  }
  // a single faint amber ember at centre (남은 온기만큼만 — 최소 발광 면적)
  blendPx(cv, cx, cy, ember, 120);
  blendPx(cv, cx + 1, cy, ember, 70);
}

// ---- P 상아 포장(등불의 참배길) : ivory plate + bleached joint decals ----
makeTile('l5_ivory.png', IVORY, {
  loHex: I_SH, hiHex: I_HI, edgeHex: I_MID, tex: 'ivory',
  after: (cv, W, H) => faintSeams(cv, W, H, I_MID, AMBER),
});

// ---- L 백은 수면 광장(생명의 샘 광장) : silver + dry-basin reflection decal ----
makeTile('l5_silver.png', SILVER, {
  loHex: I_MID, hiHex: SILVER_HI, edgeHex: I_MID, tex: 'silver',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const refl = hexToRGB(SILVER_HI), mark = hexToRGB(I_MID);
    // faint concentric "물이 있던 자국" rings
    for (let ring = 10; ring < 30; ring += 8) {
      for (let a = 0; a < 360; a += 5) {
        const px = Math.round(cx + Math.cos(a * Math.PI / 180) * ring);
        const py = Math.round(cy + Math.sin(a * Math.PI / 180) * ring * 0.5);
        if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) blendPx(cv, px, py, mark, 60);
      }
    }
    // a bright silver reflection band (물이 있던 자국의 잔광)
    for (let x = -28; x < 28; x++) { const y = cy - 4; blendPx(cv, cx + x, y, refl, 70); }
  },
});

// ---- Q 침묵의 회랑 바닥(+1, '무음' 연출) : quiet stone + fade-inward decal ----
makeTile('l5_quiet.png', '#d8d2c6', {
  loHex: I_SH, hiHex: I_HI, edgeHex: I_MID, tex: 'quiet',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const seam = hexToRGB(I_MID), hush = hexToRGB('#c2bcb0');
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dy = (y - cy) / (H / 2);
      if (Math.abs(dy) < 0.04) blendPx(cv, x, y, seam, 90);
    }
    // '무음' inward fade — a soft desaturated ring toward centre (소리가 삼켜지는 시각 힌트)
    for (let a = 0; a < 360; a += 3) {
      for (let r = 8; r < 16; r++) {
        const px = Math.round(cx + Math.cos(a * Math.PI / 180) * r);
        const py = Math.round(cy + Math.sin(a * Math.PI / 180) * r * 0.5);
        if (inDiamond(px, py, W, H)) blendPx(cv, px, py, hush, 40);
      }
    }
  },
});

// ---- C 상부 성가 회랑(+1) : ivory stone + choir-colonnade shadow decal ----
makeTile('l5_choir.png', STONE, {
  loHex: '#8b8577', hiHex: I_HI, edgeHex: '#6b6459', tex: 'choir',
  after: (cv, W, H) => {
    const line = hexToRGB('#6b6459'), amber = hexToRGB(AMBER);
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    // iso stone seams: two families forming a diamond mesh (성가대 열주 그림자)
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dx = x - cx, dy = (y - cy) * 2.0;
      if (Math.abs(((dx + dy) % 24)) < 1.4) blendPx(cv, x, y, line, 90);
      if (Math.abs(((dx - dy) % 24)) < 1.4) blendPx(cv, x, y, line, 90);
    }
    // a faint amber ember at centre (남은 잔불)
    blendPx(cv, cx, cy, amber, 110);
  },
});

// ---- O 대제단(+2) : bright ivory + radial amber offering-ring decal (신의 잔불) ----
makeTile('l5_altar.png', '#efe9dd', {
  loHex: I_SH, hiHex: I_HI, edgeHex: I_MID, tex: 'altar',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const ring = hexToRGB(I_HI), tick = hexToRGB(AMBER);
    // faint radial offering circle: 12 ticks around an amber centre ring (봉헌 원진)
    for (let a = 0; a < 360; a += 30) {
      for (let r = 16; r < 26; r++) {
        const px = Math.round(cx + Math.cos(a * Math.PI / 180) * r);
        const py = Math.round(cy + Math.sin(a * Math.PI / 180) * r * 0.5);
        if (inDiamond(px, py, W, H)) blendPx(cv, px, py, tick, 70);
      }
    }
    for (let a = 0; a < 360; a += 6) {
      const px = Math.round(cx + Math.cos(a * Math.PI / 180) * 14);
      const py = Math.round(cy + Math.sin(a * Math.PI / 180) * 7);
      if (inDiamond(px, py, W, H)) blendPx(cv, px, py, ring, 70);
    }
    blendPx(cv, cx, cy, tick, 130);
  },
});

// ---- / 경사로(ramp) : ivory with directional tread lines (오름 순례 read) ----
makeTile('l5_ramp.png', '#ded8cc', {
  loHex: I_SH, hiHex: I_MID, edgeHex: I_MID, tex: 'ivory',
  after: (cv, W, H) => {
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const tread = hexToRGB(AMBER), sh = hexToRGB(I_SH);
    for (let k = -4; k <= 4; k++) {
      const yb = cy + k * 6;
      for (let x = 0; x < W; x++) { const y = Math.round(yb + (x - cx) * 0.02); if (inDiamond(x, y, W, H) && !onDiamondEdge(x, y, W, H)) { blendPx(cv, x, y, tread, 80); blendPx(cv, x, y + 1, sh, 80); } }
    }
  },
});

// ---- l5_dark : STATIC-CLOSED gate cells + 바래 사라진 허공. Static ivory mist + a few
// very distant ember points (붕괴가 아니라 '바래 사라짐' — L4 crack silhouette 대신 안개). ----
(function darkSeal() {
  const W = 128, H = 64, cv = makeCanvas(W, H);
  const base = hexToRGB(DEEPDK), edge = hexToRGB('#0e0c14'), mist = hexToRGB('#2a2830'), ember = hexToRGB(AMBER_DK);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = base;
    const n = smoothCell(x, y, 14, 0x1411);
    if (n > 0.62) c = mix(c, mist, 0.35);   // drifting ivory mist
    if (onDiamondEdge(x, y, W, H)) c = edge;
    setPx(cv, x, y, c, 255);
  }
  // a couple of very distant amber ember points inside the faded void
  let s = 313; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let n = 0; n < 4; n++) {
    const px = 30 + Math.floor(rnd() * (W - 60)), py = 14 + Math.floor(rnd() * (H - 28));
    if (inDiamond(px, py, W, H)) blendPx(cv, px, py, ember, 70 + Math.floor(rnd() * 40));
  }
  save(cv, 'l5_dark.png');
})();

// ---- L5 cliff face : ivory cross-section (128×230, mirrors l4/l2_cliff geometry so it
// drops into the same ridge/apron slot). Ivory cap band + ash strata + faint amber weep. ----
(function cliff() {
  const W = 128, H = 230;
  const cv = makeCanvas(W, H);
  const capC = hexToRGB(I_MID), iHi = hexToRGB(I_HI), iMid = hexToRGB(I_MID),
    iSh = hexToRGB(I_SH), seam = hexToRGB(ASH), amber = hexToRGB(AMBER), ivory = hexToRGB(IVORY);
  const capH = 40;
  for (let y = 0; y < H; y++) {
    const t = y / H;
    const inset = Math.round(6 * Math.sin(t * Math.PI));
    const x0 = inset, x1 = W - inset;
    for (let x = x0; x < x1; x++) {
      const isLeft = x < W / 2;
      let c;
      if (y < capH) {
        c = mix(capC, iHi, clamp(1 - y / capH, 0, 1) * 0.4);
      } else {
        const yy = y - capH;
        const strat = Math.floor(yy / 22);
        const bandBase = (strat % 2 === 0) ? mix(ivory, iMid, 0.4) : mix(ivory, iSh, 0.4);
        const vshade = 1 - 0.20 * t;
        c = [Math.round(bandBase[0] * vshade), Math.round(bandBase[1] * vshade), Math.round(bandBase[2] * vshade)];
        if (yy % 22 < 2) c = mix(c, iHi, 0.35);      // ivory rivet line per strata
        const n = smoothCell(x, y, 10, 0x9a93);
        if (n > 0.70) c = mix(c, iHi, 0.14);
        else if (n < 0.30) c = mix(c, iSh, 0.26);
      }
      c = isLeft ? mix(c, iSh, 0.24) : mix(c, iHi, 0.10);
      setPx(cv, x, y, c, 255);
    }
  }
  // a faint ash seam + amber weep under the cap (희미한 호박빛 잔광)
  let s = 71; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  const seamX = Math.round(W * 0.62);
  for (let y = capH + 10; y < H - 6; y++) {
    blendPx(cv, seamX, y, seam, 150);
    blendPx(cv, seamX - 1, y, seam, 70);
    blendPx(cv, seamX + 1, y, seam, 70);
  }
  for (let x = 12; x < W - 12; x++) if (rnd() < 0.18) blendPx(cv, x, capH + Math.floor(rnd() * 8), amber, 50);
  save(cv, 'l5_cliff.png');
})();

console.log('L5 tiles done.');
