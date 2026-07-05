#!/usr/bin/env node
// tools_gen_char_v050b.js — v0.5 phase B character redraw (ROUND hood).
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_char_v050b.js
//
// STANDALONE regenerator for ONLY the character sheet + portrait (288×384 sheet,
// 96×96 frames; 192×192 portrait). Does NOT touch tiles or object art (unlike the
// legacy tools_gen_art.js, which would clobber the CC0 tiles + the v050b objects).
//
// Owner note: "머리만 둥글둥글하게 하면 되겠네" — keep the 방랑자/wanderer concept,
// black cloak + violet trim + staff w/ floating orb; make the hood a soft ROUND
// dome (no angular crown / back-point), slightly LARGER head ratio for charm, and
// smooth the overall cloak silhouette. Same 4-dir × 3-frame layout, 1.25 scene scale.
//
// The drawer + palette are lifted verbatim from tools_gen_art.js (candA production
// wanderer) with three deliberate v050b tweaks: hoodR 7.2 → 8.1 (bigger round head),
// a rounder lower-cowl merge, and a smoother shoulder taper on the cloak.

'use strict';
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = __dirname + '/assets/character/';

// ---- PNG encoder (from tools_gen_art.js) ----
function crc32(buf) { let c = ~0; for (let i = 0; i < buf.length; i++) { c ^= buf[i]; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xEDB88320 & -(c & 1)); } return (~c) >>> 0; }
function chunk(type, data) { const len = Buffer.alloc(4); len.writeUInt32BE(data.length, 0); const body = Buffer.concat([Buffer.from(type, 'ascii'), data]); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(body), 0); return Buffer.concat([len, body, crc]); }
function encodePNG(w, h, pixels) {
  const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const stride = w * 4, raw = Buffer.alloc((stride + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (stride + 1)] = 0; pixels.copy(raw, y * (stride + 1) + 1, y * stride, y * stride + stride); }
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', zlib.deflateSync(raw, { level: 9 })), chunk('IEND', Buffer.alloc(0))]);
}
function makeCanvas(w, h) { return { w, h, data: Buffer.alloc(w * h * 4, 0) }; }
function hexToRGB(hex) { const s = hex.replace('#', ''); return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)]; }
function setPx(cv, x, y, rgb, a = 255) { if (x < 0 || y < 0 || x >= cv.w || y >= cv.h) return; const i = (y * cv.w + x) * 4; cv.data[i] = rgb[0]; cv.data[i + 1] = rgb[1]; cv.data[i + 2] = rgb[2]; cv.data[i + 3] = a; }
function fillRect(cv, x0, y0, x1, y1, rgb, a = 255) { for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) setPx(cv, x, y, rgb, a); }
function mix(a, b, t) { return [Math.round(a[0] * (1 - t) + b[0] * t), Math.round(a[1] * (1 - t) + b[1] * t), Math.round(a[2] * (1 - t) + b[2] * t)]; }
function save(cv, name) { fs.writeFileSync(path.join(OUT, name), encodePNG(cv.w, cv.h, cv.data)); console.log('wrote', name, cv.w + 'x' + cv.h); }

const CHAR_PAL = {
  robe: hexToRGB('#26262e'), robeLit: hexToRGB('#33333d'), robeShade: hexToRGB('#16161c'), robeLine: hexToRGB('#0e0e12'),
  trim: hexToRGB('#9e7ad9'), trimLit: hexToRGB('#d9b8ff'), staff: hexToRGB('#8a6a4a'), staffLine: hexToRGB('#5c4433'),
  hoodDark: hexToRGB('#1b1b22'), orbGlow: hexToRGB('#d9b8ff'), skin: hexToRGB('#e8dfc8'), skinShade: hexToRGB('#ceccaa'),
  skinLine: hexToRGB('#b8b4a8'), silver: hexToRGB('#b8b4a8'), silverLit: hexToRGB('#e8dfc8'), wood: hexToRGB('#8a6a4a'),
  wood2: hexToRGB('#5c4433'), orbMid: hexToRGB('#9e7ad9'),
};
const CH_NW = 36, CH_NH = 48, CH_SCALE = 2, CH_FX0 = 12, CH_FY0 = 0;
function nPx(cv, ox, oy, nx, ny, rgb, a = 255) { if (nx < 0 || ny < 0 || nx >= CH_NW || ny >= CH_NH) return; const px = ox + CH_FX0 + nx * CH_SCALE, py = oy + CH_FY0 + ny * CH_SCALE; fillRect(cv, px, py, px + CH_SCALE, py + CH_SCALE, rgb, a); }

// ---- wanderer drawer (candA) — v050b: bigger round hood + smoother cloak -----
function drawWanderer(cv, ox, oy, dir, phase) {
  const P = CHAR_PAL;
  const front = (dir === 0 || dir === 1);
  const flip = (dir === 1 || dir === 3);
  const put = (nx, ny, rgb, a = 255) => nPx(cv, ox, oy, flip ? (35 - nx) : nx, ny, rgb, a);
  const bob = phase === 2 ? -1 : 0;
  const hemSway = phase === 1 ? 1 : (phase === 2 ? -1 : 0);
  const orbBob = phase === 1 ? 1 : (phase === 2 ? -1 : 0);
  const flare = phase !== 0;

  // ===== cloak body: flowing floor-length A-line, SMOOTHER shoulder taper =====
  for (let y = 14; y < 44; y++) {
    // v050b: gentler quadratic-ish growth so shoulders round into the hem (was linear).
    const t = (y - 14) / 30;
    let half = 3.4 + t * 4.0 + t * t * 1.0;
    if (flare && y >= 40) half += 0.8;
    const sway = (y >= 38) ? hemSway : 0;
    const cxg = 18 + sway;
    const lo = Math.round(cxg - half), hi = Math.round(cxg + half);
    for (let x = lo; x <= hi; x++) {
      let c = P.robe;
      if (x >= hi - 1) c = P.robeLit; else if (x <= lo + 1) c = P.robeShade;
      put(x, y, c);
    }
    if (y >= 20 && y < 42) { put(Math.round(cxg - half * 0.5), y, P.robeShade); put(Math.round(cxg + half * 0.55), y, P.robeLit); }
  }
  { const cxg = 18 + hemSway; for (let x = 12; x <= 24; x++) if (Math.abs(x - cxg) <= 7 && (x * 5) % 3 !== 0) put(x, 44, P.robeLine); }
  for (let y = 15; y <= 43; y++) {
    const t = (y - 14) / 30; let half = 3.4 + t * 4.0 + t * t * 1.0;
    if (flare && y >= 40) half += 0.8;
    const sway = (y >= 38) ? hemSway : 0, cxg = 18 + sway;
    put(Math.round(cxg - half) - 1, y, P.robeLine); put(Math.round(cxg + half) + 1, y, P.robeLine);
  }

  // ===== staff + floating orb =====
  const staffX = 27, orbY = 8 + bob + orbBob;
  for (let y = 12 + bob; y <= 40; y++) { put(staffX, y, P.wood); put(staffX + 1, y, P.wood2); }
  put(staffX, 11 + bob, P.wood2); put(staffX - 1, 12 + bob, P.wood2);
  put(staffX - 1, orbY, P.orbMid); put(staffX, orbY, P.trimLit); put(staffX + 1, orbY, P.orbMid);
  put(staffX - 1, orbY + 1, P.trimLit); put(staffX, orbY + 1, P.orbMid); put(staffX + 1, orbY + 1, P.trim);
  put(staffX, orbY - 1, P.orbGlow, 150); put(staffX + 2, orbY, P.orbGlow, 120); put(staffX - 2, orbY + 1, P.orbGlow, 110);
  put(staffX - 2, orbY - 1, P.trimLit, 130); put(staffX + 3, orbY - 2, P.trimLit, 110);

  // sleeve/arm + hand
  for (let y = 18 + bob; y < 24 + bob; y++) for (let x = 21; x <= 26 - (y > 21 + bob ? 1 : 0); x++) put(x, y, P.robe);
  put(26, 22 + bob, P.skin); put(26, 23 + bob, P.skinShade); put(25, 23 + bob, P.skinLine);

  // ===== hood: BIG ROUND dome (v0.5b: enlarged + rounder) =====
  const hoodCx = 18;
  const hoodCy = 12 + bob;
  const hoodR = 8.1;                    // v050b: 7.2 → 8.1 (larger, charming round head)
  for (let y = Math.floor(hoodCy - hoodR) - 1; y <= Math.ceil(hoodCy + hoodR); y++) {
    const dyr = (y - hoodCy) / hoodR;
    if (dyr > 1.04) continue;
    let half = hoodR * Math.sqrt(Math.max(0, 1 - dyr * dyr));
    // rounder lower-cowl merge into the shoulders (fuller than before).
    if (y > hoodCy) half = Math.max(half, hoodR * (0.68 - dyr * 0.12));
    const lo = Math.round(hoodCx - half), hi = Math.round(hoodCx + half);
    for (let x = lo; x <= hi; x++) {
      let c = P.robe;
      if (x >= hi - 1) c = P.robeLit; else if (x <= lo + 1) c = P.robeShade;
      put(x, y, c);
    }
    put(lo - 1, y, P.robeLine); put(hi + 1, y, P.robeLine);
  }
  // soft curved crown highlight — no hard corner.
  put(hoodCx, Math.round(hoodCy - hoodR), P.robeLit, 150);
  put(hoodCx - 1, Math.round(hoodCy - hoodR) + 1, P.robeLit, 100);
  put(hoodCx + 1, Math.round(hoodCy - hoodR) + 1, P.robeLit, 130);
  put(hoodCx + 2, Math.round(hoodCy - hoodR) + 2, P.robeLit, 90);

  if (front) {
    // face void (scaled to the bigger hood) + violet eyes
    const fcy = hoodCy + 1;
    for (let y = fcy - 2; y <= fcy + 3; y++) for (let x = 14; x <= 22; x++) {
      const dx = (x - 18.5) / 3.8, dy = (y - fcy) / 3.3;
      if (dx * dx + dy * dy <= 1.0) put(x, y, P.hoodDark);
    }
    put(16, fcy, P.trim); put(20, fcy, P.trim);
    put(16, fcy - 1, P.trimLit, 170); put(20, fcy - 1, P.trimLit, 170);
    put(15, fcy + 1, P.trim, 120); put(21, fcy + 1, P.trim, 120);
    // silver clasp + chest sigil
    put(17, 16 + bob, P.silver); put(18, 16 + bob, P.silverLit); put(19, 16 + bob, P.silver); put(18, 17 + bob, P.silverLit);
    put(18, 20 + bob, P.trimLit); put(17, 21 + bob, P.trim); put(19, 21 + bob, P.trim); put(18, 22 + bob, P.trimLit); put(18, 23 + bob, P.trim);
  } else {
    const fcy = hoodCy + 1;
    for (let y = fcy - 2; y <= fcy + 3; y++) for (let x = 14; x <= 22; x++) {
      const dx = (x - 18.5) / 3.8, dy = (y - fcy) / 3.3;
      if (dx * dx + dy * dy <= 1.0) put(x, y, P.robeShade);
    }
    put(18, 24 + bob, P.trim); put(17, 25 + bob, P.trim); put(19, 25 + bob, P.trim); put(18, 26 + bob, P.trimLit);
    for (let y = 17 + bob; y < 40; y += 2) put(18, y, P.robeShade);
  }
  if (phase !== 0) { const dustX = phase === 1 ? 14 : 22; put(dustX, 45, P.skinLine, 90); put(dustX + 1, 45, P.skinLine, 60); }
}

function makeCharSheet() {
  const cols = 3, rows = 4, F = 96;
  const cv = makeCanvas(cols * F, rows * F);
  for (let r = 0; r < rows; r++) { drawWanderer(cv, 0, r * F, r, 0); drawWanderer(cv, F, r * F, r, 1); drawWanderer(cv, 2 * F, r * F, r, 2); }
  save(cv, 'character_sheet.png');
}

// ---- portrait: bigger round hood dome bust ----------------------------------
function makeCharPortrait() {
  const S = 192, cv = makeCanvas(S, S), P = CHAR_PAL;
  const bg = hexToRGB('#22222a'), bgRim = hexToRGB('#3a2a5c'), cx = S / 2;
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) { const d = Math.hypot(x - cx, y - cx) / (S / 2); if (d <= 1.0) setPx(cv, x, y, mix(bg, bgRim, Math.min(1, d * d * 0.9)), 255); }
  const shoulderY = 128, hemY = S - 2;
  for (let y = shoulderY; y <= hemY; y++) {
    const t = (y - shoulderY) / (hemY - shoulderY), half = Math.round(46 + t * 40);
    for (let x = cx - half; x <= cx + half; x++) { let col = P.robe; if (x - cx > half - 10 && y < shoulderY + 40) col = P.robeLit; else if (x - cx < -(half - 10)) col = P.robeShade; setPx(cv, x, y, col, 255); }
    setPx(cv, cx - half - 1, y, P.robeLine, 255); setPx(cv, cx + half + 1, y, P.robeLine, 255);
  }
  // round hood dome — v050b: fuller radius.
  const hoodTop = 16, hoodBot = shoulderY + 10, domeCy = 80, domeR = 72;
  for (let y = hoodTop; y <= hoodBot; y++) {
    let half;
    if (y <= domeCy) { const dyr = (y - domeCy) / domeR; half = Math.round(domeR * Math.sqrt(Math.max(0, 1 - dyr * dyr))); }
    else { const t = (y - domeCy) / (hoodBot - domeCy); half = Math.round(domeR + t * 10); }
    if (half < 4) continue;
    for (let x = cx - half; x <= cx + half; x++) { let col = P.robe; if (x - cx > half - 12) col = P.robeLit; else if (x - cx < -(half - 12)) col = P.robeShade; setPx(cv, x, y, col, 255); }
    setPx(cv, cx - half - 1, y, P.robeLine, 255); setPx(cv, cx + half + 1, y, P.robeLine, 255);
  }
  const faceCx = cx, faceCy = 94;
  for (let y = faceCy - 38; y <= faceCy + 32; y++) for (let x = faceCx - 34; x <= faceCx + 34; x++) { const d = Math.hypot((x - faceCx) / 34, (y - faceCy) / 38); if (d > 1.0) continue; setPx(cv, x, y, mix(hexToRGB('#0d0d12'), P.hoodDark, Math.min(1, d * 1.15)), 255); }
  const eyeY = faceCy;
  for (const ex of [faceCx - 15, faceCx + 15]) {
    for (let y = eyeY - 7; y <= eyeY + 7; y++) for (let x = ex - 7; x <= ex + 7; x++) { const d = Math.hypot(x - ex, y - eyeY) / 7; if (d <= 1.0) setPx(cv, x, y, P.trim, Math.round(110 * (1 - d))); }
    for (let y = eyeY - 3; y <= eyeY + 3; y++) for (let x = ex - 3; x <= ex + 3; x++) if (Math.hypot(x - ex, y - eyeY) <= 3.0) setPx(cv, x, y, P.trimLit, 255);
    setPx(cv, ex + 2, eyeY - 2, hexToRGB('#ffffff'), 220);
  }
  for (let y = shoulderY - 4; y <= shoulderY + 6; y++) for (let x = cx - 8; x <= cx + 8; x++) if (Math.hypot((x - cx) / 8, (y - (shoulderY + 1)) / 5) <= 1.0) setPx(cv, x, y, (x - cx) - (y - shoulderY) > 0 ? P.silverLit : P.silver, 255);
  const sigCy = shoulderY + 34;
  for (let k = -12; k <= 12; k++) { const w = 12 - Math.abs(k); for (let x = cx - w; x <= cx + w; x++) { const edge = (x === cx - w || x === cx + w); setPx(cv, x, sigCy + k, edge ? P.trimLit : P.trim, 255); } }
  const oX = S - 32, oY = 34;
  for (let y = oY - 14; y <= oY + 14; y++) for (let x = oX - 14; x <= oX + 14; x++) { const d = Math.hypot(x - oX, y - oY) / 14; if (d <= 1.0) setPx(cv, x, y, mix(P.trimLit, P.trim, d), Math.round(230 * (1 - d * 0.55))); }
  for (let y = oY - 5; y <= oY + 5; y++) for (let x = oX - 5; x <= oX + 5; x++) if (Math.hypot(x - oX, y - oY) <= 5) setPx(cv, x, y, hexToRGB('#f2eaff'), 255);
  for (let y = oY + 10; y < oY + 46; y++) { setPx(cv, oX, y, P.wood, 255); setPx(cv, oX + 1, y, P.wood2, 255); }
  save(cv, 'character_portrait.png');
}

// ---- review strip: idle frame of each of the 4 dirs, 4× upscale ----
function makeReviewStrip() {
  const F = 96, SC = 4, PAD = 16;
  const sheet = require('pngjs').PNG.sync.read(fs.readFileSync(OUT + 'character_sheet.png'));
  const cols = 4;
  const W = cols * (F * SC + PAD) + PAD, H = F * SC + PAD * 2 + 24;
  const out = new (require('pngjs').PNG)({ width: W, height: H });
  for (let i = 0; i < out.data.length; i += 4) { out.data[i] = 96; out.data[i + 1] = 140; out.data[i + 2] = 72; out.data[i + 3] = 255; } // grass bg
  const dirNames = ['SE', 'SW', 'NE', 'NW'];
  for (let d = 0; d < 4; d++) {
    const sx = 0, sy = d * F;                     // col 0 = idle, row = dir
    const dx0 = PAD + d * (F * SC + PAD), dy0 = PAD;
    for (let y = 0; y < F; y++) for (let x = 0; x < F; x++) {
      const si = ((sy + y) * sheet.width + (sx + x)) << 2; const a = sheet.data[si + 3]; if (!a) continue;
      for (let zy = 0; zy < SC; zy++) for (let zx = 0; zx < SC; zx++) {
        const cx = dx0 + x * SC + zx, cy = dy0 + y * SC + zy; if (cx < 0 || cy < 0 || cx >= W || cy >= H) continue;
        const di = (cy * W + cx) << 2, af = a / 255;
        out.data[di] = sheet.data[si] * af + out.data[di] * (1 - af);
        out.data[di + 1] = sheet.data[si + 1] * af + out.data[di + 1] * (1 - af);
        out.data[di + 2] = sheet.data[si + 2] * af + out.data[di + 2] * (1 - af);
        out.data[di + 3] = 255;
      }
    }
    void dirNames; // labels omitted (no font); order is SE,SW,NE,NW left→right
  }
  fs.writeFileSync('/workspace/group/char-v050b-review.png', require('pngjs').PNG.sync.write(out));
  console.log('wrote /workspace/group/char-v050b-review.png  (' + W + 'x' + H + ')  dirs: SE SW NE NW');
}

console.log('== gen character v050b (round hood) ==');
makeCharSheet();
makeCharPortrait();
makeReviewStrip();
console.log('== done ==');
