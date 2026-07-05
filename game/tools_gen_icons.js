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
icons.D11 = (cv) => { // 석기 stone tool (axe head)
  // handle
  line(cv, 30, 12, 20, 40, C.brownM, 3);
  // grey blade
  for (let y = 12; y < 26; y++) { const hw = 8 - Math.abs(y - 19) * 0.5; for (let x = 24 - hw; x <= 24 + hw; x++) setPx(cv, x, y, x - 24 > 0 ? C.greyL : C.grey); }
  outline(cv, '#3f3f48');
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
// Emit all 58 files. D06 is an alias of I4 → identical bytes to I4 (spec:
// "D06 alias resolves to I4's icon").
// ============================================================================
const ALL_IDS = [];
for (let i = 1; i <= 9; i++) ALL_IDS.push('I' + i);
for (let i = 1; i <= 49; i++) ALL_IDS.push('D' + String(i).padStart(2, '0'));

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
