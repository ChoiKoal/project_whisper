'use strict';
// EX-L5 — 침묵의 종탑 (l5b) OBJECT art generator.
// Layer-5 대성당 「침묵의 종탑」의 신규 존: BELFRY (침묵의 종탑).
// Follows the EXACT grammar of tools_gen_l4a_objects.js (shared iso lib: NE-light 3-tone
// shading, ground-contact AO ellipse, iso box/cylinder, selout outline — never pure black),
// but in the L5 belfry palette: 상아/백은(ivory/silver) cool off-white stone base with the
// ONLY living colour = 호박빛 잔불(amber ember glow) on bells + embers ("silence made visible").
// Bronze for bell metal. Horizontally centred, the ground-contact ellipse near the canvas
// bottom so the loader plants them on cell centres.
//
// Silhouette variation (QA §㉙): the four repeated gatherables (bell_shard, belfry_rope,
// resonant_bronze, reverb_dust) each ship 3 baked shape/size variants (base + _b + _c) so a
// field of repeated stamps reads varied even though the loader only hash-picks among
// {base,_b,_c} via art_variants. Other objects are single sprites (+ state variants
// _lit/_clear where the map legend / gate controller references two states).
//
// Deterministic (fixed seeds → identical reruns). Pure Node.js, no deps.
// Run: cd game && NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l5b_objects.js
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

// ── palette (L5 침묵의 종탑 = 상아/백은 stone base + 호박빛 잔불(amber) as the only life) ──
const IVO = rgb('#c9c2b6'), S_HI = rgb('#eae4d8'), S_MID = rgb('#9a938a'), S_SH = rgb('#6a635c');
const AMB = rgb('#f2c14e'), AMB_HI = rgb('#ffdf8a'), AMB_DK = rgb('#c99a34');   // 호박빛 잔불
const BRZ = rgb('#b08a4a'), BRZ_HI = rgb('#d8b06a'), BRZ_DK = rgb('#7c5f30');   // 청동 bell metal
const STONE = rgb('#8a8278'), DK = rgb('#1a1614'), VOID = rgb('#0c0a08');       // 매우 어두운 cool void
// 밧줄(rope) — 종탑 밧줄 hemp tone, desaturated tan-grey (no glow)
const ROPE = rgb('#8f8368'), ROPE_HI = rgb('#b0a382'), ROPE_SH = rgb('#5f5844');
// 잔향 가루(reverb dust) — sound-ash, cool ivory-grey with the faintest amber warmth
const ASH = rgb('#b8b2a6'), ASH_HI = rgb('#d8d2c6'), ASH_SH = rgb('#7c766c');

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

// a lumpy ivory stone blob (value-noise ellipse), NE-lit.
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

// a tapered fragment / shard (upward taper).
function shard(cv, cx, footY, w, h, seed, col, colL) {
  for (let y = 0; y < h; y++) {
    const t = y / h, half = Math.round((w / 2) * (1 - t));
    for (let x = -half; x <= half; x++) {
      const lit = (x - (h - y) * 0.15) > 0;
      px(cv, cx + x, footY - y, lit ? colL : col, 255);
    }
  }
}

// draw a short amber ember line (engraved sheen / rune tick).
function emberLine(cv, x0, y, len, col, a = 200) { for (let x = 0; x < len; x++) px(cv, x0 + x, y, col, a); }

// draw a hanging iso bell (bronze), foot at (cx, footY), width w, height h.
// crown at top, flared skirt at bottom, NE-lit, optional amber ember glow inside the mouth.
function bell(cv, cx, footY, w, h, glowR) {
  const topY = footY - h;
  for (let y = 0; y < h; y++) {
    const t = y / h;
    // profile: narrow crown → flared mouth (skirt widens toward the bottom).
    const prof = 0.30 + 0.70 * Math.pow(t, 1.35);
    const half = Math.max(1, Math.round((w / 2) * prof));
    for (let x = -half; x <= half; x++) {
      const lit = (x - (h - y) * 0.18) > -half * 0.2;   // NE-lit curved face
      let c = lit ? BRZ_HI : (x < -half * 0.45 ? BRZ_DK : BRZ);
      // a bright rim highlight band near the sound-bow (just above the mouth)
      if (t > 0.80 && t < 0.90 && x > 0) c = mix(c, [255, 255, 255], 0.22);
      px(cv, cx + x, topY + y, c, 255);
    }
  }
  // mouth ellipse (dark interior) + amber ember rim
  const mHalf = Math.round((w / 2) * 1.0);
  for (let x = -mHalf; x <= mHalf; x++) {
    const yy = footY - Math.round(Math.sqrt(Math.max(0, 1 - (x / mHalf) ** 2)) * (mHalf * 0.5));
    px(cv, cx + x, yy, darker(BRZ_DK, 0.35), 235);
  }
  // crown loop (canon) on top
  const cy = topY;
  for (let a = 0; a < 360; a += 30) px(cv, cx + Math.cos(a * Math.PI / 180) * Math.max(2, w * 0.10), cy - 3 + Math.sin(a * Math.PI / 180) * 2, BRZ_DK, 220);
  rect(cv, cx - 1, cy - 5, cx + 2, cy, BRZ, 235);
  // amber ember glow from inside the mouth (the only life)
  if (glowR > 0) {
    glow(cv, cx, footY - Math.round(h * 0.12), glowR, AMB, 90);
    glow(cv, cx, footY - Math.round(h * 0.12), Math.round(glowR * 0.45), AMB_HI, 140);
    px(cv, cx, footY - Math.round(h * 0.12), AMB_HI, 220);
  }
}

// ── GATHERABLES (3 baked variants each: base + _b + _c) ──────────────────────

// l5b_bell_shard — S8. A broken bell fragment (curved bronze sherd), small amber glimmer.
function bellShard(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 22, 6, 58);
  // an ivory rest / rubble base
  blob(cv, cx, H - 20, 12, 7, IVO, s + 1, 0.24);
  // the curved bronze sherd leaning up (an arc slice, NE-lit)
  const topY = H - 20 - cfg.h, ww = cfg.w;
  for (let y = 0; y < cfg.h; y++) {
    const t = y / cfg.h;
    // an arc-shaped fragment: outer curve, hollow inner (bell-wall slice)
    const half = Math.round((ww / 2) * (0.5 + 0.5 * Math.sin(t * Math.PI * 0.9)));
    const skew = Math.round(cfg.skew * t);
    for (let x = -half; x <= half; x++) {
      // hollow the inner face to read as a broken wall segment
      if (x > -half + cfg.wall && x < half - cfg.wall && t > 0.15) continue;
      const lit = (x + skew) > -half * 0.15;
      let c = lit ? BRZ_HI : (x < -half * 0.4 ? BRZ_DK : BRZ);
      if (y < 3 && hcell(cx + x, topY + y, s & 255) < 0.4) continue;   // ragged top
      px(cv, cx + x + skew, topY + y, c, 245);
    }
  }
  // a faint amber glimmer clinging to the sound-metal
  glow(cv, cx + cfg.gx, topY + Math.round(cfg.h * 0.6), cfg.glow, AMB, 60);
  px(cv, cx + cfg.gx, topY + Math.round(cfg.h * 0.6), AMB_HI, 190);
  selout(cv, S_SH);
  save(cv, name);
}
bellShard('l5b_bell_shard.png',   { seed: 85010, w: 30, h: 30, wall: 4, skew: 4, gx: 4, glow: 10 });
bellShard('l5b_bell_shard_b.png', { seed: 85011, w: 24, h: 38, wall: 3, skew: -5, gx: -3, glow: 12 });
bellShard('l5b_bell_shard_c.png', { seed: 85012, w: 34, h: 24, wall: 5, skew: 7, gx: 6, glow: 14 });

// l5b_belfry_rope — S9. A coiled belfry rope (desaturated hemp, NO glow).
function belfryRope(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 24, 7, 60);
  const baseY = H - 18;
  // stacked coils (concentric ellipses, decreasing radius upward)
  for (let i = 0; i < cfg.coils; i++) {
    const cyy = baseY - i * cfg.stack;
    const rx = cfg.rx - i * cfg.shrink;
    if (rx < 4) break;
    const ry = Math.max(3, Math.round(rx * 0.42));
    for (let a = 0; a < 360; a += 4) {
      const rad = a * Math.PI / 180;
      const x = Math.cos(rad) * rx, y = Math.sin(rad) * ry;
      // NE-lit strand + a shadow underside
      const lit = (x - y) > 0;
      const front = y > -ry * 0.2;
      const c = front ? (lit ? ROPE_HI : ROPE) : ROPE_SH;
      px(cv, cx + x, cyy + y, c, front ? 255 : 200);
      // twist ticks along the strand for a braided look
      if (Math.round(a) % 24 < 3) px(cv, cx + x, cyy + y, ROPE_SH, 200);
    }
  }
  // a loose tail flopping off the coil
  let tx = cx + cfg.tail[0], ty = baseY + cfg.tail[1];
  for (let k = 0; k < cfg.tailLen; k++) {
    tx += Math.cos(k * 0.4) * 1.1; ty -= 0.5;
    px(cv, tx, ty, k % 5 < 2 ? ROPE_SH : ROPE, 240);
    px(cv, tx + 1, ty, ROPE_HI, 200);
  }
  selout(cv, ROPE_SH);
  save(cv, name);
}
belfryRope('l5b_belfry_rope.png',   { seed: 85030, rx: 20, ry: 8, coils: 4, stack: 5, shrink: 3, tail: [16, -2], tailLen: 20 });
belfryRope('l5b_belfry_rope_b.png', { seed: 85031, rx: 16, ry: 7, coils: 5, stack: 4, shrink: 2, tail: [-14, 0], tailLen: 16 });
belfryRope('l5b_belfry_rope_c.png', { seed: 85032, rx: 23, ry: 9, coils: 3, stack: 6, shrink: 4, tail: [18, -4], tailLen: 24 });

// l5b_resonant_bronze — S10. A resonant bronze ingot/chunk (warm bronze, faint amber).
function resonantBronze(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 22, 7, 60);
  // a squat iso ingot (bronze box) resting on the ground
  const topY = H - 20 - cfg.h, rx = cfg.rx;
  isoBox(cv, cx, topY, rx, cfg.h, mix(BRZ, BRZ_HI, 0.3), BRZ, BRZ_DK);
  // a couple of chipped chunks beside it
  for (const [dx, dy, r] of cfg.chunks) {
    blob(cv, cx + dx, H - 18 + dy, r, Math.round(r * 0.7), BRZ, s + 3 + r, 0.16);
    px(cv, cx + dx + Math.round(r * 0.4), H - 18 + dy - Math.round(r * 0.4), BRZ_HI, 210);
  }
  // faint amber warmth along the lit top edge (resonant metal)
  const rnd = deterministic(s + 5);
  for (let i = 0; i < cfg.sparks; i++) {
    const sx = cx - rx + 3 + Math.floor(rnd() * (rx * 2 - 6));
    px(cv, sx, topY + rx / 2 - 1, AMB, 150);
  }
  glow(cv, cx + cfg.gx, topY + Math.round(rx / 2), cfg.glow, AMB, 45);
  px(cv, cx + cfg.gx, topY + Math.round(rx / 2), AMB_HI, 170);
  selout(cv, BRZ_DK);
  save(cv, name);
}
resonantBronze('l5b_resonant_bronze.png',   { seed: 85050, rx: 18, h: 14, chunks: [[-15, 5, 7], [15, 4, 6]], sparks: 5, gx: 3, glow: 9 });
resonantBronze('l5b_resonant_bronze_b.png', { seed: 85051, rx: 14, h: 18, chunks: [[-13, 4, 6], [13, 6, 5], [2, -6, 5]], sparks: 4, gx: -2, glow: 8 });
resonantBronze('l5b_resonant_bronze_c.png', { seed: 85052, rx: 22, h: 11, chunks: [[-17, 5, 8], [16, 4, 7]], sparks: 6, gx: 5, glow: 11 });

// l5b_reverb_dust — S11. A small pile/mote of sound-ash dust (cool ivory-grey, faint amber).
function reverbDust(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 22, 7, 58);
  for (const [dx, dy, r] of cfg.lumps) {
    blob(cv, cx + dx, H - 18 + dy, r, Math.round(r * 0.6), ASH, s + 3 + r, 0.16);
    px(cv, cx + dx + Math.round(r * 0.4), H - 18 + dy - Math.round(r * 0.4), ASH_HI, 210);
  }
  // suspended motes drifting up (sound settling into ash), faint amber sparks
  const rnd = deterministic(s + 5);
  for (let i = 0; i < cfg.motes; i++) {
    const mx = cx + (rnd() - 0.5) * cfg.spread;
    const my = H - 22 - rnd() * cfg.rise;
    px(cv, mx, my, rnd() < 0.4 ? AMB : ASH_HI, Math.round(140 + rnd() * 90));
  }
  glow(cv, cx + cfg.gx, H - 22, cfg.glow, AMB, 38);
  px(cv, cx + cfg.gx, H - 23, AMB_HI, 160);
  selout(cv, ASH_SH);
  save(cv, name);
}
reverbDust('l5b_reverb_dust.png',   { seed: 85070, lumps: [[0, 0, 14], [-12, 4, 8], [11, 3, 9]], motes: 7, spread: 34, rise: 20, gx: 0, glow: 7 });
reverbDust('l5b_reverb_dust_b.png', { seed: 85071, lumps: [[0, 2, 11], [-10, 3, 7], [10, 5, 6], [2, -7, 5]], motes: 6, spread: 28, rise: 24, gx: -3, glow: 6 });
reverbDust('l5b_reverb_dust_c.png', { seed: 85072, lumps: [[0, -2, 16], [-14, 5, 9], [13, 4, 10]], motes: 9, spread: 40, rise: 18, gx: 3, glow: 8 });

// ── UNIQUE / FUNCTIONAL OBJECTS ──────────────────────────────────────────────

// l5b_great_bell (GB4 target / S12 unique gather source) — the great hanging bronze bell at the
//   belfry apex, dim; l5b_great_bell_lit — post re-tolling, radiant amber. Tall ~112×148 like
//   l4a_archive_core.
function greatBell(name, lit) {
  const W = 112, H = 148, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 10, 34, 10, 66);
  // stepped ivory plinth the bell frame stands on
  isoBox(cv, cx, H - 40, 32, 18, mix(IVO, S_HI, 0.25), S_MID, S_SH);
  isoBox(cv, cx, H - 58, 24, 14, IVO, S_MID, S_SH);
  // the timber/stone headstock beam the bell hangs from
  rect(cv, cx - 34, H - 128, cx + 34, H - 120, mix(IVO, S_MID, 0.4), 240);
  for (const sx of [-30, 30]) rect(cv, cx + sx - 3, H - 128, cx + sx + 3, H - 66, S_MID, 235);
  // the great bell hanging from the beam
  const glowR = lit ? 46 : 20;
  bell(cv, cx, H - 62, 58, 60, glowR);
  // clapper hint + big amber ember from the mouth
  if (lit) {
    glow(cv, cx, H - 74, 52, AMB, 130);
    glow(cv, cx, H - 74, 24, AMB_HI, 180);
    for (let i = 0; i < 44; i++) { const a = i / 44 * Math.PI * 2; px(cv, cx + Math.cos(a) * 40, H - 84 + Math.sin(a) * 20, AMB_HI, 130); }
    px(cv, cx, H - 74, rgb('#fff6d8'), 235);
  } else {
    glow(cv, cx, H - 74, 22, AMB, 60);
    px(cv, cx, H - 74, AMB, 190);
  }
  selout(cv, S_SH);
  save(cv, name);
}
greatBell('l5b_great_bell.png', false);
greatBell('l5b_great_bell_lit.png', true);

// l5b_bell_altar (H / GB4) — 응답의 타종구 봉헌 목 where the offering mounts;
//   l5b_bell_altar_lit — post-offering radiant amber/gold state. ~104×116.
function bellAltar(name, lit) {
  const W = 104, H = 116, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 28, 8, 64);
  // heavy ivory mount base
  isoBox(cv, cx, H - 44, 26, 20, mix(IVO, S_HI, 0.25), S_MID, S_SH);
  // cradle arms (two stone uprights)
  for (const sx of [-16, 16]) isoBox(cv, cx + sx, H - 78, 5, 36, STONE, S_MID, S_SH);
  // a small bronze striking-bell seated in the cradle (the 타종구)
  bell(cv, cx, H - 66, 20, 22, lit ? 18 : 0);
  // the cradle cup / mounting socket glow
  glow(cv, cx, H - 66, lit ? 30 : 12, lit ? AMB : STONE === STONE ? AMB : AMB, lit ? 150 : 45);
  if (lit) {
    glow(cv, cx, H - 66, 16, AMB_HI, 170);
    for (let a = 0; a < 360; a += 24) px(cv, cx + Math.cos(a * Math.PI / 180) * 12, H - 88 + Math.sin(a * Math.PI / 180) * 6, AMB, 150);
    px(cv, cx, H - 66, rgb('#fff6d8'), 230);
  } else {
    px(cv, cx, H - 66, AMB_DK, 170);
  }
  selout(cv, S_SH);
  save(cv, name);
}
bellAltar('l5b_bell_altar.png', false);
bellAltar('l5b_bell_altar_lit.png', true);

// l5b_chime_ward (E / GB2) — 흐려진 종음 결계 본체, a resonance-ward standing stone/gong,
//   murky; l5b_chime_ward_clear — clarified/purified after 정음의 물. ~104×120.
//   (GB2 use target — we swap the sprite between the two states.)
function chimeWard(name, clear) {
  const W = 104, H = 120, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 30, 8, 64);
  // a standing gong frame: ivory posts + lintel
  isoBox(cv, cx, H - 96, 30, 78, mix(IVO, S_HI, 0.2), S_MID, S_SH);
  // the hung resonance disc (gong) within the frame
  const gcx = cx, gcy = H - 58, gr = 26;
  for (let y = -gr; y <= gr; y++) for (let x = -gr; x <= gr; x++) {
    if (x * x + y * y > gr * gr) continue;
    const lit = (x - y) > -gr * 0.2;
    let base = clear ? BRZ : mix(BRZ_DK, S_SH, 0.4);
    let c = lit ? lighter(base, 0.16) : darker(base, 0.14);
    px(cv, gcx + x, gcy + y, c, 245);
  }
  // central boss
  for (let a = 0; a < 360; a += 8) px(cv, gcx + Math.cos(a * Math.PI / 180) * 6, gcy + Math.sin(a * Math.PI / 180) * 6, clear ? BRZ_HI : BRZ_DK, 220);
  if (clear) {
    // clarified ward: crisp concentric amber resonance rings ringing outward
    for (const rr of [10, 15, 20, 25]) for (let a = 0; a < 360; a += 6) px(cv, gcx + Math.cos(a * Math.PI / 180) * rr, gcy + Math.sin(a * Math.PI / 180) * rr, AMB, 160);
    glow(cv, gcx, gcy, 30, AMB, 100);
    glow(cv, gcx, gcy, 12, AMB_HI, 160);
    px(cv, gcx, gcy, rgb('#fff6d8'), 230);
  } else {
    // blurred/murky ward: a smeared cool haze veils the disc, dim broken tone
    for (let y = -gr; y <= gr; y++) for (let x = -gr; x <= gr; x++) {
      if (x * x + y * y > gr * gr) continue;
      const n = hcell(gcx + x, gcy + y, 12) * 0.5 + 0.5;
      px(cv, gcx + x, gcy + y, mix(S_SH, IVO, n), Math.round(90 + hcell(gcx + x, gcy + y, 7) * 70));
    }
    glow(cv, gcx, gcy, 16, AMB, 34);
  }
  selout(cv, S_SH);
  save(cv, name);
}
chimeWard('l5b_chime_ward.png', false);
chimeWard('l5b_chime_ward_clear.png', true);

// l5b_chime_bell_slot (GB3 y slots) — empty 타종 종 슬롯 pedestal;
//   l5b_chime_bell_slot_lit — a chime-bell seated & rung state. ~88×96.
function chimeBellSlot(name, lit) {
  const W = 88, H = 96, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 60);
  // pedestal base
  isoBox(cv, cx, H - 40, 24, 20, mix(IVO, S_HI, 0.22), S_MID, S_SH);
  // recessed slot on the top face
  isoEllipseTop(cv, cx, H - 44, 12, lit ? mix(IVO, AMB, 0.4) : darker(S_SH, 0.2), 255, S_SH);
  if (lit) {
    // a seated bronze chime-bell, rung, amber ember from the mouth
    bell(cv, cx, H - 46, 16, 18, 14);
    for (let a = 0; a < 360; a += 30) px(cv, cx + Math.cos(a * Math.PI / 180) * 9, H - 64 + Math.sin(a * Math.PI / 180) * 5, AMB, 200);
    glow(cv, cx, H - 55, 16, AMB, 110);
    px(cv, cx, H - 55, rgb('#fff6d8'), 230);
  } else {
    // empty: dark socket + faint amber outline awaiting a bell
    for (let a = 0; a < 360; a += 24) px(cv, cx + Math.cos(a * Math.PI / 180) * 9, H - 44 + Math.sin(a * Math.PI / 180) * 4.5, AMB_DK, 150);
    glow(cv, cx, H - 44, 10, AMB, 36);
  }
  selout(cv, S_SH);
  save(cv, name);
}
chimeBellSlot('l5b_chime_bell_slot.png', false);
chimeBellSlot('l5b_chime_bell_slot_lit.png', true);

// l5b_reverb_font (F) — 잔향 성수반, life-whisper re-acquire node (idempotent), steady amber
//   shimmer basin. ~96×108.
function reverbFont() {
  const W = 96, H = 108, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 26, 7, 62);
  // font base
  isoBox(cv, cx, H - 40, 24, 20, mix(IVO, S_HI, 0.22), S_MID, S_SH);
  // font drum (a basin pedestal, belly-tapered)
  isoCylinder(cv, cx, H - 78, 18, 40, mix(IVO, S_HI, 0.28), S_MID, S_SH, 0.9);
  // ribbed stone bands up the drum
  for (let y = 6; y < 40; y += 8) { const yy = H - 78 + 9 + y; for (let x = -16; x <= 16; x++) px(cv, cx + x, yy, darker(S_MID, 0.2), 150); }
  // the basin water surface — amber-shimmering pool
  isoEllipseTop(cv, cx, H - 78, 15, mix(IVO, AMB, 0.5), 235, S_SH);
  glow(cv, cx, H - 76, 22, AMB, 90);
  glow(cv, cx, H - 76, 9, AMB_HI, 150);
  // a few shimmer sparks rising off the surface
  const rnd = deterministic(85200);
  for (let i = 0; i < 7; i++) { const ang = rnd() * Math.PI * 2, rr = rnd() * 12; px(cv, cx + Math.cos(ang) * rr, H - 78 + Math.sin(ang) * rr * 0.5 - rnd() * 6, AMB_HI, 210); }
  selout(cv, S_SH);
  save(cv, 'l5b_reverb_font.png');
}
reverbFont();

// l5b_bellkeeper_shade (N) — 종지기의 그림자: a faint standing figure holding a bell-rope,
//   one dim amber light. ~104×128.
function bellkeeperShade() {
  const W = 104, H = 128, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 26, 7, 60);
  // translucent robed figure (drawn dim, low alpha — a shade)
  // lower robe (tapered box)
  for (let y = 0; y < 44; y++) {
    const t = y / 44, half = Math.round(16 * (0.5 + t * 0.5));
    for (let x = -half; x <= half; x++) {
      const lit = x > -half * 0.2;
      px(cv, cx + x, H - 24 - (44 - y), lit ? mix(S_MID, AMB, 0.18) : S_SH, 150);
    }
  }
  // torso + hood
  isoCylinder(cv, cx, H - 92, 12, 26, mix(S_MID, AMB, 0.14), S_MID, S_SH, 0.9);
  blob(cv, cx, H - 100, 9, 8, mix(S_SH, AMB, 0.12), 4343, 0.2);   // hood
  // one arm gripping a bell-rope descending from above
  for (let k = 0; k < 20; k++) px(cv, cx + 10 + Math.round(k * 0.6), H - 96 + Math.round(k * 0.35), mix(S_MID, AMB, 0.15), 160);
  // the bell-rope the keeper holds (a vertical hemp line up into the void)
  for (let k = 0; k < 60; k++) px(cv, cx + 22 - Math.round(k * 0.02), H - 80 - k, k % 5 < 2 ? ROPE_SH : ROPE, 190 - k);
  // a small hung bell at the rope-top, faint amber
  bell(cv, cx + 21, H - 138 + 10, 12, 12, 6);
  // one dim amber light where a face would be
  glow(cv, cx, H - 100, 8, AMB, 55);
  px(cv, cx, H - 100, AMB, 190); px(cv, cx, H - 101, AMB_HI, 160);
  selout(cv, S_SH);
  save(cv, 'l5b_bellkeeper_shade.png');
}
bellkeeperShade();

// l5b_bell_forge (C) — 정비대/주종대: a bell-casting anvil/forge (L5 crafting station),
//   ivory stone w/ amber ember glow. ~112×100.
function bellForge() {
  const W = 112, H = 100, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 34, 9, 66);
  // the forge hearth base (heavy ivory block)
  isoBox(cv, cx, H - 52, 34, 16, mix(IVO, S_HI, 0.28), S_MID, S_SH);
  // legs
  for (const sx of [-28, 28]) rect(cv, cx + sx - 2, H - 40, cx + sx + 2, H - 12, S_SH);
  // a bronze bell-casting anvil / horn on the left
  isoBox(cv, cx - 18, H - 66, 10, 14, mix(BRZ, BRZ_HI, 0.3), BRZ, BRZ_DK);
  for (let k = 0; k < 12; k++) px(cv, cx - 30 - k, H - 62 + Math.round(k * 0.2), k % 2 ? BRZ : BRZ_HI, 235);   // horn taper
  // a half-cast bell in the mould on the bench
  bell(cv, cx + 6, H - 54, 18, 18, 0);
  // the forge ember — the living amber glow (casting fire)
  glow(cv, cx + 22, H - 58, 14, AMB, 110);
  glow(cv, cx + 22, H - 58, 6, AMB_HI, 160);
  px(cv, cx + 22, H - 58, rgb('#fff6d8'), 225);
  // a couple of ember sparks lifting off
  const rnd = deterministic(85300);
  for (let i = 0; i < 6; i++) px(cv, cx + 18 + Math.floor(rnd() * 10), H - 62 - Math.floor(rnd() * 12), AMB, 190);
  selout(cv, S_SH);
  save(cv, 'l5b_bell_forge.png');
}
bellForge();

// l5b_gods_last_record_slab (landmark 3) — 신의 마지막 기록 석판, the truth-shard: an inscribed
//   ivory stone slab, faint amber glyph sheen. ~96×104.
function godsLastRecordSlab() {
  const W = 96, H = 104, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 60);
  // leaning ivory slab
  const topY = H - 84, rx = 20, h = 72;
  isoBox(cv, cx, topY, rx, h, mix(IVO, S_HI, 0.2), S_MID, S_SH);
  // engraved lines of the last divine record — faint amber glyphs
  const rnd = deterministic(85101);
  for (let ly = topY + 12; ly < topY + h - 6; ly += 6) {
    const len = 8 + Math.floor(rnd() * (rx * 1.4));
    emberLine(cv, cx - rx + 6, ly, len, AMB_DK, 200);
  }
  glow(cv, cx, topY + 6, 12, AMB, 60);   // faint activation sheen at the crown
  px(cv, cx, topY + 6, AMB_HI, 190);
  selout(cv, S_SH);
  save(cv, 'l5b_gods_last_record_slab.png');
}
godsLastRecordSlab();

// l5b_tutorial_hung_bell (landmark 4) — 첫 걸린 종: a small bronze bell half-hung in the void
//   on a stub of rope, one glowing amber ember. ~112×96.
function tutorialHungBell() {
  const W = 112, H = 96, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 6, 26, 7, 56);
  // a wisp of void tether beneath (it hangs over the drop)
  for (let k = 0; k < 18; k++) px(cv, cx, H - 12 - k, darker(AMB, 0.5), 80 - k * 3);
  // a short rope stub descending from the top into the bell crown
  for (let k = 0; k < 26; k++) px(cv, cx + Math.round(Math.sin(k * 0.3) * 1.5), 8 + k, k % 5 < 2 ? ROPE_SH : ROPE, 220);
  // the small hung bell (floats mid-canvas)
  bell(cv, cx, H - 40, 30, 34, 14);
  // aura from the mouth
  glow(cv, cx, H - 48, 16, AMB, 90);
  px(cv, cx, H - 48, AMB_HI, 225);
  selout(cv, S_SH);
  save(cv, 'l5b_tutorial_hung_bell.png');
}
tutorialHungBell();

// l5b_three_chime_bells (landmark 5) — 세 울림 종: three bells hung in a row, the chime-order
//   puzzle anchor. ~112×120.
function threeChimeBells() {
  const W = 112, H = 120, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 40, 9, 66);
  // a long headstock beam the three bells hang from
  rect(cv, cx - 44, H - 96, cx + 44, H - 88, mix(IVO, S_MID, 0.4), 240);
  for (const sx of [-40, 40]) rect(cv, cx + sx - 3, H - 96, cx + sx + 3, H - 14, S_MID, 235);
  // three bells of graduated size, only one dimly ember-lit (awaiting order)
  const bells = [
    { dx: -30, w: 22, h: 26, glow: 0 },
    { dx: 0, w: 28, h: 32, glow: 12 },
    { dx: 30, w: 20, h: 24, glow: 0 },
  ];
  for (const b of bells) {
    // hanger drop from the beam
    rect(cv, cx + b.dx - 1, H - 88, cx + b.dx + 2, H - 88 + (H - 40 - (H - 88)), S_MID, 220);
    bell(cv, cx + b.dx, H - 30, b.w, b.h, b.glow);
  }
  // three empty chime-order sockets along the beam, dim amber (awaiting order)
  for (let i = 0; i < 3; i++) {
    const lx = cx - 30 + i * 30, ly = H - 92;
    for (let a = 0; a < 360; a += 40) px(cv, lx + Math.cos(a * Math.PI / 180) * 4, ly + Math.sin(a * Math.PI / 180) * 3, AMB_DK, 170);
    glow(cv, lx, ly, 6, AMB, 40);
  }
  selout(cv, S_SH);
  save(cv, 'l5b_three_chime_bells.png');
}
threeChimeBells();

// l5b_great_bell_silhouette (landmark 2) — 큰 종 실루엣: the distant great bell seen as a
//   near-flat cool silhouette against the void (a landmark seen from afar). ~112×140.
function greatBellSilhouette() {
  const W = 112, H = 140, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 10, 30, 8, 48);
  // a faint headstock beam silhouette
  rect(cv, cx - 30, H - 118, cx + 30, H - 112, darker(S_SH, 0.2), 200);
  for (const sx of [-26, 26]) rect(cv, cx + sx - 2, H - 118, cx + sx + 2, H - 60, darker(S_SH, 0.25), 190);
  // the bell rendered as a flat cool silhouette (little internal shading — it is distant)
  const footY = H - 56, w = 54, h = 56, topY = footY - h;
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const prof = 0.30 + 0.70 * Math.pow(t, 1.35);
    const half = Math.max(1, Math.round((w / 2) * prof));
    for (let x = -half; x <= half; x++) {
      // subtle NE rim catch of cool moonlight, otherwise dark silhouette
      const rim = (x - (h - y) * 0.18) > half * 0.55;
      px(cv, cx + x, topY + y, rim ? mix(S_SH, S_HI, 0.35) : darker(S_SH, 0.35), 220);
    }
  }
  // crown loop silhouette
  rect(cv, cx - 2, topY - 6, cx + 3, topY, darker(S_SH, 0.3), 220);
  // a single faint amber ember gleaming in the far mouth (the only life, distant & dim)
  glow(cv, cx, footY - 8, 12, AMB, 55);
  px(cv, cx, footY - 8, AMB, 170);
  selout(cv, VOID);
  save(cv, 'l5b_great_bell_silhouette.png');
}
greatBellSilhouette();

// ── FIELD RUIN DECOR (QA §㉙ 실루엣 변주) ─────────────────────────────────────
// The 종의 들판 (bell fields) read as an over-repeated grid of the same gatherable stamps.
// These 5 non-gatherable decoratives break the silhouette so the field reads as a
// '침묵한 종들의 무덤'(graveyard of silenced bells) — 폐허의 리듬, not random scatter.
// All DEAD/silent (no living amber glow, or only a faint dead ember on the tilted bell) so
// they contrast the living amber of the gatherables/great bell. 3 baked shape/size variants
// each (base + _b + _c) → the loader hash-picks via art_variants so a field of stamps varies.

// l5b_broken_plinth — 깨진 받침: a cracked/toppled ivory bell-plinth, its bell long gone. A
//   snapped stump of a pedestal, a fracture line, chips at the foot. No glow (dead).
function brokenPlinth(name, cfg) {
  const W = 88, H = 92, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 24, 7, 60);
  // the snapped pedestal stump (a short iso box, sheared off at an angle)
  const topY = H - 26 - cfg.h, rx = cfg.rx;
  isoBox(cv, cx, topY, rx, cfg.h, mix(IVO, S_HI, 0.18), S_MID, S_SH);
  // sheared/jagged top edge — eat into the crown so it reads as broken, not built
  const rnd = deterministic(s + 1);
  for (let x = -rx; x <= rx; x++) {
    const bite = Math.floor(rnd() * cfg.jag);
    for (let k = 0; k < bite; k++) px(cv, cx + x, topY + Math.round(Math.abs(x) * 0.5) + k, VOID, 0);   // clear (ragged)
  }
  // a dark fracture running down the shaft
  let fx = cx + cfg.crackX;
  for (let y = topY + cfg.h * 0.3; y < H - 24; y += 1) { fx += (rnd() - 0.5) * 1.2; px(cv, fx, y, S_SH, 220); px(cv, fx + 1, y, darker(S_SH, 0.25), 180); }
  // toppled cap block + chips lying at the foot
  for (const [dx, dy, r] of cfg.chips) {
    blob(cv, cx + dx, H - 20 + dy, r, Math.round(r * 0.6), IVO, s + 3 + r, 0.2);
    px(cv, cx + dx + Math.round(r * 0.4), H - 20 + dy - Math.round(r * 0.4), S_HI, 200);
  }
  selout(cv, S_SH);
  save(cv, name);
}
brokenPlinth('l5b_broken_plinth.png',   { seed: 85410, rx: 18, h: 34, jag: 5, crackX: 2,  chips: [[-15, 6, 7], [16, 3, 6]] });
brokenPlinth('l5b_broken_plinth_b.png', { seed: 85411, rx: 14, h: 44, jag: 7, crackX: -3, chips: [[-13, 5, 6], [14, 6, 5], [3, 8, 5]] });
brokenPlinth('l5b_broken_plinth_c.png', { seed: 85412, rx: 21, h: 26, jag: 4, crackX: 4,  chips: [[-17, 6, 8], [17, 4, 7]] });

// l5b_empty_plinth — 빈 받침: an intact ivory bell-plinth with an EMPTY mounting socket on top
//   (the bell it was cast for never came, or was taken). Faint dead amber ring in the socket.
function emptyPlinth(name, cfg) {
  const W = 88, H = 100, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 62);
  // pedestal base + a taller drum so the empty socket reads at bell-mouth height
  isoBox(cv, cx, H - 34, cfg.rx, 16, mix(IVO, S_HI, 0.22), S_MID, S_SH);
  isoCylinder(cv, cx, H - 34 - cfg.drum, cfg.rx - 4, cfg.drum, mix(IVO, S_HI, 0.26), S_MID, S_SH, 0.92);
  // the recessed empty socket on the top face — dark, a faint cold amber outline (no bell)
  const topCy = H - 34 - cfg.drum;
  isoEllipseTop(cv, cx, topCy, cfg.rx - 6, darker(S_SH, 0.25), 255, S_SH);
  for (let a = 0; a < 360; a += 22) px(cv, cx + Math.cos(a * Math.PI / 180) * (cfg.rx - 8), topCy + Math.sin(a * Math.PI / 180) * (cfg.rx - 8) * 0.5, AMB_DK, 130);
  glow(cv, cx, topCy, cfg.rx - 8, AMB, 22);   // very faint dead shimmer, awaiting a bell
  // a couple of ribbed stone bands
  for (let y = 6; y < cfg.drum; y += 7) { const yy = topCy + 6 + y; for (let x = -(cfg.rx - 5); x <= cfg.rx - 5; x++) px(cv, cx + x, yy, darker(S_MID, 0.2), 130); }
  selout(cv, S_SH);
  save(cv, name);
}
emptyPlinth('l5b_empty_plinth.png',   { seed: 85430, rx: 18, drum: 30 });
emptyPlinth('l5b_empty_plinth_b.png', { seed: 85431, rx: 15, drum: 40 });
emptyPlinth('l5b_empty_plinth_c.png', { seed: 85432, rx: 21, drum: 24 });

// l5b_tilted_bell — 기울어진 종: a bronze bell that has FALLEN off its mount and lies tilted on
//   the ground, silent. Rendered leaning, mouth agape sideways, only a faint DEAD ember (dim).
function tiltedBell(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx + cfg.lean, H - 6, 26, 8, 62);
  // a low rubble rest the bell leans against
  blob(cv, cx - cfg.lean, H - 16, 12, 6, IVO, s + 1, 0.22);
  // the tilted bell body — a skewed bell profile (crown pushed to one side)
  const footY = H - 18, h = cfg.h, w = cfg.w, topY = footY - h;
  for (let y = 0; y < h; y++) {
    const t = y / h;
    const prof = 0.30 + 0.70 * Math.pow(t, 1.35);
    const half = Math.max(1, Math.round((w / 2) * prof));
    const skew = Math.round(cfg.lean * (1 - t));   // lean the crown over
    for (let x = -half; x <= half; x++) {
      const lit = (x - (h - y) * 0.18 + skew) > -half * 0.2;
      let c = lit ? BRZ_HI : (x < -half * 0.45 ? BRZ_DK : BRZ);
      if (t > 0.80 && t < 0.90 && x > 0) c = mix(c, [255, 255, 255], 0.18);
      // patina/verdigris streaks on the dead metal
      if (hcell(cx + x, topY + y, s & 255) < 0.10) c = mix(c, [90, 130, 110], 0.4);
      px(cv, cx + x + skew, topY + y, c, 255);
    }
  }
  // the mouth gapes to one side (dark ellipse, tilted)
  const mHalf = Math.round((w / 2) * 0.9);
  for (let x = -mHalf; x <= mHalf; x++) {
    const yy = footY - Math.round(Math.sqrt(Math.max(0, 1 - (x / mHalf) ** 2)) * (mHalf * 0.4));
    px(cv, cx + x + Math.round(cfg.lean * 0.2), yy, darker(BRZ_DK, 0.4), 230);
  }
  // crown loop, knocked askew
  rect(cv, cx + cfg.lean - 1, topY - 4, cx + cfg.lean + 2, topY + 1, BRZ_DK, 230);
  // a faint DEAD ember (barely alive — this bell is silent), dimmer than any gatherable
  glow(cv, cx + Math.round(cfg.lean * 0.2), footY - Math.round(h * 0.3), cfg.glow, AMB, 34);
  px(cv, cx + Math.round(cfg.lean * 0.2), footY - Math.round(h * 0.3), AMB_DK, 170);
  selout(cv, BRZ_DK);
  save(cv, name);
}
tiltedBell('l5b_tilted_bell.png',   { seed: 85450, w: 32, h: 30, lean: 7,  glow: 9 });
tiltedBell('l5b_tilted_bell_b.png', { seed: 85451, w: 26, h: 36, lean: -9, glow: 8 });
tiltedBell('l5b_tilted_bell_c.png', { seed: 85452, w: 36, h: 24, lean: 10, glow: 10 });

// l5b_low_rubble — 낮은 잔해: a low, flat pile of fallen stone + bronze debris (belfry collapse).
//   Reads short/wide — a horizontal silhouette to break the vertical plinths/bells. No glow.
function lowRubble(name, cfg) {
  const W = 96, H = 72, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 30, 8, 58);
  // scattered stone lumps + a few bronze chunks, kept low to the ground
  for (const [dx, dy, r, kind] of cfg.lumps) {
    const col = kind === 'brz' ? BRZ : IVO;
    blob(cv, cx + dx, H - 16 + dy, r, Math.round(r * 0.55), col, s + 3 + r, 0.2);
    px(cv, cx + dx + Math.round(r * 0.4), H - 16 + dy - Math.round(r * 0.4), kind === 'brz' ? BRZ_HI : S_HI, 200);
    // a shadowed underside crease
    for (let x = -r; x <= r; x++) px(cv, cx + dx + x, H - 16 + dy + Math.round(r * 0.5), darker(kind === 'brz' ? BRZ_DK : S_SH, 0.15), 120);
  }
  // a broken bronze rim shard poking out (a slice of a fallen bell wall)
  const rnd = deterministic(s + 7);
  const ax = cx + cfg.arc[0], ay = H - 18 + cfg.arc[1];
  for (let a = cfg.arc[2]; a < cfg.arc[3]; a += 4) {
    const rad = a * Math.PI / 180, ar = cfg.arc[4];
    px(cv, ax + Math.cos(rad) * ar, ay + Math.sin(rad) * ar * 0.6, a % 24 < 12 ? BRZ : BRZ_DK, 235);
    px(cv, ax + Math.cos(rad) * (ar - 2), ay + Math.sin(rad) * (ar - 2) * 0.6, BRZ_HI, 180);
  }
  selout(cv, S_SH);
  save(cv, name);
}
lowRubble('l5b_low_rubble.png',   { seed: 85470, lumps: [[-16, 4, 9, 'ivo'], [0, 2, 11, 'ivo'], [15, 5, 8, 'brz'], [6, -4, 6, 'ivo']], arc: [12, -2, 200, 320, 14] });
lowRubble('l5b_low_rubble_b.png', { seed: 85471, lumps: [[-18, 5, 8, 'ivo'], [-4, 3, 10, 'brz'], [13, 4, 9, 'ivo'], [22, 6, 6, 'ivo']], arc: [-14, 0, 220, 340, 12] });
lowRubble('l5b_low_rubble_c.png', { seed: 85472, lumps: [[-14, 4, 10, 'ivo'], [4, 2, 12, 'ivo'], [18, 5, 7, 'brz']], arc: [10, -3, 190, 310, 16] });

// l5b_nameless_stone — 무명석: a small unmarked grave-marker stone leaning in the field, ivory,
//   worn smooth, a single faint eroded groove where a name/inscription has faded. No glow (silent).
function namelessStone(name, cfg) {
  const W = 80, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx + Math.round(cfg.tilt * 0.5), H - 8, 18, 6, 60);
  // a rounded standing marker, tilted, tapering upward like a worn headstone
  const footY = H - 18, h = cfg.h, w = cfg.w, topY = footY - h;
  for (let y = 0; y < h; y++) {
    const t = y / h;
    // taper + rounded shoulder near the top
    let half = Math.round((w / 2) * (1 - 0.18 * t));
    if (t > 0.82) half = Math.round(half * Math.sqrt(Math.max(0, 1 - ((t - 0.82) / 0.18) ** 2)));
    const skew = Math.round(cfg.tilt * t);
    for (let x = -half; x <= half; x++) {
      const lit = (x + skew) > -half * 0.15;
      let c = lit ? lighter(IVO, 0.12) : darker(IVO, 0.15);
      if (x < -half * 0.5) c = darker(c, 0.12);
      // weathering mottle
      if (hcell(cx + x, topY + y, s & 255) < 0.14) c = darker(c, 0.16);
      px(cv, cx + x + skew, topY + y, c, 255);
    }
  }
  // one faint eroded groove (a faded inscription line), amber-dark, barely legible
  const gy = topY + Math.round(h * 0.5), gskew = Math.round(cfg.tilt * 0.5);
  emberLine(cv, cx - Math.round(w * 0.25) + gskew, gy, Math.round(w * 0.5), AMB_DK, 120);
  emberLine(cv, cx - Math.round(w * 0.18) + gskew, gy + 5, Math.round(w * 0.36), S_SH, 130);
  selout(cv, S_SH);
  save(cv, name);
}
namelessStone('l5b_nameless_stone.png',   { seed: 85490, w: 24, h: 52, tilt: 4 });
namelessStone('l5b_nameless_stone_b.png', { seed: 85491, w: 20, h: 62, tilt: -6 });
namelessStone('l5b_nameless_stone_c.png', { seed: 85492, w: 28, h: 42, tilt: 6 });

console.log('l5b objects: done');
