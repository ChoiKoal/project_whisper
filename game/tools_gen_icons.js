// Item icon generator for Project Whisper (v0.2.0 art/UI sprint).
// Produces 58 UNIQUE 48x48 RGBA pixel icons -> assets/icons/<id>.png.
//
// Design rules (art-style-guide §2/§3/§7):
//   - palette-strict (the 22-colour Layer-1 ramps + a few accent hues declared here)
//   - NO pure-black outlines; each shape gets a "selout" outline = a darker same-hue
//     colour, applied as a 1px border around the opaque silhouette.
//   - soft top-right light: a lighter tone on the upper-right of each blob.
//   - simple, bold, readable silhouettes on a transparent background.
//   - deterministic (fixed seeds) so regeneration is byte-stable.
//
// Families share visual cues:
//   violet-glow family (생명수/빛나는 새싹/정령꽃/어린 세계수/축복받은 가지/등불꽃/생명의 정원)
//   wood/brown family (판자/울타리/바구니/낚싯대/나무다리/새집/허수아비 …)
//   stone/grey family (석기/벽돌/조약돌/돌탑/벽 …)
//   flower/plant family (씨앗/새싹/묘목/꽃즙/꽃다발/클로버/수련/연꽃/화환 …)
'use strict';
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');

const OUT = path.join(__dirname, 'assets', 'icons');
fs.mkdirSync(OUT, { recursive: true });
const SIZE = 48;

// ---- PNG encoder (same minimal encoder as tools_gen_art.js) ----
function crc32(buf) {
  let c = ~0;
  for (let i = 0; i < buf.length; i++) {
    c ^= buf[i];
    for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1));
  }
  return (~c) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0);
  return Buffer.concat([len, body, crc]);
}
function encodePNG(w, h, pixels) {
  const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const stride = w * 4;
  const raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (stride + 1)] = 0;
    pixels.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride);
  }
  const idat = zlib.deflateSync(raw, { level: 9 });
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}

// ---- canvas + colour helpers ----
function makeCanvas(w = SIZE, h = SIZE) { return { w, h, data: Buffer.alloc(w * h * 4, 0) }; }
function hexToRGB(hex) {
  const s = hex.replace('#', '');
  return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
}
function setPx(cv, x, y, rgb, a = 255) {
  x |= 0; y |= 0;
  if (x < 0 || y < 0 || x >= cv.w || y >= cv.h) return;
  const i = (y * cv.w + x) * 4;
  // straight-alpha over-compositing (icons are drawn opaque-first so this is mostly plain writes)
  if (a >= 255) { cv.data[i] = rgb[0]; cv.data[i + 1] = rgb[1]; cv.data[i + 2] = rgb[2]; cv.data[i + 3] = 255; return; }
  const sa = a / 255, da = cv.data[i + 3] / 255;
  const oa = sa + da * (1 - sa);
  if (oa <= 0) return;
  for (let k = 0; k < 3; k++)
    cv.data[i + k] = Math.round((rgb[k] * sa + cv.data[i + k] * da * (1 - sa)) / oa);
  cv.data[i + 3] = Math.round(oa * 255);
}
function getA(cv, x, y) {
  if (x < 0 || y < 0 || x >= cv.w || y >= cv.h) return 0;
  return cv.data[(y * cv.w + x) * 4 + 3];
}
function fillRect(cv, x0, y0, x1, y1, rgb, a = 255) {
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) setPx(cv, x, y, rgb, a);
}
function darker(rgb, amt) { return rgb.map(v => Math.max(0, Math.round(v - amt))); }
function lighter(rgb, amt) { return rgb.map(v => Math.min(255, Math.round(v + amt))); }

// Filled ellipse with soft top-right light. lit/dark are same-hue tones.
function ellipse(cv, cx, cy, rx, ry, lit, dark) {
  for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
    for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
      const dx = (x - cx) / rx, dy = (y - cy) / ry;
      if (dx * dx + dy * dy <= 1.0)
        setPx(cv, x, y, (dx - dy) > 0.12 ? lit : dark, 255);
    }
}
function circle(cv, cx, cy, r, lit, dark) { ellipse(cv, cx, cy, r, r, lit, dark); }

function disc(cv, cx, cy, r, rgb, a = 255) {
  for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++)
    for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) {
      const dx = x - cx, dy = y - cy;
      if (dx * dx + dy * dy <= r * r) setPx(cv, x, y, rgb, a);
    }
}
function line(cv, x0, y0, x1, y1, rgb, w = 1) {
  x0 = Math.round(x0); y0 = Math.round(y0); x1 = Math.round(x1); y1 = Math.round(y1);
  const dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0);
  const sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let err = dx - dy, x = x0, y = y0;
  for (;;) {
    for (let oy = 0; oy < w; oy++) for (let ox = 0; ox < w; ox++) setPx(cv, x + ox, y + oy, rgb);
    if (x === x1 && y === y1) break;
    const e2 = 2 * err;
    if (e2 > -dy) { err -= dy; x += sx; }
    if (e2 < dx) { err += dx; y += sy; }
  }
}

// selout outline: paint a 1px border (colour = darker same-hue) around every opaque
// pixel that touches a transparent neighbour. Never pure black.
function outline(cv, hex) {
  const oc = hexToRGB(hex);
  const src = Buffer.from(cv.data);
  const alphaAt = (x, y) => (x < 0 || y < 0 || x >= cv.w || y >= cv.h) ? 0 : src[(y * cv.w + x) * 4 + 3];
  for (let y = 0; y < cv.h; y++)
    for (let x = 0; x < cv.w; x++) {
      if (alphaAt(x, y) !== 0) continue;
      if (alphaAt(x - 1, y) > 0 || alphaAt(x + 1, y) > 0 ||
          alphaAt(x, y - 1) > 0 || alphaAt(x, y + 1) > 0)
        setPx(cv, x, y, oc, 255);
    }
}

function save(cv, id) {
  const png = encodePNG(cv.w, cv.h, cv.data);
  fs.writeFileSync(path.join(OUT, id + '.png'), png);
  return png.length;
}

// ---- palette (art guide §3) ----
const P = {
  greenD: '#1b3a2a', green: '#2e5d3b', greenM: '#4d8b4f', greenL: '#7ab567', greenH: '#a8d982',
  brownD: '#3a2a20', brown: '#5c4433', brownM: '#8a6a4a', brownL: '#b59268',
  blueD: '#1e3a5c', blue: '#2e6b8a', blueM: '#4aa3b8', blueL: '#8fd4d9',
  violetD: '#3a2a5c', violet: '#6b4a9e', violetM: '#9e7ad9', violetL: '#d9b8ff',
  greyD: '#2a2a33', grey: '#6e6e7a', greyL: '#b8b4a8', cream: '#e8dfc8', white: '#faf5e6',
  // accent hues (declared here; §3.1 allows accent ramps for variety)
  pink: '#c96a7a', pinkL: '#f0a8b8', red: '#8a3a4a',
  gold: '#d98a3a', goldL: '#f0c078',
  // ---- Layer-2 science family (L2-4) — design v1 §C-1: metal greys + cyan glow + neon.
  navy: '#1a2438', navyL: '#28374f',
  steelD: '#222a38', steel: '#3a4452', steelM: '#5a6472', steelL: '#828c9c', steelH: '#a6b0c0',
  rust: '#7a4a38', rustD: '#4a2c22',
  cyanD: '#1f6b64', cyan: '#2fbfa8', cyanM: '#4ad9c8', cyanL: '#9df0e6',
  neonD: '#7a2e6a', neon: '#c74aa8', neonL: '#f090d8',
  amber: '#d9a23a', amberL: '#f0cd80',
  ash: '#4a4650', ashL: '#6e6a74',
};
const C = {};
for (const k in P) C[k] = hexToRGB(P[k]);

// ============================================================================
// Per-item icon painters. Each returns nothing; draws into `cv` (48x48).
// A trailing outline() + optional glow gives every icon a crisp readable edge.
// ============================================================================
const icons = {};

// ---------- Gatherables I1..I9 ----------
icons.I1 = (cv) => { // 흙 mound
  ellipse(cv, 24, 34, 17, 10, C.brownM, C.brown);
  // little clods
  disc(cv, 18, 30, 2, C.brownL); disc(cv, 30, 31, 2, C.brownL); disc(cv, 24, 28, 2, lighter(C.brownM, 10));
  outline(cv, P.brownD);
};
icons.I2 = (cv) => { // 풀 tuft
  const blades = [[16, C.greenM], [20, C.greenL], [24, C.green], [28, C.greenL], [32, C.greenM]];
  for (const [bx, col] of blades) {
    const h = 20 + ((bx * 5) % 8);
    for (let y = 0; y < h; y++) {
      const lean = Math.round((y / h) * ((bx % 3) - 1) * 5);
      setPx(cv, bx + lean, 40 - y, col); setPx(cv, bx + lean + 1, 40 - y, col);
    }
  }
  outline(cv, P.green);
};
icons.I3 = (cv) => { // 진흙 blob (glossy)
  ellipse(cv, 24, 32, 16, 11, C.brown, C.brownD);
  ellipse(cv, 20, 28, 6, 3, C.brownM, C.brown); // wet sheen
  disc(cv, 30, 34, 2, C.brownD);
  outline(cv, '#241a12');
};
icons.I4 = (cv) => { // 나무 log/trunk (also D06 alias resolves to this)
  fillRect(cv, 14, 16, 34, 34, C.brown);
  fillRect(cv, 14, 16, 22, 34, C.brownM); // lit left face? keep top-right: relight below
  // relight: right side lighter
  for (let y = 16; y < 34; y++) for (let x = 14; x < 34; x++) setPx(cv, x, y, x > 26 ? C.brownM : C.brown);
  // end-grain rings on top
  ellipse(cv, 24, 16, 10, 4, C.brownL, C.brownM);
  disc(cv, 24, 16, 3, C.brown); disc(cv, 24, 16, 1, C.brownL);
  fillRect(cv, 14, 33, 34, 36, C.brownD); // base
  outline(cv, P.brownD);
};
icons.I5 = (cv) => { // 꽃 bloom (pink, 5 petals)
  const cx = 24, cy = 22;
  fillRect(cv, 23, 24, 26, 40, C.greenM); // stem
  for (let a = 0; a < 5; a++) {
    const r = a * (Math.PI * 2 / 5) - Math.PI / 2;
    ellipse(cv, cx + Math.cos(r) * 9, cy + Math.sin(r) * 9, 6, 6, C.pinkL, C.pink);
  }
  disc(cv, cx, cy, 4, C.goldL);
  outline(cv, P.red);
};
icons.I6 = (cv) => { // 바위 boulder (grey, faceted)
  ellipse(cv, 24, 32, 17, 12, C.grey, darker(C.grey, 22));
  // top facet highlight
  for (let y = 22; y < 30; y++) for (let x = 22; x < 38; x++) if (getA(cv, x, y)) setPx(cv, x, y, C.greyL);
  line(cv, 24, 22, 20, 34, darker(C.grey, 30), 1);
  outline(cv, '#3f3f48');
};
icons.I7 = (cv) => { // 물 drop
  const cx = 24;
  // teardrop: triangle top + circle bottom
  for (let y = 12; y < 26; y++) {
    const hw = Math.round((y - 12) / 14 * 9);
    for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.blueM : C.blue);
  }
  ellipse(cv, cx, 30, 11, 11, C.blueM, C.blue);
  disc(cv, cx + 4, 27, 2, C.blueL); // sheen
  outline(cv, P.blueD);
};
icons.I8 = (cv) => { // 돌 pebble (small, pair)
  ellipse(cv, 21, 32, 10, 7, C.greyL, C.grey);
  ellipse(cv, 32, 35, 7, 5, C.grey, darker(C.grey, 18));
  outline(cv, '#45454e');
};
icons.I9 = (cv) => { // 세계수 정수 glowing violet orb
  glowBehind(cv, 24, 24, 18, C.violetM);
  circle(cv, 24, 24, 12, C.violetL, C.violetM);
  disc(cv, 28, 20, 3, C.white); // spec highlight
  disc(cv, 20, 28, 2, C.violetL, 200);
  outline(cv, P.violet);
  sparkle(cv, 14, 16); sparkle(cv, 34, 30);
};

// small helpers for the violet-glow family
function glowBehind(cv, cx, cy, r, col) {
  for (let y = cy - r; y <= cy + r; y++)
    for (let x = cx - r; x <= cx + r; x++) {
      const d = Math.hypot(x - cx, y - cy) / r;
      if (d <= 1) setPx(cv, x, y, col, Math.round(70 * (1 - d)));
    }
}
function sparkle(cv, x, y) {
  setPx(cv, x, y, C.white); setPx(cv, x - 1, y, C.violetL, 200); setPx(cv, x + 1, y, C.violetL, 200);
  setPx(cv, x, y - 1, C.violetL, 200); setPx(cv, x, y + 1, C.violetL, 200);
}

// ---------- Crafts D01..D49 ----------
icons.D01 = (cv) => { // 모래 sand pile
  ellipse(cv, 24, 34, 17, 9, C.goldL, C.gold);
  for (let i = 0; i < 24; i++) { const x = 10 + (i * 7) % 28, y = 28 + (i * 5) % 10; setPx(cv, x, y, i % 2 ? C.gold : lighter(C.goldL, 10)); }
  outline(cv, '#a8641e');
};
icons.D02 = (cv) => { // 점토 clay lump
  ellipse(cv, 24, 32, 15, 12, C.brownL, C.brownM);
  ellipse(cv, 20, 27, 5, 3, lighter(C.brownL, 15), C.brownL);
  outline(cv, P.brown);
};
icons.D03 = (cv) => { // 씨앗 seed
  ellipse(cv, 24, 26, 8, 12, C.brownL, C.brown);
  line(cv, 24, 16, 24, 36, C.brown, 1); // seam
  disc(cv, 21, 21, 2, lighter(C.brownL, 20));
  outline(cv, P.brownD);
};
icons.D04 = (cv) => { // 새싹 sprout (family: plant)
  fillRect(cv, 23, 26, 26, 40, C.greenM);
  leaf(cv, 24, 26, -1, C.greenL, C.greenM);
  leaf(cv, 24, 22, 1, C.greenH, C.greenL);
  outline(cv, P.green);
};
icons.D05 = (cv) => { // 묘목 sapling
  fillRect(cv, 23, 24, 26, 40, C.brownM);
  ellipse(cv, 24, 18, 11, 10, C.greenL, C.greenM);
  ellipse(cv, 24, 14, 6, 5, C.greenH, C.greenL);
  outline(cv, P.green);
};
// D06 -> alias of I4 (handled in the id loop; we still emit a file = copy of I4)
icons.D07 = (cv) => { // 이끼 moss patch
  ellipse(cv, 24, 32, 16, 9, C.green, C.greenD);
  for (let i = 0; i < 30; i++) { const x = 10 + (i * 11) % 28, y = 26 + (i * 7) % 12; setPx(cv, x, y, i % 3 ? C.greenM : C.greenL); }
  outline(cv, '#12281c');
};
icons.D08 = (cv) => { // 이끼바위 mossy rock (family: stone + moss)
  ellipse(cv, 24, 33, 16, 11, C.grey, darker(C.grey, 22));
  // moss cap
  for (let y = 22; y < 32; y++) for (let x = 12; x < 36; x++) {
    if (!getA(cv, x, y)) continue;
    const dx = (x - 24) / 15, dy = (y - 30) / 10;
    if (dx * dx + dy * dy <= 1 && y < 30 && ((x + y) % 3 !== 0)) setPx(cv, x, y, (x - y) > -2 ? C.greenL : C.greenM);
  }
  outline(cv, '#3f3f48');
};
icons.D09 = (cv) => { // 건초 hay bundle
  for (let i = 0; i < 16; i++) { const x = 12 + i, y = 16 + (i % 3); line(cv, x, y, x - 3, 40, i % 2 ? C.goldL : C.gold, 1); }
  fillRect(cv, 12, 26, 36, 30, C.brownM); // twine band
  fillRect(cv, 12, 27, 36, 29, C.brown);
  outline(cv, '#a8641e');
};
icons.D10 = (cv) => { // 둥지 nest
  ellipse(cv, 24, 32, 17, 11, C.brownM, C.brown);
  ellipse(cv, 24, 30, 11, 6, C.brownD, C.brownD); // hollow
  disc(cv, 21, 30, 3, C.cream); disc(cv, 28, 31, 3, C.blueL); // eggs
  outline(cv, P.brownD);
};
icons.D12 = (cv) => { // 목재 lumber (stacked cut logs)
  for (const [y0] of [[16], [26]]) {
    fillRect(cv, 10, y0, 38, y0 + 9, C.brown);
    for (let x = 12; x < 38; x += 9) { disc(cv, x, y0 + 4, 3, C.brownM); disc(cv, x, y0 + 4, 1, C.brownL); }
  }
  outline(cv, P.brownD);
};
icons.D13 = (cv) => { // 벽돌 brick (family: stone/masonry, reddish)
  fillRect(cv, 10, 20, 38, 34, C.pink === undefined ? C.brownM : hexToRGB('#a85a4a'));
  const brickRed = hexToRGB('#a85a4a'), brickLit = hexToRGB('#c47a68');
  fillRect(cv, 10, 20, 38, 34, brickRed);
  fillRect(cv, 10, 20, 38, 24, brickLit); // top-lit
  fillRect(cv, 10, 26, 38, 27, darker(brickRed, 30)); // mortar
  line(cv, 24, 20, 24, 26, darker(brickRed, 30), 1);
  outline(cv, '#6e3327');
};
icons.D14 = (cv) => { // 디딤돌 stepping stone (flat disc on water)
  ellipse(cv, 24, 34, 16, 6, C.blueM, C.blue); // water ripple base
  ellipse(cv, 24, 27, 13, 8, C.greyL, C.grey); // stone
  outline(cv, '#3f3f48');
};
icons.D15 = (cv) => { // 늪 swamp (dark water + bubbles)
  ellipse(cv, 24, 32, 17, 11, C.greenD, darker(C.greenD, 6));
  ellipse(cv, 24, 30, 13, 7, hexToRGB('#274a3a'), C.greenD);
  disc(cv, 19, 29, 2, C.greenM); disc(cv, 29, 31, 2, C.greenM); disc(cv, 25, 27, 1, C.greenL);
  outline(cv, '#0f1f16');
};
icons.D16 = (cv) => { // 꽃즙 nectar (vial with pink liquid)
  vial(cv, hexToRGB('#e08aa0'), hexToRGB('#c96a7a'));
  outline(cv, P.red);
};
icons.D17 = (cv) => { // 물감 paint (three dabs)
  disc(cv, 17, 22, 6, C.pinkL); disc(cv, 30, 20, 6, C.blueM); disc(cv, 24, 32, 6, C.goldL);
  disc(cv, 15, 20, 2, C.white);
  outline(cv, P.violet);
};
icons.D18 = (cv) => { // 꽃다발 bouquet
  fillRect(cv, 22, 28, 27, 42, C.greenM); // stems
  ellipse(cv, 18, 22, 6, 6, C.pinkL, C.pink);
  ellipse(cv, 30, 22, 6, 6, C.violetL, C.violetM);
  ellipse(cv, 24, 16, 6, 6, C.goldL, C.gold);
  fillRect(cv, 20, 30, 29, 34, C.brownM); // wrap
  outline(cv, P.green);
};
icons.D19 = (cv) => { // 생명수 water-of-life (violet-glow family: flask)
  glowBehind(cv, 24, 28, 16, C.violetM);
  flask(cv, C.violetL, C.violetM);
  sparkle(cv, 24, 18);
  outline(cv, P.violet);
};
icons.D20 = (cv) => { // 빛나는 새싹 shining sprout (glow family)
  glowBehind(cv, 24, 22, 15, C.violetM);
  fillRect(cv, 23, 26, 26, 40, C.greenM);
  leaf(cv, 24, 26, -1, C.greenH, C.greenL);
  leaf(cv, 24, 21, 1, C.violetL, C.violetM);
  sparkle(cv, 32, 16); sparkle(cv, 16, 22);
  outline(cv, P.green);
};
icons.D21 = (cv) => { // 정령꽃 spirit flower (glow family)
  glowBehind(cv, 24, 22, 16, C.violetM);
  fillRect(cv, 23, 26, 26, 42, C.greenM);
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3; ellipse(cv, 24 + Math.cos(r) * 9, 22 + Math.sin(r) * 9, 5, 5, C.violetL, C.violetM); }
  disc(cv, 24, 22, 4, C.white);
  outline(cv, P.violet);
};
icons.D22 = (cv) => { // 어린 세계수 young world tree (glow family)
  glowBehind(cv, 24, 20, 17, C.violetM);
  fillRect(cv, 22, 26, 27, 42, C.brown);
  ellipse(cv, 24, 18, 13, 12, C.greenL, C.green);
  ellipse(cv, 24, 14, 7, 6, C.greenH, C.greenL);
  sparkle(cv, 18, 14); sparkle(cv, 31, 20); sparkle(cv, 24, 8);
  outline(cv, P.green);
};
icons.D23 = (cv) => { // 판자 plank (wood family)
  fillRect(cv, 8, 20, 40, 30, C.brownM);
  fillRect(cv, 8, 20, 40, 23, C.brownL); // top-lit
  for (let x = 12; x < 40; x += 6) line(cv, x, 20, x, 30, C.brown, 1); // grain
  outline(cv, P.brown);
};
icons.D24 = (cv) => { // 울타리 fence (wood family)
  for (const px of [14, 24, 34]) { fillRect(cv, px - 2, 12, px + 2, 40, C.brownM); fillRect(cv, px - 2, 12, px, 40, C.brownL); }
  fillRect(cv, 10, 20, 38, 24, C.brown); fillRect(cv, 10, 30, 38, 34, C.brown); // rails
  outline(cv, P.brownD);
};
icons.D25 = (cv) => { // 밧줄 rope coil
  for (let a = 0; a < 360; a += 6) { const r = a * Math.PI / 180; const rad = 13; setPx(cv, 24 + Math.cos(r) * rad, 28 + Math.sin(r) * rad * 0.85, ((a / 30) | 0) % 2 ? C.brownL : C.brownM); }
  for (let a = 0; a < 360; a += 6) { const r = a * Math.PI / 180; const rad = 7; setPx(cv, 24 + Math.cos(r) * rad, 28 + Math.sin(r) * rad * 0.85, ((a / 30) | 0) % 2 ? C.brownL : C.brownM); }
  disc(cv, 24, 28, 3, 0 === 0 ? C.brownD : C.brownD);
  // recolor centre hole to transparent-ish dark
  outline(cv, P.brownD);
};
icons.D26 = (cv) => { // 바구니 basket (wood family, weave)
  for (let y = 24; y < 40; y++) { const hw = 15 - (y - 24) * 0.3; for (let x = 24 - hw; x <= 24 + hw; x++) { const w = ((x + y) % 4 < 2); setPx(cv, x, y, w ? C.brownM : C.brownL); } }
  ellipse(cv, 24, 24, 15, 4, C.brownL, C.brownM); // rim
  outline(cv, P.brownD);
};
icons.D27 = (cv) => { // 낚싯대 fishing rod (wood family)
  line(cv, 12, 40, 36, 10, C.brownM, 2);
  line(cv, 36, 10, 34, 34, C.greyL, 1); // line
  ellipse(cv, 34, 35, 3, 4, C.red === undefined ? C.pink : hexToRGB('#c96a7a'), C.red); // bob
  disc(cv, 34, 35, 2, C.pinkL);
  outline(cv, P.brownD);
};
icons.D28 = (cv) => { // 흙벽돌 mud brick (brown masonry)
  fillRect(cv, 10, 20, 38, 34, C.brownM);
  fillRect(cv, 10, 20, 38, 24, C.brownL);
  fillRect(cv, 10, 26, 38, 27, C.brown); line(cv, 24, 20, 24, 26, C.brown, 1);
  for (let i = 0; i < 8; i++) setPx(cv, 14 + i * 3, 30, C.goldL); // straw fleck
  outline(cv, P.brownD);
};
icons.D29 = (cv) => { // 화분 flower pot
  for (let y = 26; y < 42; y++) { const hw = 12 - (y - 26) * 0.35; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? hexToRGB('#c47a68') : hexToRGB('#a85a4a')); }
  fillRect(cv, 11, 24, 37, 28, hexToRGB('#c47a68'));
  ellipse(cv, 24, 20, 8, 7, C.greenL, C.greenM); disc(cv, 24, 16, 3, C.pinkL);
  outline(cv, '#6e3327');
};
icons.D30 = (cv) => { // 모래성 sand castle
  fillRect(cv, 12, 24, 36, 40, C.goldL);
  fillRect(cv, 14, 16, 20, 24, C.goldL); fillRect(cv, 28, 16, 34, 24, C.goldL); // towers
  fillRect(cv, 22, 20, 26, 40, C.gold); // gate
  for (let x = 14; x < 20; x += 2) setPx(cv, x, 15, C.gold);
  outline(cv, '#a8641e');
};
icons.D31 = (cv) => { // 조약돌 pebbles (stone family, cluster of 3)
  ellipse(cv, 18, 34, 8, 6, C.greyL, C.grey);
  ellipse(cv, 30, 32, 7, 5, C.grey, darker(C.grey, 18));
  ellipse(cv, 25, 38, 6, 4, C.greyL, C.grey);
  outline(cv, '#45454e');
};
icons.D32 = (cv) => { // 물레방아 water wheel
  circle(cv, 24, 24, 15, C.brownM, C.brown);
  disc(cv, 24, 24, 9, 0 === 0 ? C.brownD : C.brownD);
  for (let a = 0; a < 8; a++) { const r = a * Math.PI / 4; line(cv, 24, 24, 24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14, C.brownL, 1); }
  circle(cv, 24, 24, 4, C.greyL, C.grey);
  // water splash at base
  for (let i = 0; i < 6; i++) setPx(cv, 12 + i * 4, 40, C.blueL);
  outline(cv, P.brownD);
};
icons.D33 = (cv) => { // 나무다리 wooden bridge (wood family, arch)
  for (let x = 8; x < 40; x++) { const y = 30 - Math.round(Math.sin((x - 8) / 32 * Math.PI) * 8); setPx(cv, x, y, C.brownL); setPx(cv, x, y + 1, C.brownM); setPx(cv, x, y + 2, C.brown); }
  for (let x = 10; x < 40; x += 6) { const y = 30 - Math.round(Math.sin((x - 8) / 32 * Math.PI) * 8); line(cv, x, y + 2, x, y + 8, C.brown, 1); }
  outline(cv, P.brownD);
};
icons.D34 = (cv) => { // 화환 wreath (flower family, ring)
  for (let a = 0; a < 360; a += 12) { const r = a * Math.PI / 180; const rad = 14; const cx = 24 + Math.cos(r) * rad, cy = 24 + Math.sin(r) * rad; ellipse(cv, cx, cy, 4, 4, C.greenL, C.greenM); }
  for (let a = 30; a < 360; a += 90) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14, 3, C.pinkL); }
  outline(cv, P.green);
};
icons.D35 = (cv) => { // 향수 perfume bottle
  fillRect(cv, 18, 20, 30, 40, C.violetL);
  for (let y = 20; y < 40; y++) for (let x = 18; x < 30; x++) setPx(cv, x, y, x - 24 > 0 ? C.violetL : C.violetM);
  fillRect(cv, 21, 12, 27, 20, C.greyL); fillRect(cv, 20, 10, 28, 13, C.grey); // cap
  disc(cv, 21, 24, 2, C.white);
  outline(cv, P.violet);
};
icons.D36 = (cv) => { // 비료 fertilizer (sack)
  for (let y = 18; y < 42; y++) { const hw = 13 - Math.abs(y - 30) * 0.15; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.brownL : C.brownM); }
  fillRect(cv, 16, 16, 32, 20, C.brown); // tied top
  ellipse(cv, 24, 30, 6, 5, C.greenM, C.green); // leaf mark
  outline(cv, P.brownD);
};
icons.D37 = (cv) => { // 옥토 rich soil (dark tilled earth + shoot)
  ellipse(cv, 24, 34, 17, 9, hexToRGB('#4a3325'), C.brownD);
  for (let x = 12; x < 38; x += 5) line(cv, x, 30, x, 38, C.brownD, 1); // furrows
  fillRect(cv, 23, 24, 25, 30, C.greenM); leaf(cv, 24, 24, 1, C.greenL, C.greenM);
  outline(cv, '#241a12');
};
icons.D38 = (cv) => { // 텃밭 garden plot (rows with sprouts)
  fillRect(cv, 8, 28, 40, 42, C.brownM);
  for (let x = 10; x < 40; x += 8) { line(cv, x, 28, x, 42, C.brown, 1); fillRect(cv, x + 2, 24, x + 4, 30, C.greenM); leaf(cv, x + 3, 24, 1, C.greenL, C.greenM); }
  outline(cv, P.brownD);
};
icons.D39 = (cv) => { // 클로버 clover (plant family, 4-leaf)
  fillRect(cv, 23, 26, 26, 42, C.greenM);
  for (let a = 0; a < 4; a++) { const r = a * Math.PI / 2 + Math.PI / 4; heart(cv, 24 + Math.cos(r) * 7, 22 + Math.sin(r) * 7, r, C.greenL, C.greenM); }
  outline(cv, P.green);
};
icons.D40 = (cv) => { // 수련 water lily (plant family, pad + bloom)
  ellipse(cv, 24, 34, 16, 6, C.greenM, C.green); // pad
  line(cv, 24, 34, 30, 30, C.greenD, 1); // notch
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; ellipse(cv, 24 + Math.cos(r) * 6, 24 + Math.sin(r) * 6, 4, 6, C.pinkL, C.pink); }
  disc(cv, 24, 24, 3, C.goldL);
  outline(cv, '#12281c');
};
icons.D41 = (cv) => { // 연꽃 lotus (plant family, tall pink bloom)
  for (let a = 0; a < 8; a++) { const r = a * Math.PI / 4 - Math.PI / 2; ellipse(cv, 24 + Math.cos(r) * 8, 24 + Math.sin(r) * 10, 4, 8, C.pinkL, C.pink); }
  for (let a = 0; a < 5; a++) { const r = a * Math.PI * 2 / 5 - Math.PI / 2; ellipse(cv, 24 + Math.cos(r) * 4, 22 + Math.sin(r) * 4, 3, 5, C.white, C.pinkL); }
  disc(cv, 24, 22, 3, C.goldL);
  outline(cv, P.red);
};
icons.D42 = (cv) => { // 정원 garden (arch + flowers)
  // arch
  for (let a = 20; a <= 160; a += 4) { const r = a * Math.PI / 180; setPx(cv, 24 + Math.cos(r) * 15, 30 - Math.sin(r) * 15, C.greenM); setPx(cv, 24 + Math.cos(r) * 14, 30 - Math.sin(r) * 14, C.green); }
  fillRect(cv, 9, 16, 12, 40, C.greenM); fillRect(cv, 36, 16, 39, 40, C.greenM);
  disc(cv, 16, 34, 3, C.pinkL); disc(cv, 32, 34, 3, C.violetL); disc(cv, 24, 38, 3, C.goldL);
  outline(cv, P.green);
};
icons.D43 = (cv) => { // 새집 birdhouse (wood family)
  fillRect(cv, 14, 22, 34, 40, C.brownM);
  for (let x = 14; x < 34; x++) setPx(cv, x, 22, C.brownL);
  // roof
  for (let y = 12; y < 23; y++) { const hw = (y - 12); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? hexToRGB('#c47a68') : hexToRGB('#a85a4a')); }
  disc(cv, 24, 30, 4, C.brownD); // hole
  fillRect(cv, 23, 34, 25, 40, C.brown); // perch
  outline(cv, P.brownD);
};
icons.D44 = (cv) => { // 허수아비 scarecrow
  line(cv, 24, 12, 24, 42, C.brownM, 3); // post
  line(cv, 12, 20, 36, 20, C.brownM, 3); // arms
  disc(cv, 24, 14, 6, C.goldL); // straw head
  fillRect(cv, 20, 20, 28, 32, hexToRGB('#a85a4a')); // shirt
  setPx(cv, 22, 13, C.brownD); setPx(cv, 26, 13, C.brownD); // eyes
  for (let i = 0; i < 5; i++) setPx(cv, 20 + i * 2, 20, C.gold);
  outline(cv, P.brownD);
};
icons.D45 = (cv) => { // 돌탑 cairn / stone tower (stone family, stacked)
  ellipse(cv, 24, 38, 12, 5, C.grey, darker(C.grey, 20));
  ellipse(cv, 24, 30, 10, 5, C.greyL, C.grey);
  ellipse(cv, 24, 23, 8, 4, C.grey, darker(C.grey, 18));
  ellipse(cv, 24, 17, 5, 4, C.greyL, C.grey);
  outline(cv, '#3f3f48');
};
icons.D46 = (cv) => { // 벽 wall (stone family, brick courses)
  const s = hexToRGB('#7a7a86'), sd = hexToRGB('#5a5a64');
  fillRect(cv, 8, 16, 40, 40, s);
  for (let ry = 16; ry < 40; ry += 8) fillRect(cv, 8, ry, 40, ry + 1, sd);
  for (let ry = 16, row = 0; ry < 40; ry += 8, row++) for (let x = 8 + (row % 2 ? 0 : 8); x < 40; x += 16) line(cv, x, ry, x, ry + 8, sd, 1);
  outline(cv, '#3f3f48');
};
icons.D47 = (cv) => { // 축복받은 가지 blessed branch (glow family)
  glowBehind(cv, 24, 24, 16, C.violetM);
  line(cv, 12, 40, 34, 12, C.brownM, 3);
  for (const [bx, by] of [[20, 30], [26, 22], [30, 16]]) { leaf(cv, bx, by, 1, C.violetL, C.violetM); }
  sparkle(cv, 34, 12); sparkle(cv, 16, 34);
  outline(cv, P.brownD);
};
icons.D48 = (cv) => { // 등불꽃 lantern flower (glow family)
  glowBehind(cv, 24, 26, 15, C.goldL);
  // lantern bulb (violet flower shell holding warm light)
  ellipse(cv, 24, 26, 10, 12, C.violetM, C.violet);
  disc(cv, 24, 27, 5, C.goldL); disc(cv, 24, 27, 2, C.white);
  fillRect(cv, 22, 12, 26, 16, C.greenM); // stem cap
  sparkle(cv, 14, 22); sparkle(cv, 34, 30);
  outline(cv, P.violet);
};
icons.D49 = (cv) => { // 생명의 정원 garden of life (glow family, grand)
  glowBehind(cv, 24, 22, 20, C.violetM);
  // central young tree
  fillRect(cv, 22, 26, 27, 40, C.brown);
  ellipse(cv, 24, 18, 12, 11, C.greenL, C.green);
  // ring of glow flowers
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3; disc(cv, 24 + Math.cos(r) * 16, 30 + Math.sin(r) * 8, 3, a % 2 ? C.violetL : C.pinkL); }
  sparkle(cv, 24, 6); sparkle(cv, 10, 20); sparkle(cv, 38, 22); sparkle(cv, 24, 40);
  outline(cv, P.green);
};

// ---------- v0.3.1 base-recipe additions D50..D61 ----------
icons.D50 = (cv) => { // 잔디 turf sod (green-field family: flat grass strip on soil)
  fillRect(cv, 8, 30, 40, 40, C.brownM);            // soil base
  fillRect(cv, 8, 30, 40, 33, C.brown);
  for (let x = 9; x < 40; x += 2) {                 // dense short blades
    const h = 6 + ((x * 7) % 5);
    for (let y = 0; y < h; y++) setPx(cv, x, 30 - y, (x % 3) ? C.greenL : C.greenM);
  }
  outline(cv, P.green);
};
icons.D51 = (cv) => { // 화단 flower bed (flower family: soil mound + row of blooms)
  ellipse(cv, 24, 36, 17, 7, C.brownM, C.brown);    // bed of soil
  for (let x = 12; x < 38; x += 4) line(cv, x, 33, x, 39, C.brownD, 1); // furrows
  const cols = [C.pinkL, C.violetL, C.goldL, C.pinkL, C.violetL];
  for (let i = 0; i < 5; i++) {
    const bx = 13 + i * 5;
    fillRect(cv, bx, 24, bx + 1, 33, C.greenM);
    disc(cv, bx, 22, 3, cols[i]); disc(cv, bx, 22, 1, C.gold);
  }
  outline(cv, P.brownD);
};
icons.D52 = (cv) => { // 자갈 gravel (stone family: scatter of small grey chips)
  const pts = [[16,32],[24,34],[31,31],[20,38],[29,37],[24,29],[34,35],[14,37]];
  for (let i = 0; i < pts.length; i++) {
    const [px, py] = pts[i];
    ellipse(cv, px, py, 3 + (i % 2), 2 + (i % 2), i % 2 ? C.greyL : C.grey, darker(C.grey, 18));
  }
  outline(cv, '#45454e');
};
icons.D53 = (cv) => { // 암석층 rock strata (stone family: horizontal banded slab)
  const bands = [C.greyL, C.grey, darker(C.grey, 16), C.greyL, C.grey];
  for (let i = 0; i < bands.length; i++) fillRect(cv, 9, 16 + i * 5, 39, 21 + i * 5, bands[i]);
  for (let i = 1; i < bands.length; i++) fillRect(cv, 9, 16 + i * 5 - 1, 39, 16 + i * 5, C.greyD); // seams
  outline(cv, '#3f3f48');
};
icons.D54 = (cv) => { // 초원 meadow (green-field family: rolling grass + a few flowers)
  for (let x = 8; x < 40; x++) {                    // grassy hillline
    const y = 28 - Math.round(Math.sin((x - 8) / 32 * Math.PI) * 5);
    for (let yy = y; yy < 40; yy++) setPx(cv, x, yy, (yy < y + 3) ? C.greenL : ((yy % 2) ? C.greenM : C.green));
  }
  disc(cv, 16, 26, 2, C.pinkL); disc(cv, 27, 24, 2, C.goldL); disc(cv, 33, 27, 2, C.violetL); // wildflowers
  outline(cv, P.green);
};
icons.D55 = (cv) => { // 이끼돌 moss stone (stone + moss: grey pebble with green cap)
  ellipse(cv, 24, 33, 15, 11, C.grey, darker(C.grey, 22));
  for (let y = 23; y < 32; y++) for (let x = 12; x < 36; x++) {
    if (!getA(cv, x, y)) continue;
    const dx = (x - 24) / 14, dy = (y - 30) / 9;
    if (dx * dx + dy * dy <= 1 && y < 30 && ((x * 3 + y) % 4 !== 0))
      setPx(cv, x, y, (x - y) > -2 ? C.greenL : C.greenM);
  }
  outline(cv, '#3f3f48');
};
icons.D56 = (cv) => { // 화관 flower crown (flower family: ring of blooms)
  for (let a = 20; a <= 160; a += 3) {              // arc band of the circlet
    const r = a * Math.PI / 180;
    setPx(cv, 24 + Math.cos(r) * 14, 30 - Math.sin(r) * 13, C.greenM);
    setPx(cv, 24 + Math.cos(r) * 13, 30 - Math.sin(r) * 12, C.green);
  }
  const cols = [C.pinkL, C.goldL, C.violetL, C.pinkL, C.goldL];
  for (let i = 0; i < 5; i++) {
    const a = (30 + i * 30) * Math.PI / 180;
    ellipse(cv, 24 + Math.cos(a) * 14, 30 - Math.sin(a) * 13, 4, 4, cols[i], darker(cols[i], 30));
  }
  outline(cv, P.green);
};
icons.D57 = (cv) => { // 도끼 axe (tool family: wood handle + stone head)
  line(cv, 20, 42, 28, 12, C.brownM, 3);            // wooden haft
  line(cv, 20, 42, 28, 12, C.brownL, 1);
  // stone axe head (grey wedge, upper right)
  for (let y = 10; y < 24; y++) {
    const hw = 9 - Math.abs(y - 16) * 0.6;
    for (let x = 28 - hw; x <= 28 + hw; x++) setPx(cv, x, y, x - 28 > 0 ? C.greyL : C.grey);
  }
  fillRect(cv, 26, 15, 31, 17, darker(C.grey, 20));  // lashing
  outline(cv, '#3f3f48');
};
icons.D58 = (cv) => { // 수액 sap (amber drop)
  glowBehind(cv, 24, 28, 13, C.goldL);
  const cx = 24;
  for (let y = 12; y < 26; y++) {                    // teardrop top
    const hw = Math.round((y - 12) / 14 * 8);
    for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.goldL : C.gold);
  }
  ellipse(cv, cx, 30, 10, 10, C.goldL, C.gold);      // bulb
  disc(cv, cx + 3, 27, 2, C.white);                  // sheen
  outline(cv, '#a8641e');
};
icons.D59 = (cv) => { // 돌도끼 stone axe (tool family: heavier double stone head)
  line(cv, 19, 42, 27, 12, C.brown, 3);              // darker sturdier haft
  line(cv, 19, 42, 27, 12, C.brownM, 1);
  // broad double-bevel stone head
  for (let y = 9; y < 25; y++) {
    const hw = 11 - Math.abs(y - 17) * 0.55;
    for (let x = 27 - hw; x <= 27 + hw; x++)
      setPx(cv, x, y, x - 27 > 0 ? C.greyL : (x - 27 < -4 ? darker(C.grey, 16) : C.grey));
  }
  line(cv, 27, 10, 27, 24, darker(C.grey, 26), 1);   // centre ridge
  fillRect(cv, 24, 16, 31, 18, darker(C.grey, 22));  // lashing
  outline(cv, '#3f3f48');
};
icons.D60 = (cv) => { // 꽃병 flower vase (flower family: bloom in a vase)
  for (let y = 26; y < 42; y++) {                     // vase body (blue ceramic)
    const hw = 9 - Math.abs(y - 34) * 0.25;
    for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.blueM : C.blue);
  }
  fillRect(cv, 20, 24, 28, 27, C.blueM);              // rim
  fillRect(cv, 23, 18, 25, 26, C.greenM);             // stem
  for (let a = 0; a < 5; a++) {                       // bloom
    const r = a * (Math.PI * 2 / 5) - Math.PI / 2;
    ellipse(cv, 24 + Math.cos(r) * 6, 14 + Math.sin(r) * 6, 4, 4, C.pinkL, C.pink);
  }
  disc(cv, 24, 14, 2, C.goldL);
  disc(cv, 21, 32, 2, C.blueL);                       // vase sheen
  outline(cv, P.blueD);
};
icons.D61 = (cv) => { // 암석 boulder-on-stone (stone family: big rock stacked on a slab)
  fillRect(cv, 10, 34, 38, 41, C.grey);               // slab
  fillRect(cv, 10, 34, 38, 36, C.greyL);
  ellipse(cv, 24, 26, 14, 11, C.greyL, C.grey);       // boulder
  for (let y = 18; y < 26; y++) for (let x = 20; x < 34; x++) if (getA(cv, x, y)) setPx(cv, x, y, lighter(C.greyL, 8));
  line(cv, 24, 16, 20, 32, darker(C.grey, 30), 1);    // fracture
  outline(cv, '#3f3f48');
};

// ---- shared shape helpers used above ----
function leaf(cv, x, y, dir, lit, dark) {
  for (let i = 0; i < 8; i++) {
    const hw = Math.round(Math.sin((i / 8) * Math.PI) * 4);
    for (let w = -hw; w <= hw; w++) setPx(cv, x + dir * (i) + w * 0.2, y - i, (w * dir) > 0 ? lit : dark);
  }
}
function heart(cv, x, y, rot, lit, dark) {
  ellipse(cv, x - 2, y, 3, 3, lit, dark); ellipse(cv, x + 2, y, 3, 3, lit, dark);
  for (let i = 0; i < 5; i++) { const hw = 4 - i; for (let w = -hw; w <= hw; w++) setPx(cv, x + w, y + 2 + i, (w > 0) ? lit : dark); }
}
function vial(cv, lit, dark) {
  fillRect(cv, 20, 10, 28, 14, C.greyL); // stopper
  for (let y = 14; y < 40; y++) { const hw = y < 20 ? 4 : 9; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? lit : dark); }
  disc(cv, 21, 30, 2, C.white);
}
function flask(cv, lit, dark) {
  fillRect(cv, 21, 12, 27, 20, C.greyL); // neck
  for (let y = 20; y < 40; y++) { const hw = Math.round(Math.sqrt(Math.max(0, 1 - ((y - 32) / 12) ** 2)) * 12); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? lit : dark); }
  disc(cv, 20, 32, 2, C.white);
}

// ============================================================================
// LAYER-2 SCIENCE FAMILY (L2-4). J1..J7 gather + D62..D102 craft. Shared cues
// (design v1 §C-1/§C-2): metal-grey silhouettes with a darker steel selout; powered /
// glowing items get a cyan (or neon) glowBehind; inert ruins stay matte metal.
// ============================================================================

// --- helper: cyan spark dot cluster (dead-tech "still faintly alive" accent) ---
function cyanSpark(cv, x, y) {
  setPx(cv, x, y, C.cyanL); setPx(cv, x - 1, y, C.cyanM, 200); setPx(cv, x + 1, y, C.cyanM, 200);
  setPx(cv, x, y - 1, C.cyanM, 200); setPx(cv, x, y + 1, C.cyanM, 200);
}

// ---------- J1..J7 (Layer-2 gather) ----------
icons.J1 = (cv) => { // 고철 scrap-metal chunk (jagged plate + bolt)
  fillRect(cv, 12, 20, 36, 36, C.steel);
  for (let y = 20; y < 36; y++) for (let x = 12; x < 36; x++) setPx(cv, x, y, x - y > 2 ? C.steelM : C.steel);
  fillRect(cv, 12, 20, 22, 26, C.steelD); // torn corner notch
  fillRect(cv, 30, 30, 36, 36, C.steelD);
  disc(cv, 18, 30, 2, C.steelD); disc(cv, 28, 24, 2, C.rust); // rust bolt + hole
  outline(cv, P.steelD);
};
icons.J2 = (cv) => { // 전선 wire coil (copper loop)
  for (let a = 0; a < 360; a += 6) {
    const r = a * Math.PI / 180;
    disc(cv, 24 + Math.cos(r) * 12, 24 + Math.sin(r) * 10, 2, (Math.sin(r) < 0) ? C.amberL : C.amber);
  }
  // loose stripped tips
  line(cv, 24, 14, 30, 8, C.steelL, 1); line(cv, 24, 34, 18, 40, C.amberL, 1);
  outline(cv, P.rustD);
};
icons.J3 = (cv) => { // 유리 glass shard (translucent triangular sliver)
  for (let y = 10; y < 40; y++) { const hw = Math.round((40 - y) / 30 * 12); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, (x < 24) ? C.cyanL : C.steelL, 200); }
  line(cv, 24, 10, 20, 38, C.white, 1); // glint
  disc(cv, 27, 22, 1, C.white);
  outline(cv, P.steel);
};
icons.J4 = (cv) => { // 회로 circuit fragment (green board + traces)
  fillRect(cv, 12, 14, 36, 38, C.cyanD);
  for (let y = 14; y < 38; y++) for (let x = 12; x < 36; x++) setPx(cv, x, y, (x + y) % 2 ? C.cyanD : darker(C.cyanD, 8));
  line(cv, 16, 18, 32, 18, C.amber, 1); line(cv, 16, 26, 30, 26, C.amber, 1); line(cv, 20, 18, 20, 34, C.amber, 1);
  disc(cv, 32, 34, 2, C.steelL); disc(cv, 16, 34, 2, C.steelL); // solder pads
  cyanSpark(cv, 28, 30);
  outline(cv, P.steelD);
};
icons.J5 = (cv) => { // 기름 oil puddle (dark iridescent blot)
  ellipse(cv, 24, 32, 17, 9, C.navyL, C.navy);
  ellipse(cv, 20, 30, 6, 3, C.violet, C.navyL); // oily sheen
  ellipse(cv, 30, 33, 4, 2, C.cyanD, C.navy);
  disc(cv, 18, 30, 1, C.violetM);
  outline(cv, '#10161f');
};
icons.J6 = (cv) => { // 네온 결정 neon crystal (glowing cyan shard cluster)
  glowBehind(cv, 24, 26, 17, C.cyanM);
  for (const [cx, cy, h] of [[24, 12, 22], [17, 20, 14], [31, 22, 12]]) {
    for (let y = 0; y < h; y++) { const hw = Math.round((1 - y / h) * 4) + 1; for (let x = -hw; x <= hw; x++) setPx(cv, cx + x, cy + y, x > 0 ? C.cyanL : C.cyan); }
  }
  cyanSpark(cv, 24, 16);
  outline(cv, P.cyanD);
};
icons.J7 = (cv) => { // 재 ash heap (dark grey mound + drifting flecks)
  ellipse(cv, 24, 35, 16, 8, C.ash, darker(C.ash, 14));
  ellipse(cv, 24, 32, 9, 5, C.ashL, C.ash);
  for (const [x, y] of [[16, 22], [30, 20], [24, 18], [34, 26]]) disc(cv, x, y, 1, C.ashL, 180);
  outline(cv, '#2a2830');
};

// ---------- D62..D69 gate-chain crafts ----------
icons.D62 = (cv) => { // 구리 도선 copper conductor (straightened bright wire)
  for (let x = 8; x < 40; x++) { setPx(cv, x, 23, C.amber); setPx(cv, x, 24, C.amberL); setPx(cv, x, 25, C.amber); }
  disc(cv, 8, 24, 3, C.steelL); disc(cv, 40, 24, 3, C.steelL); // crimped ends
  cyanSpark(cv, 24, 24);
  outline(cv, P.rustD);
};
icons.D63 = (cv) => { // 정류 회로 rectifier circuit (chip + cyan pulse)
  glowBehind(cv, 24, 24, 13, C.cyanM);
  fillRect(cv, 14, 16, 34, 32, C.steelD);
  fillRect(cv, 17, 19, 31, 29, C.cyan);
  for (let i = 15; i <= 33; i += 4) { setPx(cv, i, 14, C.steelL); setPx(cv, i, 15, C.steelL); setPx(cv, i, 33, C.steelL); setPx(cv, i, 34, C.steelL); }
  line(cv, 20, 24, 28, 24, C.cyanL, 1); cyanSpark(cv, 24, 24);
  outline(cv, P.steelD);
};
icons.D64 = (cv) => { // 전지 battery (cell + charge bar)
  glowBehind(cv, 24, 26, 14, C.cyanM);
  fillRect(cv, 18, 12, 30, 40, C.steel);
  fillRect(cv, 21, 8, 27, 12, C.steelL); // terminal cap
  for (let y = 12; y < 40; y++) for (let x = 18; x < 30; x++) setPx(cv, x, y, x > 24 ? C.steelM : C.steel);
  fillRect(cv, 20, 22, 28, 38, C.cyan); // charge fill
  setPx(cv, 24, 28, C.cyanL); line(cv, 22, 30, 26, 30, C.cyanL, 1); line(cv, 24, 26, 24, 34, C.cyanL, 1); // + mark
  outline(cv, P.steelD);
};
icons.D65 = (cv) => { // 네온 랜턴 neon lantern (handheld glow lamp)
  glowBehind(cv, 24, 26, 18, C.cyanM);
  fillRect(cv, 20, 8, 28, 12, C.steelM); // handle ring
  disc(cv, 24, 10, 4, C.steelD); disc(cv, 24, 10, 2, C.navy);
  fillRect(cv, 16, 16, 32, 38, C.steel); // housing
  fillRect(cv, 19, 19, 29, 35, C.cyanL); // glowing glass
  ellipse(cv, 24, 27, 4, 7, C.white, C.cyanL);
  outline(cv, P.steelD);
};
icons.D66 = (cv) => { // 절연 퓨즈 fuse (glass tube + filament, metal caps)
  fillRect(cv, 10, 20, 16, 28, C.steelL); fillRect(cv, 32, 20, 38, 28, C.steelL); // caps
  for (let y = 20; y < 28; y++) for (let x = 16; x < 32; x++) setPx(cv, x, y, C.cyanL, 160); // glass
  line(cv, 16, 24, 32, 24, C.amber, 1); // filament
  outline(cv, P.steel);
};
icons.D67 = (cv) => { // 코어 骨格 core frame (cold hexagonal cage)
  const pts = [];
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; pts.push([24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14]); }
  for (let i = 0; i < 6; i++) line(cv, pts[i][0], pts[i][1], pts[(i + 1) % 6][0], pts[(i + 1) % 6][1], C.steelM, 2);
  for (let i = 0; i < 6; i++) line(cv, pts[i][0], pts[i][1], 24, 24, C.steel, 1);
  disc(cv, 24, 24, 3, C.steelD);
  outline(cv, P.steelD);
};
icons.D68 = (cv) => { // 코어 조각 core shard (frame + one neon node lit)
  const pts = [];
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; pts.push([24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14]); }
  for (let i = 0; i < 6; i++) line(cv, pts[i][0], pts[i][1], pts[(i + 1) % 6][0], pts[(i + 1) % 6][1], C.steelM, 2);
  glowBehind(cv, 24, 24, 9, C.cyanM);
  disc(cv, 24, 24, 5, C.cyan); disc(cv, 24, 24, 2, C.cyanL); cyanSpark(cv, 24, 24);
  outline(cv, P.steelD);
};
icons.D69 = (cv) => { // 파워 코어 power core (bright orb in a two-shard cage)
  glowBehind(cv, 24, 24, 20, C.cyanM);
  const pts = [];
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; pts.push([24 + Math.cos(r) * 15, 24 + Math.sin(r) * 15]); }
  for (let i = 0; i < 6; i++) line(cv, pts[i][0], pts[i][1], pts[(i + 1) % 6][0], pts[(i + 1) % 6][1], C.steelL, 2);
  circle(cv, 24, 24, 9, C.cyanL, C.cyan); disc(cv, 21, 21, 3, C.white);
  cyanSpark(cv, 30, 18); cyanSpark(cv, 17, 30);
  outline(cv, P.cyanD);
};

// ---------- D70..D82 basic-inter crafts ----------
icons.D70 = (cv) => { // 강철판 steel plate (flat sheet, rivets)
  fillRect(cv, 10, 16, 38, 34, C.steelM);
  for (let y = 16; y < 34; y++) for (let x = 10; x < 38; x++) setPx(cv, x, y, y < 24 ? C.steelL : C.steel);
  for (const [x, y] of [[14, 20], [34, 20], [14, 30], [34, 30]]) disc(cv, x, y, 1, C.steelD);
  outline(cv, P.steelD);
};
icons.D71 = (cv) => { // 유리 렌즈 glass lens (convex disc + glint)
  ellipse(cv, 24, 24, 15, 15, C.cyanL, C.cyan);
  ellipse(cv, 24, 24, 11, 11, C.steelL, C.cyanL);
  disc(cv, 19, 19, 3, C.white); line(cv, 30, 28, 34, 32, C.white, 1);
  outline(cv, P.cyanD);
};
icons.D72 = (cv) => { // 회로 기판 PCB board (green board + chip + traces)
  fillRect(cv, 10, 14, 38, 38, C.cyanD);
  line(cv, 14, 20, 34, 20, C.amber, 1); line(cv, 14, 30, 34, 30, C.amber, 1); line(cv, 24, 14, 24, 38, C.amber, 1);
  fillRect(cv, 26, 22, 34, 30, C.steelD); // chip
  disc(cv, 15, 34, 1, C.steelL); disc(cv, 33, 16, 1, C.steelL);
  outline(cv, P.steelD);
};
icons.D73 = (cv) => { // 네온관 neon tube (bent glowing cyan tube)
  glowBehind(cv, 24, 24, 16, C.cyanM);
  for (let y = 10; y < 38; y++) { setPx(cv, 16, y, C.cyanL); setPx(cv, 17, y, C.cyan); }
  for (let x = 16; x < 32; x++) { setPx(cv, x, 10, C.cyanL); setPx(cv, x, 11, C.cyan); setPx(cv, x, 37, C.cyanL); setPx(cv, x, 38, C.cyan); }
  for (let y = 10; y < 38; y++) { setPx(cv, 31, y, C.cyanL); setPx(cv, 32, y, C.cyan); }
  disc(cv, 16, 10, 2, C.steelL); disc(cv, 32, 38, 2, C.steelL);
  outline(cv, P.cyanD);
};
icons.D74 = (cv) => { // 기름 헝겊 oily rag (crumpled cloth, dark stain)
  ellipse(cv, 24, 28, 16, 12, C.ashL, C.ash);
  ellipse(cv, 22, 26, 8, 6, C.navyL, C.navy); // oil stain
  line(cv, 12, 24, 36, 30, darker(C.ash, 12), 1); line(cv, 14, 32, 34, 24, darker(C.ash, 12), 1); // folds
  disc(cv, 20, 26, 1, C.violetM);
  outline(cv, '#2a2830');
};
icons.D75 = (cv) => { // 축전 셀 capacitor cell (cylinder + stripe)
  glowBehind(cv, 24, 26, 12, C.cyanM);
  ellipse(cv, 24, 14, 9, 3, C.steelL, C.steel);
  fillRect(cv, 15, 14, 33, 38, C.steel);
  for (let y = 14; y < 38; y++) for (let x = 15; x < 33; x++) setPx(cv, x, y, x > 25 ? C.steelM : C.steel);
  fillRect(cv, 22, 14, 26, 38, C.cyan); // charge stripe
  ellipse(cv, 24, 38, 9, 3, C.steelD, C.steelD);
  outline(cv, P.steelD);
};
icons.D76 = (cv) => { // 절연 피복선 insulated cable (thick sheathed wire, cutaway)
  for (let x = 8; x < 40; x++) { for (let dy = -5; dy <= 5; dy++) setPx(cv, x, 24 + dy, Math.abs(dy) > 3 ? C.navy : C.steelM); }
  disc(cv, 40, 24, 6, C.amber); disc(cv, 40, 24, 3, C.amberL); // exposed core tip
  outline(cv, '#10161f');
};
icons.D77 = (cv) => { // 콘크리트 반죽 concrete mortar (grey mound + trowel ridge)
  ellipse(cv, 24, 32, 17, 10, C.steelL, C.steel);
  for (const [x, y] of [[16, 28], [24, 26], [32, 30], [20, 34]]) disc(cv, x, y, 2, darker(C.steel, 10));
  line(cv, 14, 26, 34, 24, C.steelH, 1); // trowel sheen
  outline(cv, P.steelD);
};
icons.D78 = (cv) => { // 방열판 heatsink (finned block)
  fillRect(cv, 12, 30, 36, 38, C.steel); // base
  for (let x = 13; x < 36; x += 4) { fillRect(cv, x, 12, x + 2, 30, C.steelM); fillRect(cv, x, 12, x + 1, 30, C.steelL); }
  outline(cv, P.steelD);
};
icons.D79 = (cv) => { // 신호기 signal beacon (post + blinking cyan lamp)
  glowBehind(cv, 24, 16, 12, C.cyanM);
  fillRect(cv, 22, 20, 26, 40, C.steel); // post
  disc(cv, 24, 16, 7, C.steelD); disc(cv, 24, 16, 5, C.cyanL); disc(cv, 22, 14, 2, C.white);
  outline(cv, P.steelD);
};
icons.D80 = (cv) => { // 방탄 유리 armored glass (thick pane in steel frame)
  fillRect(cv, 10, 10, 38, 38, C.steel); // frame
  for (let y = 14; y < 34; y++) for (let x = 14; x < 34; x++) setPx(cv, x, y, C.cyanL, 150);
  line(cv, 14, 14, 33, 33, C.white, 1); line(cv, 20, 14, 33, 27, C.cyanL, 1); // layered glints
  outline(cv, P.steelD);
};
icons.D81 = (cv) => { // 콘크리트 블록 concrete block (cinder block, two holes)
  fillRect(cv, 10, 16, 38, 36, C.steelL);
  for (let y = 16; y < 36; y++) for (let x = 10; x < 38; x++) setPx(cv, x, y, y < 24 ? lighter(C.steelL, 8) : C.steelL);
  fillRect(cv, 15, 21, 22, 31, C.steelD); fillRect(cv, 26, 21, 33, 31, C.steelD);
  outline(cv, P.steel);
};
icons.D82 = (cv) => { // 기폭 심지 blasting fuse (rag-wrapped bundle + lit cord)
  fillRect(cv, 16, 20, 32, 38, C.ash); // bundle
  ellipse(cv, 24, 20, 8, 3, C.ashL, C.ash);
  for (let i = 0; i < 12; i++) setPx(cv, 24 + Math.round(Math.sin(i) * 3), 18 - i, C.amber); // cord up
  disc(cv, 24 + Math.round(Math.sin(12) * 3), 6, 2, C.amberL); cyanSpark(cv, 27, 6);
  outline(cv, '#2a2830');
};

// ---------- D83..D88 Layer-1 cross crafts ----------
icons.D83 = (cv) => { // 전선 횃대 wire perch (branch wrapped in wire)
  line(cv, 12, 38, 34, 14, C.brown, 3); // dead branch
  for (let t = 0; t < 10; t++) { const x = 14 + t * 2, y = 36 - t * 2.2; disc(cv, x, y, 1, (t % 2) ? C.amberL : C.amber); }
  disc(cv, 34, 14, 2, C.steelL);
  outline(cv, P.brownD);
};
icons.D84 = (cv) => { // 유리 모래 glass sand (glittering pale dune)
  ellipse(cv, 24, 34, 17, 9, C.steelL, C.steel);
  for (const [x, y] of [[16, 30], [22, 28], [30, 31], [26, 33], [19, 34], [33, 29]]) disc(cv, x, y, 1, C.cyanL);
  outline(cv, P.steel);
};
icons.D85 = (cv) => { // 이끼 낀 잔해 mossy wreck (scrap + green moss + faint glow)
  glowBehind(cv, 24, 30, 12, C.greenM);
  fillRect(cv, 12, 22, 34, 36, C.steel);
  fillRect(cv, 12, 22, 24, 30, C.steelM);
  for (const [x, y] of [[16, 22], [24, 20], [30, 24], [20, 26]]) disc(cv, x, y, 3, C.greenM);
  disc(cv, 18, 20, 2, C.greenL); disc(cv, 28, 22, 2, C.greenL);
  outline(cv, P.steelD);
};
icons.D86 = (cv) => { // 화분 안테나 pot antenna (flower pot + broken dish sprig)
  for (let y = 28; y < 40; y++) { const hw = 10 - Math.round((y - 28) / 2); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x > 24 ? C.rust : darker(C.rust, 10)); }
  fillRect(cv, 14, 26, 34, 30, C.rustD); // rim
  line(cv, 24, 26, 24, 10, C.steelM, 2); // mast
  ellipse(cv, 24, 10, 7, 3, C.steelL, C.steel); // dish
  outline(cv, P.rustD);
};
icons.D87 = (cv) => { // 기름 등불 oil lamp (lantern with amber flame glow)
  glowBehind(cv, 24, 24, 15, C.amber);
  fillRect(cv, 18, 16, 30, 38, C.steelD);
  fillRect(cv, 20, 20, 28, 34, C.amberL);
  ellipse(cv, 24, 27, 3, 6, C.white, C.amber); // flame
  fillRect(cv, 20, 8, 28, 12, C.steelM); disc(cv, 24, 10, 2, C.steelD);
  outline(cv, P.steelD);
};
icons.D88 = (cv) => { // 강철 도끼 steel axe (wood haft + bright steel head)
  for (let y = 8; y < 42; y++) { setPx(cv, 26, y, C.brown); setPx(cv, 27, y, C.brownM); setPx(cv, 25, y, C.brownD); }
  for (let y = 10; y < 26; y++) { const w = Math.round(Math.sin((y - 10) / 16 * Math.PI) * 8) + 2; for (let x = 26 - w; x < 26; x++) setPx(cv, x, y, x < 20 ? C.steelL : C.steelM); }
  line(cv, 18, 12, 18, 24, C.steelH, 1); // edge glint
  outline(cv, P.steelD);
};

// ---------- D89..D95 dead-end ruins ----------
icons.D89 = (cv) => { // 꺼진 로봇 dead robot (blocky body + dark eyes)
  fillRect(cv, 14, 20, 34, 40, C.steel); // torso
  fillRect(cv, 17, 8, 31, 20, C.steelM); // head
  disc(cv, 21, 14, 2, C.navy); disc(cv, 27, 14, 2, C.navy); // dead eyes
  fillRect(cv, 10, 24, 14, 36, C.steelD); fillRect(cv, 34, 24, 38, 36, C.steelD); // arms
  line(cv, 24, 4, 24, 8, C.steelM, 1); disc(cv, 24, 4, 1, C.rust); // antenna
  outline(cv, P.steelD);
};
icons.D90 = (cv) => { // 고장 난 라디오 broken radio (box + dial + bent aerial)
  fillRect(cv, 12, 18, 36, 38, C.steel);
  fillRect(cv, 15, 22, 27, 34, C.steelD); // speaker grille
  for (let y = 23; y < 34; y += 2) line(cv, 16, y, 26, y, C.steelM, 1);
  disc(cv, 31, 26, 3, C.steelL); disc(cv, 31, 33, 2, C.steelM); // dials
  line(cv, 34, 18, 40, 8, C.steelM, 1); // bent aerial
  outline(cv, P.steelD);
};
icons.D91 = (cv) => { // 멈춘 시계 stopped clock (round face, frozen hands)
  circle(cv, 24, 24, 15, C.steelL, C.steel);
  circle(cv, 24, 24, 12, C.cream, C.steelL);
  for (let a = 0; a < 12; a++) { const r = a * Math.PI / 6; disc(cv, 24 + Math.cos(r) * 10, 24 + Math.sin(r) * 10, 1, C.steelD); }
  line(cv, 24, 24, 24, 16, C.navy, 1); line(cv, 24, 24, 31, 27, C.navy, 1); // hands frozen
  disc(cv, 24, 24, 2, C.rust);
  outline(cv, P.steelD);
};
icons.D92 = (cv) => { // 빈 액자 empty frame (steel frame, hollow centre)
  fillRect(cv, 10, 8, 38, 40, C.steelM);
  fillRect(cv, 15, 13, 33, 35, C.navy); // empty
  for (let y = 13; y < 35; y++) for (let x = 15; x < 33; x++) if ((x + y) % 6 === 0) setPx(cv, x, y, C.navyL);
  line(cv, 10, 8, 15, 13, C.steelL, 1); line(cv, 38, 8, 33, 13, C.steelD, 1);
  outline(cv, P.steelD);
};
icons.D93 = (cv) => { // 녹슨 훈장 rusted medal (round disc + ribbon)
  fillRect(cv, 19, 8, 23, 20, C.rust); fillRect(cv, 25, 8, 29, 20, C.rustD); // ribbon
  circle(cv, 24, 30, 10, C.amber, C.rust); circle(cv, 24, 30, 6, C.amberL, C.amber);
  for (let a = 0; a < 5; a++) { const r = a * Math.PI * 2 / 5 - Math.PI / 2; disc(cv, 24 + Math.cos(r) * 4, 30 + Math.sin(r) * 4, 1, C.rustD); }
  outline(cv, P.rustD);
};
icons.D94 = (cv) => { // 말라붙은 잉크병 dried inkwell (glass jar, black crust)
  for (let y = 18; y < 40; y++) { const hw = (y < 22) ? 5 : 10; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, C.cyanL, 130); }
  fillRect(cv, 16, 30, 32, 40, C.navy); // dried ink at bottom
  ellipse(cv, 24, 30, 9, 2, darker(C.navy, 6), C.navy);
  fillRect(cv, 20, 14, 28, 18, C.steelD); // neck
  outline(cv, P.steel);
};
icons.D95 = (cv) => { // 부서진 헬멧 broken helmet (dented dome + crack)
  for (let y = 14; y < 30; y++) { const hw = Math.round(Math.sqrt(Math.max(0, 1 - ((y - 30) / 16) ** 2)) * 15); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x > 24 ? C.steelM : C.steel); }
  fillRect(cv, 9, 28, 39, 34, C.steelD); // brim
  line(cv, 20, 15, 26, 30, C.navy, 1); line(cv, 26, 30, 22, 34, C.navy, 1); // crack
  for (const [x, y] of [[16, 22], [32, 20]]) disc(cv, x, y, 1, C.ashL); // ash smudge
  outline(cv, P.steelD);
};

// ---------- D96..D102 placement decor/structures ----------
icons.D96 = (cv) => { // 가로등 street lamp (LIT — post + glowing cyan head + pool)
  glowBehind(cv, 26, 12, 12, C.cyanM);
  fillRect(cv, 22, 12, 25, 42, C.steel); // post
  for (let x = 22; x < 34; x++) setPx(cv, x, 11, C.steelM); // arm
  disc(cv, 32, 13, 5, C.cyanL); disc(cv, 32, 13, 3, C.white); // lamp head
  ellipse(cv, 24, 42, 12, 3, C.cyanD, C.navy); // light pool on ground
  outline(cv, P.steelD);
};
icons.D97 = (cv) => { // 위성 안테나(모형) satellite dish model (dish + tripod)
  ellipse(cv, 22, 20, 14, 11, C.steelL, C.steel); // dish
  ellipse(cv, 22, 20, 9, 7, C.steelM, C.steel);
  line(cv, 22, 20, 30, 12, C.steelD, 1); disc(cv, 30, 12, 2, C.amber); // feed horn
  line(cv, 22, 28, 16, 42, C.steelM, 2); line(cv, 22, 28, 30, 42, C.steelM, 2); line(cv, 22, 28, 22, 42, C.steelD, 1); // tripod
  outline(cv, P.steelD);
};
icons.D98 = (cv) => { // 모니터 monitor (screen with cyan blink + stand)
  glowBehind(cv, 24, 22, 14, C.cyanM);
  fillRect(cv, 10, 10, 38, 34, C.steelD); // bezel
  fillRect(cv, 13, 13, 35, 31, C.cyan);
  line(cv, 16, 18, 32, 18, C.cyanL, 1); line(cv, 16, 24, 28, 24, C.cyanL, 1); cyanSpark(cv, 30, 28);
  fillRect(cv, 21, 34, 27, 40, C.steel); fillRect(cv, 16, 40, 32, 43, C.steelM); // stand
  outline(cv, P.steelD);
};
icons.D99 = (cv) => { // 로봇 동상 robot statue (dead robot on concrete plinth)
  fillRect(cv, 12, 36, 36, 44, C.steelL); // plinth
  fillRect(cv, 18, 18, 30, 36, C.steel); // body
  fillRect(cv, 20, 8, 28, 18, C.steelM); // head
  disc(cv, 22, 13, 1, C.navy); disc(cv, 26, 13, 1, C.navy);
  fillRect(cv, 14, 22, 18, 34, C.steelD); fillRect(cv, 30, 22, 34, 34, C.steelD);
  outline(cv, P.steelD);
};
icons.D100 = (cv) => { // 발전기 모형 generator model (housing + spinning glow)
  glowBehind(cv, 24, 26, 15, C.cyanM);
  fillRect(cv, 12, 18, 36, 40, C.steel);
  for (let y = 18; y < 40; y++) for (let x = 12; x < 36; x++) setPx(cv, x, y, y < 28 ? C.steelM : C.steel);
  circle(cv, 24, 28, 7, C.cyanL, C.cyan); disc(cv, 24, 28, 2, C.white); // turbine
  line(cv, 24, 21, 24, 35, C.cyanD, 1); line(cv, 17, 28, 31, 28, C.cyanD, 1);
  fillRect(cv, 30, 12, 34, 18, C.steelD); // exhaust
  outline(cv, P.steelD);
};
icons.D101 = (cv) => { // 철조망 barbed wire (X posts + coiled barbs)
  line(cv, 12, 40, 16, 10, C.steel, 2); line(cv, 36, 40, 32, 10, C.steel, 2); // posts
  for (let x = 14; x < 34; x++) { const y = 22 + Math.round(Math.sin(x / 2) * 3); setPx(cv, x, y, C.steelL); }
  for (const bx of [18, 24, 30]) { const by = 22 + Math.round(Math.sin(bx / 2) * 3); line(cv, bx - 2, by - 2, bx + 2, by + 2, C.steelH, 1); line(cv, bx - 2, by + 2, bx + 2, by - 2, C.steelH, 1); }
  outline(cv, P.steelD);
};
icons.D102 = (cv) => { // 네온 간판 neon sign (framed board + glowing letters)
  glowBehind(cv, 24, 24, 17, C.neon);
  fillRect(cv, 8, 14, 40, 34, C.steelD);
  // abstract neon "letters"
  line(cv, 13, 20, 13, 28, C.neonL, 2); line(cv, 13, 20, 18, 20, C.neonL, 2); line(cv, 13, 24, 17, 24, C.neonL, 2);
  circle(cv, 24, 24, 4, C.cyanL, C.cyan);
  line(cv, 32, 20, 32, 28, C.neonL, 2); line(cv, 32, 20, 36, 24, C.neonL, 2); line(cv, 32, 24, 36, 28, C.neonL, 2);
  outline(cv, P.steelD);
};

// ============================================================================
// Emit all icon files. Item catalog = 9 gatherables (I1..I9) + crafts D01..D61
// minus the retired 석기 D11 (removed v0.3.1) + Layer-2 J1..J7 + D62..D102 (L2-4).
// D06 is an alias of I4 → identical bytes to I4 (spec: "D06 alias resolves to I4's
// icon"). => 68 Layer-1 unique-id files + 48 Layer-2 files.
// ============================================================================
const RETIRED = new Set(['D11']); // 석기 — replaced by 도끼(D57)/돌도끼(D59)
const ALL_IDS = [];
for (let i = 1; i <= 9; i++) ALL_IDS.push('I' + i);
for (let i = 1; i <= 61; i++) {
  const id = 'D' + String(i).padStart(2, '0');
  if (!RETIRED.has(id)) ALL_IDS.push(id);
}
// Layer-2 (L2-4): J1..J7 gather + D62..D102 craft.
for (let i = 1; i <= 7; i++) ALL_IDS.push('J' + i);
for (let i = 62; i <= 102; i++) ALL_IDS.push('D' + i);

let count = 0, total = 0;
for (const id of ALL_IDS) {
  const cv = makeCanvas();
  if (id === 'D06') {
    icons.I4(cv); // alias → same art as I4
  } else if (icons[id]) {
    icons[id](cv);
  } else {
    throw new Error('no painter for ' + id);
  }
  const bytes = save(cv, id);
  total += bytes; count++;
}
console.log('wrote', count, 'icons,', total, 'bytes total, ->', OUT);
