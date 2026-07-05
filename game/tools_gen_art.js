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

// ---- Tile generation ----
// spec: fill color, optional edge color, optional dot color + density, dither for water
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
  // deterministic pseudo-random for dot placement
  let seed = 1234567;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (!inDiamond(x, y, W, H)) continue;
      let c = fill;
      // water dither: two-tone checker on the surface
      if (opts.dither) {
        const alt = hexToRGB(opts.ditherHex);
        if (((x >> 2) + (y >> 1)) % 2 === 0) c = alt;
      }
      if (edge && onDiamondEdge(x, y, W, H)) c = edge;
      setPx(cv, x, y, c, 255);
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

// T0 VOID: dark with violet edge hint — keep the violet rim strong (world signature).
makeTile('t0_void.png', '#2a2a33', { edgeHex: '#6b4a9e', hardEdge: true });
// T1 dirt path
makeTile('t1_dirt.png', '#8a6a4a', { edgeHex: '#5c4433' });
// T2A grass
makeTile('t2a_grass.png', '#7ab567', { edgeHex: '#4d8b4f' });
// T2B grass + pink flowers
makeTile('t2b_grass_flowers.png', '#7ab567', { edgeHex: '#4d8b4f', dotHex: '#f0a8b8', dotCount: 14 });
// T2C grass + clover (darker green dots)
makeTile('t2c_grass_clover.png', '#4d8b4f', { edgeHex: '#2e5d3b', dotHex: '#7ab567', dotCount: 12 });
// T2D flower grass, light with white dots
makeTile('t2d_flower_grass.png', '#a8d982', { edgeHex: '#7ab567', dotHex: '#faf5e6', dotCount: 16 });
// T4 mud
makeTile('t4_mud.png', '#5c4433', { edgeHex: '#3a2a20' });
// T5A water
makeTile('t5a_water.png', '#4aa3b8', { edgeHex: '#2e6b8a', dither: true, ditherHex: '#8fd4d9' });
// T5B water2
makeTile('t5b_water2.png', '#2e6b8a', { edgeHex: '#1e3a5c', dither: true, ditherHex: '#4aa3b8' });

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

// ---- Character sheet ----
// Frames 96x96. Layout: rows = directions [SE, SW, NE, NW],
// cols = [idle, walk0, walk1]. Sheet = 3 cols x 4 rows = 288x384.
function drawCat(cv, ox, oy, dir, walkPhase) {
  // dir: 0=SE,1=SW,2=NE,3=NW. Body cream, eyes violet.
  const body = hexToRGB('#e8dfc8');
  const bodyDark = hexToRGB('#b8b4a8');
  const eye = hexToRGB('#9e7ad9');
  const F = 96;
  const cx = ox + F / 2;
  // body: rounded blob centered, ground at oy+F-10
  const baseY = oy + F - 16;
  const bodyR = 22, bodyH = 30;
  // legs bob for walk
  const bob = walkPhase === 1 ? 2 : 0;
  // body ellipse (torso)
  for (let y = -bodyH; y <= 0; y++) {
    for (let x = -bodyR; x <= bodyR; x++) {
      const dx = x / bodyR, dy = y / bodyH;
      if (dx * dx + dy * dy <= 1.0) {
        const c = (x - y) > 4 ? body : bodyDark;
        setPx(cv, cx + x, baseY + y - bob, c, 255);
      }
    }
  }
  // head: circle on top
  const hy = baseY - bodyH - 8 - bob;
  const hR = 18;
  for (let y = -hR; y <= hR; y++) {
    for (let x = -hR; x <= hR; x++) {
      if (x * x + y * y <= hR * hR) {
        const c = (x - y) > 3 ? body : bodyDark;
        setPx(cv, cx + x, hy + y, c, 255);
      }
    }
  }
  // ears (two triangles)
  for (let e = -1; e <= 1; e += 2) {
    const exc = cx + e * 11;
    for (let y = 0; y < 10; y++) {
      const halfw = Math.floor((10 - y) / 2);
      for (let x = -halfw; x <= halfw; x++) setPx(cv, exc + x, hy - hR - 2 + y, body, 255);
    }
  }
  // eyes: depend on direction. NE/NW (facing away) -> no eyes / faint.
  const facingAway = (dir === 2 || dir === 3);
  if (!facingAway) {
    const ex = (dir === 0) ? 5 : -5; // SE looks right-ish, SW left-ish
    setPx(cv, cx + ex - 4, hy - 2, eye); setPx(cv, cx + ex - 3, hy - 2, eye);
    setPx(cv, cx + ex - 4, hy - 1, eye); setPx(cv, cx + ex - 3, hy - 1, eye);
    setPx(cv, cx + ex + 4, hy - 2, eye); setPx(cv, cx + ex + 5, hy - 2, eye);
    setPx(cv, cx + ex + 4, hy - 1, eye); setPx(cv, cx + ex + 5, hy - 1, eye);
  } else {
    // tail hint for back views
    fillRect(cv, cx + (dir === 2 ? 12 : -16), baseY - 20, cx + (dir === 2 ? 18 : -10), baseY - 6, bodyDark);
  }
}

function makeCharSheet() {
  const cols = 3, rows = 4, F = 96;
  const cv = makeCanvas(cols * F, rows * F);
  for (let r = 0; r < rows; r++) {
    // col0 idle (phase 0), col1 walk0 (phase 0), col2 walk1 (phase 1)
    drawCat(cv, 0 * F, r * F, r, 0);
    drawCat(cv, 1 * F, r * F, r, 0);
    drawCat(cv, 2 * F, r * F, r, 1);
  }
  save(cv, 'character_sheet.png');
}
makeCharSheet();

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

// ---- Cauldron (솥단지, M3) ----
// 128x128, ground origin at bottom-center. Dark pot body with a violet glow rim
// (accent #9e7ad9) around the mouth — reads as the fusion cauldron. Palette per
// art guide: dark #2a2a33 base, violet accent #9e7ad9, cream highlight #faf5e6.
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const bodyDark = hexToRGB('#2a2a33');
  const bodyLit = hexToRGB('#3d3d4a');
  const glow = hexToRGB('#9e7ad9');
  const glowBright = hexToRGB('#c8a8ec');
  const brew = hexToRGB('#6b4a9e');
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

  // mouth: brewing ellipse at the top of the belly (the violet fusion surface)
  const mcx = 64, mcy = 52, mrx = 40, mry = 13;
  for (let y = -mry; y <= mry; y++)
    for (let x = -mrx; x <= mrx; x++) {
      const dx = x / mrx, dy = y / mry;
      if (dx * dx + dy * dy <= 1.0) {
        // shimmer: alternate brew / glow for a bubbling look
        const c = (((x >> 2) + (y >> 1)) % 2 === 0) ? brew : glow;
        setPx(cv, mcx + x, mcy + y, c, 255);
      }
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

  // faint cream sparkle above the brew (the "whisper")
  setPx(cv, 60, 40, cream, 220); setPx(cv, 61, 40, cream, 220);
  setPx(cv, 72, 36, cream, 180);
  setPx(cv, 52, 38, cream, 160);

  save(cv, 'cauldron.png');
})();

// ============================================================================
// M4 art — 시작의 숲 landmarks & gates.
// Palette (art guide §3): green #4d8b4f/#7ab567, brown #5c4433/#8a6a4a,
// violet #6b4a9e/#9e7ad9/#d9b8ff, moss #4d8b4f, cream #faf5e6.
// All objects: bottom-center ground origin; violet glow baked as a separate
// *_glow.png additive layer (kept out of CanvasModulate so night makes it pop).
// ============================================================================

// ---- Dry bush (G2, bush_dry). 128x128, dry brown/grey, thorny clumps. ----
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  // contact shadow
  const sh = hexToRGB('#000000');
  for (let y = -6; y <= 6; y++)
    for (let x = -30; x <= 30; x++) {
      const dx = x / 30, dy = y / 6;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 10 + y, sh, 40);
    }
  const dry = hexToRGB('#8a6a4a');      // dry brown
  const dryDark = hexToRGB('#5c4433');
  const grey = hexToRGB('#6e6e7a');     // dead grey
  // three overlapping dry blobs
  const blobs = [[64, 78, 30, 26], [44, 88, 22, 18], [86, 90, 20, 16]];
  for (const [bcx, bcy, brx, bry] of blobs) {
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++) {
        const dx = (x - bcx) / brx, dy = (y - bcy) / bry;
        if (dx * dx + dy * dy <= 1.0) {
          const c = (dx - dy) > 0.2 ? dry : dryDark;
          setPx(cv, x, y, c, 255);
        }
      }
  }
  // grey dead twigs sticking up
  let seed = 99;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let t = 0; t < 14; t++) {
    const bx = 40 + Math.floor(rnd() * 48);
    const h = 14 + Math.floor(rnd() * 22);
    for (let y = 0; y < h; y++) {
      const lean = Math.floor((y / h) * (rnd() * 6 - 3));
      setPx(cv, bx + lean, 70 - y, grey);
    }
  }
  save(cv, 'bush_dry.png');
})();

// ---- Bloomed bush (G2 after I7 water). Same silhouette, green + violet flowers. ----
(function () {
  const W = 128, H = 128;
  const cv = makeCanvas(W, H);
  const sh = hexToRGB('#000000');
  for (let y = -6; y <= 6; y++)
    for (let x = -30; x <= 30; x++) {
      const dx = x / 30, dy = y / 6;
      if (dx * dx + dy * dy <= 1.0) setPx(cv, (W >> 1) + x, H - 10 + y, sh, 40);
    }
  const green = hexToRGB('#4d8b4f');
  const greenLit = hexToRGB('#7ab567');
  const bloom = hexToRGB('#d9b8ff');
  const blobs = [[64, 78, 30, 26], [44, 88, 22, 18], [86, 90, 20, 16]];
  for (const [bcx, bcy, brx, bry] of blobs) {
    for (let y = 0; y < H; y++)
      for (let x = 0; x < W; x++) {
        const dx = (x - bcx) / brx, dy = (y - bcy) / bry;
        if (dx * dx + dy * dy <= 1.0) {
          const c = (dx - dy) > 0.2 ? greenLit : green;
          setPx(cv, x, y, c, 255);
        }
      }
  }
  let seed = 7;
  const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
  for (let f = 0; f < 20; f++) {
    const x = 40 + Math.floor(rnd() * 48);
    const y = 62 + Math.floor(rnd() * 34);
    setPx(cv, x, y, bloom); setPx(cv, x + 1, y, bloom);
    setPx(cv, x, y + 1, bloom); setPx(cv, x + 1, y + 1, bloom);
  }
  save(cv, 'bush_bloom.png');
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

console.log('DONE');
