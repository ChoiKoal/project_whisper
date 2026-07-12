'use strict';
// EX-L3 — 태엽 광산 (l3m) OBJECT art generator.
// Same Layer-3 machine world as tools_gen_l3_objects.js, but UNDERGROUND (지하 광산):
// the copper/brass ramp is pulled DARKER + desaturated one notch (deep-mine gloom), and
// the ONLY living colour is the amber/orange spring-glow (#ff9a3a-ish) on ore veins,
// the excavator core, and the residual dynamo. Everything follows the shared iso grammar
// (tools_iso_lib.js): NE-light 3-tone shading, ground-contact AO ellipse, iso box/cylinder,
// selout outline (never pure black). Horizontally centred with the ground-contact ellipse
// near the canvas bottom so the loader plants them on cell centres like the l2s/l3 objects.
//
// Silhouette variation (QA §㉘): the four repeated gatherables (spring_ore, rusted_axle,
// mine_coal, condensate_crystal) each ship 3 baked shape/size variants (base + _b + _c) so
// a field of repeated stamps reads varied even if the loader does not auto-vary (the loader
// hash-picks among {base,_b,_c} via art_variants). Other objects are single sprites (+ state
// variants _lit/_open where the map legend references two states).
//
// Deterministic (fixed seeds → identical reruns). Pure Node.js, no deps.
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l3m_objects.js
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

// ── palette ────────────────────────────────────────────────────────────────
// Deep-mine brass/copper ramp = the l3 machine coppers pulled darker/desaturated one notch.
const BRASS_D = rgb('#241813'), BRASS = rgb('#3a281c'), BRASS_M = rgb('#5a4230'),
      BRASS_L = rgb('#8a6a44'), BRASS_H = rgb('#b89058');
const IRON_D = rgb('#161a20'), IRON = rgb('#282e38'), IRON_M = rgb('#414a58'),
      IRON_L = rgb('#5e6a7a');
// amber/orange spring-glow (the ONE living colour of the mine — first-wound clockwork).
const AMBER = rgb('#ff9a3a'), AMBER_D = rgb('#b35e1a'), AMBER_HI = rgb('#ffe0a8'),
      AMBER_MID = rgb('#e07826');
// rust: brown + flaking oxide
const RUST = rgb('#6e4028'), RUST_D = rgb('#341c10'), RUST_L = rgb('#9a5f38');
// coal: near-black chunky
const COAL = rgb('#1c1c22'), COAL_D = rgb('#0b0b0e'), COAL_L = rgb('#3a3a44');
// condensate crystal: cool amber-lit quartz (dimmer than the core glow)
const QTZ_D = rgb('#4a3a2a'), QTZ = rgb('#8a6a44'), QTZ_L = rgb('#d8b878');

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

// a lumpy ore/rust blob (value-noise ellipse)
function blob(cv, cx, cy, rx, ry, col, seed, mott = 0.18) {
  const rnd = deterministic(seed);
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++) {
    const d = (x / rx) ** 2 + (y / ry) ** 2;
    if (d > 1.0) continue;
    const lit = (x - y * 0.4) > -rx * 0.2;   // NE-lit face
    let c = lit ? lighter(col, 0.14) : darker(col, 0.16);
    if (hcell(cx + x, cy + y, seed & 255) < mott) c = darker(c, 0.22);
    px(cv, cx + x, cy + y, c, 255);
  }
}

// a faceted crystal shard
function shard(cv, cx, footY, w, h, seed, col, colL) {
  for (let y = 0; y < h; y++) {
    const t = y / h, half = Math.round((w / 2) * (1 - t));
    for (let x = -half; x <= half; x++) {
      const lit = (x - (h - y) * 0.15) > 0;
      px(cv, cx + x, footY - y, lit ? colL : col, 255);
    }
  }
}

// ── GATHERABLES (3 baked variants each: base + _b + _c) ──────────────────────

// l3m_spring_ore — K8. A half-mined clockwork ore vein, amber spring still faintly wound.
function springOre(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 24, 7, 60);
  // rock matrix chunk (dark brass ore)
  blob(cv, cx, H - 24, cfg.rx, cfg.ry, BRASS, s + 1, 0.22);
  for (const [dx, dy, r] of cfg.lumps) blob(cv, cx + dx, H - 24 + dy, r, Math.round(r * 0.72), s + 5 + r, 0.2);
  // exposed amber spring coil (the living wound)
  glow(cv, cx + cfg.gx, H - 24 + cfg.gy, cfg.glow, AMBER, 95);
  for (const [dx, dy] of cfg.coil) {
    px(cv, cx + dx, H - 24 + dy, AMBER, 240);
    px(cv, cx + dx, H - 25 + dy, AMBER_HI, 200);
  }
  px(cv, cx + cfg.gx, H - 24 + cfg.gy, AMBER_HI, 220);
  selout(cv, BRASS_D);
  save(cv, name);
}
springOre('l3m_spring_ore.png',   { seed: 83010, rx: 22, ry: 15, gx: 2, gy: -3, glow: 16, lumps: [[-13, 6, 8], [15, 4, 7]], coil: [[0, -4], [3, -3], [-2, -5], [5, -2]] });
springOre('l3m_spring_ore_b.png', { seed: 83011, rx: 18, ry: 17, gx: -4, gy: -5, glow: 13, lumps: [[12, 8, 9], [-13, 5, 6], [0, -10, 5]], coil: [[-4, -6], [-1, -5], [-6, -4]] });
springOre('l3m_spring_ore_c.png', { seed: 83012, rx: 25, ry: 12, gx: 6, gy: -2, glow: 18, lumps: [[-16, 3, 7], [16, 5, 8]], coil: [[6, -3], [9, -2], [3, -4], [11, -1]] });

// l3m_rusted_axle — K9. A broken drill axle, teeth worn to nothing (no glow).
function rustedAxle(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 22, 6, 58);
  // the axle shaft (iron cylinder lying/leaning)
  isoCylinder(cv, cx, H - 22 - cfg.len, 10, cfg.len, IRON_M, IRON, IRON_D, 1.0);
  // rust flaking down the shaft
  const rnd = deterministic(s + 3);
  for (let i = 0; i < cfg.rust; i++) {
    const rx = cx - 8 + Math.floor(rnd() * 16), ry = H - 22 - Math.floor(rnd() * cfg.len);
    px(cv, rx, ry, RUST, 210); px(cv, rx, ry + 1, RUST_D, 180);
  }
  // worn gear teeth at the top (broken, uneven)
  for (const [dx, dy] of cfg.teeth) { px(cv, cx + dx, H - 22 - cfg.len + dy, RUST_L, 220); px(cv, cx + dx, H - 21 - cfg.len + dy, RUST_D, 200); }
  selout(cv, IRON_D);
  save(cv, name);
}
rustedAxle('l3m_rusted_axle.png',   { seed: 83030, len: 34, rust: 26, teeth: [[-11, 2], [11, 3], [-6, -1], [7, 0], [0, 1]] });
rustedAxle('l3m_rusted_axle_b.png', { seed: 83031, len: 28, rust: 20, teeth: [[-10, 4], [10, 2], [-4, 1]] });
rustedAxle('l3m_rusted_axle_c.png', { seed: 83032, len: 40, rust: 32, teeth: [[-12, 1], [12, 2], [-7, 0], [8, -1], [0, 2], [4, 3]] });

// l3m_mine_coal — K10. A pile of near-black coal lumps (no glow).
function mineCoal(name, cfg) {
  const W = 96, H = 88, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 6, 24, 7, 62);
  for (const [dx, dy, r] of cfg.lumps) {
    blob(cv, cx + dx, H - 18 + dy, r, Math.round(r * 0.78), COAL, s + 3 + r, 0.28);
    // faceted glints on a couple lumps
    px(cv, cx + dx - Math.round(r * 0.4), H - 18 + dy - Math.round(r * 0.4), COAL_L, 200);
  }
  selout(cv, COAL_D);
  save(cv, name);
}
mineCoal('l3m_mine_coal.png',   { seed: 83050, lumps: [[0, 0, 16], [-14, 4, 10], [13, 3, 11], [-4, -9, 8]] });
mineCoal('l3m_mine_coal_b.png', { seed: 83051, lumps: [[0, 2, 13], [-11, 3, 9], [12, 5, 8]] });
mineCoal('l3m_mine_coal_c.png', { seed: 83052, lumps: [[0, -2, 18], [-16, 5, 11], [15, 4, 12], [3, -11, 9], [-6, 8, 7]] });

// l3m_condensate_crystal — K11. Wall-condensed quartz cluster, faint amber sheen.
function condensateCrystal(name, cfg) {
  const W = 96, H = 100, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 20, 6, 58);
  // small dark base rock
  blob(cv, cx, H - 20, 16, 9, BRASS_D, s + 1, 0.25);
  glow(cv, cx, H - 30, cfg.glow, AMBER_MID, 55);
  for (const [dx, ww, hh, sd] of cfg.shards) shard(cv, cx + dx, H - 20, ww, hh, s + sd, QTZ, QTZ_L);
  px(cv, cx + cfg.shards[0][0], H - 20 - cfg.shards[0][2], AMBER_HI, 170);
  selout(cv, QTZ_D);
  save(cv, name);
}
condensateCrystal('l3m_condensate_crystal.png',   { seed: 83070, glow: 22, shards: [[0, 10, 40, 1], [-9, 6, 24, 2], [10, 6, 22, 3]] });
condensateCrystal('l3m_condensate_crystal_b.png', { seed: 83071, glow: 18, shards: [[-3, 8, 30, 1], [7, 8, 36, 2], [-11, 5, 18, 3]] });
condensateCrystal('l3m_condensate_crystal_c.png', { seed: 83072, glow: 26, shards: [[2, 12, 46, 1], [-12, 6, 22, 2]] });

// ── UNIQUE / FUNCTIONAL OBJECTS ──────────────────────────────────────────────

// l3m_excavator_core (O / K12 / GM4 offering target) — a tall dim first-spring core column,
//   faintly pulsing amber; l3m_excavator_core_lit — post-purification: fully radiant amber.
function excavatorCore(name, lit) {
  const W = 112, H = 148, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 10, 30, 9, 66);
  // stepped brass plinth
  isoBox(cv, cx, H - 40, 30, 18, BRASS_M, BRASS_L, BRASS);
  isoBox(cv, cx, H - 58, 22, 14, BRASS, BRASS_M, BRASS_D);
  // the core column (iron drum wound with a spring)
  const topY = H - 118, rx = 16, h = 66;
  isoCylinder(cv, cx, topY, rx, h, IRON_M, IRON, IRON_D, 0.92);
  // spring winding rings up the column
  const g = lit ? 255 : 120;
  for (let y = 4; y < h; y += 7) {
    const yy = topY + rx / 2 + y;
    for (let x = -rx + 2; x <= rx - 2; x++) px(cv, cx + x, yy, lit ? AMBER : AMBER_D, lit ? 230 : 150);
    px(cv, cx, yy, AMBER_HI, lit ? 200 : 110);
  }
  // crowning glow
  glow(cv, cx, topY, lit ? 44 : 26, AMBER, lit ? 150 : 80);
  glow(cv, cx, topY, lit ? 18 : 10, AMBER_HI, lit ? 200 : 120);
  if (lit) for (let i = 0; i < 40; i++) { const a = i / 40 * Math.PI * 2; px(cv, cx + Math.cos(a) * 30, topY + Math.sin(a) * 14, AMBER_HI, 120); }
  selout(cv, IRON_D);
  save(cv, name);
}
excavatorCore('l3m_excavator_core.png', false);
excavatorCore('l3m_excavator_core_lit.png', true);

// l3m_excavator_altar (H / GM4) — the offering neck where the 태엽 노심 is mounted;
//   l3m_excavator_altar_lit — post-offering radiant state.
function excavatorAltar(name, lit) {
  const W = 104, H = 116, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 28, 8, 64);
  // heavy brass mount base
  isoBox(cv, cx, H - 44, 26, 20, BRASS_M, BRASS_L, BRASS);
  // cradle arms (two iron uprights)
  for (const sx of [-16, 16]) {
    isoBox(cv, cx + sx, H - 78, 5, 36, IRON_M, IRON, IRON_D);
  }
  // the cradle cup between the arms
  isoEllipseTop(cv, cx, H - 74, 14, lit ? AMBER : IRON_M, 255, IRON_D);
  glow(cv, cx, H - 74, lit ? 30 : 14, AMBER, lit ? 150 : 60);
  if (lit) { glow(cv, cx, H - 74, 14, AMBER_HI, 170); px(cv, cx, H - 74, AMBER_HI, 230); }
  selout(cv, IRON_D);
  save(cv, name);
}
excavatorAltar('l3m_excavator_altar.png', false);
excavatorAltar('l3m_excavator_altar_lit.png', true);

// l3m_vent_door (D / GM2) — a corroded blocked ventilation door, sealed;
//   l3m_vent_door_open — the door retracted / pressure restored (open state).
function ventDoor(name, open) {
  const W = 104, H = 120, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 30, 8, 64);
  // frame
  isoBox(cv, cx, H - 96, 30, 78, IRON, IRON_M, IRON_D);
  const inX0 = cx - 22, inX1 = cx + 22, inY0 = H - 90, inY1 = H - 18;
  if (open) {
    // door slid up: dark recess + a faint amber draft
    rect(cv, inX0, inY0, inX1, inY1, darker(IRON_D, 0.3));
    glow(cv, cx, (inY0 + inY1) / 2, 22, AMBER_MID, 55);
    // retracted louvre slats up top
    for (let y = inY0 - 8; y < inY0; y += 2) rect(cv, inX0, y, inX1, y + 1, IRON_L, 210);
  } else {
    // corroded louvre door (horizontal slats + rust)
    for (let y = inY0; y < inY1; y += 6) {
      rect(cv, inX0, y, inX1, y + 4, IRON_M);
      rect(cv, inX0, y + 4, inX1, y + 5, IRON_D);
    }
    const rnd = deterministic(7711);
    for (let i = 0; i < 60; i++) px(cv, inX0 + Math.floor(rnd() * 44), inY0 + Math.floor(rnd() * 72), RUST, 170);
    // central pressure valve wheel
    for (let a = 0; a < 360; a += 12) { const wy = (inY0 + inY1) / 2; px(cv, cx + Math.cos(a * Math.PI / 180) * 10, wy + Math.sin(a * Math.PI / 180) * 10, RUST_L, 220); }
  }
  selout(cv, IRON_D);
  save(cv, name);
}
ventDoor('l3m_vent_door.png', false);
ventDoor('l3m_vent_door_open.png', true);

// l3m_spring_dynamo (E) — a residual spring dynamo, energy re-acquire node (idempotent).
function springDynamo() {
  const W = 96, H = 108, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 26, 7, 62);
  // base
  isoBox(cv, cx, H - 40, 24, 20, BRASS_M, BRASS_L, BRASS);
  // dynamo drum
  isoCylinder(cv, cx, H - 78, 18, 40, IRON_M, IRON, IRON_D, 0.95);
  // amber spring coil bands
  for (let y = 6; y < 40; y += 6) { const yy = H - 78 + 9 + y; for (let x = -16; x <= 16; x++) px(cv, cx + x, yy, AMBER_D, 170); px(cv, cx, yy, AMBER, 200); }
  glow(cv, cx, H - 74, 22, AMBER, 90);
  glow(cv, cx, H - 74, 9, AMBER_HI, 150);
  selout(cv, IRON_D);
  save(cv, 'l3m_spring_dynamo.png');
}
springDynamo();

// l3m_digger_bot (N) — the remnant NPC: a stalled digger robot, one dim amber optic.
function diggerBot() {
  const W = 104, H = 128, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 28, 8, 64);
  // tracked base
  isoBox(cv, cx, H - 40, 26, 20, IRON, IRON_M, IRON_D);
  for (let x = -22; x <= 22; x += 6) px(cv, cx + x, H - 22, IRON_D, 220);   // track links
  // body drum
  isoCylinder(cv, cx, H - 82, 16, 44, BRASS_M, BRASS, BRASS_D, 0.95);
  // drill arm (folded, drooping — stalled)
  for (let k = 0; k < 26; k++) { px(cv, cx + 16 + Math.round(k * 0.7), H - 70 + k, IRON_M, 235); px(cv, cx + 17 + Math.round(k * 0.7), H - 70 + k, IRON_D, 200); }
  blob(cv, cx + 34, H - 44, 6, 5, RUST, 4242, 0.3);   // rusted drill bit
  // head + single dim optic
  isoBox(cv, cx, H - 100, 12, 14, IRON_M, IRON, IRON_D);
  glow(cv, cx, H - 96, 8, AMBER_MID, 70);
  px(cv, cx, H - 96, AMBER, 210); px(cv, cx, H - 97, AMBER_HI, 180);
  selout(cv, IRON_D);
  save(cv, 'l3m_digger_bot.png');
}
diggerBot();

// l3m_workbench (C) — the mine repair bench (L3 crafting station), brass w/ amber lamp.
function workbench() {
  const W = 112, H = 100, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 34, 9, 66);
  // bench top (iso slab)
  isoBox(cv, cx, H - 52, 34, 16, BRASS_M, BRASS_L, BRASS);
  // legs
  for (const sx of [-28, 28]) rect(cv, cx + sx - 2, H - 40, cx + sx + 2, H - 12, BRASS_D);
  // tools + a small amber work-lamp
  rect(cv, cx - 20, H - 60, cx - 8, H - 54, IRON_M);   // vice
  for (let i = 0; i < 5; i++) px(cv, cx + 6 + i * 3, H - 58, IRON_L, 220);  // laid tools
  glow(cv, cx + 22, H - 62, 12, AMBER, 90);
  px(cv, cx + 22, H - 62, AMBER_HI, 220);
  selout(cv, BRASS_D);
  save(cv, 'l3m_workbench.png');
}
workbench();

// l3m_miner_log_slab (landmark 3) — the truth-shard slab (miner's last log).
function minerLogSlab() {
  const W = 96, H = 104, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 8, 24, 7, 60);
  // leaning stone slab
  const topY = H - 84, rx = 20, h = 72;
  isoBox(cv, cx, topY, rx, h, BRASS, BRASS_M, BRASS_D);
  // engraved (smudged) lines of a log
  const rnd = deterministic(9001);
  for (let ly = topY + 12; ly < topY + h - 6; ly += 6) {
    const len = 8 + Math.floor(rnd() * (rx * 1.4));
    rect(cv, cx - rx + 6, ly, cx - rx + 6 + len, ly + 1, BRASS_D, 200);
  }
  glow(cv, cx, topY + 6, 12, AMBER_MID, 60);   // faint activation sheen
  selout(cv, BRASS_D);
  save(cv, 'l3m_miner_log_slab.png');
}
minerLogSlab();

// l3m_ore_cart (landmark 4) — tutorial ore cart with a half-wound glowing ore.
function oreCart() {
  const W = 112, H = 96, cv = C(W, H), cx = W / 2;
  ao(cv, cx, H - 6, 34, 9, 64);
  // cart body (iso trapezoid box)
  isoBox(cv, cx, H - 46, 30, 20, IRON_M, IRON, IRON_D);
  // wheels
  for (const sx of [-22, 22]) { isoEllipseTop(cv, cx + sx, H - 16, 8, IRON_D, 255, null); px(cv, cx + sx, H - 16, IRON_L, 200); }
  // a glowing ore lump inside
  blob(cv, cx, H - 52, 12, 8, BRASS, 5511, 0.2);
  glow(cv, cx, H - 54, 14, AMBER, 100);
  px(cv, cx, H - 54, AMBER_HI, 230); px(cv, cx + 3, H - 53, AMBER, 210);
  selout(cv, IRON_D);
  save(cv, 'l3m_ore_cart.png');
}
oreCart();

console.log('l3m objects: done');
