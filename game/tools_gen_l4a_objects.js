'use strict';
// EX-L4-1 — 부유 서고 (l4a) OBJECT art generator.
// Layer-4 magic-world 「봉인이 풀린 마탑」의 신규 존: FLOATING ARCHIVE (부유 서고).
// Follows the EXACT grammar of tools_gen_l3m_objects.js (shared iso lib: NE-light 3-tone
// shading, ground-contact AO ellipse, iso box/cylinder, selout outline — never pure black),
// but in the L4 mage-tower palette: 자수정 보라(amethyst) base with 금색(gold) + 청백(blue-white)
// rune glow as the ONLY living colour ("금서 청백/금색 룬 발광"). Horizontally centred, the
// ground-contact ellipse near the canvas bottom so the loader plants them on cell centres.
//
// Silhouette variation (QA §㉙): the four repeated gatherables (forbidden_page,
// archive_rune_slab, reading_wax, starpage_ink) each ship 3 baked shape/size variants
// (base + _b + _c) so a field of repeated stamps reads varied even though the loader only
// hash-picks among {base,_b,_c} via art_variants. Other objects are single sprites (+ state
// variants _lit/_clear/_open where the map legend references two states).
//
// Deterministic (fixed seeds → identical reruns). Pure Node.js, no deps.
// Run: cd game && NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l4a_objects.js
const fs = require('fs');
const path = require('path');
const ISO = require('./tools_iso_lib.js');
const {
  C, hex, px, rect, mix, darker, lighter, deterministic,
  ao, glow, isoBox, isoCylinder, isoEllipseTop, topDiamond, diamondOutline, saver,
} = ISO;

const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');
const save = saver(OUT);
const rgb = hex;

// ── palette (L4 부유 서고 = 자수정 보라 base + 금색/청백 룬 발광) ─────────────────
const AME = rgb('#2a1f3d'), P_HI = rgb('#7a5cae'), P_MID = rgb('#4a3670'), P_SH = rgb('#221830');
const GOLD = rgb('#f2c14e'), GOLD_DK = rgb('#c99a34');
const RUNE = rgb('#a8c8ff'), RUNE_HI = rgb('#dbeaff');   // blue-white 룬 청백
const STONE = rgb('#5a4a6a'), DK = rgb('#150e22'), VOID = rgb('#060410');
// 금서 종이(vellum) — torn forbidden-book page tone
const PAGE = rgb('#d8c8a0'), PAGE_HI = rgb('#f0e4c4'), PAGE_SH = rgb('#9a8860');
// 촛농(wax) — hardened reading candle-wax, warm ivory
const WAX = rgb('#e6dcc0'), WAX_HI = rgb('#f6f0dc'), WAX_SH = rgb('#b0a480');

function hcell(ix, iy, salt) { let h = (ix * 374761393) ^ (iy * 668265263) ^ (salt * 2246822519); h = (h ^ (h >>> 13)) >>> 0; h = (h * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; }
function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

// non-pure-black outline pass (selout idiom, per-sprite dark tone).
function selout(cv, ol) {
  const W = cv.w, H = cv.h, src = Buffer.from(cv.data);
  const aAt = (x, y) => (x < 0 || y < 0 || x >= W || y >= H) ? 0 : src[(y * W + x) * 4 + 3];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (aAt(x, y) > 0) continue;
    if (aAt(x - 1, y) > 60 || aAt(x + 1, y) > 60 || aAt(x, y - 1) > 60 || aAt(x, y + 1) > 60)
      px(cv, x, y, ol, 235);
  }
}

// a lumpy amethyst stone blob (value-noise ellipse), NE-lit.
function blob(cv, cx, cy, rx, ry, col, seed, mott = 0.18) {
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++) {
    const d = (x / rx) ** 2 + (y / ry) ** 2;
    if (d > 1.0) continue;
    const lit = (x - y * 0.4) > -rx * 0.2;   // NE-lit face
    let c = lit ? lighter(col, 0.14) : darker(col, 0.16);
    if (hcell(cx + x, cy + y, seed & 255) < mott) c = darker(c, 0.22);
    px(cv, cx + x, cy + y, c, 255);
  }
}

// a faceted crystal / ink shard (tapered upward).
function shard(cv, cx, footY, w, h, seed, col, colL) {
  for (let y = 0; y < h; y++) {
    const t = y / h, half = Math.round((w / 2) * (1 - t));
    for (let x = -half; x <= half; x++) {
      const lit = (x - (h - y) * 0.15) > 0;
      px(cv, cx + x, footY - y, lit ? colL : col, 255);
    }
  }
}

// draw a short golden/blue-white rune glyph line (engraved sheen).
function runeLine(cv, x0, y, len, col, a = 200) { for (let x = 0; x < len; x++) px(cv, x0 + x, y, col, a); }

// ── GATHERABLES (3 baked variants each: base + _b + _c) ──────────────────────

// l4a_forbidden_page — P8. Torn forbidden-book page, half its rune text still glowing.
function forbiddenPage(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 22, 6, 58);
  // a small amethyst rest / crumpled page base
  blob(cv, cx, H - 20, 12, 7, AME, s + 1, 0.24);
  // the torn page leaning up (irregular quad, NE-lit)
  const topY = H - 20 - cfg.h, ww = cfg.w;
  for (let y = 0; y < cfg.h; y++) {
    const t = y / cfg.h;
    const half = Math.round((ww / 2) * (1 - t * cfg.taper));
    const skew = Math.round(cfg.skew * t);
    for (let x = -half; x <= half; x++) {
      const lit = (x + skew) > -half * 0.15;
      let c = lit ? PAGE_HI : (x < -half * 0.4 ? PAGE_SH : PAGE);
      // ragged torn top edge
      if (y < 3 && hcell(cx + x, topY + y, s & 255) < 0.4) continue;
      px(cv, cx + x + skew, topY + y, c, 240);
    }
  }
  // rune text lines — lower half glowing blue-white, upper half dead (torn-off ink).
  const rnd = deterministic(s + 7);
  for (let ly = topY + 6; ly < topY + cfg.h - 3; ly += 5) {
    const len = 4 + Math.floor(rnd() * (ww * 0.5));
    const glowing = ly > topY + cfg.h * 0.5;
    runeLine(cv, cx - Math.round(ww * 0.32) + Math.round(cfg.skew * (ly - topY) / cfg.h), ly,
      len, glowing ? RUNE : GOLD_DK, glowing ? 220 : 150);
  }
  // faint glow behind the living (lower) half
  glow(cv, cx, topY + Math.round(cfg.h * 0.72), cfg.glow, RUNE, 70);
  px(cv, cx, topY + Math.round(cfg.h * 0.72), RUNE_HI, 200);
  selout(cv, P_SH);
  save(cv, name);
}
forbiddenPage('l4a_forbidden_page.png',   { seed: 84010, w: 26, h: 34, taper: 0.2, skew: 4, glow: 12 });
forbiddenPage('l4a_forbidden_page_b.png', { seed: 84011, w: 22, h: 40, taper: 0.35, skew: -5, glow: 14 });
forbiddenPage('l4a_forbidden_page_c.png', { seed: 84012, w: 30, h: 28, taper: 0.12, skew: 7, glow: 16 });

// l4a_archive_rune_slab — P9. A shelf rune-slab, its lock-rune emptied (dim gold groove).
function archiveRuneSlab(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 22, 6, 58);
  // leaning amethyst slab (iso box, short)
  const topY = H - 22 - cfg.h, rx = cfg.rx;
  isoBox(cv, cx, topY, rx, cfg.h, mix(AME, P_HI, 0.28), P_MID, P_SH);
  // the emptied lock-rune (a hollow gold ring groove on the face)
  const rnd = deterministic(s + 3);
  const gy = topY + rx / 2 + Math.round(cfg.h * 0.5);
  for (let a = 0; a < 360; a += 14) {
    const gx = cx + Math.cos(a * Math.PI / 180) * cfg.ring;
    const yy = gy + Math.sin(a * Math.PI / 180) * (cfg.ring * 0.6);
    px(cv, gx, yy, GOLD_DK, 210);
  }
  // a couple faint remnant glyph ticks
  for (let i = 0; i < cfg.ticks; i++) {
    const tx = cx - rx + 4 + Math.floor(rnd() * (rx * 2 - 8));
    const ty = topY + rx / 2 + 4 + Math.floor(rnd() * (cfg.h - 8));
    px(cv, tx, ty, GOLD, 160);
  }
  glow(cv, cx, gy, cfg.glow, GOLD, 45);   // emptied but faintly warm
  selout(cv, P_SH);
  save(cv, name);
}
archiveRuneSlab('l4a_archive_rune_slab.png',   { seed: 84030, rx: 20, h: 26, ring: 9, ticks: 5, glow: 12 });
archiveRuneSlab('l4a_archive_rune_slab_b.png', { seed: 84031, rx: 16, h: 32, ring: 7, ticks: 3, glow: 10 });
archiveRuneSlab('l4a_archive_rune_slab_c.png', { seed: 84032, rx: 24, h: 20, ring: 11, ticks: 6, glow: 14 });

// l4a_reading_wax — P10. A pile of hardened reading candle-wax drips (warm ivory, no glow).
function readingWax(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 22, 7, 60);
  for (const [dx, dy, r] of cfg.lumps) {
    blob(cv, cx + dx, H - 18 + dy, r, Math.round(r * 0.7), WAX, s + 3 + r, 0.14);
    // a soft drip highlight on the NE shoulder
    px(cv, cx + dx + Math.round(r * 0.4), H - 18 + dy - Math.round(r * 0.4), WAX_HI, 210);
  }
  // one leftover wick stub with the faintest gold spark
  const wx = cx + cfg.wick[0], wy = H - 18 + cfg.wick[1];
  px(cv, wx, wy, DK, 230); px(cv, wx, wy - 1, DK, 200);
  px(cv, wx, wy - 2, GOLD, 180); glow(cv, wx, wy - 2, cfg.glow, GOLD, 40);
  selout(cv, WAX_SH);
  save(cv, name);
}
readingWax('l4a_reading_wax.png',   { seed: 84050, lumps: [[0, 0, 15], [-13, 4, 9], [12, 3, 10]], wick: [0, -14], glow: 6 });
readingWax('l4a_reading_wax_b.png', { seed: 84051, lumps: [[0, 2, 12], [-10, 3, 8], [11, 5, 7], [2, -8, 6]], wick: [-4, -12], glow: 5 });
readingWax('l4a_reading_wax_c.png', { seed: 84052, lumps: [[0, -2, 17], [-15, 5, 10], [14, 4, 11]], wick: [3, -16], glow: 7 });

// l4a_starpage_ink — P11. Star-ground ink bottle, faint blue-white glow (starlight ink).
function starpageInk(name, cfg) {
  const W = 96, H = 100, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 18, 6, 56);
  // squat glass bottle body (amethyst-tinted, iso cylinder)
  const topY = H - 20 - cfg.h, rx = cfg.rx;
  isoCylinder(cv, cx, topY, rx, cfg.h, mix(AME, P_HI, 0.22), P_MID, P_SH, 0.86);
  // ink surface — blue-white starlight pool at the neck
  isoEllipseTop(cv, cx, topY, Math.round(rx * 0.7), RUNE, 235, P_SH);
  glow(cv, cx, topY, cfg.glow, RUNE, 90);
  glow(cv, cx, topY, Math.round(cfg.glow * 0.4), RUNE_HI, 130);
  // star flecks suspended in the ink
  const rnd = deterministic(s + 5);
  for (let i = 0; i < cfg.stars; i++) {
    const ang = rnd() * Math.PI * 2, rr = rnd() * rx * 0.6;
    px(cv, cx + Math.cos(ang) * rr, topY + Math.sin(ang) * rr * 0.5, RUNE_HI, 220);
  }
  selout(cv, P_SH);
  save(cv, name);
}
starpageInk('l4a_starpage_ink.png',   { seed: 84070, rx: 13, h: 24, glow: 12, stars: 6 });
starpageInk('l4a_starpage_ink_b.png', { seed: 84071, rx: 11, h: 30, glow: 10, stars: 5 });
starpageInk('l4a_starpage_ink_c.png', { seed: 84072, rx: 15, h: 20, glow: 14, stars: 8 });

// ── UNIQUE / FUNCTIONAL OBJECTS ──────────────────────────────────────────────

// l4a_archive_core (GW4 offering target / P12 unique gather source) — deepest forbidden-archive
//   core column, dim with blue-white flickering runes; l4a_archive_core_lit — post re-sealing,
//   radiant gold. Tall column ~112×148 like l3m_excavator_core.
function archiveCore(name, lit) {
  const W = 112, H = 148, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 10, 30, 9, 66);
  // stepped amethyst plinth
  isoBox(cv, cx, H - 40, 30, 18, mix(AME, P_HI, 0.25), P_MID, P_SH);
  isoBox(cv, cx, H - 58, 22, 14, AME, P_MID, P_SH);
  // the core column (amethyst drum wound with rune bands)
  const topY = H - 118, rx = 16, h = 66;
  isoCylinder(cv, cx, topY, rx, h, mix(AME, P_HI, 0.3), P_MID, P_SH, 0.92);
  // rune winding rings up the column: dim blue-white → radiant gold when lit
  const band = lit ? GOLD : RUNE, bandHi = lit ? rgb('#fff0c0') : RUNE_HI;
  for (let y = 4; y < h; y += 7) {
    const yy = topY + rx / 2 + y;
    for (let x = -rx + 2; x <= rx - 2; x++) px(cv, cx + x, yy, lit ? GOLD : darker(RUNE, 0.25), lit ? 230 : 150);
    px(cv, cx, yy, bandHi, lit ? 210 : 120);
  }
  // crowning glow
  glow(cv, cx, topY, lit ? 44 : 26, band, lit ? 150 : 80);
  glow(cv, cx, topY, lit ? 18 : 10, bandHi, lit ? 200 : 120);
  if (lit) for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2; px(cv, cx + Math.cos(a) * 30, topY + Math.sin(a) * 14, bandHi, 120); }
  selout(cv, P_SH);
  save(cv, name);
}
archiveCore('l4a_archive_core.png', false);
archiveCore('l4a_archive_core_lit.png', true);

// l4a_seal_altar (H / GW4) — offering neck where the 금기 봉인구 mounts;
//   l4a_seal_altar_lit — post-offering radiant state. ~104×116.
function sealAltar(name, lit) {
  const W = 104, H = 116, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 28, 8, 64);
  // heavy amethyst mount base
  isoBox(cv, cx, H - 44, 26, 20, mix(AME, P_HI, 0.25), P_MID, P_SH);
  // cradle arms (two stone uprights)
  for (const sx of [-16, 16]) isoBox(cv, cx + sx, H - 78, 5, 36, STONE, P_MID, P_SH);
  // the cradle cup between the arms (seal socket)
  isoEllipseTop(cv, cx, H - 74, 14, lit ? GOLD : STONE, 255, P_SH);
  glow(cv, cx, H - 74, lit ? 30 : 14, lit ? GOLD : RUNE, lit ? 150 : 60);
  if (lit) { glow(cv, cx, H - 74, 14, rgb('#fff0c0'), 170); px(cv, cx, H - 74, rgb('#fff0c0'), 230); }
  else { px(cv, cx, H - 74, RUNE_HI, 200); }
  selout(cv, P_SH);
  save(cv, name);
}
sealAltar('l4a_seal_altar.png', false);
sealAltar('l4a_seal_altar_lit.png', true);

// l4a_reading_ward (E / GW2) — blurred reading-ward gate, murky base;
//   l4a_reading_ward_clear — clarified after 정화의 물. ~104×120.
//   (map uses mana_spring.tscn scene for E; we swap the sprite.)
function readingWard(name, clear) {
  const W = 104, H = 120, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 30, 8, 64);
  // arch frame (two amethyst posts + lintel)
  isoBox(cv, cx, H - 96, 30, 78, mix(AME, P_HI, 0.2), P_MID, P_SH);
  const inX0 = cx - 22, inX1 = cx + 22, inY0 = H - 90, inY1 = H - 18;
  if (clear) {
    // clarified ward: a crisp blue-white rune curtain
    rect(cv, inX0, inY0, inX1, inY1, mix(AME, RUNE, 0.35), 200);
    const rnd = deterministic(8801);
    for (let ly = inY0 + 4; ly < inY1; ly += 7) runeLine(cv, inX0 + 4, ly, Math.floor(rnd() * 36) + 4, RUNE, 220);
    glow(cv, cx, (inY0 + inY1) / 2, 26, RUNE, 90);
    px(cv, cx, (inY0 + inY1) / 2, RUNE_HI, 230);
  } else {
    // blurred/murky ward: smeared dark violet haze, dim broken glyphs
    for (let y = inY0; y < inY1; y++) for (let x = inX0; x < inX1; x++) {
      const n = hcell(x, y, 12) * 0.5 + 0.5;
      px(cv, x, y, mix(P_SH, AME, n), Math.round(120 + hcell(x, y, 7) * 80));
    }
    const rnd = deterministic(8800);
    for (let i = 0; i < 40; i++) px(cv, inX0 + Math.floor(rnd() * 44), inY0 + Math.floor(rnd() * 72), darker(RUNE, 0.5), 120);
    glow(cv, cx, (inY0 + inY1) / 2, 18, RUNE, 40);
  }
  selout(cv, P_SH);
  save(cv, name);
}
readingWard('l4a_reading_ward.png', false);
readingWard('l4a_reading_ward_clear.png', true);

// l4a_seal_tablet_slot (GW3) — empty sealing-tablet slot pedestal;
//   l4a_seal_tablet_slot_lit — sealed/lit state. ~88×96.
function sealTabletSlot(name, lit) {
  const W = 88, H = 96, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 60);
  // pedestal base
  isoBox(cv, cx, H - 40, 24, 20, mix(AME, P_HI, 0.22), P_MID, P_SH);
  // recessed tablet slot on the top face
  isoEllipseTop(cv, cx, H - 44, 12, lit ? mix(AME, GOLD, 0.4) : darker(P_SH, 0.2), 255, P_SH);
  if (lit) {
    // a seated tablet with a lit gold seal-rune
    isoBox(cv, cx, H - 62, 9, 14, mix(AME, P_HI, 0.35), GOLD_DK, P_SH);
    for (let a = 0; a < 360; a += 30) px(cv, cx + Math.cos(a * Math.PI / 180) * 5, H - 55 + Math.sin(a * Math.PI / 180) * 3, GOLD, 220);
    glow(cv, cx, H - 55, 16, GOLD, 110);
    px(cv, cx, H - 55, rgb('#fff0c0'), 230);
  } else {
    // empty: dark socket + faint rune-blue outline awaiting a tablet
    for (let a = 0; a < 360; a += 24) px(cv, cx + Math.cos(a * Math.PI / 180) * 9, H - 44 + Math.sin(a * Math.PI / 180) * 4.5, darker(RUNE, 0.4), 150);
    glow(cv, cx, H - 44, 10, RUNE, 40);
  }
  selout(cv, P_SH);
  save(cv, name);
}
sealTabletSlot('l4a_seal_tablet_slot.png', false);
sealTabletSlot('l4a_seal_tablet_slot_lit.png', true);

// l4a_mana_residue_ward (W) — residual reading-ward well, mana re-acquire node
//   (idempotent), steady blue-white glow. ~96×108.
function manaResidueWard() {
  const W = 96, H = 108, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 26, 7, 62);
  // well base
  isoBox(cv, cx, H - 40, 24, 20, mix(AME, P_HI, 0.22), P_MID, P_SH);
  // well drum
  isoCylinder(cv, cx, H - 78, 18, 40, mix(AME, P_HI, 0.28), P_MID, P_SH, 0.95);
  // blue-white rune bands + a pooled starlight surface
  for (let y = 6; y < 40; y += 6) { const yy = H - 78 + 9 + y; for (let x = -16; x <= 16; x++) px(cv, cx + x, yy, darker(RUNE, 0.35), 170); px(cv, cx, yy, RUNE, 200); }
  isoEllipseTop(cv, cx, H - 78, 14, RUNE, 235, P_SH);
  glow(cv, cx, H - 76, 22, RUNE, 90);
  glow(cv, cx, H - 76, 9, RUNE_HI, 150);
  selout(cv, P_SH);
  save(cv, 'l4a_mana_residue_ward.png');
}
manaResidueWard();

// l4a_archivist_shade (N) — the remnant NPC: a faint translucent archivist shade still
//   shelving books, one dim rune-light. ~104×128.
function archivistShade() {
  const W = 104, H = 128, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 26, 7, 60);
  // translucent robed figure (drawn dim, low alpha — a shade)
  // lower robe (tapered box)
  for (let y = 0; y < 44; y++) {
    const t = y / 44, half = Math.round(16 * (0.5 + t * 0.5));
    for (let x = -half; x <= half; x++) {
      const lit = x > -half * 0.2;
      px(cv, cx + x, H - 24 - (44 - y), lit ? mix(P_MID, RUNE, 0.25) : P_SH, 150);
    }
  }
  // torso + hood
  isoCylinder(cv, cx, H - 92, 12, 26, mix(P_MID, RUNE, 0.2), P_MID, P_SH, 0.9);
  blob(cv, cx, H - 100, 9, 8, mix(P_SH, RUNE, 0.15), 4343, 0.2);   // hood
  // one arm reaching to a shelf (holding a faint book)
  for (let k = 0; k < 20; k++) { px(cv, cx + 10 + Math.round(k * 0.7), H - 96 + Math.round(k * 0.3), mix(P_MID, RUNE, 0.2), 160); }
  rect(cv, cx + 22, H - 92, cx + 30, H - 82, mix(AME, RUNE, 0.2), 170);   // ghostly book
  // single dim rune-light where a face would be
  glow(cv, cx, H - 100, 8, RUNE, 60);
  px(cv, cx, H - 100, RUNE, 200); px(cv, cx, H - 101, RUNE_HI, 170);
  selout(cv, P_SH);
  save(cv, 'l4a_archivist_shade.png');
}
archivistShade();

// l4a_bindery (C) — the bindery workbench (L4 crafting station), amethyst w/ gold work-lamp. ~112×100.
function bindery() {
  const W = 112, H = 100, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 34, 9, 66);
  // bench top (iso slab)
  isoBox(cv, cx, H - 52, 34, 16, mix(AME, P_HI, 0.28), P_MID, P_SH);
  // legs
  for (const sx of [-28, 28]) rect(cv, cx + sx - 2, H - 40, cx + sx + 2, H - 12, P_SH);
  // a stitched book in the press + laid binding tools
  rect(cv, cx - 22, H - 62, cx - 6, H - 54, PAGE, 235);   // page block
  rect(cv, cx - 22, H - 62, cx - 6, H - 60, PAGE_HI, 220);
  rect(cv, cx - 24, H - 56, cx - 4, H - 54, mix(AME, P_HI, 0.3), 235);   // press bar
  for (let i = 0; i < 5; i++) px(cv, cx + 6 + i * 3, H - 58, STONE, 220);  // awls/needles
  // small gold work-lamp
  glow(cv, cx + 22, H - 62, 12, GOLD, 90);
  px(cv, cx + 22, H - 62, rgb('#fff0c0'), 220);
  selout(cv, P_SH);
  save(cv, 'l4a_bindery.png');
}
bindery();

// l4a_forbidden_log_slab (landmark 3) — the truth-shard slab (forbidden reading-log). ~96×104.
function forbiddenLogSlab() {
  const W = 96, H = 104, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 60);
  // leaning amethyst slab
  const topY = H - 84, rx = 20, h = 72;
  isoBox(cv, cx, topY, rx, h, mix(AME, P_HI, 0.2), P_MID, P_SH);
  // engraved (smudged) lines of a forbidden log — faint blue-white glyphs
  const rnd = deterministic(9101);
  for (let ly = topY + 12; ly < topY + h - 6; ly += 6) {
    const len = 8 + Math.floor(rnd() * (rx * 1.4));
    runeLine(cv, cx - rx + 6, ly, len, darker(RUNE, 0.2), 200);
  }
  glow(cv, cx, topY + 6, 12, RUNE, 60);   // faint activation sheen
  px(cv, cx, topY + 6, RUNE_HI, 190);
  selout(cv, P_SH);
  save(cv, 'l4a_forbidden_log_slab.png');
}
forbiddenLogSlab();

// l4a_drifting_book (landmark 4) — the first drifting forbidden-book: a book half-suspended
//   in the void with one glowing torn page. ~112×96.
function driftingBook() {
  const W = 112, H = 96, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 6, 30, 8, 58);
  // a wisp of void tether beneath (it floats)
  for (let k = 0; k < 18; k++) px(cv, cx, H - 12 - k, darker(RUNE, 0.4), 90 - k * 3);
  const by = H - 46;   // book floats above the ground
  // open book — two amethyst covers angled (iso-ish V)
  for (let side = -1; side <= 1; side += 2) {
    for (let y = 0; y < 22; y++) {
      const t = y / 22, half = Math.round(20 * (1 - t * 0.15));
      for (let x = 0; x <= half; x++) {
        const lit = side > 0;
        px(cv, cx + side * x + side * 2, by + y - Math.round(x * 0.25), lit ? mix(AME, P_HI, 0.35) : P_MID, 240);
      }
    }
  }
  // pages spread (paper) with rune text
  for (let side = -1; side <= 1; side += 2) {
    for (let y = 2; y < 18; y++) {
      const half = Math.round(15 * (1 - y / 22));
      for (let x = 1; x <= half; x++) px(cv, cx + side * x, by + y - Math.round(x * 0.25) + 1, side > 0 ? PAGE_HI : PAGE, 235);
    }
  }
  // one torn page lifting off, glowing blue-white
  const px0 = cx + 14, py0 = by - 8;
  for (let y = 0; y < 16; y++) { const half = Math.round(6 * (1 - y / 16)); for (let x = -half; x <= half; x++) px(cv, px0 + x + Math.round(y * 0.3), py0 - y, PAGE_HI, 235); }
  for (let ly = py0 - 12; ly < py0 - 2; ly += 3) runeLine(cv, px0 - 2, ly, 6, RUNE, 220);
  glow(cv, px0, py0 - 8, 12, RUNE, 90);
  px(cv, px0, py0 - 8, RUNE_HI, 230);
  glow(cv, cx, by + 6, 16, RUNE, 50);   // faint aura in the spine
  selout(cv, P_SH);
  save(cv, 'l4a_drifting_book.png');
}
driftingBook();

// l4a_great_shelf (landmark 5) — the great forbidden-book shelf, puzzle anchor: a tall shelf
//   reaching up with three empty tablet-locks awaiting order. ~112×120.
function greatShelf() {
  const W = 112, H = 120, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 34, 9, 66);
  // tall shelf carcass (iso box, deep)
  const topY = H - 104, rx = 30, h = 92;
  isoBox(cv, cx, topY, rx, h, mix(AME, P_HI, 0.22), P_MID, P_SH);
  // three shelf rows with rows of book spines (varied colours, amethyst family + gold)
  const rnd = deterministic(9201);
  const shelfY = [topY + rx / 2 + 14, topY + rx / 2 + 40, topY + rx / 2 + 66];
  for (const sy of shelfY) {
    rect(cv, cx - rx + 4, sy - 2, cx + rx - 4, sy, P_SH, 220);   // shelf plank
    let bx = cx - rx + 6;
    while (bx < cx + rx - 6) {
      const bw = 3 + Math.floor(rnd() * 3), bh = 16 + Math.floor(rnd() * 6);
      const tone = rnd();
      const col = tone < 0.5 ? mix(AME, P_HI, 0.3 + rnd() * 0.3) : (tone < 0.8 ? P_MID : mix(AME, GOLD, 0.25));
      for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) px(cv, bx + x, sy - 2 - y, x === 0 ? darker(col, 0.2) : col, 240);
      bx += bw + 1;
    }
  }
  // three empty tablet-lock sockets down the right stile, dim blue-white (awaiting order)
  for (let i = 0; i < 3; i++) {
    const ly = topY + rx / 2 + 14 + i * 26, lx = cx + rx - 6;
    for (let a = 0; a < 360; a += 40) px(cv, lx + Math.cos(a * Math.PI / 180) * 4, ly + Math.sin(a * Math.PI / 180) * 4, darker(RUNE, 0.35), 170);
    glow(cv, lx, ly, 6, RUNE, 45);
  }
  selout(cv, P_SH);
  save(cv, 'l4a_great_shelf.png');
}
greatShelf();

console.log('l4a objects: done');
