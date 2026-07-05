// Placeholder art generator for Project Whisper M1.
// Minimal zlib-backed PNG encoder (RGBA, 8-bit) using Node's built-in zlib.
// Generates: 8 isometric diamond tiles (128x64), a character sheet (96x96 frames),
// and 2 tree objects (128x256).
'use strict';
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const OUT = __dirname;

// ---- PNG encoder ----
function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1));
  }
  return (~c) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const typeBuf = Buffer.from(type, 'ascii');
  const body = Buffer.concat([typeBuf, data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
// pixels: Uint8Array length w*h*4 (RGBA)
function encodePNG(w, h, pixels) {
  const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;   // bit depth
  ihdr[9] = 6;   // color type RGBA
  ihdr[10] = 0;  // compression
  ihdr[11] = 0;  // filter
  ihdr[12] = 0;  // interlace
  // raw scanlines with filter byte 0
  const stride = w * 4;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (stride + 1)] = 0;
    pixels.copy
      ? pixels.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride)
      : Buffer.from(pixels.buffer, y * stride, stride).copy(raw, y * (stride + 1) + 1);
  }
  const idatData = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([
    sig,
    chunk('IHDR', ihdr),
    chunk('IDAT', idatData),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// ---- drawing helpers ----
function makeCanvas(w, h) {
  return { w, h, data: Buffer.alloc(w * h * 4, 0) }; // transparent
}
function hexToRGB(hex) {
  const s = hex.replace('#', '');
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function setPx(cv, x, y, rgb, a = 255) {
  if (x < 0 || y < 0 || x >= cv.w || y >= cv.h) return;
  const i = (y * cv.w + x) * 4;
  cv.data[i] = rgb[0]; cv.data[i + 1] = rgb[1]; cv.data[i + 2] = rgb[2]; cv.data[i + 3] = a;
}
function fillRect(cv, x0, y0, x1, y1, rgb, a = 255) {
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) setPx(cv, x, y, rgb, a);
}
function save(cv, name) {
  const png = encodePNG(cv.w, cv.h, cv.data);
  fs.writeFileSync(path.join(OUT, name), png);
  console.log('wrote', name, png.length, 'bytes');
}

// Diamond membership: for a 128x64 tile, point (x,y) is inside the 2:1 diamond
// centered at (64,32) if |x-64|/64 + |y-32|/32 <= 1.
function inDiamond(x, y, w, h) {
  const cx = (w - 1) / 2, cy = (h - 1) / 2;
  return Math.abs(x - cx) / (w / 2) + Math.abs(y - cy) / (h / 2) <= 1.0 + 1e-6;
}
function onDiamondEdge(x, y, w, h) {
  // approximate 1px edge band
  const cx = (w - 1) / 2, cy = (h - 1) / 2;
  const d = Math.abs(x - cx) / (w / 2) + Math.abs(y - cy) / (h / 2);
  return d > 0.88 && d <= 1.0 + 1e-6;
}

// ---- colour helpers (tile texture density, v0.3.0) ----
// Small deterministic tone shift of an rgb toward another rgb by t (0..1).
function mix(a, b, t) {
  return [
    Math.round(a[0] * (1 - t) + b[0] * t),
    Math.round(a[1] * (1 - t) + b[1] * t),
    Math.round(a[2] * (1 - t) + b[2] * t),
  ];
}

// ---- Tile generation ----
// spec: fill color, optional edge color, optional dot color + density, dither for water
//
// v0.3.0 tile texture density: the base diamond fields were flat single-colour
// fields, reading as plastic under the new diorama lighting. Each ground family now
// carries a richer *procedural* interior texture (still 128×64, still deterministic,
// still palette-strict — the extra tones are all art-guide §3 ramp colours). The
// silhouette + soft v0.2.0 edge blend are UNCHANGED (subtle), so M4 tile counts and
// save diffs stay exact. Texture kind is chosen by opts.tex:
//   "grass" — directional blade strokes + 2-3 green tonal patches
//   "dirt"  — pebbles + horizontal strata specks
//   "water" — horizontal shimmer bands + sparse bright highlight pixels
//   "mud"   — wet blotches (darker + a couple glossy specks)
function makeTile(name, fillHex, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const fill = hexToRGB(fillHex);
  // Ground readability (v0.2.0): the per-tile diamond outline was reading as a
  // hard checkerboard. Soften every tile's edge by blending the declared edge
  // colour ~40% toward the fill (so contrast drops to ~40% of the original),
  // UNLESS the caller opts out (opts.hardEdge — used by VOID/mystic whose violet
  // rim is a deliberate world signature). Fully deterministic.
  const EDGE_MIX = opts.edgeMix !== undefined ? opts.edgeMix : 0.6; // 0.6 fill / 0.4 edge
  let edge = opts.edgeHex ? hexToRGB(opts.edgeHex) : null;
  if (edge && !opts.hardEdge) {
    edge = edge.map((v, i) => Math.round(v * (1 - EDGE_MIX) + fill[i] * EDGE_MIX));
  }
  const dot = opts.dotHex ? hexToRGB(opts.dotHex) : null;
  // deterministic pseudo-random for dot placement (unchanged seed → flower/clover
  // dots land exactly where they did in v0.2.x for the decorated variants).
  let seed = 1234567;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };

  // Optional richer interior texture. Uses its OWN separate seed stream (keyed off
  // the tile name) so it never perturbs the flower/clover `rnd` sequence above.
  const tex = opts.tex || null;
  let tseed = 0;
  for (let i = 0; i < name.length; i++) tseed = (tseed * 131 + name.charCodeAt(i)) & 0x7fffffff;
  tseed = (tseed ^ 0x5bd1e995) & 0x7fffffff;
  const trnd = () => { tseed = (tseed * 1103515245 + 12345) & 0x7fffffff; return tseed / 0x7fffffff; };
  // Palette-strict tone families per texture kind (all art-guide §3 ramp colours).
  const texTones = tex ? {
    grass: { lo: hexToRGB(opts.texLo || '#4d8b4f'), hi: hexToRGB(opts.texHi || '#a8d982'), blade: hexToRGB(opts.texLo || '#4d8b4f') },
    dirt:  { lo: hexToRGB('#5c4433'), hi: hexToRGB('#b59268'), blade: hexToRGB('#3a2a20') },
    water: { lo: hexToRGB(opts.texLo || '#2e6b8a'), hi: hexToRGB(opts.texHi || '#8fd4d9'), blade: null },
    mud:   { lo: hexToRGB('#3a2a20'), hi: hexToRGB('#8a6a4a'), blade: hexToRGB('#3a2a20') },
  }[tex] : null;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      // water dither: two-tone checker on the surface
      if (opts.dither) {
        const alt = hexToRGB(opts.ditherHex);
        if (((x >> 2) + (y >> 1)) % 2 === 0) c = alt;
      }
      // ---- procedural interior texture (v0.3.0) ----
      if (texTones && !onDiamondEdge(x, y, W, H)) {
        if (tex === 'grass') {
          // large soft tonal patches from value-noise-ish hash, top-right lit.
          const n = smoothCell(x, y, 16, 0x1111);
          const n2 = smoothCell(x, y, 7, 0x2222);
          if (n > 0.66) c = mix(c, texTones.hi, 0.35);
          else if (n < 0.34) c = mix(c, texTones.lo, 0.30);
          // faint upper-right lift
          if (n2 > 0.6 && (x + (H - y)) > 96) c = mix(c, texTones.hi, 0.18);
        } else if (tex === 'dirt') {
          const n = smoothCell(x, y, 12, 0x3333);
          if (n > 0.60) c = mix(c, texTones.hi, 0.28);
          else if (n < 0.36) c = mix(c, texTones.lo, 0.30);
          // horizontal strata specks
          if (((y % 6) === 0) && smoothCell(x, y, 3, 0x4444) > 0.62) c = mix(c, texTones.lo, 0.5);
        } else if (tex === 'water') {
          // horizontal shimmer bands (already dithered above): lighten alternating rows.
          if ((y % 4) === 1) c = mix(c, texTones.hi, 0.30);
          else if ((y % 4) === 3) c = mix(c, texTones.lo, 0.25);
        } else if (tex === 'mud') {
          const n = smoothCell(x, y, 10, 0x5555);
          if (n < 0.32) c = mix(c, texTones.lo, 0.45);   // wet dark blotches
          else if (n > 0.70) c = mix(c, texTones.hi, 0.22);
        }
      }
      if (edge && onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, x, y, c, 255);
    }
  }

  // ---- directional blade strokes / pebbles / highlight pixels (overlaid) ----
  if (texTones) {
    if (tex === 'grass') {
      // short directional blade strokes (2-3px), leaning up-right (top-right light).
      const strokes = 34;
      for (let n = 0; n < strokes; n++) {
        const bx = 14 + Math.floor(trnd() * (W - 28));
        const by = 8 + Math.floor(trnd() * (H - 16));
        const len = 2 + Math.floor(trnd() * 3);
        const dark = trnd() < 0.5;
        const col = dark ? texTones.lo : texTones.hi;
        for (let k = 0; k < len; k++) {
          const px = bx + k, py = by - k; // up-right lean
          if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) setPx(cv, px, py, col, 255);
        }
      }
    } else if (tex === 'dirt') {
      // scattered pebbles (2×2, mid-grey-brown) + a few dark specks.
      const peb = hexToRGB('#8a6a4a'), pebLit = hexToRGB('#b59268'), speck = hexToRGB('#3a2a20');
      for (let n = 0; n < 20; n++) {
        const px = 12 + Math.floor(trnd() * (W - 24));
        const py = 8 + Math.floor(trnd() * (H - 16));
        if (!inDiamond(px, py, W, H) || onDiamondEdge(px, py, W, H)) continue;
        setPx(cv, px, py, pebLit); setPx(cv, px + 1, py, peb);
        setPx(cv, px, py + 1, peb); setPx(cv, px + 1, py + 1, mix(peb, speck, 0.5));
      }
      for (let n = 0; n < 26; n++) {
        const px = 10 + Math.floor(trnd() * (W - 20));
        const py = 6 + Math.floor(trnd() * (H - 12));
        if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) setPx(cv, px, py, speck);
      }
    } else if (tex === 'water') {
      // sparse bright highlight pixels (shimmer glints), top-right biased.
      const glint = hexToRGB('#8fd4d9');
      for (let n = 0; n < 16; n++) {
        const px = 16 + Math.floor(trnd() * (W - 32));
        const py = 8 + Math.floor(trnd() * (H - 16));
        if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) {
          setPx(cv, px, py, glint, 235); setPx(cv, px + 1, py, glint, 200);
        }
      }
    } else if (tex === 'mud') {
      // a couple glossy wet specks (cream, low alpha) for the sheen.
      const gloss = hexToRGB('#b8b4a8');
      for (let n = 0; n < 8; n++) {
        const px = 20 + Math.floor(trnd() * (W - 40));
        const py = 12 + Math.floor(trnd() * (H - 24));
        if (inDiamond(px, py, W, H) && !onDiamondEdge(px, py, W, H)) setPx(cv, px, py, gloss, 130);
      }
    }
  }

  // scatter dots (flowers/clover) inside diamond, not on edge
  if (dot) {
    const count = opts.dotCount || 10;
    for (let n = 0; n < count; n++) {
      const x = 8 + Math.floor(rnd() * (W - 16));
      const y = 6 + Math.floor(rnd() * (H - 12));
      if (inDiamond(x, y, W, H) && !onDiamondEdge(x, y, W, H)) {
        // 2x2 dot
        setPx(cv, x, y, dot); setPx(cv, x + 1, y, dot);
        setPx(cv, x, y + 1, dot); setPx(cv, x + 1, y + 1, dot);
      }
    }
  }
  save(cv, name);
}

// Deterministic smooth value in [0,1] from a coarse hash grid with bilinear
// smoothstep interp — used for organic tonal patches inside tiles.
function hcell(ix, iy, salt) {
  let h = (ix * 374761393) ^ (iy * 668265263) ^ (salt * 2246822519);
  h = (h ^ (h >>> 13)) >>> 0;
  h = (h * 1274126177) >>> 0;
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}
function smoothCell(x, y, cell, salt) {
  const gx = x / cell, gy = y / cell;
  const x0 = Math.floor(gx), y0 = Math.floor(gy);
  let fx = gx - x0, fy = gy - y0;
  fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
  const n00 = hcell(x0, y0, salt), n10 = hcell(x0 + 1, y0, salt);
  const n01 = hcell(x0, y0 + 1, salt), n11 = hcell(x0 + 1, y0 + 1, salt);
  const nx0 = n00 * (1 - fx) + n10 * fx;
  const nx1 = n01 * (1 - fx) + n11 * fx;
  return nx0 * (1 - fy) + nx1 * fy;
}

// T0 VOID: dark with violet edge hint — keep the violet rim strong (world signature).
makeTile('t0_void.png', '#2a2a33', { edgeHex: '#6b4a9e', hardEdge: true });

// T0 HOLLOW (v0.3.1): "빈 자국" — an interior gathered tile. Unlike the border VOID
// (a hard-rimmed violet-edged hole), the hollow is a WALKABLE dark-earthen depression:
// a brownish-dark #201a18 basin that sinks toward the center with soft (not hard)
// edges and faint violet ember flecks — reads as "채집당한 흔적" you can still walk
// over. Deterministic (own name-seeded stream). Distinct from the border void, which
// is mostly hidden under the cliff skirts anyway.
function makeHollowTile(name) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const rim   = hexToRGB('#3a2a20');  // earthen rim (soft, brown)
  const mid   = hexToRGB('#2a201c');  // mid basin
  const deep  = hexToRGB('#201a18');  // deep center (spec)
  const ember = hexToRGB('#9e7ad9');  // faint violet ember
  const emberLit = hexToRGB('#d9b8ff');
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  // name-seeded deterministic stream (ember fleck placement).
  let s = 0; for (let i = 0; i < name.length; i++) s = (s * 131 + name.charCodeAt(i)) & 0x7fffffff;
  s = (s ^ 0x5bd1e995) & 0x7fffffff;
  const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      // normalized diamond radius 0 (center) .. 1 (edge)
      const d = Math.abs(x - cx) / (W / 2) + Math.abs(y - cy) / (H / 2);
      // basin gradient: deep at center, mid, then a soft earthen rim near the edge.
      let c;
      if (d < 0.45) c = deep;
      else if (d < 0.78) c = mix(deep, mid, (d - 0.45) / 0.33);
      else c = mix(mid, rim, (d - 0.78) / 0.22);
      // top-right soft light: lift the upper-right basin wall a touch.
      if ((x - cx) - (y - cy) * 2 > 40 && d > 0.4 && d < 0.85) c = mix(c, rim, 0.35);
      setPx(cv, x, y, c, 255);
    }
  }
  // faint violet ember flecks scattered in the basin (few, low alpha) — the "still-warm
  // emptied spot" signature, subtler than the border void's whole violet rim.
  for (let n = 0; n < 10; n++) {
    const px = 24 + Math.floor(rnd() * (W - 48));
    const py = 12 + Math.floor(rnd() * (H - 24));
    if (!inDiamond(px, py, W, H) || onDiamondEdge(px, py, W, H)) continue;
    const bright = rnd() < 0.35;
    setPx(cv, px, py, bright ? emberLit : ember, bright ? 150 : 110);
  }
  save(cv, name);
}
makeHollowTile('t0_hollow.png');
// T1 dirt path — pebbles + strata specks.
makeTile('t1_dirt.png', '#8a6a4a', { edgeHex: '#5c4433', tex: 'dirt' });
// T2A grass — blade strokes + 2-3 green tonal patches.
makeTile('t2a_grass.png', '#7ab567', { edgeHex: '#4d8b4f', tex: 'grass', texLo: '#4d8b4f', texHi: '#a8d982' });
// T2B grass + pink flowers
makeTile('t2b_grass_flowers.png', '#7ab567', { edgeHex: '#4d8b4f', tex: 'grass', texLo: '#4d8b4f', texHi: '#a8d982', dotHex: '#f0a8b8', dotCount: 14 });
// T2C grass + clover (darker green dots) — darker grass tone family.
makeTile('t2c_grass_clover.png', '#4d8b4f', { edgeHex: '#2e5d3b', tex: 'grass', texLo: '#2e5d3b', texHi: '#7ab567', dotHex: '#7ab567', dotCount: 12 });
// T2D flower grass, light with white dots — bright grass tone family.
makeTile('t2d_flower_grass.png', '#a8d982', { edgeHex: '#7ab567', tex: 'grass', texLo: '#7ab567', texHi: '#faf5e6', dotHex: '#faf5e6', dotCount: 16 });
// T4 mud — wet blotches.
makeTile('t4_mud.png', '#5c4433', { edgeHex: '#3a2a20', tex: 'mud' });
// T5A water — horizontal shimmer bands + sparse highlight glints.
makeTile('t5a_water.png', '#4aa3b8', { edgeHex: '#2e6b8a', dither: true, ditherHex: '#8fd4d9', tex: 'water', texLo: '#2e6b8a', texHi: '#8fd4d9' });
// T5B water2
makeTile('t5b_water2.png', '#2e6b8a', { edgeHex: '#1e3a5c', dither: true, ditherHex: '#4aa3b8', tex: 'water', texLo: '#1e3a5c', texHi: '#4aa3b8' });

// ---- Tree objects (128x256, ground origin at bottom-center diamond) ----
function makeTree(name, trunkHex, canopyHex) {
  const W = 128, H = 256;
  const cv = makeCanvas(W, H);
  const trunk = hexToRGB(trunkHex);
  const canopy = hexToRGB(canopyHex);
  const canopyDark = canopy.map(v => Math.max(0, v - 30));
  // trunk: vertical rect near bottom center. Ground contact ~ y=H-8 (center of base diamond).
  const trunkW = 20;
  fillRect(cv, (W - trunkW) / 2, 150, (W + trunkW) / 2, 244, trunk);
  // canopy: blobby circle in upper portion
  const ccx = W / 2, ccy = 110, rx = 54, ry = 70;
  for (let y = 0; y < 200; y++) {
    for (let x = 0; x < W; x++) {
      const dx = (x - ccx) / rx, dy = (y - ccy) / ry;
      const d = dx * dx + dy * dy;
      if (d <= 1.0) {
        // lighter upper-right, darker lower-left for soft top-right light
        const c = (dx - dy) > 0.15 ? canopy : canopyDark;
        setPx(cv, x, y, c, 255);
      }
    }
  }
  save(cv, name);
}
makeTree('tree_a.png', '#5c4433', '#2e5d3b');
makeTree('tree_b.png', '#5c4433', '#4d8b4f');

// ---- Character sheet (v0.4.0-B: candidate A 「방랑자」 production build) ----
// Frames 96x96. Layout: rows = directions [SE, SW, NE, NW],
// cols = [idle, walk0, walk1]. Sheet = 3 cols x 4 rows = 288x384.
//
// v0.4.0-B: the owner-approved character design is candidate A 「방랑자」 (from
// tools_char_design.js candA): a hooded floor-length cloak, a floating violet orb on a
// wooden staff, violet eyes glowing in the hood void, a silver clasp + a violet chest
// sigil. That design is drawn on a 36×48 native grid; here it is PRODUCTIONISED into the
// four iso directions + walk frames at 36×48 native ×2 (=72×96) centred in the 96×96
// frame, feet anchored ~y88 so the AnimatedSprite2D offset (0,-40) plants it on the tile.
//
// Native (36×48) → frame (96×96): scale ×2, x-offset = (96-72)/2 = 12, and the native
// figure's feet (~y44) land at frame y88 (44*2 = 88) with y-offset 0. So px(nx,ny) fills
// the 2×2 block at (12 + nx*2, ny*2).
//
// Directions: SE/SW are front (eyes, clasp, sigil, staff on the OUTER side — mirror
// consistent); NE/NW are back (hood point, cloak back with a subtle violet sigil, staff
// still visible). Walk: cloak-hem sway (hem silhouette ±1px alternating + bottom flare),
// a slight body bob, and the orb bobs with a 1-frame-lag feel (offset alternates). Idle:
// orb held gently high + static bright (the sheet has a single idle column, kept at 1).
//
// selout outlines (面색보다 2단계 어두운 동색계 1px, 순수 검정 없음), top-right soft light,
// palette-strict (art guide §2–§4 — near-black charcoal cloak kept per the v0.3.1 owner
// directive, violet ident colour, cream accents).
const CHAR_PAL = {
  robe:      hexToRGB('#26262e'),  // near-black charcoal cloak (mid)
  robeLit:   hexToRGB('#33333d'),  // top-right lift (still dark, just readable)
  robeShade: hexToRGB('#16161c'),  // lower-left deep shade
  robeLine:  hexToRGB('#0e0e12'),  // selout outline (2 steps darker, NOT pure black)
  trim:      hexToRGB('#9e7ad9'),  // violet trim / sigil (kept)
  trimLit:   hexToRGB('#d9b8ff'),  // bright violet (orb core / eye glow)
  staff:     hexToRGB('#8a6a4a'),  // wooden staff (unchanged)
  staffLine: hexToRGB('#5c4433'),  // staff outline (2 steps darker brown)
  hoodDark:  hexToRGB('#1b1b22'),  // hood interior shadow (deeper, matches charcoal)
  orbGlow:   hexToRGB('#d9b8ff'),  // additive-bright orb accent (baked bright)
  // cream face + hands accents so the figure reads against the dark ground.
  skin:      hexToRGB('#e8dfc8'),  // cream face (in hood cavity) / hands
  skinShade: hexToRGB('#ceccaa'),  // cream lower-left shade
  skinLine:  hexToRGB('#b8b4a8'),  // cream selout
  silver:    hexToRGB('#b8b4a8'),  // silver clasp (candA)
  silverLit: hexToRGB('#e8dfc8'),  // clasp highlight
  wood:      hexToRGB('#8a6a4a'),  // staff wood (candA)
  wood2:     hexToRGB('#5c4433'),  // staff wood shade
  orbMid:    hexToRGB('#9e7ad9'),  // orb body (violet)
};


// ============================================================================
// candidate A 「방랑자」 — production character drawer (v0.4.0-B).
// Native 36×48 grid (matches tools_char_design.js candA), ×2 into the 96×96 frame.
// nx∈[0,36), ny∈[0,48). Frame pixel = (FX0 + nx*2 + dx, ny*2 + dy) for dx,dy∈{0,1}.
// FX0 = 12 centres the 72-wide figure; feet at native y44 → frame y88.
// ============================================================================
const CH_NW = 36, CH_NH = 48, CH_SCALE = 2, CH_FX0 = 12, CH_FY0 = 0;

// Paint one NATIVE pixel (a CH_SCALE×CH_SCALE block) into the frame at (ox,oy).
function nPx(cv, ox, oy, nx, ny, rgb, a = 255) {
  if (nx < 0 || ny < 0 || nx >= CH_NW || ny >= CH_NH) return;
  const px = ox + CH_FX0 + nx * CH_SCALE;
  const py = oy + CH_FY0 + ny * CH_SCALE;
  fillRect(cv, px, py, px + CH_SCALE, py + CH_SCALE, rgb, a);
}

// Draw candidate A into a 96×96 frame at (ox,oy).
//   dir: 0=SE, 1=SW, 2=NE, 3=NW.  front = SE/SW (face/eyes/clasp/sigil); back = NE/NW.
//   phase: 0=idle, 1=walk0, 2=walk1.
// The native art is authored facing-right (staff on the figure's right = screen-right).
// SW/NW mirror it to the left (staff on screen-left) by flipping nx around the grid.
// Walk motion: body bob, cloak-hem sway (±1 alternating + bottom flare), orb bob w/ lag.
function drawWanderer(cv, ox, oy, dir, phase) {
  const P = CHAR_PAL;
  const front = (dir === 0 || dir === 1);
  const flip = (dir === 1 || dir === 3);   // SW / NW mirror to the left
  // native-grid put with optional horizontal flip around x=18 (grid centre 36/2).
  const put = (nx, ny, rgb, a = 255) => nPx(cv, ox, oy, flip ? (35 - nx) : nx, ny, rgb, a);

  // --- walk kinematics ---
  const bob = phase === 2 ? -1 : 0;                 // lift on the up-beat
  const hemSway = phase === 1 ? 1 : (phase === 2 ? -1 : 0);  // hem shifts ±1 native px
  const orbBob = phase === 1 ? 1 : (phase === 2 ? -1 : 0);   // orb lag: opposite-ish drift
  const flare = phase !== 0;                        // walk frames flare the hem out

  // ===== cloak body: flowing floor-length A-line (candA silhouette) =====
  // half-width grows from shoulders (y14) to hem (y43); hem sways with the walk.
  for (let y = 14; y < 44; y++) {
    let half = 3 + (y - 14) * 4.2 / 30;
    if (flare && y >= 40) half += 0.8;              // bottom flare on walk frames
    const sway = (y >= 38) ? hemSway : 0;           // only the lower hem sways
    const cxg = 18 + sway;
    const lo = Math.round(cxg - half), hi = Math.round(cxg + half);
    for (let x = lo; x <= hi; x++) {
      // top-right soft light: lit right edge, shaded left edge, mid otherwise.
      let c = P.robe;
      if (x >= hi - 1) c = P.robeLit;
      else if (x <= lo + 1) c = P.robeShade;
      put(x, y, c);
    }
    // inner fold lines (subtle vertical creases)
    if (y >= 20 && y < 42) {
      put(Math.round(cxg - half * 0.5), y, P.robeShade);
      put(Math.round(cxg + half * 0.55), y, P.robeLit);
    }
  }
  // ragged hem bottom (selout) + a hair of bottom flare pixels
  {
    const cxg = 18 + hemSway;
    for (let x = 12; x <= 24; x++) {
      if (Math.abs(x - cxg) <= 7 && (x * 5) % 3 !== 0) put(x, 44, P.robeLine);
    }
  }
  // silhouette selout down both sides of the cloak
  for (let y = 15; y <= 43; y++) {
    let half = 3 + (y - 14) * 4.2 / 30;
    if (flare && y >= 40) half += 0.8;
    const sway = (y >= 38) ? hemSway : 0;
    const cxg = 18 + sway;
    put(Math.round(cxg - half) - 1, y, P.robeLine);
    put(Math.round(cxg + half) + 1, y, P.robeLine);
  }

  // ===== staff + floating orb (figure's right side = native x27..28) =====
  // The staff and orb are on the OUTER side and mirror consistently with the body.
  const staffX = 27;
  const orbY = 8 + bob + orbBob;                    // orb bobs high, with walk lag
  // shaft
  for (let y = 12 + bob; y <= 40; y++) { put(staffX, y, P.wood); put(staffX + 1, y, P.wood2); }
  put(staffX, 11 + bob, P.wood2);
  put(staffX - 1, 12 + bob, P.wood2);               // shaft selout (inner)
  // orb: a small violet ball with a bright core + glow specks
  put(staffX - 1, orbY, P.orbMid);   put(staffX, orbY, P.trimLit);
  put(staffX + 1, orbY, P.orbMid);
  put(staffX - 1, orbY + 1, P.trimLit); put(staffX, orbY + 1, P.orbMid);
  put(staffX + 1, orbY + 1, P.trim);
  put(staffX, orbY - 1, P.orbGlow, 150);            // baked glow specks
  put(staffX + 2, orbY, P.orbGlow, 120);
  put(staffX - 2, orbY + 1, P.orbGlow, 110);
  put(staffX - 2, orbY - 1, P.trimLit, 130);        // candA sparkle
  put(staffX + 3, orbY - 2, P.trimLit, 110);

  // sleeve/arm reaching toward the staff (front only shows the hand clearly)
  for (let y = 18 + bob; y < 24 + bob; y++) {
    for (let x = 21; x <= 26 - (y > 21 + bob ? 1 : 0); x++) put(x, y, P.robe);
  }
  // cream hand gripping the staff (a warm point against the dark cloak)
  put(26, 22 + bob, P.skin); put(26, 23 + bob, P.skinShade);
  put(25, 23 + bob, P.skinLine);

  // ===== hood: big, pointed toward the back =====
  const hoodCy = 11 + bob;
  // rounded hood cowl (ellipse-ish)
  for (let y = hoodCy - 6; y <= hoodCy + 5; y++) {
    const t = (y - (hoodCy - 6)) / 11;
    const half = Math.round(2 + t * 4);
    for (let x = 18 - half; x <= 18 + half; x++) {
      let c = P.robe;
      if (x >= 18 + half - 1) c = P.robeLit;
      else if (x <= 18 - half + 1) c = P.robeShade;
      put(x, y, c);
    }
    put(18 - half - 1, y, P.robeLine);
    put(18 + half + 1, y, P.robeLine);
  }
  // hood crown selout
  for (let x = 15; x <= 21; x++) put(x, hoodCy - 7, P.robeLine);
  // hood point tilting back-left (native art): a couple of pixels off the crown
  put(12, hoodCy - 4, P.robe); put(13, hoodCy - 5, P.robe); put(13, hoodCy - 6, P.robeShade);
  put(11, hoodCy - 3, P.robeLine);

  if (front) {
    // ===== face void + glowing violet eyes (SE/SW) =====
    for (let y = hoodCy - 1; y <= hoodCy + 3; y++) {
      for (let x = 15; x <= 21; x++) {
        const dx = (x - 18.5) / 3.4, dy = (y - (hoodCy + 1)) / 3.0;
        if (dx * dx + dy * dy <= 1.0) put(x, y, P.hoodDark);
      }
    }
    // two violet eyes (with one bright shine), inner-hood violet rim glow
    put(16, hoodCy + 1, P.trim);  put(20, hoodCy + 1, P.trim);
    put(16, hoodCy, P.trimLit, 170); put(20, hoodCy, P.trimLit, 170);
    put(15, hoodCy + 2, P.trim, 120); put(21, hoodCy + 2, P.trim, 120);

    // ===== silver clasp at the throat =====
    put(17, 16 + bob, P.silver); put(18, 16 + bob, P.silverLit); put(19, 16 + bob, P.silver);
    put(18, 17 + bob, P.silverLit);
    // ===== violet chest sigil (small vertical diamond stroke) =====
    put(18, 20 + bob, P.trimLit);
    put(17, 21 + bob, P.trim); put(19, 21 + bob, P.trim);
    put(18, 22 + bob, P.trimLit); put(18, 23 + bob, P.trim);
  } else {
    // ===== back view (NE/NW): hood interior is cloak shade, no face =====
    for (let y = hoodCy - 1; y <= hoodCy + 3; y++) {
      for (let x = 15; x <= 21; x++) {
        const dx = (x - 18.5) / 3.4, dy = (y - (hoodCy + 1)) / 3.0;
        if (dx * dx + dy * dy <= 1.0) put(x, y, P.robeShade);
      }
    }
    // a subtle violet sigil on the cloak back (small diamond)
    put(18, 24 + bob, P.trim);
    put(17, 25 + bob, P.trim); put(19, 25 + bob, P.trim);
    put(18, 26 + bob, P.trimLit);
    // spine crease down the back
    for (let y = 17 + bob; y < 40; y += 2) put(18, y, P.robeShade);
  }

  // ===== optional tiny dust hint under the trailing foot on walk frames =====
  if (phase !== 0) {
    const dustX = phase === 1 ? 14 : 22;
    put(dustX, 45, P.skinLine, 90);
    put(dustX + 1, 45, P.skinLine, 60);
  }
}

function makeCharSheet() {
  const cols = 3, rows = 4, F = 96;
  const cv = makeCanvas(cols * F, rows * F);
  for (let r = 0; r < rows; r++) {
    // col0 idle (phase 0), col1 walk0 (phase 1), col2 walk1 (phase 2).
    drawWanderer(cv, 0 * F, r * F, r, 0);
    drawWanderer(cv, 1 * F, r * F, r, 1);
    drawWanderer(cv, 2 * F, r * F, r, 2);
  }
  save(cv, 'character_sheet.png');
}
makeCharSheet();

// ---- Character portrait (v0.4.0-B: candA SE-idle bust, extra detail) ----
// A 192×192 front bust rebaked from the new SE idle: hood cowl + shoulders filling the
// frame, a dark hood cavity with two glowing violet eyes + a soft face-shadow depth, the
// silver clasp + violet chest sigil, and the staff orb glinting upper-right with a glow
// halo. Palette-strict, top-right soft light, selout (no pure black), on a dark disc.
function makeCharPortrait() {
  const S = 192;
  const cv = makeCanvas(S, S);
  const P = CHAR_PAL;
  const bg = hexToRGB('#22222a');
  const bgRim = hexToRGB('#3a2a5c');
  const cx = S / 2;
  // rounded dark backdrop disc
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const d = Math.hypot(x - cx, y - cx) / (S / 2);
    if (d <= 1.0) setPx(cv, x, y, mix(bg, bgRim, Math.min(1, d * d * 0.9)), 255);
  }
  // shoulders / cloak mantle (trapezoid)
  const shoulderY = 128, hemY = S - 2;
  for (let y = shoulderY; y <= hemY; y++) {
    const t = (y - shoulderY) / (hemY - shoulderY);
    const half = Math.round(46 + t * 40);
    for (let x = cx - half; x <= cx + half; x++) {
      let col = P.robe;
      if (x - cx > half - 10 && y < shoulderY + 40) col = P.robeLit;
      else if (x - cx < -(half - 10)) col = P.robeShade;
      setPx(cv, x, y, col, 255);
    }
    setPx(cv, cx - half - 1, y, P.robeLine, 255);
    setPx(cv, cx + half + 1, y, P.robeLine, 255);
  }
  // hood cowl framing a dark face cavity
  const hoodTop = 26, hoodBot = shoulderY + 10;
  for (let y = hoodTop; y <= hoodBot; y++) {
    const t = (y - hoodTop) / (hoodBot - hoodTop);
    const half = Math.round(20 + t * 58);
    for (let x = cx - half; x <= cx + half; x++) {
      let col = P.robe;
      if (x - cx > half - 12) col = P.robeLit;
      else if (x - cx < -(half - 12)) col = P.robeShade;
      setPx(cv, x, y, col, 255);
    }
    setPx(cv, cx - half - 1, y, P.robeLine, 255);
    setPx(cv, cx + half + 1, y, P.robeLine, 255);
  }
  for (let x = cx - 22; x <= cx + 22; x++) setPx(cv, x, hoodTop - 1, P.robeLine, 255);
  // hood point tilting back (upper-left)
  for (let k = 0; k < 10; k++) setPx(cv, cx - 20 - k, hoodTop + 6 + k, P.robeShade, 255);

  // ===== face cavity: dark void with a soft face-shadow depth gradient =====
  const faceCx = cx, faceCy = 92;
  for (let y = faceCy - 36; y <= faceCy + 30; y++) for (let x = faceCx - 32; x <= faceCx + 32; x++) {
    const d = Math.hypot((x - faceCx) / 32, (y - faceCy) / 36);
    if (d > 1.0) continue;
    // radial depth: near-black centre → hood shadow rim (face-shadow depth, portrait extra).
    const c = mix(hexToRGB('#0d0d12'), P.hoodDark, Math.min(1, d * 1.15));
    setPx(cv, x, y, c, 255);
  }
  // ===== two glowing violet eyes + soft glow halo =====
  const eyeY = faceCy;
  for (const ex of [faceCx - 15, faceCx + 15]) {
    for (let y = eyeY - 7; y <= eyeY + 7; y++) for (let x = ex - 7; x <= ex + 7; x++) {
      const d = Math.hypot(x - ex, y - eyeY) / 7;
      if (d <= 1.0) setPx(cv, x, y, P.trim, Math.round(110 * (1 - d)));
    }
    for (let y = eyeY - 3; y <= eyeY + 3; y++) for (let x = ex - 3; x <= ex + 3; x++) {
      if (Math.hypot(x - ex, y - eyeY) <= 3.0) setPx(cv, x, y, P.trimLit, 255);
    }
    // top-right shine
    setPx(cv, ex + 2, eyeY - 2, hexToRGB('#ffffff'), 220);
  }
  // ===== silver clasp at the throat =====
  for (let y = shoulderY - 4; y <= shoulderY + 6; y++) for (let x = cx - 8; x <= cx + 8; x++) {
    if (Math.hypot((x - cx) / 8, (y - (shoulderY + 1)) / 5) <= 1.0) {
      setPx(cv, x, y, (x - cx) - (y - shoulderY) > 0 ? P.silverLit : P.silver, 255);
    }
  }
  // ===== violet chest sigil (diamond) below the clasp =====
  const sigCy = shoulderY + 34;
  for (let k = -12; k <= 12; k++) {
    const w = 12 - Math.abs(k);
    for (let x = cx - w; x <= cx + w; x++) {
      const edge = (x === cx - w || x === cx + w);
      setPx(cv, x, sigCy + k, edge ? P.trimLit : P.trim, 255);
    }
  }
  // ===== staff orb glinting upper-right, with a glow halo =====
  const oX = S - 32, oY = 34;
  for (let y = oY - 14; y <= oY + 14; y++) for (let x = oX - 14; x <= oX + 14; x++) {
    const d = Math.hypot(x - oX, y - oY) / 14;
    if (d <= 1.0) setPx(cv, x, y, mix(P.trimLit, P.trim, d), Math.round(230 * (1 - d * 0.55)));
  }
  for (let y = oY - 5; y <= oY + 5; y++) for (let x = oX - 5; x <= oX + 5; x++) {
    if (Math.hypot(x - oX, y - oY) <= 5) setPx(cv, x, y, hexToRGB('#f2eaff'), 255);
  }
  // a hint of the wooden staff below the orb
  for (let y = oY + 10; y < oY + 46; y++) { setPx(cv, oX, y, P.wood, 255); setPx(cv, oX + 1, y, P.wood2, 255); }
  save(cv, 'character_portrait.png');
}
makeCharPortrait();

// ---- Small gatherable objects (M2) ----
// 64x64 sprites, ground origin at bottom-center. Placed via Sprite2D offset so
// the object's base sits on the tile it occupies. Simple geometric placeholders.
function makeBlob(name, W, H, cx, cy, rx, ry, litHex, darkHex, groundShadow = true) {
  const cv = makeCanvas(W, H);
  const lit = hexToRGB(litHex);
  const dark = hexToRGB(darkHex);
  if (groundShadow) {
    // faint contact ellipse shadow at the base
    const sh = hexToRGB('#000000');
    for (let y = -6; y <= 6; y++)
      for (let x = -18; x <= 18; x++) {
        const dx = x / 18, dy = y / 6;
        if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 8 + y, sh, 40);
      }
  }
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0) {
        // top-right light
        const c = (dx - dy) > 0.15 ? lit : dark;
        setPx(cv, x, y, c, 255);
      }
    }
  return cv;
}

// Rock (I6): grey rounded boulder.
save(makeBlob('rock.png', 64, 64, 32, 40, 20, 16, '#9a9aa4', '#5c5c66'), 'rock.png');
// Stone (I8): small grey pebble, low to the ground.
save(makeBlob('stone.png', 64, 64, 32, 50, 12, 8, '#b0b0ba', '#6c6c76'), 'stone.png');

// Flower (I5): green stem + pink bloom.
(function () {
  const cv = makeBlob('flower.png', 64, 64, 32, 28, 12, 12, '#f0a8b8', '#c86a86', false);
  const stem = hexToRGB('#4d8b4f');
  fillRect(cv, 30, 30, 34, 56, stem); // stem to ground
  save(cv, 'flower.png');
})();

// Grass tuft (I2): a small clump of green blades.
(function () {
  const cv = makeCanvas(64, 64);
  const g1 = hexToRGB('#7ab567'), g2 = hexToRGB('#4d8b4f');
  for (let b = 0; b < 9; b++) {
    const bx = 16 + b * 4;
    const h = 18 + ((b * 7) % 12);
    const c = b % 2 === 0 ? g1 : g2;
    for (let y = 0; y < h; y++) {
      const lean = Math.floor((y / h) * ((b % 3) - 1) * 4);
      setPx(cv, bx + lean, 56 - y, c);
      setPx(cv, bx + lean + 1, 56 - y, c);
    }
  }
  save(cv, 'grass_tuft.png');
})();

// ---- Cauldron (솥단지, M3; v0.2.1 gets a 2-frame bubble) ----
// 128x128, ground origin at bottom-center. Dark pot body with a violet glow rim
// (accent #9e7ad9) around the mouth — reads as the fusion cauldron. Palette per
// art guide: dark #2a2a33 base, violet accent #9e7ad9, cream highlight #faf5e6.
// v0.2.1: factored into makeCauldron(name, bubble) so we emit two brew-surface
// frames (cauldron.png + cauldron_bubble.png); the world sprite alternates them for
// a subtle bubbling animation (조합 쾌감 §5, world-cauldron polish).
function makeCauldron(name, bubble) {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const bodyDark = hexToRGB('#2a2a33');
  const bodyLit = hexToRGB('#3d3d4a');
  const glow = hexToRGB('#9e7ad9');
  const glowBright = hexToRGB('#c8a8ec');
  const brew = hexToRGB('#6b4a9e');
  const brewLit = hexToRGB('#8a5ac8');
  const cream = hexToRGB('#faf5e6');

  // contact shadow at the base
  const sh = hexToRGB('#000000');
  for (let y = -8; y <= 8; y++)
    for (let x = -40; x <= 40; x++) {
      const dx = x / 40, dy = y / 8;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 10 + y, sh, 50);
    }

  // pot body: rounded cauldron. Center ~ (64, 74), radii (44, 38). Only draw the
  // lower ~3/4 (the belly), leaving an open mouth ellipse on top.
  const bcx = 64, bcy = 74, brx = 44, bry = 40;
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      const dx = (x - bcx) / brx, dy = (y - bcy) / bry;
      const d = dx * dx + dy * dy;
      if (d <= 1.0 && y >= 48) {
        // top-right light on the belly
        const c = (dx - dy) > 0.15 ? bodyLit : bodyDark;
        setPx(cv, x, y, c, 255);
      }
    }

  // three little feet
  for (const fx of [40, 64, 88]) {
    fillRect(cv, fx - 6, 108, fx + 6, 118, bodyDark);
  }

  // mouth: brewing ellipse at the top of the belly (the violet fusion surface).
  // The bubble frame shifts the shimmer checker phase and lifts a couple of rising
  // bubbles so the two frames read as a gentle boil.
  const mcx = 64, mcy = 52, mrx = 40, mry = 13;
  const phase = bubble ? 1 : 0;
  for (let y = -mry; y <= mry; y++)
    for (let x = -mrx; x <= mrx; x++) {
      const dx = x / mrx, dy = y / mry;
      if (dx * dx + dy * dy <= 1.0) {
        // shimmer: alternate brew / glow for a bubbling look (phase-shifted per frame)
        const c = ((((x >> 2) + (y >> 1) + phase) % 2 === 0)) ? brew : glow;
        setPx(cv, mcx + x, mcy + y, c, 255);
      }
    }
  // rising bubbles: small bright blobs, positioned differently per frame.
  const bubbles = bubble
    ? [[54, 48], [70, 46], [62, 50]]
    : [[58, 50], [74, 49]];
  for (const [bx, by] of bubbles) {
    setPx(cv, bx, by, brewLit); setPx(cv, bx + 1, by, brewLit);
    setPx(cv, bx, by - 1, glowBright, 220); setPx(cv, bx + 1, by - 1, glowBright, 220);
  }

  // glow rim: bright violet ring around the mouth
  for (let a = 0; a < 360; a++) {
    const rad = a * Math.PI / 180;
    const rx = mrx + 3, ry = mry + 3;
    const x = Math.round(mcx + Math.cos(rad) * rx);
    const y = Math.round(mcy + Math.sin(rad) * ry);
    setPx(cv, x, y, glowBright, 255);
    setPx(cv, x, y + 1, glow, 200);
  }

  // faint cream sparkle above the brew (the "whisper") — one extra on the bubble frame.
  setPx(cv, 60, 40, cream, 220); setPx(cv, 61, 40, cream, 220);
  setPx(cv, 72, 36, cream, 180);
  setPx(cv, 52, 38, cream, 160);
  if (bubble) { setPx(cv, 66, 34, cream, 200); setPx(cv, 67, 34, cream, 200); }

  save(cv, name);
}
makeCauldron('cauldron.png', false);
makeCauldron('cauldron_bubble.png', true);

// ============================================================================
// M4 art — 시작의 숲 landmarks & gates.
// Palette (art guide §3): green #4d8b4f/#7ab567, brown #5c4433/#8a6a4a,
// violet #6b4a9e/#9e7ad9/#d9b8ff, moss #4d8b4f, cream #faf5e6.
// All objects: bottom-center ground origin; violet glow baked as a separate
// *_glow.png additive layer (kept out of CanvasModulate so night makes it pop).
// ============================================================================

// ---- Dry / Bloomed gate bush (G2). v0.4.0-B readability rebuild. ------------
// Owner: "덤불이 덤불같지 않아서 인지할 수가 없다" — the old bush read as a small tree.
// New: an UNMISTAKABLE dry THORNBUSH — a round-ish dome WIDER THAN TALL (base ~96px
// wide, ~64px tall, seated at the canvas bottom-center), built from TANGLED brown
// branches (2-3 tone browns) crisscrossing from a low base, a few thorn spikes, and a
// few WITHERED grey-green leaf clumps caught in the tangle. NOT tree-like: no single
// trunk, no tall canopy — a squat thicket. bush_bloom.png reuses the exact same branch
// tangle silhouette but bursting with pink/violet flowers + soft glow pixels.
//
// Canvas stays 128×128 (bush_dry.gd offset −80 + the diamond collision are unchanged);
// the bush body simply occupies the lower band y≈60..120, wider than tall.
function makeThornbush(name, mode) {  // mode: 'dry' | 'bloom'
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  // deterministic per-name stream so re-runs are byte-identical.
  let s = 0; for (let i = 0; i < name.length; i++) s = (s * 131 + name.charCodeAt(i)) & 0x7fffffff;
  s = (s ^ 0x5bd1e995) & 0x7fffffff;
  const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };

  // Palette (art guide §3).
  const br1 = hexToRGB('#8a6a4a');  // dry brown (lit)
  const br2 = hexToRGB('#5c4433');  // mid brown
  const br3 = hexToRGB('#3a2a20');  // deep brown (shadow / selout)
  const leafDry = hexToRGB('#6e6e7a');   // withered grey
  const leafGrn = hexToRGB('#4d8b4f');   // grey-green leaf clump
  const grnLit = hexToRGB('#7ab567');
  const bloomV = hexToRGB('#9e7ad9');
  const bloomVL = hexToRGB('#d9b8ff');
  const bloomP = hexToRGB('#f0a8b8');

  // ground contact shadow — WIDE ellipse (reads as a wide bush footprint).
  const sh = hexToRGB('#000000');
  for (let y = -7; y <= 7; y++)
    for (let x = -46; x <= 46; x++) {
      const dx = x / 46, dy = y / 7;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 10 + y, sh, 42);
    }

  // Dome silhouette: centre (64, 92), half-width 46, half-height 32 → WIDER than TALL.
  const cxg = 64, cyg = 92, rxg = 46, ryg = 32;
  function inDome(x, y) {
    const dx = (x - cxg) / rxg, dy = (y - cyg) / ryg;
    // slightly flattened top, rounded — and only the upper hemisphere + a bit below.
    return dx * dx + dy * dy <= 1.0 && y <= cyg + ryg && y >= cyg - ryg - 2;
  }

  // ----- tangled branches: many short strokes radiating from a few low base nodes -----
  const bases = [[50, 116], [64, 118], [80, 116], [40, 114], [90, 114]];
  const nStrokes = 130;
  for (let i = 0; i < nStrokes; i++) {
    // pick a base node, shoot a branch up-and-out at a random-ish angle, staying in dome.
    const [bx, by] = bases[Math.floor(rnd() * bases.length)];
    const ang = -Math.PI * (0.15 + rnd() * 0.7);        // mostly upward, fanning out
    const len = 16 + Math.floor(rnd() * 34);
    const dirx = Math.cos(ang) * (rnd() < 0.5 ? 1 : -1);
    const diry = Math.sin(ang);
    let x = bx, y = by;
    // pick branch tone (2-3 browns), lit on the up-right per top-right light.
    let tone = rnd() < 0.4 ? br1 : (rnd() < 0.6 ? br2 : br3);
    for (let k = 0; k < len; k++) {
      // gentle wander so branches look tangled, not straight.
      x += dirx + (rnd() - 0.5) * 1.4;
      y += diry * 1.1 + (rnd() - 0.5) * 0.8;
      const ix = Math.round(x), iy = Math.round(y);
      if (!inDome(ix, iy)) break;
      // top-right lift
      const c = ((ix - cxg) - (iy - cyg) > 6) ? br1 : tone;
      setPx(cv, ix, iy, c, 255);
      // occasional 2px thickness for main branches
      if (k < 8 && rnd() < 0.5) setPx(cv, ix + 1, iy, br2, 255);
    }
  }

  if (mode === 'dry') {
    // thorn spikes: short sharp specks poking out of the tangle silhouette edge.
    for (let i = 0; i < 26; i++) {
      const a = rnd() * Math.PI * 2;
      const ex = Math.round(cxg + Math.cos(a) * rxg * (0.72 + rnd() * 0.26));
      const ey = Math.round(cyg + Math.sin(a) * ryg * (0.6 + rnd() * 0.3)) - 2;
      setPx(cv, ex, ey, br3, 255);
      setPx(cv, ex + Math.sign(Math.cos(a)), ey - 1, br2, 220);
    }
    // withered grey-green leaf clumps: a FEW small 2×2 patches caught in the tangle.
    for (let i = 0; i < 9; i++) {
      const lx = 34 + Math.floor(rnd() * 60);
      const ly = 66 + Math.floor(rnd() * 40);
      if (!inDome(lx, ly)) continue;
      const c = rnd() < 0.5 ? leafDry : leafGrn;
      setPx(cv, lx, ly, c, 235); setPx(cv, lx + 1, ly, c, 235);
      setPx(cv, lx, ly + 1, c, 210);
    }
  } else {
    // bloom: the SAME tangle now bursting with pink/violet flowers + soft glow pixels.
    for (let i = 0; i < 46; i++) {
      const fx = 32 + Math.floor(rnd() * 64);
      const fy = 62 + Math.floor(rnd() * 44);
      if (!inDome(fx, fy)) continue;
      const r = rnd();
      const c = r < 0.4 ? bloomVL : (r < 0.72 ? bloomV : bloomP);
      // 4-petal flower dab
      setPx(cv, fx, fy, c); setPx(cv, fx + 1, fy, c);
      setPx(cv, fx, fy + 1, c); setPx(cv, fx + 1, fy + 1, c);
      setPx(cv, fx, fy - 1, bloomVL, 200);
    }
    // a few healthy green leaves peeking through
    for (let i = 0; i < 12; i++) {
      const lx = 34 + Math.floor(rnd() * 60);
      const ly = 70 + Math.floor(rnd() * 38);
      if (!inDome(lx, ly)) continue;
      const c = rnd() < 0.5 ? leafGrn : grnLit;
      setPx(cv, lx, ly, c, 235);
    }
    // soft glow pixels (baked, low alpha) scattered over the blossoms.
    for (let i = 0; i < 22; i++) {
      const gx = 36 + Math.floor(rnd() * 56);
      const gy = 62 + Math.floor(rnd() * 40);
      if (!inDome(gx, gy)) continue;
      setPx(cv, gx, gy, bloomVL, 120);
    }
  }
  save(cv, name);
}
makeThornbush('bush_dry.png', 'dry');
makeThornbush('bush_bloom.png', 'bloom');

// (legacy IIFE bodies below retired — replaced by makeThornbush above.)
(function () {
  return;
})();

// ---- Rest Stump (U). 128x128, brown stump with moss-green top. ----
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const sh = hexToRGB('#000000');
  for (let y = -6; y <= 6; y++)
    for (let x = -28; x <= 28; x++) {
      const dx = x / 28, dy = y / 6;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 10 + y, sh, 45);
    }
  const bark = hexToRGB('#5c4433');
  const barkLit = hexToRGB('#8a6a4a');
  const moss = hexToRGB('#4d8b4f');
  const mossLit = hexToRGB('#7ab567');
  const rings = hexToRGB('#3a2a20');
  // trunk cylinder: x 40..88, y 60..112
  for (let y = 60; y < 112; y++)
    for (let x = 40; x < 88; x++) {
      // rounded sides
      const dx = (x - 64) / 24;
      if (dx * dx > 1.0) continue;
      const c = (x - 64) > 4 ? bark : barkLit;
      setPx(cv, x, y, c, 255);
    }
  // top ellipse (moss-covered cut face)
  const tcx = 64, tcy = 60, trx = 26, tryy = 12;
  for (let y = -tryy; y <= tryy; y++)
    for (let x = -trx; x <= trx; x++) {
      const dx = x / trx, dy = y / tryy;
      const d = dx * dx + dy * dy;
      if (d <= 1.0) {
        // concentric rings + moss patches
        let c = (x - y) > 2 ? mossLit : moss;
        if (Math.abs(d - 0.5) < 0.08) c = rings;
        setPx(cv, tcx + x, tcy + y, c, 255);
      }
    }
  save(cv, 'rest_stump.png');
})();

// ---- World Tree (O0). 512x512, big canopy with violet glow accents. ----
// Plus a separate world_tree_glow.png additive layer.
(function () {
  const W = 512, H = 512;
  const cv = makeCanvas(W, H);
  const glowCv = makeCanvas(W, H);
  const trunk = hexToRGB('#5c4433');
  const trunkLit = hexToRGB('#8a6a4a');
  const canopy = hexToRGB('#2e5d3b');
  const canopyLit = hexToRGB('#4d8b4f');
  const violet = hexToRGB('#9e7ad9');
  const violetBright = hexToRGB('#d9b8ff');
  // contact shadow
  const sh = hexToRGB('#000000');
  for (let y = -14; y <= 14; y++)
    for (let x = -90; x <= 90; x++) {
      const dx = x / 90, dy = y / 14;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 22 + y, sh, 55);
    }
  // trunk: wide, tapering. base y~492 center x=256
  for (let y = 300; y < 492; y++) {
    const t = (y - 300) / 192;
    const halfW = 26 + t * 34;
    for (let x = -halfW; x <= halfW; x++) {
      const c = x > 6 ? trunk : trunkLit;
      setPx(cv, 256 + x, y, c, 255);
    }
  }
  // roots spread at base
  for (let r = -2; r <= 2; r++) {
    const rx = 256 + r * 40;
    for (let y = 470; y < 496; y++) {
      const w = 8 - Math.floor((y - 470) / 4);
      for (let x = -w; x <= w; x++) setPx(cv, rx + x, y, trunk, 255);
    }
  }
  // canopy: large blobby cloud, upper 2/3
  const ccx = 256, ccy = 210, rx = 200, ry = 200;
  let seed = 4242;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let y = 0; y < 430; y++)
    for (let x = 0; x < W; x++) {
      const dx = (x - ccx) / rx, dy = (y - ccy) / ry;
      const d = dx * dx + dy * dy;
      if (d <= 1.0) {
        // ragged edge
        if (d > 0.85 && rnd() < 0.4) continue;
        const c = (dx - dy) > 0.15 ? canopyLit : canopy;
        setPx(cv, x, y, c, 255);
      }
    }
  // violet glow motes scattered in canopy (baked faint + strong in glow layer)
  seed = 909;
  for (let n = 0; n < 90; n++) {
    const x = 80 + Math.floor(rnd() * 352);
    const y = 60 + Math.floor(rnd() * 300);
    const dx = (x - ccx) / rx, dy = (y - ccy) / ry;
    if (dx * dx + dy * dy > 0.95) continue;
    const bright = rnd() < 0.3;
    const c = bright ? violetBright : violet;
    setPx(cv, x, y, c, 220);
    setPx(cv, x + 1, y, c, 200);
    setPx(cv, x, y + 1, c, 200);
    // glow layer: soft blob
    for (let gy = -3; gy <= 3; gy++)
      for (let gx = -3; gx <= 3; gx++) {
        const gd = gx * gx + gy * gy;
        if (gd <= 9) setPx(glowCv, x + gx, y + gy, violetBright, Math.max(0, 120 - gd * 12));
      }
  }
  save(cv, 'world_tree.png');
  save(glowCv, 'world_tree_glow.png');
})();

// ---- Young world tree (D22 planted / clear). 128x128 sapling with glow. ----
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const trunk = hexToRGB('#5c4433');
  const canopy = hexToRGB('#4d8b4f');
  const canopyLit = hexToRGB('#7ab567');
  const violet = hexToRGB('#d9b8ff');
  fillRect(cv, 60, 80, 68, 116, trunk);
  const ccx = 64, ccy = 60, rx = 30, ry = 34;
  for (let y = 0; y < 100; y++)
    for (let x = 0; x < W; x++) {
      const dx = (x - ccx) / rx, dy = (y - ccy) / ry;
      if (dx * dx + dy * dy <= 1.0) {
        const c = (dx - dy) > 0.15 ? canopyLit : canopy;
        setPx(cv, x, y, c, 255);
      }
    }
  let seed = 31;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let n = 0; n < 14; n++) {
    const x = 44 + Math.floor(rnd() * 40);
    const y = 40 + Math.floor(rnd() * 40);
    setPx(cv, x, y, violet, 220);
  }
  save(cv, 'young_tree.png');
})();

// ---- Mystic water tile (m). 128x64 diamond, deep teal + violet glow. ----
(function () {
  makeTile('t5m_mystic.png', '#1e3a5c', { edgeHex: '#6b4a9e', dither: true, ditherHex: '#3a2a5c', hardEdge: true });
  // glow overlay diamond
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const violet = hexToRGB('#9e7ad9');
  for (let y = 0; y < H; y++)
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      const cx = 64, cy = 32;
      const d = Math.hypot((x - cx) / 64, (y - cy) / 32);
      setPx(cv, x, y, violet, Math.max(0, Math.floor(90 * (1 - d))));
    }
  save(cv, 't5m_mystic_glow.png');
})();

// ---- Night bloom gate flower (G3). 128x128 closed (day) + open (night). ----
(function () {
  function bud(name, open) {
    const W = 128, H = 128;
    const cv = makeCanvas(W, H);
    const stem = hexToRGB('#4d8b4f');
    fillRect(cv, 60, 70, 68, 116, stem);
    if (open) {
      // open glowing violet blossom
      const pet = hexToRGB('#9e7ad9');
      const petLit = hexToRGB('#d9b8ff');
      for (let a = 0; a < 8; a++) {
        const rad = a * Math.PI / 4;
        const px = 64 + Math.cos(rad) * 24;
        const py = 56 + Math.sin(rad) * 24;
        for (let y = -10; y <= 10; y++)
          for (let x = -10; x <= 10; x++) {
            if (x * x + y * y <= 100) {
              const c = (x - y) > 2 ? petLit : pet;
              setPx(cv, Math.round(px) + x, Math.round(py) + y, c, 220);
            }
          }
      }
      const core = hexToRGB('#faf5e6');
      for (let y = -6; y <= 6; y++)
        for (let x = -6; x <= 6; x++)
          if (x * x + y * y <= 36) setPx(cv, 64 + x, 56 + y, core, 255);
    } else {
      // closed grey-green bud
      const budC = hexToRGB('#5c4433');
      const budLit = hexToRGB('#6e6e7a');
      for (let y = -20; y <= 14; y++)
        for (let x = -14; x <= 14; x++) {
          const dx = x / 14, dy = y / 20;
          if (dx * dx + dy * dy <= 1.0) {
            const c = (x - y) > 2 ? budLit : budC;
            setPx(cv, 64 + x, 54 + y, c, 255);
          }
        }
    }
    save(cv, name);
  }
  bud('night_bud_closed.png', false);
  bud('night_bud_open.png', true);
})();

// ============================================================================
// M6a art — seamless-ground edge overlays + object-density variety.
// Palette (art guide §3) strict. Lighting top-right (soft light), origin at the
// bottom-center diamond for objects, tile-center for edge overlays.
// ============================================================================

// ---- Edge / transition overlays (128x64 diamonds, mostly transparent). ------
// These sit ON TOP of the base grass tile as separate Sprite2D overlays (the
// base tilemap is never altered, so M4 tile counts stay exact). Each overlay
// bleeds a neighbour material in from ONE shared diamond edge, fading to
// transparent toward the tile centre so grass shows through.
//
// Direction codes map to the iso grid neighbours (Godot Diamond-Down):
//   br = neighbour (c+1, r)  bottom-right edge   e = (u + v)
//   bl = neighbour (c,   r+1) bottom-left  edge  e = (-u + v)
//   tl = neighbour (c-1, r)  top-left     edge   e = (-u - v)
//   tr = neighbour (c,   r-1) top-right    edge  e = (u - v)
// where u=(x-cx)/64, v=(y-cy)/32 (diamond interior |u|+|v|<=1).
function edgeCoord(dir, u, v) {
  switch (dir) {
    case 'br': return u + v;
    case 'bl': return -u + v;
    case 'tl': return -u - v;
    case 'tr': return u - v;
  }
  return 0;
}
// mat: {lit, dark} hex for the neighbour material. foam: optional shoreline hex.
function makeEdgeOverlay(name, dir, mat, opts = {}) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const lit = hexToRGB(mat.lit);
  const dark = hexToRGB(mat.dark);
  const foam = opts.foam ? hexToRGB(opts.foam) : null;
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  // Bleed band: fill where the neighbour edge coord is within [start, 1].
  const start = opts.start !== undefined ? opts.start : 0.42;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      const u = (x - cx) / (W / 2), v = (y - cy) / (H / 2);
      const e = edgeCoord(dir, u, v);
      if (e < start) continue;                 // toward centre: leave grass showing
      // alpha ramps 0 at `start` -> full at the edge (e≈1)
      const t = Math.min(1, (e - start) / (1.0 - start));
      let a = Math.round(255 * (0.25 + 0.75 * t));
      // top-right soft light on the bleed
      let c = (u - v) > 0.15 ? lit : dark;
      // shoreline foam: a bright waterline right at the boundary band
      if (foam && e > 0.80 && e <= 0.94) { c = foam; a = 235; }
      setPx(cv, x, y, c, a);
    }
  }
  save(cv, name);
}
// grass→dirt (path-side crumble), grass→water (teal + cream foam), grass→mud.
for (const dir of ['br', 'bl', 'tl', 'tr']) {
  makeEdgeOverlay('edge_dirt_' + dir + '.png', dir,
    { lit: '#8a6a4a', dark: '#5c4433' });
  makeEdgeOverlay('edge_water_' + dir + '.png', dir,
    { lit: '#4aa3b8', dark: '#2e6b8a' }, { foam: '#8fd4d9', start: 0.50 });
  makeEdgeOverlay('edge_mud_' + dir + '.png', dir,
    { lit: '#5c4433', dark: '#3a2a20' });
}

// ---- tree_c: taller pine-ish conifer (128x256, top-right light). -----------
(function () {
  const W = 128, H = 256;
  const cv = makeCanvas(W, H);
  const trunk = hexToRGB('#5c4433');
  const trunkLit = hexToRGB('#8a6a4a');
  const needle = hexToRGB('#2e5d3b');
  const needleLit = hexToRGB('#4d8b4f');
  // contact shadow
  const sh = hexToRGB('#000000');
  for (let y = -6; y <= 6; y++)
    for (let x = -22; x <= 22; x++) {
      const dx = x / 22, dy = y / 6;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 12 + y, sh, 40);
    }
  // narrow trunk
  fillRect(cv, 58, 176, 70, 244, trunk);
  fillRect(cv, 58, 176, 62, 244, trunkLit);
  // stacked triangular tiers (pine), top-right lit
  const tiers = [[48, 118], [58, 150], [70, 186]]; // [halfWidth at base, baseY]
  let topY = 40;
  for (const [halfW, baseY] of tiers) {
    for (let y = topY; y < baseY; y++) {
      const t = (y - topY) / (baseY - topY);
      const hw = Math.floor(halfW * t);
      for (let x = -hw; x <= hw; x++) {
        const c = (x - (y - topY) * 0.3) > 4 ? needleLit : needle;
        setPx(cv, 64 + x, y, c, 255);
      }
    }
    topY = baseY - 40;
  }
  save(cv, 'tree_c.png');
})();

// ---- Flower colour variants (64x64) — palette pinks/violets. ----------------
// flower.png (base pink) already exists from M2; add two more hues.
function makeFlower(name, bloomLit, bloomDark) {
  const cv = makeBlob(name, 64, 64, 32, 28, 12, 12, bloomLit, bloomDark, false);
  const stem = hexToRGB('#4d8b4f');
  fillRect(cv, 30, 30, 34, 56, stem);
  save(cv, name);
}
makeFlower('flower_violet.png', '#9e7ad9', '#6b4a9e');   // violet bloom
makeFlower('flower_pink.png', '#d9b8ff', '#9e7ad9');     // light violet-pink

// ---- bush_green: decorative gatherable bush (풀, I2). 128x128. --------------
// NOT the gate bush (that is bush_dry/bloom). A rounded green shrub, top-right lit.
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const sh = hexToRGB('#000000');
  for (let y = -6; y <= 6; y++)
    for (let x = -28; x <= 28; x++) {
      const dx = x / 28, dy = y / 6;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 12 + y, sh, 40);
    }
  const green = hexToRGB('#4d8b4f');
  const greenLit = hexToRGB('#7ab567');
  const greenHi = hexToRGB('#a8d982');
  const blobs = [[64, 80, 32, 26], [46, 90, 22, 18], [86, 90, 22, 18]];
  for (const [bcx, bcy, brx, bry] of blobs) {
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++) {
        const dx = (x - bcx) / brx, dy = (y - bcy) / bry;
        const d = dx * dx + dy * dy;
        if (d <= 1.0) {
          let c = (dx - dy) > 0.15 ? greenLit : green;
          if ((dx - dy) > 0.55) c = greenHi; // top-right highlight
          setPx(cv, x, y, c, 255);
        }
      }
  }
  save(cv, 'bush_green.png');
})();

// ============================================================================
// v0.3.0 Workstream A — diorama map visual quality.
// ============================================================================

// ---- A1: Diorama cliff-skirt tiles ----------------------------------------
// The floating-island look: authored ground doesn't just stop at the void — its
// south/east-facing outer edges drop away as a lit cliff cross-section (dirt →
// rock strata). These are VISUAL ONLY sprites the map loader hangs under the outer
// edge cells (behind/under the ground, no collision). 128px wide to match the tile
// diamond footprint; ~112px tall so the strata read. Top-right lit (art guide §2),
// palette browns/greys. Deterministic.
//
// Variants:
//   cliff_skirt_s   — south-facing drop (hangs below a cell whose south is void)
//   cliff_skirt_e   — east-facing drop
//   cliff_skirt_se  — outer corner where south + east meet (wider spread)
// Each is drawn as the lower half-diamond "lip" of the tile continuing down into a
// strata wall, so it tucks under the diamond's bottom edge seamlessly.
function makeCliffSkirt(name, kind) {
  const W = 128, H = 112;
  const cv = makeCanvas(W, H);
  // Palette ramps (art guide §3 browns + neutral greys).
  const dirt = hexToRGB('#5c4433');
  const dirtLit = hexToRGB('#8a6a4a');
  const dirtDark = hexToRGB('#3a2a20');
  const rock = hexToRGB('#6e6e7a');
  const rockLit = hexToRGB('#b8b4a8');
  const rockDark = hexToRGB('#2a2a33');
  const cx = 64;
  // The diamond's bottom vertex sits at (64, 32) in tile space; the skirt starts at
  // the diamond's lower edges (y≈0..32 across the width) and the wall drops to H.
  // Top lip: the thin band of soil right under the diamond rim.
  // For each column x, compute how far down the diamond's lower edge is at that x
  // (the wall only exists below the ground silhouette).
  function rimY(x) {
    // lower half of a 128×64 diamond centred at (64,32): |x-64|/64 + (y-32)/32 = 1
    // → y = 32 + 32*(1 - |x-64|/64). Clamp to [0..32]. Above rimY = still ground.
    const u = Math.abs(x - cx) / 64;
    return Math.round(32 * (1 - u)) + 0; // 0..32; but we anchor skirt so rim≈y0
  }
  // Wall silhouette width: for the S skirt the full diamond width tapers; for E,
  // we bias to the right half; for SE, a broad wedge.
  for (let x = 0; x < W; x++) {
    // horizontal presence + inset per kind
    let present = true;
    let inset = 0;
    const u = (x - cx) / 64; // -1..1
    if (kind === 'e') { present = u > -0.15; inset = Math.round((1 - Math.min(1, Math.max(0, (u + 0.15)))) * 6); }
    else if (kind === 's') { present = true; }
    else if (kind === 'se') { present = true; }
    if (!present) continue;
    const ry = rimY(x); // the diamond lower-edge y for this column (0..32)
    const wallTop = ry;  // soil starts right at the diamond rim
    const wallBot = H - Math.round((1 - Math.abs(u)) * 6); // slight rounded base
    for (let y = wallTop; y < wallBot; y++) {
      const depth = (y - wallTop) / (H - wallTop); // 0 at rim → 1 at base
      let c;
      // Top ~28%: dirt/soil band. Below: rock strata.
      if (depth < 0.28) {
        c = (u > 0.1) ? dirtLit : dirt;               // top-right lit soil
        if (depth < 0.06) c = mix(dirtLit, hexToRGB('#4d8b4f'), 0.3); // mossy top rim
      } else {
        // strata: horizontal bands alternating rock tones + occasional dark seam.
        const band = Math.floor((y - wallTop) / 9);
        const seam = ((y - wallTop) % 9) === 0;
        let base = (band % 2 === 0) ? rock : mix(rock, rockDark, 0.35);
        base = (u > 0.15) ? mix(base, rockLit, 0.28) : base;         // top-right lift
        if (u < -0.35) base = mix(base, rockDark, 0.30);             // left in shadow
        c = seam ? mix(base, rockDark, 0.55) : base;
        // a few embedded pebble specks (deterministic)
        if (smoothCell(x, y, 4, 0x6a6a) > 0.86) c = rockLit;
        if (smoothCell(x, y, 5, 0x7b7b) < 0.08) c = dirtDark;
      }
      setPx(cv, x, y, c, 255);
    }
    // 1px selout on the left silhouette edge of the wall (2 steps darker)
  }
  // outline the vertical silhouette edges (selout, no pure black)
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 4;
      if (cv.data[i + 3] === 0) continue;
      // if the pixel to the left/right is transparent → draw a darker rim
      const li = (y * W + (x - 1)) * 4;
      const rimDark = mix(dirtDark, rockDark, 0.5);
      if (x === 0 || cv.data[li + 3] === 0) { setPx(cv, x, y, rimDark, 255); }
    }
  }
  save(cv, name);
}
makeCliffSkirt('cliff_skirt_s.png', 's');
makeCliffSkirt('cliff_skirt_e.png', 'e');
makeCliffSkirt('cliff_skirt_se.png', 'se');

// ---- A3 (v0.4.0): Interior ridge rock (raised rock mound cross-section) ------
// Authored interior VOID bands (the G2 corridor walls + G3 night-path wall) used to
// render as flat black hollow-like tiles — unreadable, confusable with gathered
// hollows ("바위 맵 뚫을수가 없거든?"). The ridge sprite is a raised rocky mound that
// clearly reads as impassable TERRAIN: a grey-brown rock cross-section (art guide §3
// neutral greys + browns) rising above the tile's diamond, top-right lit, with a few
// subtle moss hints. 128 wide (one tile) × 160 tall; the lower 64 px is the diamond
// footprint band (so it seats on the cell) and the upper ~96 px is the mound crown that
// rises above the ground plane. Deterministic (name-seeded speck placement).
function makeRidge(name) {
  const W = 128, H = 160;
  const cv = makeCanvas(W, H);
  // Rock ramp (neutral greys) + brown lowers + moss accents.
  const rock    = hexToRGB('#6e6e7a');
  const rockLit = hexToRGB('#b8b4a8');
  const rockDk  = hexToRGB('#2a2a33');
  const brown   = hexToRGB('#5c4433');
  const brownLit= hexToRGB('#8a6a4a');
  const brownDk = hexToRGB('#3a2a20');
  const moss    = hexToRGB('#4d8b4f');
  const mossDk  = hexToRGB('#2e5d3b');
  // name-seeded deterministic stream (speck / moss placement)
  let s = 0; for (let i = 0; i < name.length; i++) s = (s * 131 + name.charCodeAt(i)) & 0x7fffffff;
  s = (s ^ 0x5bd1e995) & 0x7fffffff;
  const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };

  const cx = 64;
  // The tile diamond occupies y in [H-64 .. H] (bottom band), centred at (64, H-32).
  // Diamond membership for the seating band:
  function inTileDiamond(x, y) {
    const dyc = y - (H - 32);
    return Math.abs(x - cx) / 64 + Math.abs(dyc) / 32 <= 1.0;
  }
  // The mound crown: a rounded rocky hump whose base spans most of the tile width and
  // whose apex is up near the top. Silhouette = an ellipse-ish cap merged with the tile
  // diamond's upper half so the whole thing reads as one raised rock.
  const apexY = 20;            // top of the mound
  const baseY = H - 20;        // where the mound meets the ground band
  const halfW = 52;            // half-width of the mound base
  function moundHalfWidthAt(y) {
    // 0 at apex → halfW near base, with a rounded (sqrt-ish) profile.
    if (y < apexY) return 0;
    const t = Math.min(1, (y - apexY) / (baseY - apexY));
    return halfW * Math.sqrt(t) * (0.72 + 0.28 * t);
  }

  for (let y = 0; y < H; y++) {
    const hw = moundHalfWidthAt(y);
    for (let x = 0; x < W; x++) {
      const inMound = (y >= apexY && Math.abs(x - cx) <= hw);
      const inBand = inTileDiamond(x, y);
      if (!inMound && !inBand) continue;
      const u = (x - cx) / 64;                       // -1..1 across
      const depth = (y - apexY) / (H - apexY);        // 0 top → 1 bottom
      let c;
      // vertical zoning: crown rock (upper) → strata (mid) → brown earthen base (lower band)
      if (y > H - 46) {
        // earthen base band (the part seated on the tile) — browns, darker at the rim.
        c = (u > 0.1) ? brownLit : brown;
        if (Math.abs(u) > 0.72) c = brownDk;
      } else {
        // rock body: horizontal strata with a top-right lift.
        const band = Math.floor(y / 11);
        const seam = (y % 11) === 0;
        let base = (band % 2 === 0) ? rock : mix(rock, rockDk, 0.32);
        base = (u > 0.12) ? mix(base, rockLit, 0.30) : base;   // top-right lit
        if (u < -0.4) base = mix(base, rockDk, 0.34);          // left in shadow
        c = seam ? mix(base, rockDk, 0.5) : base;
        // embedded pebble specks / cracks (deterministic)
        if (smoothCell(x, y, 4, 0x9a1c) > 0.88) c = rockLit;
        if (smoothCell(x, y, 5, 0xb2e7) < 0.07) c = brownDk;
      }
      // moss hints: cling to the upper-left crown + a few base tufts (shaded green).
      const mn = smoothCell(x, y, 6, 0x3055);
      if (y < H - 40 && depth < 0.55 && u < 0.15 && mn > 0.80) c = (mn > 0.9) ? moss : mossDk;
      if (y > H - 52 && y < H - 30 && mn > 0.88) c = mossDk;
      setPx(cv, x, y, c, 255);
    }
  }
  // selout: darken the silhouette edge (1px) where a filled pixel borders transparency.
  const rim = mix(rockDk, brownDk, 0.5);
  const snap = cv.data.slice();
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const i = (y * W + x) * 4;
      if (snap[i + 3] === 0) continue;
      let edge = false;
      for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]) {
        const nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= W || ny >= H) { edge = true; break; }
        if (snap[(ny * W + nx) * 4 + 3] === 0) { edge = true; break; }
      }
      if (edge) setPx(cv, x, y, rim, 255);
    }
  }
  save(cv, name);
}
makeRidge('ridge_rock.png');

// ---- A3 (v0.4.0): Worn-dirt trail patch (corridor hint decal) ---------------
// A subtle worn-earth patch laid on playable cells leading up to the G2 bush corridor,
// hinting "the way through is here". Half-tile-ish soft brown blotch on the 128×64
// diamond, low-contrast (it should read as trodden ground, not a hard tile swap).
function makeWornDirt(name) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const dirt   = hexToRGB('#8a6a4a');
  const dirtDk = hexToRGB('#5c4433');
  const speck  = hexToRGB('#3a2a20');
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  let s = 0; for (let i = 0; i < name.length; i++) s = (s * 131 + name.charCodeAt(i)) & 0x7fffffff;
  s = (s ^ 0x5bd1e995) & 0x7fffffff;
  const rnd = () => { s = (s * 1103515245 + 12345) & 0x7fffffff; return s / 0x7fffffff; };
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      // soft irregular blotch: within an inset diamond radius, alpha fades to the edge.
      const d = Math.abs(x - cx) / (W / 2) + Math.abs(y - cy) / (H / 2);
      const n = smoothCell(x, y, 7, 0x77aa);
      const rad = 0.58 + n * 0.20;      // wobbly edge
      if (d > rad) continue;
      const t = d / rad;                // 0 center → 1 edge
      let c = (n > 0.55) ? dirt : dirtDk;
      if (smoothCell(x, y, 3, 0x1234) < 0.10) c = speck;
      // fade alpha toward the edge so it blends with the grass (trodden, not a hard tile).
      const a = Math.round(150 * (1 - t) * (1 - t));
      if (a <= 4) continue;
      setPx(cv, x, y, c, a);
    }
  }
  save(cv, name);
}
makeWornDirt('worn_dirt_patch.png');

// ---- A3: Local light-pool decals (radial gradient PNGs, 256px) -------------
// Soft additive glow decals the map loader lays UNDER/around light sources
// (cauldron, world tree, mystic water, open night buds). Rendered on the glow
// CanvasLayer (additive, unaffected by day/night modulate) so at night they read
// like the reference dioramas' local light. Radial gradient, low peak alpha.
//   light_pool_violet  — cauldron / night buds (warm violet)
//   light_pool_violet_lg — world tree (large)
//   light_pool_cyan    — mystic water (cyan-violet)
function makeLightPool(name, size, coreHex, edgeHex, peakAlpha) {
  const W = size, H = size;
  const cv = makeCanvas(W, H);
  const core = hexToRGB(coreHex);
  const edge = hexToRGB(edgeHex);
  const cx = (W - 1) / 2, cy = (H - 1) / 2;
  const R = W / 2;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const d = Math.hypot(x - cx, y - cy) / R; // 0 center → 1 rim
      if (d >= 1.0) continue;
      // smooth falloff: quadratic-ish, soft toward the rim
      const f = Math.pow(1.0 - d, 2.2);
      const a = Math.round(peakAlpha * f);
      if (a <= 0) continue;
      // colour lerps core→edge with radius so the rim tints slightly cooler/warmer
      const c = mix(core, edge, Math.min(1, d * 1.1));
      setPx(cv, x, y, c, a);
    }
  }
  save(cv, name);
}
makeLightPool('light_pool_violet.png', 256, '#d9b8ff', '#6b4a9e', 150);
makeLightPool('light_pool_violet_lg.png', 256, '#d9b8ff', '#6b4a9e', 175);
makeLightPool('light_pool_cyan.png', 256, '#8fd4d9', '#4a5c9e', 140);

console.log('DONE');
