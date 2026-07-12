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
  // ---- Layer-3 machine family (L3) — design Part C: copper/brass + orange steam glow.
  copper: '#3a2c1e', brass: '#8a6a34', brassHi: '#c8a24a', brassSh: '#4a3820',
  orange: '#ff9a3c', ember: '#e8842c',
  // ---- Layer-4 magic family (L4) — design v1 Part C: amethyst violet + gold rune glow.
  amyD: '#241834', amy: '#4a3670', amyM: '#7a5aae', amyL: '#b593e0', amyH: '#dcc4ff',
  runeGold: '#f2c14e', runeGoldD: '#b8862c', runeGoldL: '#ffe3a0',
  voidBlue: '#0e0a18', silverL: '#e0dcd0', silver: '#a8a49a', vellum: '#e8dcae', vellumD: '#b8a870',
  // ---- Layer-5 divinity family (L5) — design v1 Part A/C: pale ivory/silver, desaturated,
  // with a faint warm amber glow (꺼져가는 잔불). Low saturation throughout — 채도를 뺀 세계.
  ivoryD: '#6b6459', ivory: '#9a9385', ivoryM: '#c4bdaf', ivoryL: '#e6e0d4', ivoryH: '#f4efe4',
  ashGrey: '#4a463f', ashGreyL: '#726c62',
  ambient: '#e0a94a', ambientD: '#a87c2e', ambientL: '#f2ce8c',
  // ---- EX-L1 (v1.2.0 색/생명 확장): warm teacup ceramic for the tea crafts.
  creamCup: '#c9b48a', creamCupL: '#e6d7b0',
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
// LAYER-3 MACHINE FAMILY (L3). K1..K7 gather + D103..D139 craft. Shared cues
// (design Part C): copper/brass silhouettes with a darker brass selout; powered /
// glowing steam-tech items get an orange glowBehind; inert ruins stay matte metal.
// ============================================================================

// --- helper: orange ember dot cluster (steam-tech "still warm" accent) ---
function emberSpark(cv, x, y) {
  setPx(cv, x, y, C.orange); setPx(cv, x - 1, y, C.ember, 200); setPx(cv, x + 1, y, C.ember, 200);
  setPx(cv, x, y - 1, C.ember, 200); setPx(cv, x, y + 1, C.ember, 200);
}
// --- helper: a single brass gear (teeth + hub) centred at cx,cy with radius r ---
function gear(cv, cx, cy, r, lit, dark, teeth) {
  teeth = teeth || 8;
  for (let t = 0; t < teeth; t++) {
    const a = t * Math.PI * 2 / teeth;
    fillGearTooth(cv, cx, cy, r, a, lit, dark);
  }
  circle(cv, cx, cy, r, lit, dark);
  disc(cv, cx, cy, Math.max(1, Math.round(r * 0.28)), C.copper); // hub hole
}
function fillGearTooth(cv, cx, cy, r, a, lit, dark) {
  const ux = Math.cos(a), uy = Math.sin(a);
  for (let d = r - 1; d <= r + 2; d++)
    for (let w = -1.4; w <= 1.4; w += 0.5) {
      const px = cx + ux * d - uy * w, py = cy + uy * d + ux * w;
      setPx(cv, px, py, (ux - uy) > 0 ? lit : dark);
    }
}
// --- helper: a coiled spring (concentric arcs) centred at cx,cy ---
function coil(cv, cx, cy, rMax, lit, dark) {
  for (let a = 0; a < Math.PI * 6; a += 0.12) {
    const rr = rMax * (1 - a / (Math.PI * 6.5));
    setPx(cv, cx + Math.cos(a) * rr, cy + Math.sin(a) * rr, ((a % (Math.PI)) < Math.PI / 2) ? lit : dark);
  }
}

// ---------- K1..K7 (Layer-3 gather) ----------
icons.K1 = (cv) => { // 태엽 coiled mainspring
  coil(cv, 24, 24, 15, C.brassHi, C.brass);
  disc(cv, 24, 24, 2, C.brassSh);
  outline(cv, P.brassSh);
};
icons.K2 = (cv) => { // 톱니 single gear
  gear(cv, 24, 24, 13, C.brassHi, C.brass, 8);
  outline(cv, P.brassSh);
};
icons.K3 = (cv) => { // 황동 bright brass ingot/offcut
  for (let y = 22; y < 34; y++) for (let x = 12; x < 36; x++) setPx(cv, x, y, x - y > 0 ? C.brassHi : C.brass);
  // trapezoid ingot top bevel
  for (let x = 14; x < 34; x++) { setPx(cv, x, 21, C.brassHi); }
  fillRect(cv, 12, 22, 36, 24, C.brassHi); // lit top
  fillRect(cv, 12, 32, 36, 34, C.brassSh); // shadow base
  outline(cv, P.brassSh);
};
icons.K4 = (cv) => { // 증기응축수 water droplet + steam wisp
  const cx = 24;
  for (let y = 20; y < 30; y++) { const hw = Math.round((y - 20) / 10 * 7); for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.brassHi : C.copper); }
  ellipse(cv, cx, 34, 9, 8, C.orange, C.ember); // warm droplet body
  disc(cv, cx + 3, 31, 2, C.brassHi); // sheen
  // steam wisp rising
  for (let i = 0; i < 8; i++) setPx(cv, cx + Math.round(Math.sin(i / 1.5) * 3), 18 - i, C.brassHi, 150);
  outline(cv, P.brassSh);
};
icons.K5 = (cv) => { // 가죽 벨트 leather drive-belt loop
  const lC = hexToRGB('#6a4326'), lD = hexToRGB('#3a2416');
  for (let a = 0; a < 360; a += 4) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 13, 26 + Math.sin(r) * 11, 3, (Math.sin(r) < 0) ? lC : lD); }
  for (let a = 0; a < 360; a += 4) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 13, 26 + Math.sin(r) * 11, 1, C.copper); }
  // stitch dots
  for (let a = 0; a < 360; a += 30) { const r = a * Math.PI / 180; setPx(cv, 24 + Math.cos(r) * 13, 26 + Math.sin(r) * 11, C.brassHi); }
  outline(cv, '#2a190e');
};
icons.K6 = (cv) => { // 석탄 coal lump cluster
  const cD = hexToRGB('#26232a'), cL = hexToRGB('#4a464f');
  ellipse(cv, 20, 32, 9, 7, cL, cD);
  ellipse(cv, 31, 30, 7, 6, cL, cD);
  ellipse(cv, 26, 36, 6, 4, cL, cD);
  disc(cv, 17, 29, 1, C.ashL); disc(cv, 29, 27, 1, C.ashL); // facet glints
  outline(cv, '#16141a');
};
icons.K7 = (cv) => { // 기름때 유리 oily glass shard
  for (let y = 10; y < 40; y++) { const hw = Math.round((40 - y) / 30 * 11); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, (x < 24) ? C.brassHi : C.brass, 200); }
  ellipse(cv, 22, 26, 6, 5, hexToRGB('#3a2c4a'), C.copper); // oily film
  line(cv, 24, 10, 20, 38, C.brassHi, 1); // glint
  outline(cv, P.brassSh);
};

// ---------- D103..D139 (Layer-3 craft) ----------
icons.D103 = (cv) => { // 황동 톱니 원판 brass gear disc
  gear(cv, 24, 24, 14, C.brassHi, C.brass, 10);
  circle(cv, 24, 24, 7, C.brass, C.brassSh); // inner disc rim
  outline(cv, P.brassSh);
};
icons.D104 = (cv) => { // 맞물림 톱니 two meshing gears (orange spark)
  gear(cv, 17, 20, 9, C.brassHi, C.brass, 8);
  gear(cv, 31, 30, 9, C.brassHi, C.brass, 8);
  emberSpark(cv, 24, 25); // spark at mesh point
  outline(cv, P.brassSh);
};
icons.D105 = (cv) => { // 압력 밸브 valve wheel
  circle(cv, 24, 24, 14, C.brassHi, C.brass);
  disc(cv, 24, 24, 9, C.copper);
  for (let a = 0; a < 4; a++) { const r = a * Math.PI / 2 + Math.PI / 4; line(cv, 24, 24, 24 + Math.cos(r) * 13, 24 + Math.sin(r) * 13, C.brass, 2); }
  circle(cv, 24, 24, 4, C.brassHi, C.brass); disc(cv, 24, 24, 2, C.brassSh); // hub
  fillRect(cv, 22, 36, 26, 44, C.brass); // stem
  outline(cv, P.brassSh);
};
icons.D106 = (cv) => { // 젖은 석탄 wet coal (droplet on coal)
  const cD = hexToRGB('#26232a'), cL = hexToRGB('#4a464f');
  ellipse(cv, 22, 32, 10, 8, cL, cD);
  ellipse(cv, 32, 31, 7, 6, cL, cD);
  ellipse(cv, 22, 28, 5, 3, hexToRGB('#5a5660'), cL); // wet sheen
  for (let y = 12; y < 20; y++) { const hw = Math.round((y - 12) / 8 * 4); for (let x = 22 - hw; x <= 22 + hw; x++) setPx(cv, x, y, x - 22 > 0 ? C.blueL : C.blueM); }
  ellipse(cv, 22, 22, 5, 5, C.blueM, C.blue); disc(cv, 24, 20, 1, C.white); // droplet
  outline(cv, '#16141a');
};
icons.D107 = (cv) => { // 강철 케이블 twisted steel cable
  for (let x = 8; x < 40; x++) {
    const ph = x * 0.6;
    setPx(cv, x, 24 + Math.round(Math.sin(ph) * 4), C.steelL);
    setPx(cv, x, 24 + Math.round(Math.sin(ph + 2) * 4), C.steelM);
    setPx(cv, x, 24 + Math.round(Math.sin(ph + 4) * 4), C.steel);
  }
  disc(cv, 8, 24, 3, C.steelD); disc(cv, 40, 24, 3, C.steelD); // clamped ends
  outline(cv, P.steelD);
};
icons.D108 = (cv) => { // 평형추 counterweight on a cable
  line(cv, 24, 4, 24, 22, C.steelM, 1); // cable
  disc(cv, 24, 6, 3, C.steelD); // pulley eye
  for (let y = 22; y < 40; y++) { const hw = 9 - Math.abs(y - 31) * 0.15; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.steelM : C.steel); }
  fillRect(cv, 20, 20, 28, 24, C.steelL); // top cap
  line(cv, 20, 30, 28, 30, C.steelD, 1); // cast seam
  outline(cv, P.steelD);
};
icons.D109 = (cv) => { // 심장 뼈대 heart-shaped brass frame with spring
  // brass heart outline frame
  const HC = C.brassHi, HD = C.brass;
  ellipse(cv, 18, 20, 7, 7, HC, HD); ellipse(cv, 30, 20, 7, 7, HC, HD);
  for (let i = 0; i < 14; i++) { const hw = 12 - i; for (let w = -hw; w <= hw; w++) setPx(cv, 24 + w, 22 + i, (w > 0) ? HC : HD); }
  disc(cv, 24, 24, 9, C.copper); // hollow interior
  coil(cv, 24, 23, 6, C.brassHi, C.brass); // spring inside
  outline(cv, P.brassSh);
};
icons.D110 = (cv) => { // 태엽 문자판 clock dial behind glass
  circle(cv, 24, 24, 15, C.brassHi, C.brass);
  circle(cv, 24, 24, 12, C.cream, C.brassSh);
  for (let a = 0; a < 12; a++) { const r = a * Math.PI / 6; disc(cv, 24 + Math.cos(r) * 10, 24 + Math.sin(r) * 10, 1, C.copper); }
  line(cv, 24, 24, 24, 15, C.copper, 1); line(cv, 24, 24, 30, 26, C.copper, 1); // hands
  disc(cv, 24, 24, 2, C.brass);
  disc(cv, 19, 19, 3, C.white, 120); // glass glint
  outline(cv, P.brassSh);
};
icons.D111 = (cv) => { // 태엽심장 glowing orange clockwork heart (glow!)
  glowBehind(cv, 24, 24, 18, C.orange);
  ellipse(cv, 18, 20, 7, 7, C.ember, C.copper); ellipse(cv, 30, 20, 7, 7, C.ember, C.copper);
  for (let i = 0; i < 14; i++) { const hw = 12 - i; for (let w = -hw; w <= hw; w++) setPx(cv, 24 + w, 22 + i, (w > 0) ? C.orange : C.ember); }
  coil(cv, 24, 23, 7, C.brassHi, C.brass); // glowing clockwork spring
  disc(cv, 24, 23, 2, C.white);
  emberSpark(cv, 14, 14); emberSpark(cv, 34, 30);
  outline(cv, P.ember);
};
icons.D112 = (cv) => { // 강철 톱니바퀴 two stacked gears
  gear(cv, 22, 26, 11, C.steelL, C.steel, 9);
  gear(cv, 30, 18, 8, C.steelH, C.steelM, 8);
  outline(cv, P.steelD);
};
icons.D113 = (cv) => { // 연마 유리알 polished glass bead
  circle(cv, 24, 24, 13, C.cyanL, C.steelL);
  disc(cv, 24, 24, 9, C.brassHi, 90); // brassy inner refraction
  disc(cv, 19, 19, 4, C.white); disc(cv, 29, 29, 2, C.white, 160); // polished glints
  outline(cv, P.steel);
};
icons.D114 = (cv) => { // 황동관 brass tube
  fillRect(cv, 10, 20, 38, 30, C.brass);
  fillRect(cv, 10, 20, 38, 23, C.brassHi); // top-lit
  fillRect(cv, 10, 28, 38, 30, C.brassSh);
  ellipse(cv, 10, 25, 3, 5, C.copper, C.brassSh); // near-end bore
  ellipse(cv, 10, 25, 2, 3, C.brassSh, C.copper);
  outline(cv, P.brassSh);
};
icons.D115 = (cv) => { // 그을린 벨트 scorched belt
  const lC = hexToRGB('#5a3820'), lD = hexToRGB('#2e1c10');
  for (let a = 0; a < 360; a += 4) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 13, 26 + Math.sin(r) * 11, 3, (Math.sin(r) < 0) ? lC : lD); }
  for (let a = 0; a < 360; a += 4) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 13, 26 + Math.sin(r) * 11, 1, C.copper); }
  // scorch marks
  for (const [x, y] of [[18, 16], [32, 22], [24, 39]]) disc(cv, x, y, 2, C.ash);
  outline(cv, '#1e1109');
};
icons.D116 = (cv) => { // 기름 헝겊 oily rag
  ellipse(cv, 24, 28, 16, 12, hexToRGB('#8a7a5a'), hexToRGB('#5a4a34'));
  ellipse(cv, 22, 26, 8, 6, hexToRGB('#3a2c4a'), C.copper); // oil stain
  line(cv, 12, 24, 36, 30, hexToRGB('#4a3c28'), 1); line(cv, 14, 32, 34, 24, hexToRGB('#4a3c28'), 1); // folds
  disc(cv, 20, 26, 1, C.orange);
  outline(cv, '#2a2018');
};
icons.D117 = (cv) => { // 태엽 감개 spring winder (key + coil)
  fillRect(cv, 22, 20, 26, 42, C.brass); // shaft
  fillRect(cv, 22, 20, 24, 42, C.brassHi);
  // wing handle (butterfly key top)
  ellipse(cv, 17, 16, 6, 4, C.brassHi, C.brass); ellipse(cv, 31, 16, 6, 4, C.brassHi, C.brass);
  disc(cv, 24, 16, 3, C.brassSh);
  coil(cv, 24, 34, 6, C.brassHi, C.brass); // wound spring at base
  outline(cv, P.brassSh);
};
icons.D118 = (cv) => { // 황동 볼트 brass bolt
  // hex head
  const pts = [];
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; pts.push([24 + Math.cos(r) * 10, 16 + Math.sin(r) * 10]); }
  for (let y = 8; y < 24; y++) for (let x = 14; x < 34; x++) {
    // simple hex fill via bounding + skip corners
    if (Math.abs(x - 24) + Math.abs(y - 16) * 0.6 < 12) setPx(cv, x, y, x - 24 > 0 ? C.brassHi : C.brass);
  }
  disc(cv, 24, 16, 3, C.brassSh); // socket
  fillRect(cv, 21, 24, 27, 42, C.brass); // shank
  for (let y = 26; y < 42; y += 3) line(cv, 21, y, 27, y, C.brassSh, 1); // thread
  outline(cv, P.brassSh);
};
icons.D119 = (cv) => { // 연료 벽돌 fuel brick
  fillRect(cv, 10, 18, 38, 36, C.copper);
  fillRect(cv, 10, 18, 38, 22, hexToRGB('#5a4630')); // top-lit
  for (let y = 20; y < 36; y += 5) line(cv, 10, y, 38, y, C.brassSh, 1); // pressed grooves
  for (let x = 16; x < 38; x += 7) line(cv, x, 18, x, 36, C.brassSh, 1);
  disc(cv, 15, 21, 1, C.ember); disc(cv, 32, 33, 1, C.ember); // fleck
  outline(cv, '#241a10');
};
icons.D120 = (cv) => { // 응결 렌즈 condensation lens (droplet-in-lens)
  circle(cv, 24, 24, 14, C.brassHi, C.brass); // brass rim
  disc(cv, 24, 24, 11, C.cyanL);
  ellipse(cv, 24, 26, 6, 8, C.blueM, C.blue); // condensed droplet inside
  disc(cv, 20, 20, 3, C.white); // glint
  outline(cv, P.brassSh);
};
icons.D121 = (cv) => { // 벨트 도르래 belt pulley
  circle(cv, 24, 24, 13, C.brassHi, C.brass); // wheel
  circle(cv, 24, 24, 10, C.copper, C.brassSh); // groove channel
  disc(cv, 24, 24, 4, C.brass); disc(cv, 24, 24, 2, C.brassSh); // hub
  // belt over the top
  const lC = hexToRGB('#6a4326');
  for (let x = 8; x < 40; x++) { setPx(cv, x, 10, lC); setPx(cv, x, 11, C.copper); }
  outline(cv, P.brassSh);
};
icons.D122 = (cv) => { // 구동 모듈 drive module (gear + cable)
  fillRect(cv, 12, 14, 36, 38, C.copper); // housing
  fillRect(cv, 12, 14, 36, 17, hexToRGB('#5a4630'));
  gear(cv, 24, 26, 9, C.brassHi, C.brass, 8); // gear window
  // cable exiting right
  for (let x = 34; x < 44; x++) setPx(cv, x, 22 + Math.round(Math.sin(x * 0.6) * 2), C.steelL);
  emberSpark(cv, 24, 26);
  outline(cv, '#241a10');
};
icons.D123 = (cv) => { // 압력 계기 pressure gauge (needle in red)
  circle(cv, 24, 24, 14, C.brassHi, C.brass); // bezel
  circle(cv, 24, 24, 11, C.cream, C.brassSh); // face
  // red danger arc top-right
  for (let a = -Math.PI / 2; a < 0; a += 0.15) disc(cv, 24 + Math.cos(a) * 9, 24 + Math.sin(a) * 9, 1, C.red);
  line(cv, 24, 24, 30, 18, C.red, 1); // needle in red zone
  disc(cv, 24, 24, 2, C.brassSh);
  outline(cv, P.brassSh);
};
icons.D124 = (cv) => { // 증기 파이프 steam pipe with wisp
  fillRect(cv, 10, 26, 40, 34, C.brass);
  fillRect(cv, 10, 26, 40, 28, C.brassHi);
  fillRect(cv, 18, 22, 24, 38, C.brass); // vertical joint
  fillRect(cv, 18, 22, 20, 38, C.brassHi);
  fillRect(cv, 16, 20, 26, 24, C.brassSh); // flange
  // steam wisp from top
  for (let i = 0; i < 10; i++) setPx(cv, 21 + Math.round(Math.sin(i / 1.4) * 3), 18 - i, C.brassHi, 150);
  outline(cv, P.brassSh);
};
icons.D125 = (cv) => { // 태엽 인형 windup doll
  disc(cv, 24, 16, 6, C.brassHi); // head
  disc(cv, 21, 15, 1, C.copper); disc(cv, 27, 15, 1, C.copper); // eyes
  fillRect(cv, 19, 22, 29, 36, C.brass); // body
  fillRect(cv, 19, 22, 22, 36, C.brassHi);
  fillRect(cv, 15, 24, 19, 32, C.brass); fillRect(cv, 29, 24, 33, 32, C.brass); // arms
  fillRect(cv, 20, 36, 23, 44, C.brass); fillRect(cv, 25, 36, 28, 44, C.brass); // legs
  disc(cv, 33, 28, 3, C.brassSh); disc(cv, 33, 28, 1, C.copper); // windup key on back
  outline(cv, P.brassSh);
};
icons.D126 = (cv) => { // 이끼 낀 톱니 mossy gear (green tinge on brass)
  gear(cv, 24, 24, 13, C.brassHi, C.brass, 8);
  // moss patches
  for (const [x, y] of [[16, 18], [30, 20], [20, 30], [28, 30]]) disc(cv, x, y, 3, C.greenM);
  disc(cv, 15, 17, 2, C.greenL); disc(cv, 29, 31, 2, C.greenL);
  outline(cv, P.brassSh);
};
icons.D127 = (cv) => { // 네온 태엽등 neon+spring lamp (glow)
  glowBehind(cv, 24, 24, 17, C.orange);
  fillRect(cv, 20, 8, 28, 12, C.brass); // hanger
  fillRect(cv, 16, 14, 32, 38, C.brass); // housing
  fillRect(cv, 19, 17, 29, 35, C.orange); // glowing glass
  coil(cv, 24, 26, 6, C.brassHi, C.ember); // spring filament inside
  disc(cv, 24, 26, 2, C.white);
  outline(cv, P.brassSh);
};
icons.D128 = (cv) => { // 강철 태엽 도끼 axe with brass spring
  for (let y = 8; y < 42; y++) { setPx(cv, 26, y, C.brass); setPx(cv, 27, y, C.brassHi); setPx(cv, 25, y, C.brassSh); }
  for (let y = 10; y < 26; y++) { const w = Math.round(Math.sin((y - 10) / 16 * Math.PI) * 8) + 2; for (let x = 26 - w; x < 26; x++) setPx(cv, x, y, x < 20 ? C.steelL : C.steelM); }
  line(cv, 18, 12, 18, 24, C.steelH, 1); // edge glint
  coil(cv, 26, 36, 5, C.brassHi, C.brass); // spring at haft base
  outline(cv, P.steelD);
};
icons.D129 = (cv) => { // 멈춘 가로 태엽시계 street clock post
  fillRect(cv, 22, 24, 26, 44, C.brass); // post
  fillRect(cv, 22, 24, 24, 44, C.brassHi);
  fillRect(cv, 18, 42, 30, 45, C.brassSh); // base
  circle(cv, 24, 16, 11, C.brassHi, C.brass); // clock head
  circle(cv, 24, 16, 8, C.cream, C.brassSh);
  line(cv, 24, 16, 24, 10, C.copper, 1); line(cv, 24, 16, 29, 18, C.copper, 1); // frozen hands
  disc(cv, 24, 16, 1, C.brassSh);
  outline(cv, P.brassSh);
};
icons.D130 = (cv) => { // 증기 가로등 steam lamp (glow)
  glowBehind(cv, 24, 14, 12, C.orange);
  fillRect(cv, 22, 16, 26, 44, C.brass); // post
  fillRect(cv, 22, 16, 24, 44, C.brassHi);
  disc(cv, 24, 14, 6, C.ember); disc(cv, 24, 14, 4, C.orange); disc(cv, 23, 12, 1, C.white); // lamp
  fillRect(cv, 20, 6, 28, 9, C.brassSh); // cap
  // steam wisp
  for (let i = 0; i < 6; i++) setPx(cv, 30 + Math.round(Math.sin(i) * 2), 12 - i, C.brassHi, 130);
  outline(cv, P.brassSh);
};
icons.D131 = (cv) => { // 태엽 분수 clockwork fountain (glow)
  glowBehind(cv, 24, 20, 15, C.orange);
  ellipse(cv, 24, 38, 16, 6, C.brass, C.brassSh); // basin
  ellipse(cv, 24, 36, 12, 4, C.copper, C.brassSh);
  fillRect(cv, 22, 22, 26, 36, C.brass); // column
  gear(cv, 24, 20, 6, C.brassHi, C.brass, 8); // clockwork top
  // orange water arcs
  for (let i = 0; i < 8; i++) { setPx(cv, 24 - i, 20 + i * 1.6, C.orange, 200); setPx(cv, 24 + i, 20 + i * 1.6, C.orange, 200); }
  outline(cv, P.brassSh);
};
icons.D132 = (cv) => { // 황동 톱니 문 gear door
  fillRect(cv, 12, 8, 36, 42, C.copper); // door frame
  fillRect(cv, 12, 8, 36, 11, hexToRGB('#5a4630'));
  gear(cv, 24, 24, 12, C.brassHi, C.brass, 10); // big gear set in door
  disc(cv, 24, 24, 5, C.copper);
  for (const [x, y] of [[16, 12], [32, 12], [16, 38], [32, 38]]) disc(cv, x, y, 2, C.brassSh); // corner rivets
  outline(cv, '#241a10');
};
icons.D133 = (cv) => { // 멈춘 로봇 좌상 seated stopped robot
  fillRect(cv, 16, 24, 32, 38, C.brass); // torso
  fillRect(cv, 16, 24, 20, 38, C.brassHi);
  fillRect(cv, 19, 12, 29, 24, C.brass); // head
  disc(cv, 22, 17, 2, C.copper); disc(cv, 26, 17, 2, C.copper); // dead eyes
  fillRect(cv, 12, 38, 22, 42, C.brass); fillRect(cv, 26, 38, 36, 42, C.brass); // folded legs
  fillRect(cv, 12, 28, 16, 38, C.brassSh); // arm resting
  disc(cv, 24, 30, 3, C.brassSh); disc(cv, 24, 30, 1, C.copper); // chest wound key
  outline(cv, P.brassSh);
};
icons.D134 = (cv) => { // 연료 화로 brazier (glow)
  glowBehind(cv, 24, 20, 15, C.orange);
  for (let y = 22; y < 36; y++) { const hw = 13 - (y - 22) * 0.5; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.brass : C.copper); }
  ellipse(cv, 24, 22, 13, 4, C.brassSh, C.copper); // bowl rim
  // flames
  for (const [fx, fh] of [[19, 8], [24, 12], [29, 9]]) for (let i = 0; i < fh; i++) setPx(cv, fx + Math.round(Math.sin(i / 2) * 2), 22 - i, i > fh * 0.6 ? C.orange : C.ember);
  disc(cv, 24, 20, 2, C.white);
  fillRect(cv, 20, 40, 24, 44, C.brassSh); fillRect(cv, 26, 40, 30, 44, C.brassSh); // legs
  outline(cv, P.brassSh);
};
icons.D135 = (cv) => { // 태엽 간판 clockwork sign (glow)
  glowBehind(cv, 24, 22, 16, C.orange);
  fillRect(cv, 8, 12, 40, 32, C.copper); // board
  fillRect(cv, 8, 12, 40, 15, hexToRGB('#5a4630'));
  gear(cv, 14, 22, 5, C.brassHi, C.brass, 8); // little cog decoration
  // glowing symbol
  line(cv, 22, 18, 22, 27, C.orange, 2); line(cv, 22, 18, 28, 18, C.orange, 2); line(cv, 22, 22, 27, 22, C.orange, 2);
  circle(cv, 33, 22, 4, C.ember, C.orange);
  fillRect(cv, 22, 32, 26, 40, C.brass); // hanging post
  outline(cv, '#241a10');
};
icons.D136 = (cv) => { // 녹슨 태엽 훈장 rusty spring medal
  fillRect(cv, 19, 8, 23, 18, C.rust); fillRect(cv, 25, 8, 29, 18, C.rustD); // ribbon
  circle(cv, 24, 28, 11, C.brass, C.brassSh); // medal disc (tarnished brass)
  circle(cv, 24, 28, 7, C.rust, C.rustD); // rusted centre
  coil(cv, 24, 28, 5, C.brassHi, C.brass); // spring emblem
  for (const [x, y] of [[18, 24], [30, 32]]) disc(cv, x, y, 2, C.rustD); // rust spots
  outline(cv, P.rustD);
};
icons.D137 = (cv) => { // 말라붙은 기름병 dried oil bottle
  for (let y = 18; y < 40; y++) { const hw = (y < 22) ? 5 : 10; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, C.brassHi, 150); }
  fillRect(cv, 18, 30, 30, 40, hexToRGB('#3a2c14')); // dried oil crust at bottom
  ellipse(cv, 24, 30, 9, 2, hexToRGB('#2a2010'), C.copper);
  fillRect(cv, 20, 12, 28, 18, C.brassSh); // neck/cap
  disc(cv, 21, 24, 1, C.white); // glass glint
  outline(cv, P.brassSh);
};
icons.D138 = (cv) => { // 부서진 태엽 오르골 broken music box
  fillRect(cv, 12, 22, 36, 40, C.copper); // box
  fillRect(cv, 12, 22, 36, 25, hexToRGB('#5a4630'));
  // broken open lid (tilted)
  line(cv, 12, 22, 34, 14, C.brass, 2); line(cv, 12, 22, 34, 14, C.brassHi, 1);
  gear(cv, 22, 32, 6, C.brassHi, C.brass, 8); // exposed cylinder gear
  // scattered spring, broken
  coil(cv, 31, 33, 4, C.brassHi, C.brass);
  line(cv, 26, 30, 30, 28, C.brassSh, 1); // crack
  outline(cv, '#241a10');
};
icons.D139 = (cv) => { // 꺼진 신호 톱니 dark signal gear (inert, no glow)
  gear(cv, 24, 24, 13, C.brass, C.brassSh, 8); // dim brass
  disc(cv, 24, 24, 6, C.copper);
  disc(cv, 24, 24, 3, C.ash); disc(cv, 24, 24, 1, hexToRGB('#2a2830')); // dead signal lamp
  outline(cv, P.brassSh);
};

// ============================================================================
// LAYER-4 MAGIC FAMILY (L4). P1..P7 gather + D140..D176 craft. Shared cues
// (design v1 Part C): amethyst-violet silhouettes with a darker amethyst selout;
// magical / powered items get a gold rune glowBehind; the sealed/void items carry a
// cold void-blue accent. Each id gets a byte-unique painter (bespoke P1-P7 + a
// deterministic per-id rune-glyph variation for the D-crafts).
// ============================================================================

// --- helper: a gold rune glyph (a small angular sigil) at cx,cy, variant v ---
function runeGlyph(cv, cx, cy, v, col) {
  col = col || C.runeGold;
  const forms = [
    [[-3,-4,3,-4],[0,-4,0,4],[-3,4,3,4]],          // I-bar
    [[-3,-4,3,4],[3,-4,-3,4]],                       // X
    [[0,-5,0,5],[0,-2,4,-5],[0,2,4,5]],              // Y-ish
    [[-3,-4,-3,4],[-3,-4,3,-4],[-3,0,2,0]],          // F
    [[-3,4,-3,-4],[-3,-4,3,0],[3,0,-3,4]],           // R
    [[-4,0,4,0],[0,-4,0,4],[-3,-3,3,3]],             // asterisk-ish
  ];
  const f = forms[((v % forms.length) + forms.length) % forms.length];
  for (const seg of f) line(cv, cx + seg[0], cy + seg[1], cx + seg[2], cy + seg[3], col, 1);
}

// --- helper: a faceted amethyst shard body centred at cx,cy ---
function amethystBody(cv, cx, cy, rx, ry, lit, dark) {
  ellipse(cv, cx, cy, rx, ry, lit || C.amyM, dark || C.amy);
  line(cv, cx, cy - ry, cx, cy + ry, C.amyL, 1);            // facet ridge
  disc(cv, cx - Math.round(rx * 0.4), cy - Math.round(ry * 0.4), 2, C.amyH); // glint
}

// ---------- P1..P7 (Layer-4 gather) — design §B-1 ----------
icons.P1 = (cv) => { // 룬석 rune stone — grey slab with one faint carved rune
  ellipse(cv, 24, 30, 15, 12, C.amyM, C.amy);
  for (let y = 20; y < 30; y++) for (let x = 16; x < 34; x++) if (getA(cv, x, y)) setPx(cv, x, y, x - y > -4 ? C.amyM : C.amy);
  runeGlyph(cv, 24, 26, 0, C.runeGoldD);   // unlit carved rune
  outline(cv, P.amyD);
};
icons.P2 = (cv) => { // 마력 결정 mana crystal — glowing violet cluster
  glowBehind(cv, 24, 24, 16, C.amyM);
  amethystBody(cv, 24, 26, 8, 13, C.amyL, C.amyM);
  amethystBody(cv, 15, 32, 5, 8, C.amyL, C.amyM);
  amethystBody(cv, 33, 30, 5, 9, C.amyL, C.amyM);
  disc(cv, 24, 20, 2, C.white);
  outline(cv, P.amyD);
};
icons.P3 = (cv) => { // 은가루 silver dust — a small heap of pale glinting powder
  ellipse(cv, 24, 34, 15, 7, C.silver, darker(C.silver, 30));
  for (let i = 0; i < 24; i++) { const x = 12 + (i * 7 % 24), y = 28 + (i * 5 % 8); setPx(cv, x, y, C.silverL); }
  disc(cv, 20, 30, 1, C.white); disc(cv, 29, 31, 1, C.white); sparkle(cv, 24, 26);
  outline(cv, '#4a4650');
};
icons.P4 = (cv) => { // 양피지 vellum — blank rolled parchment
  for (let y = 14; y < 36; y++) for (let x = 15; x < 33; x++) setPx(cv, x, y, x < 20 ? C.vellumD : C.vellum);
  ellipse(cv, 18, 25, 4, 12, C.vellumD, darker(C.vellumD, 20)); // rolled left edge
  ellipse(cv, 30, 25, 4, 12, C.vellum, C.vellumD);              // rolled right edge
  line(cv, 22, 20, 28, 20, C.vellumD, 1); line(cv, 22, 25, 28, 25, C.vellumD, 1); // faint lines
  outline(cv, '#8a7840');
};
icons.P5 = (cv) => { // 봉인 밀랍 sealing wax — a dark-violet wax seal blob
  ellipse(cv, 24, 28, 14, 12, C.amy, C.amyD);
  disc(cv, 24, 28, 7, C.amyM);
  runeGlyph(cv, 24, 28, 3, C.runeGold);   // stamped sigil
  disc(cv, 19, 23, 2, C.amyL);            // wax sheen
  outline(cv, P.amyD);
};
icons.P6 = (cv) => { // 별빛 이슬 starlight dew — a luminous dewdrop with a star
  glowBehind(cv, 24, 28, 14, C.amyL);
  const cx = 24;
  for (let y = 16; y < 28; y++) { const hw = Math.round((y - 16) / 12 * 8); for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.amyL : C.amyM); }
  ellipse(cv, cx, 32, 10, 10, C.amyL, C.amyM);
  disc(cv, cx + 3, 29, 2, C.white); sparkle(cv, cx, 24);
  outline(cv, P.amyD);
};
icons.P7 = (cv) => { // 공허 파편 void shard — a weightless cold-blue splinter
  for (let y = 10; y < 40; y++) { const hw = Math.round((40 - y) / 30 * 9); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, (x < 24) ? C.voidBlue : darker(C.amy, 10), 220); }
  line(cv, 24, 10, 19, 38, C.amyL, 1);   // cold glint
  disc(cv, 22, 22, 1, C.amyH); disc(cv, 26, 30, 1, C.amyH);
  outline(cv, '#0a0714');
};

// ---------- D140..D176 (Layer-4 craft) — deterministic per-id variation ----------
// A shared amethyst plaque body + a per-id count/arrangement of gold rune glyphs, with a
// gold glow on the "powered/glowing" ids and a void-blue accent on the sealed/void ids. The
// numeric id drives glyph count, positions, and accents so every file is byte-unique.
const L4_GLOW_IDS = new Set([148, 143, 145, 154, 158, 160, 162, 164, 167, 168, 171, 172, 175, 176]);
const L4_VOID_IDS = new Set([147, 155, 158, 173, 174, 175, 176]);
function paintL4Craft(cv, n) {
  const glow = L4_GLOW_IDS.has(n);
  const voidy = L4_VOID_IDS.has(n);
  if (glow) glowBehind(cv, 24, 24, 17, C.runeGold);
  // plaque body — rounded amethyst tablet; its tint shifts subtly with n for extra variance.
  const tintUp = (n % 5) * 3;
  const bodyLit = lighter(C.amyM, tintUp), bodyDk = darker(C.amy, (n % 3) * 4);
  for (let y = 12; y < 38; y++) for (let x = 12; x < 36; x++) {
    const edge = (x === 12 || x === 35 || y === 12 || y === 37);
    setPx(cv, x, y, edge ? bodyDk : (x - y > (n % 7) - 3 ? bodyLit : C.amy));
  }
  // corner studs (void-blue for sealed/void items, gold otherwise) — count varies by id.
  const studCol = voidy ? C.voidBlue : C.runeGoldD;
  const studs = [[15, 15], [33, 15], [15, 35], [33, 35]];
  for (let i = 0; i < (2 + (n % 3)); i++) { const s = studs[i % 4]; disc(cv, s[0], s[1], 2, studCol); }
  // gold rune glyphs — 1..3 of them, arranged by id, each a different form.
  const glyphCount = 1 + (n % 3);
  const gcol = glow ? C.runeGoldL : C.runeGold;
  const positions = [[24, 24], [18, 22], [30, 26], [24, 32]];
  for (let i = 0; i < glyphCount; i++) {
    const pp = positions[i % positions.length];
    runeGlyph(cv, pp[0], pp[1], n + i, gcol);
  }
  // a void speck accent (cold) for the void family.
  if (voidy) { disc(cv, 24, 30, 2, C.voidBlue); sparkle(cv, 24, 30); }
  else if (glow) sparkle(cv, 30, 18);
  outline(cv, P.amyD);
}
for (let i = 140; i <= 176; i++) {
  icons['D' + i] = ((n) => (cv) => paintL4Craft(cv, n))(i);
}

// ============================================================================
// LAYER-5 DIVINITY FAMILY (L5). S1..S7 gather + D177..D218 craft. Shared cues
// (design v1 Part A/C): pale ivory/silver desaturated silhouettes, faint warm amber
// (꺼져가는 잔불) glow only on the lit/sacred items — 채도를 뺀 세계. Each id gets a
// byte-unique painter (bespoke S1-S7 + deterministic per-id variation for D-crafts).
// ============================================================================

// --- helper: a small amber ember flicker at cx,cy ---
function emberFlicker(cv, cx, cy, r) {
  glowBehind(cv, cx, cy, r, C.ambient);
  disc(cv, cx, cy, Math.max(1, Math.round(r * 0.4)), C.ambientL);
  disc(cv, cx, cy, 1, C.ivoryH);
}

// ---------- S1..S7 (Layer-5 gather) — design §B-1 ----------
icons.S1 = (cv) => { // 성수 holy water — a still ivory-rimmed font of pale water
  ellipse(cv, 24, 30, 15, 10, C.ivory, C.ivoryD);   // stone basin
  ellipse(cv, 24, 28, 11, 6, C.blueM, C.blue);       // still water surface
  disc(cv, 20, 26, 2, C.ivoryL);                     // faint sheen
  outline(cv, P.ivoryD);
};
icons.S2 = (cv) => { // 빛바랜 성물 faded relic — a worn, indistinct ivory reliquary
  ellipse(cv, 24, 28, 12, 14, C.ivoryM, C.ivory);
  for (let y = 16; y < 40; y++) for (let x = 14; x < 34; x++) if (getA(cv, x, y)) setPx(cv, x, y, ((x + y) % 5 === 0) ? C.ivoryD : (x - y > -2 ? C.ivoryM : C.ivory));
  disc(cv, 24, 22, 2, C.ambientD);                   // one faint warm speck
  outline(cv, P.ivoryD);
};
icons.S3 = (cv) => { // 대리석 조각 marble chunk — a broken faceted white shard
  for (let y = 16; y < 38; y++) { const hw = Math.round((38 - y) / 22 * 13); for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - y > -3 ? C.ivoryL : C.ivoryM); }
  line(cv, 24, 16, 18, 36, C.ivoryH, 1);             // vein
  line(cv, 24, 16, 30, 36, C.ivoryD, 1);
  outline(cv, P.ivoryD);
};
icons.S4 = (cv) => { // 기도 구슬 prayer bead — a short string of pale beads
  const beads = [[15, 30], [22, 33], [29, 33], [34, 28]];
  line(cv, 15, 30, 34, 28, C.ivoryD, 1);
  for (const [bx, by] of beads) { circle(cv, bx, by, 3, C.ivoryL, C.ivory); disc(cv, bx - 1, by - 1, 1, C.ivoryH); }
  outline(cv, P.ivoryD);
};
icons.S5 = (cv) => { // 성가 악보 hymn sheet — a pale sheet with faint staff lines + notes
  for (let y = 12; y < 38; y++) for (let x = 14; x < 34; x++) setPx(cv, x, y, x < 17 ? C.ivoryM : C.ivoryL);
  for (const ly of [18, 22, 26, 30]) line(cv, 17, ly, 32, ly, C.ivoryD, 1);
  disc(cv, 21, 26, 1, C.ashGrey); disc(cv, 27, 22, 1, C.ashGrey); // faint notes
  outline(cv, P.ivoryD);
};
icons.S6 = (cv) => { // 재의 날개 ash wing — a grey feathered wing dusted with ash
  for (let i = 0; i < 6; i++) { const ang = -0.5 + i * 0.28; const ex = 24 + Math.cos(ang) * (10 + i), ey = 30 + Math.sin(ang) * (10 + i); line(cv, 20, 32, ex, ey, (i % 2) ? C.ashGreyL : C.ashGrey, 1); }
  ellipse(cv, 20, 32, 5, 4, C.ivoryM, C.ashGreyL);
  for (let i = 0; i < 8; i++) setPx(cv, 16 + (i * 5 % 22), 12 + (i * 3 % 10), C.ivoryL); // drifting ash
  outline(cv, P.ashGrey);
};
icons.S7 = (cv) => { // 신성한 잔불 divine ember — a dying warm ember on grey ash
  ellipse(cv, 24, 34, 14, 6, C.ashGrey, darker(C.ashGrey, 12)); // ash bed
  emberFlicker(cv, 24, 28, 12);
  disc(cv, 20, 30, 1, C.ambient); disc(cv, 29, 31, 1, C.ambientD); // stray coals
  outline(cv, P.ashGrey);
};

// ---------- D177..D218 (Layer-5 craft) — deterministic per-id variation ----------
// A shared ivory tablet body + per-id count/arrangement of faint marks; the "lit/sacred"
// ids carry an amber ember glow, others stay cold and desaturated. Numeric id drives mark
// count, positions, and accents so every file is byte-unique.
// Glow ids = the lantern/spring/ember/candle/glowing-decor outputs (design (a)/(e) glows:true).
const L5_GLOW_IDS = new Set([178, 180, 184, 193, 197, 202, 203, 204, 209, 210, 214]);
function paintL5Craft(cv, n) {
  const glow = L5_GLOW_IDS.has(n);
  if (glow) glowBehind(cv, 24, 24, 17, C.ambient);
  // tablet body — rounded ivory tablet; tint shifts subtly with n for extra variance.
  const tintUp = (n % 5) * 3;
  const bodyLit = lighter(C.ivoryM, tintUp), bodyDk = darker(C.ivory, (n % 3) * 5);
  for (let y = 12; y < 38; y++) for (let x = 12; x < 36; x++) {
    const edge = (x === 12 || x === 35 || y === 12 || y === 37);
    setPx(cv, x, y, edge ? bodyDk : (x - y > (n % 7) - 3 ? bodyLit : C.ivory));
  }
  // corner studs (amber for glowing/sacred items, ash-grey otherwise) — count varies by id.
  const studCol = glow ? C.ambientD : C.ashGrey;
  const studs = [[15, 15], [33, 15], [15, 35], [33, 35]];
  for (let i = 0; i < (2 + (n % 3)); i++) { const s = studs[i % 4]; disc(cv, s[0], s[1], 2, studCol); }
  // faint carved marks — 1..3 of them, arranged by id (reuse the L4 runeGlyph as a sigil form).
  const markCount = 1 + (n % 3);
  const mcol = glow ? C.ambientL : C.ivoryD;
  const positions = [[24, 24], [18, 22], [30, 26], [24, 32]];
  for (let i = 0; i < markCount; i++) {
    const pp = positions[i % positions.length];
    runeGlyph(cv, pp[0], pp[1], n + i, mcol);
  }
  // an ember speck for the lit family, a cold ash speck otherwise.
  if (glow) { emberFlicker(cv, 24, 30, 5); }
  else { disc(cv, 24, 30, 1, C.ashGreyL); }
  outline(cv, P.ivoryD);
}
for (let i = 177; i <= 218; i++) {
  icons['D' + i] = ((n) => (cv) => paintL5Craft(cv, n))(i);
}

// ---------- D219..D221 (v1.1.0 GP-2 §2.3) 실패작 — junk outputs of 그럴듯한 오답 조합 ----------
// A murky swamp/gray blob with per-id bubbles/specks so each is byte-unique. Intentionally dull
// (실패도 수집: it belongs in the 도감 as a grimy trophy, not a proud craft).
icons.D219 = (cv) => { // 미지근한 진흙 (풀+나무 → 늪)
  ellipse(cv, 24, 31, 16, 11, C.greenD, darker(C.greenD, 8));
  ellipse(cv, 24, 30, 12, 7, hexToRGB('#3a3a2e'), C.greenD);
  disc(cv, 19, 30, 2, hexToRGB('#5a5a44')); disc(cv, 29, 32, 2, hexToRGB('#4a4a38'));
  disc(cv, 25, 27, 1, hexToRGB('#6a6a50'));
  outline(cv, '#14140e');
};
icons.D220 = (cv) => { // 짓무른 꽃 (꽃+바위 → 뭉개짐)
  ellipse(cv, 24, 30, 14, 12, hexToRGB('#4a3540'), hexToRGB('#372836'));
  disc(cv, 20, 26, 3, hexToRGB('#6a4a5a')); disc(cv, 29, 28, 3, hexToRGB('#5a3f4f'));
  disc(cv, 24, 34, 2, hexToRGB('#3a2a34'));
  disc(cv, 24, 22, 1, hexToRGB('#7a5a68'));
  outline(cv, '#1e141b');
};
icons.D221 = (cv) => { // 돌에 낀 꽃물 (꽃+돌 → 얼룩)
  ellipse(cv, 24, 30, 15, 11, hexToRGB('#4a4650'), hexToRGB('#35323a'));
  disc(cv, 18, 31, 2, hexToRGB('#6a5a6a')); disc(cv, 27, 29, 3, hexToRGB('#5a4a5f'));
  disc(cv, 31, 33, 1, hexToRGB('#4a3a4a'));
  outline(cv, '#161318');
};

// ============================================================================
// EX-L1 EXPANSION (v1.2.0 색/생명 확장). New Layer-1 gathers I10..I17 + crafts
// D222..D254. Two thematic chapters:
//   garden  = 색 잃은 파스텔 톤 (faded/desaturated pastels being recoloured)
//   heart   = 심부 어둠 + 뿌리 보라 발광 (dark heart-core with root-violet glow)
// Reuses the Layer-1 conventions: 1px selout (darker same-hue, never pure black),
// soft top-right light, bold silhouettes; "glows" items get an additive glowBehind
// core exactly like the existing violet-glow family. Deterministic (fixed layout
// per id) so regeneration is byte-stable.
// ============================================================================

// --- helpers for the EX-L1 palette (faded pastels + warm-violet life glow) ---
// paint-pot: a small ceramic pot brimming with a coloured paint (lit/dark same-hue).
function paintPot(cv, lit, dark, rim) {
  for (let y = 22; y < 40; y++) { // pot body (grey ceramic)
    const hw = 11 - Math.abs(y - 31) * 0.12;
    for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greyL : C.grey);
  }
  ellipse(cv, 24, 22, 11, 4, C.greyL, C.grey);        // rim
  ellipse(cv, 24, 22, 8, 3, dark, dark);              // paint surface (dark ring)
  ellipse(cv, 24, 21, 7, 2, lit, dark);               // lit paint meniscus
  // a fat drip down the front
  fillRect(cv, 22, 24, 26, 34, dark);
  fillRect(cv, 22, 24, 24, 34, lit);
  disc(cv, 21, 25, 1, C.white);                       // ceramic glint
  if (rim) { for (let x = 15; x < 34; x++) setPx(cv, x, 22, rim); }
}
// desaturate a hue toward the pale-grey of the 색 잃은 garden.
function faded(rgb, amt) {
  const g = Math.round((rgb[0] + rgb[1] + rgb[2]) / 3);
  return rgb.map(v => Math.round(v + (g - v) * amt));
}
// warm-violet life glow accent (a deeper/heavier sibling of `sparkle`).
function lifeSpark(cv, x, y) {
  setPx(cv, x, y, C.white); setPx(cv, x - 1, y, C.violetL, 210); setPx(cv, x + 1, y, C.violetL, 210);
  setPx(cv, x, y - 1, C.violetL, 210); setPx(cv, x, y + 1, C.violetL, 210);
  setPx(cv, x - 1, y - 1, C.gold, 120); setPx(cv, x + 1, y + 1, C.gold, 120);
}

// ---------- I10..I17 (EX-L1 gather) ----------
icons.I10 = (cv) => { // 희귀 꽃 rare flower — faded pastel bloom (garden)
  fillRect(cv, 23, 24, 26, 42, faded(C.greenM, 0.35)); // pale stem
  const pc = faded(C.pinkL, 0.4), pd = faded(C.pink, 0.4);
  for (let a = 0; a < 6; a++) {
    const r = a * (Math.PI * 2 / 6) - Math.PI / 2;
    ellipse(cv, 24 + Math.cos(r) * 8, 20 + Math.sin(r) * 8, 5, 6, pc, pd);
  }
  disc(cv, 24, 20, 4, faded(C.goldL, 0.35)); disc(cv, 24, 20, 2, C.cream);
  outline(cv, '#7a5560'); // faded-rose selout
};
icons.I11 = (cv) => { // 꽃 이슬 flower dew — a droplet, faint glow (garden)
  glowBehind(cv, 24, 28, 12, faded(C.blueL, 0.3));
  const cx = 24;
  for (let y = 14; y < 26; y++) { const hw = Math.round((y - 14) / 12 * 8); for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.blueL : C.blueM); }
  ellipse(cv, cx, 30, 10, 10, C.blueL, C.blueM);
  disc(cv, cx + 3, 27, 2, C.white); disc(cv, cx - 3, 32, 1, C.white, 180);
  outline(cv, P.blueD);
};
icons.I12 = (cv) => { // 색 모래 color sand — granular pile, faint desat colour speck (garden)
  ellipse(cv, 24, 34, 17, 9, faded(C.goldL, 0.35), faded(C.gold, 0.35));
  const specks = [C.pinkL, C.blueL, C.violetL, C.greenL];
  for (let i = 0; i < 26; i++) {
    const x = 10 + (i * 7) % 28, y = 28 + (i * 5) % 10;
    setPx(cv, x, y, (i % 5 === 0) ? faded(specks[i % 4], 0.45) : (i % 2 ? faded(C.gold, 0.3) : faded(C.goldL, 0.25)));
  }
  outline(cv, '#8a7a5a');
};
icons.I13 = (cv) => { // 꽃가루 pollen — pale yellow scatter (garden)
  const pc = faded(C.goldL, 0.2), pd = faded(C.gold, 0.25);
  disc(cv, 24, 28, 9, pc);                  // soft central puff
  disc(cv, 24, 28, 5, lighter(pc, 12));
  const pts = [[14,22],[33,20],[16,34],[32,35],[24,16],[20,38],[30,26],[18,27]];
  for (let i = 0; i < pts.length; i++) disc(cv, pts[i][0], pts[i][1], 1 + (i % 2), i % 2 ? pd : pc);
  disc(cv, 21, 25, 1, C.white);
  outline(cv, '#b89a4a');
};
icons.I14 = (cv) => { // 생명의 정수 life essence — UNIQUE, bigger/warmer sibling of I9 (heart)
  glowBehind(cv, 24, 24, 21, C.violetM);            // wider glow than I9 (r18)
  glowBehind(cv, 24, 24, 14, C.gold);               // warm gold inner glow
  circle(cv, 24, 24, 14, C.violetL, C.violet);      // heavier orb (r14 vs I9 r12)
  disc(cv, 24, 26, 8, C.violetM, 150);              // warm-violet depth
  disc(cv, 22, 22, 4, C.goldL, 170);                // gold heart-core
  disc(cv, 28, 19, 3, C.white);                     // spec highlight
  disc(cv, 19, 29, 2, C.violetL, 200);
  outline(cv, P.violet);
  lifeSpark(cv, 12, 15); lifeSpark(cv, 36, 30); lifeSpark(cv, 30, 10);
};
icons.I15 = (cv) => { // 뿌리 수액 root sap — slow amber/green liquid drop (heart)
  glowBehind(cv, 24, 28, 12, C.gold);
  const cx = 24;
  for (let y = 14; y < 26; y++) { const hw = Math.round((y - 14) / 12 * 8); for (let x = cx - hw; x <= cx + hw; x++) setPx(cv, x, y, x - cx > 1 ? C.goldL : C.gold); }
  ellipse(cv, cx, 30, 10, 10, C.goldL, C.gold);
  ellipse(cv, cx - 2, 33, 5, 4, C.greenM, C.green);  // green root-tinge swirl
  disc(cv, cx + 3, 27, 2, C.white);
  outline(cv, '#a8641e');
};
icons.I16 = (cv) => { // 세계수 씨눈 world-tree bud/seed-eye (heart)
  ellipse(cv, 24, 28, 10, 13, C.brownL, C.brown);    // seed husk
  line(cv, 24, 16, 24, 40, C.brownD, 1);             // seam
  // the "eye": a violet-glow bud peeking from the top split
  glowBehind(cv, 24, 18, 9, C.violetM);
  disc(cv, 24, 19, 4, C.violetL); disc(cv, 24, 19, 2, C.white);
  leaf(cv, 24, 16, 1, C.greenH, C.greenL);           // tiny sprout tip
  disc(cv, 21, 25, 2, lighter(C.brownL, 18));        // husk sheen
  outline(cv, P.brownD);
};
icons.I17 = (cv) => { // 심장 이끼 heart moss — dark green with faint violet (heart)
  ellipse(cv, 24, 32, 16, 9, C.greenD, darker(C.greenD, 6));
  for (let i = 0; i < 30; i++) { const x = 10 + (i * 11) % 28, y = 26 + (i * 7) % 12; setPx(cv, x, y, i % 4 === 0 ? C.violetM : (i % 3 ? C.green : C.greenM)); }
  disc(cv, 20, 28, 2, C.violetL, 160); disc(cv, 30, 30, 1, C.violetL, 160); // violet glow flecks
  outline(cv, '#12281c');
};

// ---------- D222..D254 (EX-L1 craft) ----------
// GARDEN color/paint chapter: D222-D230, D236-D241, D248, D251-D253.
icons.D222 = (cv) => { // 색 모래 반죽 paint paste — thick colour-flecked dough (garden)
  ellipse(cv, 24, 31, 16, 12, faded(C.goldL, 0.3), faded(C.gold, 0.3));
  ellipse(cv, 20, 27, 6, 4, lighter(faded(C.goldL, 0.25), 12), faded(C.goldL, 0.3)); // wet knead sheen
  for (const [x, y, c] of [[18, 30, C.pinkL], [29, 29, C.blueL], [24, 34, C.violetL], [31, 33, C.greenL]])
    disc(cv, x, y, 2, faded(c, 0.35));
  outline(cv, '#8a7248');
};
icons.D223 = (cv) => { // 꽃돌다리 flower stepping-stone bridge piece (garden)
  ellipse(cv, 24, 34, 16, 6, faded(C.blueM, 0.3), faded(C.blue, 0.3)); // water ripple
  ellipse(cv, 24, 27, 14, 8, C.greyL, C.grey);        // flat stone
  for (let a = 0; a < 5; a++) { const r = a * (Math.PI * 2 / 5) - Math.PI / 2; disc(cv, 24 + Math.cos(r) * 7, 25 + Math.sin(r) * 4, 2, faded(C.pinkL, 0.3)); } // inlaid petals
  disc(cv, 24, 25, 1, faded(C.goldL, 0.2));
  outline(cv, '#3f3f48');
};
icons.D224 = (cv) => { // 꽃즙 flower juice — vial of soft pink liquid (garden)
  vial(cv, faded(C.pinkL, 0.2), faded(C.pink, 0.25));
  outline(cv, '#7a4552');
};
icons.D225 = (cv) => { // 개화의 물감 bloom paint — vivid (garden, saturated)
  disc(cv, 18, 22, 7, C.pinkL); disc(cv, 30, 21, 7, C.violetL); disc(cv, 24, 33, 7, C.goldL);
  disc(cv, 18, 22, 3, C.pink); disc(cv, 30, 21, 3, C.violetM); disc(cv, 24, 33, 3, C.gold);
  disc(cv, 16, 19, 2, C.white);
  outline(cv, P.violet);
};
icons.D226 = (cv) => { // 붉은 물감 red paint pot (garden)
  paintPot(cv, C.pinkL, C.red);
  outline(cv, '#5a2632');
};
icons.D227 = (cv) => { // 노란 물감 yellow paint pot (garden)
  paintPot(cv, C.goldL, C.gold);
  outline(cv, '#a8641e');
};
icons.D228 = (cv) => { // 푸른 물감 blue paint pot (garden)
  paintPot(cv, C.blueL, C.blue);
  outline(cv, P.blueD);
};
icons.D229 = (cv) => { // 무지개 물감 rainbow paint (garden)
  for (let y = 22; y < 40; y++) { const hw = 11 - Math.abs(y - 31) * 0.12; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greyL : C.grey); }
  ellipse(cv, 24, 22, 11, 4, C.greyL, C.grey);
  // rainbow bands across the surface
  const bands = [C.red, C.gold, C.goldL, C.greenM, C.blue, C.violetM];
  for (let i = 0; i < bands.length; i++) fillRect(cv, 16 + i * 3, 20, 19 + i * 3, 24, bands[i]);
  fillRect(cv, 22, 24, 26, 34, C.violetM); fillRect(cv, 22, 24, 24, 34, C.pinkL); // drip
  disc(cv, 21, 25, 1, C.white);
  outline(cv, P.violet);
};
icons.D230 = (cv) => { // 색의 정수 color essence — radiant multi-hue glow (garden, glows)
  glowBehind(cv, 24, 24, 19, C.pinkL);
  glowBehind(cv, 24, 24, 15, C.blueL);
  circle(cv, 24, 24, 12, C.white, C.violetL);
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3; disc(cv, 24 + Math.cos(r) * 7, 24 + Math.sin(r) * 7, 3, [C.pink, C.gold, C.greenL, C.blueM, C.violetM, C.pinkL][a]); }
  disc(cv, 24, 24, 3, C.white);
  outline(cv, P.violet);
  sparkle(cv, 13, 16); sparkle(cv, 35, 30); sparkle(cv, 30, 11);
};
icons.D236 = (cv) => { // 꽃 목걸이 flower necklace (garden)
  for (let a = 30; a <= 150; a += 6) { const r = a * Math.PI / 180; setPx(cv, 24 + Math.cos(r) * 14, 20 + Math.sin(r) * 13, faded(C.greenM, 0.2)); } // cord
  const cols = [C.pinkL, C.goldL, C.violetL, C.pinkL, C.blueL];
  for (let i = 0; i < 5; i++) { const a = (35 + i * 28) * Math.PI / 180; ellipse(cv, 24 + Math.cos(a) * 14, 22 + Math.sin(a) * 13, 4, 4, faded(cols[i], 0.15), darker(faded(cols[i], 0.15), 30)); }
  disc(cv, 24, 35, 3, faded(C.pinkL, 0.15)); // pendant bloom
  outline(cv, P.green);
};
icons.D237 = (cv) => { // 이슬 유리 dew glass — glows (garden, glows)
  glowBehind(cv, 24, 26, 15, C.blueL);
  ellipse(cv, 24, 26, 12, 14, C.blueL, C.blueM);   // rounded glass drop
  ellipse(cv, 24, 26, 8, 10, lighter(C.blueL, 15), C.blueL);
  disc(cv, 20, 20, 3, C.white); disc(cv, 28, 30, 2, C.white, 180);
  sparkle(cv, 24, 14); sparkle(cv, 34, 28);
  outline(cv, P.blueD);
};
icons.D238 = (cv) => { // 모래 그림판 sand drawing board (garden)
  fillRect(cv, 9, 14, 39, 38, C.brownM);            // wooden frame
  fillRect(cv, 12, 17, 36, 35, faded(C.goldL, 0.3)); // sand bed
  // a doodled colour line drawn in the sand
  line(cv, 15, 30, 22, 22, faded(C.pinkL, 0.3), 1);
  line(cv, 22, 22, 30, 28, faded(C.blueL, 0.3), 1);
  disc(cv, 30, 28, 2, faded(C.violetL, 0.3));
  for (const [x, y] of [[16, 20], [33, 32]]) disc(cv, x, y, 1, C.gold); // stray grains
  outline(cv, P.brownD);
};
icons.D239 = (cv) => { // 꽃가루 향낭 pollen sachet (garden)
  for (let y = 20; y < 40; y++) { const hw = 11 - Math.abs(y - 32) * 0.2; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? faded(C.pinkL, 0.15) : faded(C.pink, 0.2)); }
  fillRect(cv, 17, 16, 31, 20, faded(C.violetM, 0.2)); // tied neck
  for (let x = 18; x < 31; x += 3) setPx(cv, x, 14, faded(C.violetM, 0.2)); // gather folds
  for (let i = 0; i < 6; i++) setPx(cv, 18 + i * 3, 30, faded(C.goldL, 0.15)); // pollen showing through
  disc(cv, 24, 28, 3, faded(C.goldL, 0.2));
  outline(cv, '#7a4552');
};
icons.D240 = (cv) => { // 색 이슬차 colored dew tea (garden)
  for (let y = 24; y < 40; y++) { const hw = 10 - Math.abs(y - 32) * 0.1; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.creamCupL : C.creamCup); } // cup
  ellipse(cv, 24, 24, 10, 3, C.creamCupL, C.creamCup);   // rim
  ellipse(cv, 24, 24, 8, 2, faded(C.pinkL, 0.1), faded(C.pink, 0.15)); // tea surface
  circle(cv, 34, 30, 4, C.creamCupL, C.creamCup); // handle
  for (let i = 0; i < 5; i++) setPx(cv, 22 + Math.round(Math.sin(i) * 2), 20 - i, faded(C.violetL, 0.2), 150); // steam
  outline(cv, '#9a8a5a');
};
icons.D241 = (cv) => { // 물든 모래병 dyed sand bottle — layered colored sand (garden)
  for (let y = 14; y < 40; y++) { const hw = (y < 18) ? 4 : 9; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, C.blueL, 130); } // clear glass
  const layers = [[34, faded(C.pinkL, 0.25)], [30, faded(C.goldL, 0.2)], [26, faded(C.blueL, 0.2)], [22, faded(C.violetL, 0.25)]];
  for (const [y0, c] of layers) for (let x = 16; x < 33; x++) { const wob = Math.round(Math.sin(x * 0.7) * 1); fillRect(cv, x, y0 + wob, x + 1, y0 + 4 + wob, c); }
  fillRect(cv, 20, 10, 28, 14, C.brownM); // cork
  disc(cv, 20, 24, 1, C.white);
  outline(cv, P.blueD);
};
icons.D248 = (cv) => { // 색을 되찾은 꽃밭 recolored flowerbed — glows (garden, glows)
  glowBehind(cv, 24, 24, 19, C.pinkL);
  ellipse(cv, 24, 36, 17, 7, C.brownM, C.brown);      // soil bed
  const cols = [C.pinkL, C.violetL, C.goldL, C.blueL, C.greenH];
  for (let i = 0; i < 5; i++) {
    const bx = 13 + i * 5;
    fillRect(cv, bx, 22, bx + 1, 33, C.greenM);
    disc(cv, bx, 20, 3, cols[i]); disc(cv, bx, 20, 1, C.white);
  }
  sparkle(cv, 12, 18); sparkle(cv, 36, 20); sparkle(cv, 24, 10);
  outline(cv, P.green);
};
icons.D251 = (cv) => { // 정령꽃 등롱 spirit-flower lantern — glows (garden, glows)
  glowBehind(cv, 24, 26, 16, C.violetM);
  fillRect(cv, 20, 8, 28, 12, faded(C.greenM, 0.2)); // hanger stem
  // flower-shaped lantern shell
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3; ellipse(cv, 24 + Math.cos(r) * 8, 26 + Math.sin(r) * 9, 5, 6, C.violetM, C.violet); }
  disc(cv, 24, 26, 6, C.violetL); disc(cv, 24, 26, 3, C.white); // glowing core
  sparkle(cv, 13, 22); sparkle(cv, 35, 30);
  outline(cv, P.violet);
};
icons.D252 = (cv) => { // 색을 잃은 화관 colorless wreath — desaturated (garden)
  for (let a = 0; a < 360; a += 12) { const r = a * Math.PI / 180; const rad = 14; ellipse(cv, 24 + Math.cos(r) * rad, 24 + Math.sin(r) * rad, 4, 4, faded(C.greenL, 0.7), faded(C.greenM, 0.7)); }
  for (let a = 30; a < 360; a += 90) { const r = a * Math.PI / 180; disc(cv, 24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14, 3, faded(C.pinkL, 0.75)); } // washed-out blooms
  outline(cv, '#5a5a52');
};
icons.D253 = (cv) => { // 지워진 팔레트 erased grey palette (garden)
  // artist's palette (kidney shape via two arcs) in dull grey
  for (let y = 18; y < 38; y++) { const hw = 15 - Math.abs(y - 28) * 0.35; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greyL : C.grey); }
  disc(cv, 30, 33, 4, C.greyD); // thumb hole
  for (const [x, y] of [[16, 22], [22, 20], [29, 21], [18, 30]]) { disc(cv, x, y, 3, faded(C.grey, 0.4)); disc(cv, x, y, 1, faded(C.greyL, 0.3)); } // erased paint dabs (grey)
  outline(cv, '#45454e');
};

// HEART life chapter: D231-D235, D242-D247, D249, D250, D254.
icons.D231 = (cv) => { // 맑은 수액 clear sap — pale amber vial (heart)
  vial(cv, C.goldL, C.gold);
  disc(cv, 24, 30, 3, lighter(C.goldL, 15), 160); // clarity sheen
  outline(cv, '#a8641e');
};
icons.D232 = (cv) => { // 소생의 수액 revival sap — glowing (heart, glows)
  glowBehind(cv, 24, 28, 15, C.gold);
  glowBehind(cv, 24, 28, 10, C.violetM);
  vial(cv, C.goldL, C.gold);
  disc(cv, 24, 30, 4, C.violetL, 150); disc(cv, 24, 28, 2, C.white);
  sparkle(cv, 24, 16); sparkle(cv, 33, 30);
  outline(cv, '#a8641e');
};
icons.D233 = (cv) => { // 생명의 씨눈 life seedling — warm glow (heart, glows)
  glowBehind(cv, 24, 22, 15, C.gold);
  ellipse(cv, 24, 30, 8, 11, C.brownL, C.brown);   // seed
  glowBehind(cv, 24, 18, 8, C.violetM);
  fillRect(cv, 23, 20, 26, 26, C.greenM);
  leaf(cv, 24, 20, -1, C.greenH, C.greenL);
  leaf(cv, 24, 16, 1, C.violetL, C.violetM);
  disc(cv, 24, 16, 2, C.white);
  sparkle(cv, 33, 16); sparkle(cv, 15, 22);
  outline(cv, P.green);
};
icons.D234 = (cv) => { // 심장의 고동물 heartbeat fluid — pulsing violet (heart, glows)
  glowBehind(cv, 24, 26, 17, C.violetM);
  flask(cv, C.violetL, C.violetM);
  // pulse rings inside
  circle(cv, 24, 30, 7, C.violetL, C.violetM); circle(cv, 24, 30, 4, C.white, C.violetL);
  disc(cv, 24, 30, 2, C.pinkL);
  sparkle(cv, 24, 16); sparkle(cv, 15, 30); sparkle(cv, 33, 28);
  outline(cv, P.violet);
};
icons.D235 = (cv) => { // 되살아난 심장 revived heart — warm glowing heart core (heart, glows)
  glowBehind(cv, 24, 24, 19, C.red);
  glowBehind(cv, 24, 24, 13, C.gold);
  // heart silhouette (pink→red), warm core
  ellipse(cv, 18, 20, 8, 8, C.pinkL, C.pink); ellipse(cv, 30, 20, 8, 8, C.pinkL, C.pink);
  for (let i = 0; i < 16; i++) { const hw = 13 - i; for (let w = -hw; w <= hw; w++) setPx(cv, 24 + w, 22 + i, (w > 0) ? C.pinkL : C.pink); }
  disc(cv, 24, 24, 6, C.goldL); disc(cv, 24, 24, 3, C.white); // glowing life-core
  sparkle(cv, 14, 14); sparkle(cv, 34, 16); sparkle(cv, 24, 40);
  outline(cv, P.red);
};
icons.D242 = (cv) => { // 쌍뿌리 매듭 twin-root knot (heart)
  // two brown roots interwoven into a knot
  for (let t = 0; t < 40; t++) { const y = 8 + t; const x1 = 24 + Math.round(Math.sin(t * 0.32) * 8); const x2 = 24 - Math.round(Math.sin(t * 0.32) * 8); disc(cv, x1, y, 2, (t % 2) ? C.brownL : C.brownM); disc(cv, x2, y, 2, (t % 2) ? C.brownM : C.brown); }
  disc(cv, 24, 24, 3, C.brownD); // central knot cinch
  disc(cv, 24, 24, 1, C.violetM); // faint life at core
  outline(cv, P.brownD);
};
icons.D243 = (cv) => { // 겹씨눈 double bud (heart)
  glowBehind(cv, 18, 22, 8, C.violetM); glowBehind(cv, 30, 26, 8, C.violetM);
  ellipse(cv, 18, 24, 8, 11, C.brownL, C.brown); ellipse(cv, 30, 26, 8, 11, C.brownL, C.brown);
  disc(cv, 18, 20, 3, C.violetL); disc(cv, 18, 20, 1, C.white);
  disc(cv, 30, 22, 3, C.violetL); disc(cv, 30, 22, 1, C.white);
  outline(cv, P.brownD);
};
icons.D244 = (cv) => { // 이끼 방석 moss cushion (heart)
  for (let y = 24; y < 40; y++) { const hw = 16 - Math.abs(y - 32) * 0.3; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greenM : C.green); } // plump cushion
  for (let i = 0; i < 40; i++) { const x = 10 + (i * 11) % 28, y = 26 + (i * 7) % 12; setPx(cv, x, y, i % 5 === 0 ? C.violetM : (i % 3 ? C.greenL : C.greenH)); }
  ellipse(cv, 24, 26, 12, 4, C.greenL, C.greenM); // top-lit dome
  outline(cv, '#12281c');
};
icons.D245 = (cv) => { // 수액 등불 sap lantern — glows (heart, glows)
  glowBehind(cv, 24, 26, 16, C.gold);
  fillRect(cv, 20, 8, 28, 12, C.brownM); // hanger
  fillRect(cv, 16, 14, 32, 38, C.brown); // wooden frame
  fillRect(cv, 19, 17, 29, 35, C.goldL); // glowing sap glass
  ellipse(cv, 24, 27, 4, 7, C.white, C.goldL);
  disc(cv, 24, 33, 2, C.gold);
  sparkle(cv, 14, 22); sparkle(cv, 34, 30);
  outline(cv, P.brownD);
};
icons.D246 = (cv) => { // 심장 이끼차 heart moss tea (heart)
  for (let y = 24; y < 40; y++) { const hw = 10 - Math.abs(y - 32) * 0.1; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.creamCupL : C.creamCup); }
  ellipse(cv, 24, 24, 10, 3, C.creamCupL, C.creamCup);
  ellipse(cv, 24, 24, 8, 2, C.greenD, darker(C.greenD, 6)); // dark mossy brew
  disc(cv, 22, 24, 1, C.violetM); // faint violet sheen
  circle(cv, 34, 30, 4, C.creamCupL, C.creamCup); // handle
  for (let i = 0; i < 5; i++) setPx(cv, 22 + Math.round(Math.sin(i) * 2), 20 - i, C.violetL, 140);
  outline(cv, '#9a8a5a');
};
icons.D247 = (cv) => { // 생명의 눈꽃 life snow-flower — glows (heart, glows)
  glowBehind(cv, 24, 24, 17, C.violetM);
  glowBehind(cv, 24, 24, 11, C.blueL);
  // 6-fold snowflake-flower of violet/white
  for (let a = 0; a < 6; a++) {
    const r = a * Math.PI / 3;
    line(cv, 24, 24, 24 + Math.cos(r) * 14, 24 + Math.sin(r) * 14, C.violetL, 1);
    ellipse(cv, 24 + Math.cos(r) * 12, 24 + Math.sin(r) * 12, 3, 3, C.white, C.violetL);
    disc(cv, 24 + Math.cos(r) * 7, 24 + Math.sin(r) * 7, 1, C.blueL);
  }
  disc(cv, 24, 24, 3, C.white);
  sparkle(cv, 13, 15); sparkle(cv, 35, 32);
  outline(cv, P.violet);
};
icons.D249 = (cv) => { // 세계수 묘목 화분 sapling pot (heart)
  glowBehind(cv, 24, 18, 12, C.violetM);
  for (let y = 28; y < 42; y++) { const hw = 11 - (y - 28) * 0.3; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? hexToRGB('#c47a68') : hexToRGB('#a85a4a')); }
  fillRect(cv, 11, 26, 37, 30, hexToRGB('#c47a68')); // rim
  fillRect(cv, 23, 18, 26, 28, C.brownM); // trunk
  ellipse(cv, 24, 16, 9, 8, C.greenL, C.greenM); // canopy
  ellipse(cv, 24, 12, 5, 4, C.greenH, C.greenL);
  sparkle(cv, 24, 6); sparkle(cv, 34, 16);
  outline(cv, '#6e3327');
};
icons.D250 = (cv) => { // 생명수 성수반 life-water font — glows (heart, glows)
  glowBehind(cv, 24, 26, 18, C.violetM);
  // pedestal font
  fillRect(cv, 21, 30, 27, 42, C.greyL); // stem
  fillRect(cv, 16, 40, 32, 44, C.grey);  // base
  for (let y = 22; y < 32; y++) { const hw = 15 - (y - 22) * 0.4; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greyL : C.grey); } // bowl
  ellipse(cv, 24, 22, 15, 4, C.greyL, C.grey);       // bowl rim
  ellipse(cv, 24, 22, 12, 3, C.violetL, C.violetM);  // glowing water
  disc(cv, 24, 22, 3, C.white);
  sparkle(cv, 12, 20); sparkle(cv, 36, 20); sparkle(cv, 24, 12);
  outline(cv, '#3f3f48');
};
icons.D254 = (cv) => { // 첫 실험의 잔재 first-experiment remnant — hardened failed lump (heart)
  ellipse(cv, 24, 31, 15, 12, hexToRGB('#4a3f4a'), hexToRGB('#332a35')); // murky violet-grey lump
  disc(cv, 19, 27, 3, hexToRGB('#5f4a5f')); disc(cv, 30, 29, 3, hexToRGB('#4a3a4f'));
  disc(cv, 24, 35, 2, hexToRGB('#3a2f3a'));
  disc(cv, 22, 24, 1, C.violetM, 160); disc(cv, 29, 26, 1, C.gold, 120); // faint failed-life glint
  outline(cv, '#1c141c');
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
// Layer-3 (L3): K1..K7 gather + D103..D139 craft.
for (let i = 1; i <= 7; i++) ALL_IDS.push('K' + i);
for (let i = 103; i <= 139; i++) ALL_IDS.push('D' + i);
// Layer-4 (L4): P1..P7 gather + D140..D176 craft.
for (let i = 1; i <= 7; i++) ALL_IDS.push('P' + i);
for (let i = 140; i <= 176; i++) ALL_IDS.push('D' + i);
// Layer-5 (L5): S1..S7 gather + D177..D218 craft.
for (let i = 1; i <= 7; i++) ALL_IDS.push('S' + i);
for (let i = 177; i <= 218; i++) ALL_IDS.push('D' + i);
// v1.1.0 GP-2 §2.3: 실패작 D219..D221 (junk outputs of fail_recipes).
for (let i = 219; i <= 221; i++) ALL_IDS.push('D' + i);
// v1.2.0 EX-L1 색/생명 확장: gathers I10..I17 + crafts D222..D254.
for (let i = 10; i <= 17; i++) ALL_IDS.push('I' + i);
for (let i = 222; i <= 254; i++) ALL_IDS.push('D' + i);

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
