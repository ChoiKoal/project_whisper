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
  const edge = opts.edgeHex ? hexToRGB(opts.edgeHex) : null;
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

// T0 VOID: dark with violet edge hint
makeTile('t0_void.png', '#2a2a33', { edgeHex: '#6b4a9e' });
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

console.log('DONE');
