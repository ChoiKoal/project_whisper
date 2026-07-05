'use strict';
// L2-1 — Science-world (Layer 2) TILE generator. Deterministic 128×64 iso diamonds,
// matching the Layer-1 tile fidelity (self-contained PNG encoder copied from
// tools_gen_art.js). Palette per project-whisper-layer2-design-v1.md Part C §1:
//   base 남색 #1a2438, 금속 회색 램프 hi #5a6472 / mid #3a4452 / shadow #222a38,
//   시안 발광 #4ad9c8, 냉각수 독성 청록 #2fbfa8.
// Produces (into assets/tiles/):
//   l2_metal.png (M) l2_metal_broken.png (m) l2_concrete.png (C) l2_concrete_crack.png (c)
//   l2_waste.png (G) l2_ash.png (A) l2_coolant_anim.png (W, 256×64 2-frame)
//   l2_cliff.png (metal-and-concrete cross-section cliff face, 128×230 — mirrors ridge_rock)
// Run: NODE_PATH=... node tools_gen_l2_tiles.js   (no external deps)
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');

// ---- PNG encoder (copied from tools_gen_art.js, unchanged) ----
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
// deterministic value-noise (bilinear smoothstep of a coarse hash grid) — organic patches
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}

// ---- palette (Part C §1) ----
const NAVY = '#1a2438';       // base 남색
const M_HI = '#5a6472';       // 금속 하이라이트
const M_MID = '#3a4452';      // 금속 미드
const M_SH = '#222a38';       // 금속 섀도
const CYAN = '#4ad9c8';       // 시안 발광
const COOLANT = '#2fbfa8';    // 냉각수 독성 청록
const RUST = '#7a4a3a';       // 노출 배선 붉은 녹
const ASH = '#20222a';        // 재/그을음
const WASTE = '#39414e';      // 황무지 회색토
const CONCRETE = '#4a4e56';   // 콘크리트

// Base diamond fill with an interior procedural texture, top-right lit (matches L1
// iso lighting). `tex` chooses the surface treatment; edge is a darker rim.
function makeTile(name, fillHex, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const fill = hexToRGB(fillHex);
  const lo = hexToRGB(opts.loHex || M_SH);
  const hi = hexToRGB(opts.hiHex || M_HI);
  const edge = hexToRGB(opts.edgeHex || M_SH);
  const tex = opts.tex || 'metal';
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      if (!onDiamondEdge(x, y, W, H)) {
        if (tex === 'metal') {
          // large soft tonal patches (worn plate), top-right lit
          const n = smoothCell(x, y, 14, 0x1a24);
          if (n > 0.66) c = mix(c, hi, 0.22);
          else if (n < 0.34) c = mix(c, lo, 0.26);
          if ((x + (H - y)) > 108) c = mix(c, hi, 0.10);   // upper-right sheen
        } else if (tex === 'concrete') {
          const n = smoothCell(x, y, 9, 0x2c0c);
          if (n > 0.60) c = mix(c, hi, 0.16);
          else if (n < 0.36) c = mix(c, lo, 0.20);
        } else if (tex === 'waste') {
          const n = smoothCell(x, y, 11, 0x3d3d);
          if (n > 0.64) c = mix(c, hi, 0.14);
          else if (n < 0.32) c = mix(c, lo, 0.18);
        } else if (tex === 'ash') {
          const n = smoothCell(x, y, 8, 0x5e5e);
          if (n < 0.40) c = mix(c, lo, 0.55);              // dark ash drifts
          else if (n > 0.72) c = mix(c, hi, 0.14);
        }
      }
      if (onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, x, y, c, 255);
    }
  }
  if (opts.after) opts.after(cv, W, H);
  save(cv, name);
}

// Panel seam grid: iso lines dividing the plate into 4 quadrants + a rivet at center.
function panelSeams(cv, W, H, seamHex, rivetHex) {
  const seam = hexToRGB(seamHex), rivet = hexToRGB(rivetHex);
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  for (let x = 0; x < W; x++) {
    for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dx = (x - cx) / (W / 2), dy = (y - cy) / (H / 2);
      // two iso seam lines crossing the middle (the plate join)
      if (Math.abs(dy) < 0.045) blendPx(cv, x, y, seam, 150);        // horizontal iso mid
      if (Math.abs(dx) < 0.030) blendPx(cv, x, y, seam, 130);        // vertical iso mid
    }
  }
  // corner rivets (2×2) at the four sub-plate centers
  const rv = [[0.5, 0.5], [-0.5, 0.5], [0.5, -0.5], [-0.5, -0.5]];
  for (const [rx, ry] of rv) {
    const px = Math.round(cx + rx * (W / 2) * 0.5), py = Math.round(cy + ry * (H / 2) * 0.5);
    for (let a = 0; a < 2; a++) for (let b = 0; b < 2; b++)
      if (inDiamond(px + a, py + b, W, H)) blendPx(cv, px + a, py + b, rivet, 200);
  }
}

// ---- M 금속 바닥 : paneled metal plate, seam lines, subtle wear ----
makeTile('l2_metal.png', NAVY, {
  loHex: M_SH, hiHex: M_HI, edgeHex: M_SH, tex: 'metal',
  after: (cv, W, H) => panelSeams(cv, W, H, M_SH, M_HI),
});

// ---- m 파손 금속 : torn panel, exposed dark under + rust + cyan spark ----
makeTile('l2_metal_broken.png', NAVY, {
  loHex: M_SH, hiHex: M_HI, edgeHex: M_SH, tex: 'metal',
  after: (cv, W, H) => {
    panelSeams(cv, W, H, M_SH, M_MID);
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    const dark = hexToRGB('#0d1018'), rust = hexToRGB(RUST), spark = hexToRGB(CYAN);
    // a torn hole: exposed dark under-structure with a jagged rim, offset to lower-left
    const hx = cx - 16, hy = cy + 6, hr = 18;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      const d = Math.hypot((x - hx), (y - hy) * 2.0);   // iso-squashed radius
      const jag = 0.82 + smoothCell(x * 3, y * 3, 4, 0x77) * 0.4;
      if (d < hr * jag) {
        blendPx(cv, x, y, dark, 235);
        if (d > hr * jag - 3) blendPx(cv, x, y, rust, 160);   // rust rim
      }
    }
    // exposed wiring strands + cyan sparks
    let s = 991;
    const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    for (let n = 0; n < 5; n++) {
      const wx = hx - 10 + Math.floor(rnd() * 20), wy = hy - 8 + Math.floor(rnd() * 16);
      blendPx(cv, wx, wy, rust, 220); blendPx(cv, wx + 1, wy, rust, 180);
      if (rnd() < 0.5) { blendPx(cv, wx, wy - 1, spark, 200); }
    }
  },
});

// ---- C 콘크리트 포장 광장 ----
makeTile('l2_concrete.png', CONCRETE, {
  loHex: '#33363c', hiHex: '#5e626a', edgeHex: '#2c2f34', tex: 'concrete',
  after: (cv, W, H) => {
    // expansion joints: faint iso cross lines (quarter offset)
    const seam = hexToRGB('#33363c');
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    for (let x = 0; x < W; x++) for (let y = 0; y < H; y++) {
      if (!inDiamond(x, y, W, H) || onDiamondEdge(x, y, W, H)) continue;
      const dy = (y - cy) / (H / 2);
      if (Math.abs(dy - 0.5) < 0.03 || Math.abs(dy + 0.5) < 0.03) blendPx(cv, x, y, seam, 110);
    }
  },
});

// ---- c 균열 포장 : cracks + weeds hint ----
makeTile('l2_concrete_crack.png', CONCRETE, {
  loHex: '#33363c', hiHex: '#5e626a', edgeHex: '#2c2f34', tex: 'concrete',
  after: (cv, W, H) => {
    const crack = hexToRGB('#22242a'), weed = hexToRGB('#3d5a48');
    const cx = (W - 1) / 2, cy = (H - 1) / 2;
    // a branching crack walking across the diamond
    let x = cx - 30, y = cy - 6;
    let s = 431; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    for (let i = 0; i < 60 && x < cx + 34; i++) {
      x += 1 + Math.floor(rnd() * 2);
      y += Math.floor(rnd() * 3) - 1;
      if (inDiamond(x, y, W, H)) { blendPx(cv, x, y, crack, 220); if (inDiamond(x, y + 1, W, H)) blendPx(cv, x, y + 1, crack, 120); }
      if (rnd() < 0.14) { const by = y - 1 - Math.floor(rnd() * 3); if (inDiamond(x, by, W, H)) blendPx(cv, x, by, crack, 150); }
      // weed sprouting from a crack, occasionally
      if (rnd() < 0.06 && inDiamond(x, y - 1, W, H)) { blendPx(cv, x, y - 1, weed, 200); blendPx(cv, x, y - 2, weed, 150); }
    }
  },
});

// ---- G 황무지 회색토 ----
makeTile('l2_waste.png', WASTE, { loHex: '#2b323d', hiHex: '#4c5563', edgeHex: '#2b323d', tex: 'waste' });

// ---- A 재/그을음 : dark ash drifts ----
makeTile('l2_ash.png', ASH, {
  loHex: '#131519', hiHex: '#3a3d46', edgeHex: '#131519', tex: 'ash',
  after: (cv, W, H) => {
    // a few soot flecks (near-black) + faint ember specks
    let s = 707; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    const soot = hexToRGB('#0b0c0f'), ember = hexToRGB('#6a3a2a');
    for (let n = 0; n < 26; n++) {
      const px = 12 + Math.floor(rnd() * (W - 24)), py = 8 + Math.floor(rnd() * (H - 16));
      if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) blendPx(cv, px, py, soot, 200);
    }
    for (let n = 0; n < 6; n++) {
      const px = 16 + Math.floor(rnd() * (W - 32)), py = 10 + Math.floor(rnd() * (H - 20));
      if (inDiamond(px, py, W, H)) blendPx(cv, px, py, ember, 150);
    }
  },
});

// ---- W 냉각수 : toxic teal, 2-frame animation (256×64 sheet, like Layer-1 water) ----
(function coolant() {
  const W = 128, H = 64, FR = 2;
  const cv = makeCanvas(W * FR, H);
  const base = hexToRGB(COOLANT), dk = hexToRGB('#1c6b5e'), gl = hexToRGB(CYAN), edge = hexToRGB('#155248');
  for (let f = 0; f < FR; f++) {
    const ox = f * W;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = base;
      // horizontal shimmer bands that shift per frame (flow)
      const band = ((y + f * 2) % 4);
      if (band === 1) c = mix(c, gl, 0.24);
      else if (band === 3) c = mix(c, dk, 0.30);
      // toxic mottling
      const n = smoothCell(x, y + f * 7, 6, 0x2f2f);
      if (n < 0.30) c = mix(c, dk, 0.35);
      else if (n > 0.74) c = mix(c, gl, 0.20);
      if (onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, ox + x, y, c, 255);
    }
    // bright toxic glints, drifting per frame
    let s = 337 + f * 101; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
    for (let n = 0; n < 14; n++) {
      const px = 16 + Math.floor(rnd() * (W - 32)), py = 8 + Math.floor(rnd() * (H - 16));
      if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) { blendPx(cv, ox + px, py, gl, 220); blendPx(cv, ox + px + 1, py, gl, 150); }
    }
  }
  save(cv, 'l2_coolant_anim.png');
})();

// ---- L2 cliff face : metal-and-concrete cross-section (128×230, mirrors ridge_rock geometry
// so it can drop into the ridge/apron slot). Concrete cap band on top, riveted metal strata
// below, exposed rebar + cyan conduit leak. Two-column iso-lit (left shaded / right lit). ----
(function cliff() {
  const W = 128, H = 230;
  const cv = makeCanvas(W, H);
  const capC = hexToRGB(CONCRETE), metalHi = hexToRGB(M_HI), metalMid = hexToRGB(M_MID),
    metalSh = hexToRGB(M_SH), rebar = hexToRGB('#6b6f76'), conduit = hexToRGB(CYAN), rust = hexToRGB(RUST);
  // The wall occupies a 128-wide vertical band; top ~48px is the concrete cap diamond lip,
  // the rest is the metal cross-section. Front face only (matches ridge_rock silhouette:
  // full-width column, bottom seats on the lower diamond).
  const capH = 40;
  for (let y = 0; y < H; y++) {
    // horizontal wall extent: taper very slightly to give a chunky pillar look
    const t = y / H;
    const inset = Math.round(6 * Math.sin(t * Math.PI));   // slight barrel
    const x0 = inset, x1 = W - inset;
    for (let x = x0; x < x1; x++) {
      const isLeft = x < W / 2;
      let c;
      if (y < capH) {
        // concrete cap band, lit top
        c = mix(capC, hexToRGB('#5e626a'), clamp(1 - y / capH, 0, 1) * 0.4);
      } else {
        // metal strata: horizontal riveted bands, quantized shading
        const yy = y - capH;
        const strat = Math.floor(yy / 22);
        const bandBase = (strat % 2 === 0) ? metalMid : metalSh;
        const vshade = 1 - 0.22 * t;                      // darken downward
        c = [Math.round(bandBase[0] * vshade), Math.round(bandBase[1] * vshade), Math.round(bandBase[2] * vshade)];
        // rivet line at the top of each strata band
        if (yy % 22 < 2) c = mix(c, metalHi, 0.35);
        // facet noise
        const n = smoothCell(x, y, 10, 0x9a9a);
        if (n > 0.70) c = mix(c, metalHi, 0.16);
        else if (n < 0.30) c = mix(c, metalSh, 0.30);
      }
      // side lighting: left face shaded, right lit (light upper-right)
      c = isLeft ? mix(c, metalSh, 0.28) : mix(c, metalHi, 0.10);
      setPx(cv, x, y, c, 255);
    }
  }
  // exposed rebar verticals + one cyan conduit leak seeping down the right face
  let s = 55; const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let n = 0; n < 4; n++) {
    const rx = 20 + Math.floor(rnd() * (W - 40));
    for (let y = capH + 6; y < H - 8; y += 1) if (rnd() < 0.9) blendPx(cv, rx, y, rebar, 120);
  }
  // cyan conduit: a glowing vertical seam leaking, with a soft bloom
  const conX = Math.round(W * 0.62);
  for (let y = capH + 10; y < H - 6; y++) {
    blendPx(cv, conX, y, conduit, 200);
    blendPx(cv, conX - 1, y, conduit, 90);
    blendPx(cv, conX + 1, y, conduit, 90);
    if (y % 9 === 0) { blendPx(cv, conX + 2, y, conduit, 60); blendPx(cv, conX - 2, y, conduit, 60); }
  }
  // rust weeping under the cap
  for (let x = 12; x < W - 12; x++) if (rnd() < 0.3) blendPx(cv, x, capH + Math.floor(rnd() * 8), rust, 90);
  save(cv, 'l2_cliff.png');
})();

console.log('L2 tiles done.');

// ---- l2_dark : non-walkable sealed dark floor for STATIC-CLOSED gate cells (B/D/N-gate/O
// base). Reads as an unpowered dead panel; the gate OBJECT art renders on top. Distinct from
// coolant so gates don't look like water. Deep navy with a faint dead-conduit grid. ----
(function darkSeal() {
  const W = 128, H = 64, cv = makeCanvas(W, H);
  const base = hexToRGB('#0f1420'), edge = hexToRGB('#0a0d15'), dead = hexToRGB('#1c2430');
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = base;
    const n = smoothCell(x, y, 12, 0x0f14);
    if (n > 0.66) c = mix(c, dead, 0.25);
    // dead conduit grid (dim)
    const cy2 = (H - 1) / 2, dy = (y - cy2) / (H / 2);
    if (Math.abs(dy) < 0.04) c = mix(c, dead, 0.5);
    if (onDiamondEdge(x, y, W, H)) c = edge;
    setPx(cv, x, y, c, 255);
  }
  save(cv, 'l2_dark.png');
})();
