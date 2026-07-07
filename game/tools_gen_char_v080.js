#!/usr/bin/env node
// tools_gen_char_v080.js — AP-3: 8-direction character sheet (round-hood wanderer).
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_char_v080.js
//
// Extends the approved v050b design (round-hood 방랑자 / black cloak + violet trim +
// staff w/ floating orb) from 4 directions to the full compass:
//
//   rows (top→bottom): S, SE, E, NE, N, NW, W, SW
//   cols (left→right): idle, walk0, walk1
//
// Same 36×48 native grid, ×2 scale, 96×96 frame as v050b — style, resolution and
// palette are byte-for-byte the v050b drawer. The ONLY additions are per-heading
// pose params: torso 3/4 rotation cue (face-void offset + chest sigil visibility)
// and hood-tilt, so diagonals read distinctly, plus true side profiles for E / W.
// Cardinals (S/N) and the four diagonals reuse the exact v050b front/back drawing;
// E / W add a hood-forward profile with a single eye.
//
// STANDALONE: touches ONLY character_sheet.png (+ an 8-dir review strip). Does not
// regenerate the portrait (unchanged) nor any tile / object art.

'use strict';
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = __dirname + '/assets/character/';

// ---- PNG encoder (verbatim from v050b) ----
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

// ---- 8-direction heading table -----------------------------------------------
// view: 'front' (face+sigil), 'back' (seam), 'side' (profile, single eye).
// flip:  mirror the whole frame horizontally (staff swaps to the other hand).
// hoodDx: horizontal hood/face-void shift in native px (3/4 rotation cue).
// staffFront: side view only — bring the staff to the leading edge.
const HEADINGS = [
  { name: 'S',  view: 'front', flip: false, hoodDx: 0 },   // toward camera
  { name: 'SE', view: 'front', flip: false, hoodDx: 1 },   // front-3/4 right  (= v050b dir0)
  { name: 'E',  view: 'side',  flip: false, hoodDx: 2 },   // profile right
  { name: 'NE', view: 'back',  flip: false, hoodDx: 1 },   // back-3/4 right   (= v050b dir2)
  { name: 'N',  view: 'back',  flip: false, hoodDx: 0 },   // away from camera
  { name: 'NW', view: 'back',  flip: true,  hoodDx: 1 },   // back-3/4 left    (mirror of NE)
  { name: 'W',  view: 'side',  flip: true,  hoodDx: 2 },   // profile left
  { name: 'SW', view: 'front', flip: true,  hoodDx: 1 },   // front-3/4 left   (= v050b dir1)
];

// ---- wanderer drawer — v080 8-dir. Body/cloak/staff/hood lifted from v050b. ----
function drawWanderer(cv, ox, oy, head, phase) {
  const P = CHAR_PAL;
  const view = head.view, flip = head.flip, hoodDx = head.hoodDx;
  const put = (nx, ny, rgb, a = 255) => nPx(cv, ox, oy, flip ? (35 - nx) : nx, ny, rgb, a);
  const bob = phase === 2 ? -1 : 0;
  const hemSway = phase === 1 ? 1 : (phase === 2 ? -1 : 0);
  const orbBob = phase === 1 ? 1 : (phase === 2 ? -1 : 0);
  const flare = phase !== 0;

  // ===== cloak body: flowing floor-length A-line (v050b, verbatim) =====
  for (let y = 14; y < 44; y++) {
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

  // ===== staff + floating orb (v050b) — side views bring the staff forward =====
  const staffX = view === 'side' ? 24 : 27, orbY = 8 + bob + orbBob;
  for (let y = 12 + bob; y <= 40; y++) { put(staffX, y, P.wood); put(staffX + 1, y, P.wood2); }
  put(staffX, 11 + bob, P.wood2); put(staffX - 1, 12 + bob, P.wood2);
  put(staffX - 1, orbY, P.orbMid); put(staffX, orbY, P.trimLit); put(staffX + 1, orbY, P.orbMid);
  put(staffX - 1, orbY + 1, P.trimLit); put(staffX, orbY + 1, P.orbMid); put(staffX + 1, orbY + 1, P.trim);
  put(staffX, orbY - 1, P.orbGlow, 150); put(staffX + 2, orbY, P.orbGlow, 120); put(staffX - 2, orbY + 1, P.orbGlow, 110);
  put(staffX - 2, orbY - 1, P.trimLit, 130); put(staffX + 3, orbY - 2, P.trimLit, 110);

  // sleeve/arm + hand (v050b)
  const armX1 = view === 'side' ? 23 : 26;
  for (let y = 18 + bob; y < 24 + bob; y++) for (let x = 21; x <= armX1 - (y > 21 + bob ? 1 : 0); x++) put(x, y, P.robe);
  put(armX1, 22 + bob, P.skin); put(armX1, 23 + bob, P.skinShade); put(armX1 - 1, 23 + bob, P.skinLine);

  // ===== hood: BIG ROUND dome (v050b) — hoodDx tilts it for 3/4 headings =====
  const hoodCx = 18 + (flip ? -hoodDx : hoodDx);
  const hoodCy = 12 + bob;
  const hoodR = 8.1;
  for (let y = Math.floor(hoodCy - hoodR) - 1; y <= Math.ceil(hoodCy + hoodR); y++) {
    const dyr = (y - hoodCy) / hoodR;
    if (dyr > 1.04) continue;
    let half = hoodR * Math.sqrt(Math.max(0, 1 - dyr * dyr));
    if (y > hoodCy) half = Math.max(half, hoodR * (0.68 - dyr * 0.12));
    const lo = Math.round(hoodCx - half), hi = Math.round(hoodCx + half);
    for (let x = lo; x <= hi; x++) {
      let c = P.robe;
      if (x >= hi - 1) c = P.robeLit; else if (x <= lo + 1) c = P.robeShade;
      put(x, y, c);
    }
    put(lo - 1, y, P.robeLine); put(hi + 1, y, P.robeLine);
  }
  // soft curved crown highlight
  put(hoodCx, Math.round(hoodCy - hoodR), P.robeLit, 150);
  put(hoodCx - 1, Math.round(hoodCy - hoodR) + 1, P.robeLit, 100);
  put(hoodCx + 1, Math.round(hoodCy - hoodR) + 1, P.robeLit, 130);
  put(hoodCx + 2, Math.round(hoodCy - hoodR) + 2, P.robeLit, 90);

  const fcx = 18.5 + (flip ? -hoodDx : hoodDx);   // face-void centre tracks the hood tilt
  const fcy = hoodCy + 1;

  if (view === 'front') {
    // face void (v050b) + violet eyes, shifted by the 3/4 hood tilt.
    for (let y = fcy - 2; y <= fcy + 3; y++) for (let x = Math.round(fcx - 4.5); x <= Math.round(fcx + 3.5); x++) {
      const dx = (x - fcx) / 3.8, dy = (y - fcy) / 3.3;
      if (dx * dx + dy * dy <= 1.0) put(x, y, P.hoodDark);
    }
    const eL = Math.round(fcx - 2.5), eR = Math.round(fcx + 1.5);
    put(eL, fcy, P.trim); put(eR, fcy, P.trim);
    put(eL, fcy - 1, P.trimLit, 170); put(eR, fcy - 1, P.trimLit, 170);
    put(eL - 1, fcy + 1, P.trim, 120); put(eR + 1, fcy + 1, P.trim, 120);
    // silver clasp + chest sigil
    put(17, 16 + bob, P.silver); put(18, 16 + bob, P.silverLit); put(19, 16 + bob, P.silver); put(18, 17 + bob, P.silverLit);
    put(18, 20 + bob, P.trimLit); put(17, 21 + bob, P.trim); put(19, 21 + bob, P.trim); put(18, 22 + bob, P.trimLit); put(18, 23 + bob, P.trim);
  } else if (view === 'back') {
    // shadowed hood interior + back seam (v050b), tilted.
    for (let y = fcy - 2; y <= fcy + 3; y++) for (let x = Math.round(fcx - 4.5); x <= Math.round(fcx + 3.5); x++) {
      const dx = (x - fcx) / 3.8, dy = (y - fcy) / 3.3;
      if (dx * dx + dy * dy <= 1.0) put(x, y, P.robeShade);
    }
    put(18, 24 + bob, P.trim); put(17, 25 + bob, P.trim); put(19, 25 + bob, P.trim); put(18, 26 + bob, P.trimLit);
    for (let y = 17 + bob; y < 40; y += 2) put(18, y, P.robeShade);
  } else {
    // ===== SIDE PROFILE: hood cheek forward + a single glinting eye =====
    // A crescent of hood-dark opens toward the leading (right, pre-flip) edge; one eye.
    const px0 = Math.round(fcx - 1);
    for (let y = fcy - 2; y <= fcy + 3; y++) for (let x = px0; x <= Math.round(fcx + 4.5); x++) {
      const dx = (x - (fcx + 1.5)) / 3.4, dy = (y - fcy) / 3.3;
      if (dx * dx + dy * dy <= 1.0) put(x, y, P.hoodDark);
    }
    // brow/cheek shade catch on the lit (right) rim
    put(Math.round(fcx + 4.5), fcy - 1, P.robeLit, 150);
    // single eye near the opening
    const eX = Math.round(fcx + 2);
    put(eX, fcy, P.trim); put(eX, fcy - 1, P.trimLit, 180); put(eX + 1, fcy + 1, P.trim, 120);
    // profile keeps a hint of the chest clasp, no full sigil (torso turned away)
    put(19, 17 + bob, P.silver); put(20, 17 + bob, P.silverLit);
  }

  if (phase !== 0) { const dustX = phase === 1 ? 14 : 22; put(dustX, 45, P.skinLine, 90); put(dustX + 1, 45, P.skinLine, 60); }
}

// ---- 8×3 sheet: rows = S,SE,E,NE,N,NW,W,SW · cols = idle,walk0,walk1 ----------
function makeCharSheet() {
  const cols = 3, rows = 8, F = 96;
  const cv = makeCanvas(cols * F, rows * F);
  for (let r = 0; r < rows; r++) {
    drawWanderer(cv, 0, r * F, HEADINGS[r], 0);
    drawWanderer(cv, F, r * F, HEADINGS[r], 1);
    drawWanderer(cv, 2 * F, r * F, HEADINGS[r], 2);
  }
  save(cv, 'character_sheet.png');
}

// ---- review strip: idle frame of all 8 dirs, 4× upscale, on grass ----
function makeReviewStrip() {
  const F = 96, SC = 3, PAD = 12;
  const sheet = require('pngjs').PNG.sync.read(fs.readFileSync(OUT + 'character_sheet.png'));
  const cols = 8;
  const W = cols * (F * SC + PAD) + PAD, H = F * SC + PAD * 2;
  const out = new (require('pngjs').PNG)({ width: W, height: H });
  for (let i = 0; i < out.data.length; i += 4) { out.data[i] = 96; out.data[i + 1] = 140; out.data[i + 2] = 72; out.data[i + 3] = 255; }
  for (let d = 0; d < 8; d++) {
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
  }
  fs.writeFileSync('/workspace/group/char-v080-review.png', require('pngjs').PNG.sync.write(out));
  console.log('wrote /workspace/group/char-v080-review.png  (' + W + 'x' + H + ')  dirs: S SE E NE N NW W SW');
}

console.log('== gen character v080 (8-direction) ==');
makeCharSheet();
makeReviewStrip();
console.log('== done ==');
