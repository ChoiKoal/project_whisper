'use strict';
// EX-L2 — 지하 데이터 성소 (l2s) OBJECT art generator.
// Same Layer-2 science world as tools_gen_l2_objects.js, but UNDERGROUND: the base
// metal ramp is desaturated + dimmed one notch (deep-mine steel), corroded ruins get
// rust-brown + sickly-green, and the ONLY living colour is the cyan data-glow
// (#3fe0ff-ish) on crystals / cores / active nodes. Everything follows the shared iso
// grammar (tools_iso_lib.js): NE-light 3-tone shading, ground-contact AO ellipse,
// iso box/cylinder, selout outline (never pure black). Horizontally centred with the
// ground-contact ellipse near the canvas bottom so the loader plants them on cell
// centres like the l1x/l2 objects.
//
// Silhouette variation (QA §㉘): the four gatherable types (data_crystal, corroded_core,
// fiber_bundle, coolant_gel) each ship 3 baked shape/size variants (base + _b + _c) so a
// field of repeated stamps reads varied even if the loader does not auto-vary. The wiring
// agent can hash-pick among {base,_b,_c}. All other objects are single sprites (+ state
// variants _lit/_open where the map legend references two states).
//
// Deterministic (fixed seeds → identical reruns). Pure Node.js, no deps.
// Run: NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_l2s_objects.js
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
// Deep-mine metal ramp = the l2 science greys pulled darker/desaturated one notch.
const METAL_D = rgb('#141a24'), METAL = rgb('#222c3a'), METAL_M = rgb('#38424f'),
      METAL_L = rgb('#5a6472'), METAL_H = rgb('#828c9c');
const PANEL_D = rgb('#0d1220');           // recessed void panel
// cyan data-glow (brighter/purer than l2's teal so it reads as the one living colour)
const CYAN = rgb('#3fe0ff'), CYAN_D = rgb('#1f7a8c'), CYAN_HI = rgb('#c8f8ff'),
      CYAN_MID = rgb('#4ad9c8');
// corrosion: rust brown + sickly green
const RUST = rgb('#6e4028'), RUST_D = rgb('#3a2418'), RUST_L = rgb('#9a5f38');
const SICK = rgb('#4a6a3a'), SICK_L = rgb('#7aa055');
// coolant gel: translucent blue-green
const GEL_D = rgb('#1f5a5a'), GEL = rgb('#3a8f88'), GEL_L = rgb('#7ad6cc');
const CHAR = rgb('#1a1a22'), CHAR_D = rgb('#0a0a0e'), CHAR_L = rgb('#33333d');

const STEEL = { sh: METAL, mid: METAL_M, hi: METAL_L };   // base 3-tone ramp

// value-noise mottle (idiom shared with the l1/l2 generators)
function hcell(ix, iy, salt) { let h = (ix * 374761393) ^ (iy * 668265263) ^ (salt * 2246822519); h = (h ^ (h >>> 13)) >>> 0; h = (h * 1274126177) >>> 0; return ((h ^ (h >>> 16)) >>> 0) / 4294967295; }
function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v); }

// selout outline: paint a 1px darker-same-hue border around the opaque silhouette.
function selout(cv, ol) {
  const src = Buffer.from(cv.data), W = cv.w, H = cv.h;
  const aAt = (x, y) => (x < 0 || y < 0 || x >= W || y >= H) ? 0 : src[(y * W + x) * 4 + 3];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (aAt(x, y) !== 0) continue;
    if (aAt(x - 1, y) || aAt(x + 1, y) || aAt(x, y - 1) || aAt(x, y + 1)) px(cv, x, y, ol, 255);
  }
}

// a single upright faceted crystal (cyan data-glow) rising from (cx, footY).
function crystal(cv, cx, footY, w, h, seed) {
  for (let y = 0; y < h; y++) {
    const yy = footY - y;
    const ww = Math.max(1, Math.round(w * (1 - y / h * 0.7)));
    for (let x = -ww; x <= ww; x++) {
      const lit = (x - y * 0.2) > 0;             // NE facet
      const t = y / h;
      px(cv, cx + x, yy, mix(lit ? CYAN : CYAN_D, CYAN_HI, t * 0.4), 250);
    }
  }
  for (let y = 0; y < h; y++) px(cv, cx, footY - y, CYAN_HI, Math.round(200 * (y / h))); // bright core axis
  px(cv, cx, footY - h, CYAN_HI, 240);
}

// rusted metal chunk (iso-ish blob) with corrosion speckle.
function rustBlob(cv, cx, cy, rx, ry, seed) {
  for (let y = -ry; y <= ry; y++) for (let x = -rx; x <= rx; x++) {
    const nx = x / rx, ny = y / ry; if (nx * nx + ny * ny > 1) continue;
    const lit = clamp(0.5 - nx * 0.5 - ny * 0.5, 0, 1);
    let c = mix(RUST_D, RUST_L, lit);
    const n = hcell(cx + x, cy + y, seed);
    if (n > 0.72) c = mix(c, SICK_L, 0.5);
    else if (n < 0.24) c = mix(c, SICK, 0.6);
    px(cv, cx + x, cy + y, c, 255);
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GATHERABLES (3 baked variants each: base + _b + _c)
// ════════════════════════════════════════════════════════════════════════════

// l2s_data_crystal — J8. A cyan crystal cluster on a dark server-rack fragment.
function dataCrystal(name, cfg) {
  const W = 96, H = 112, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 24, 7, 62);
  // server-rack fragment plinth (dark ribbed metal box, iso)
  const topY = H - 30, rx = cfg.plinth, h = 16;
  isoBox(cv, cx, topY, rx, h, METAL_M, mix(METAL_M, METAL_L, 0.4), METAL);
  for (let y = 2; y < h; y += 3) for (let x = -rx + 3; x < rx - 3; x++) px(cv, cx + x, topY + rx / 2 + y, METAL_D, 200); // ribs on the lit face
  // crystal cluster
  glow(cv, cx, topY - 24, cfg.glow, CYAN, 95);
  for (const [dx, ww, hh, sd] of cfg.shards) crystal(cv, cx + dx, topY - 2, ww, hh, s + sd);
  glow(cv, cx + cfg.shards[0][0], topY - cfg.shards[0][2], 8, CYAN_HI, 150);
  selout(cv, METAL_D);
  save(cv, name);
}
dataCrystal('l2s_data_crystal.png',   { seed: 82010, plinth: 20, glow: 30, shards: [[0, 8, 46, 1], [-11, 5, 28, 2], [12, 5, 24, 3]] });
dataCrystal('l2s_data_crystal_b.png', { seed: 82011, plinth: 17, glow: 24, shards: [[-4, 6, 34, 1], [8, 7, 40, 2], [-13, 4, 20, 3], [15, 4, 18, 4]] });
dataCrystal('l2s_data_crystal_c.png', { seed: 82012, plinth: 22, glow: 34, shards: [[2, 10, 52, 1], [-14, 6, 26, 2]] });

// l2s_corroded_core — J9. A rusted computation-core chunk (brown/green corrosion).
function corrodedCore(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 24, 7, 62);
  // main rusted core mass
  rustBlob(cv, cx, H - 26, cfg.rx, cfg.ry, s + 1);
  for (const [dx, dy, r] of cfg.lumps) rustBlob(cv, cx + dx, H - 26 + dy, r, Math.round(r * 0.7), s + 5 + r);
  // a few surviving metal pins/traces poking from the rust
  const rnd = deterministic(s + 20);
  for (let i = 0; i < cfg.pins; i++) {
    const bx = cx - cfg.rx + Math.floor(rnd() * cfg.rx * 2), by = H - 26 - Math.floor(rnd() * cfg.ry);
    for (let k = 0; k < 5; k++) px(cv, bx, by - k, METAL_M, 220);
    px(cv, bx, by - 5, METAL_L, 200);
  }
  // sickly corrosion glints
  for (const [dx, dy] of cfg.spore) px(cv, cx + dx, H - 26 + dy, SICK_L, 210);
  selout(cv, RUST_D);
  save(cv, name);
}
corrodedCore('l2s_corroded_core.png',   { seed: 82030, rx: 22, ry: 15, lumps: [[-14, 6, 8], [15, 4, 7]], pins: 5, spore: [[-8, -4], [10, 2], [2, 8]] });
corrodedCore('l2s_corroded_core_b.png', { seed: 82031, rx: 18, ry: 17, lumps: [[12, 8, 9], [-13, 5, 6], [0, -10, 5]], pins: 3, spore: [[6, -6], [-6, 4]] });
corrodedCore('l2s_corroded_core_c.png', { seed: 82032, rx: 24, ry: 12, lumps: [[-16, 3, 7], [16, 5, 8]], pins: 7, spore: [[0, 0], [12, -3], [-10, 5]] });

// l2s_fiber_bundle — J10. A drooping bundle of fiber-optic threads, faint tip glow.
function fiberBundle(name, cfg) {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, 22, 6, 55);
  // a small crimp collar the fibers spill from
  const cy = 24;
  rect(cv, cx - 12, cy - 4, cx + 12, cy + 6, METAL_M);
  rect(cv, cx - 12, cy - 4, cx + 12, cy - 1, METAL_L);
  rect(cv, cx - 12, cy + 4, cx + 12, cy + 6, METAL_D);
  // drooping threads
  const tips = [];
  for (let i = 0; i < cfg.n; i++) {
    const sx = cx - 10 + i * (20 / cfg.n);
    const ex = cx - cfg.spread + i * (cfg.spread * 2 / cfg.n) + cfg.skew;
    const ey = H - 14 - ((i * 7) % cfg.sag);
    let px_ = sx, py = cy + 6;
    for (let t = 0; t <= 44; t++) {
      const u = t / 44;
      const x = sx + (ex - sx) * u;
      const y = cy + 6 + (ey - (cy + 6)) * u + Math.sin(u * Math.PI) * cfg.droop;
      const c = i % 3 === 0 ? METAL_L : (i % 3 === 1 ? METAL_H : METAL_M);
      px(cv, x, y, c, 240);
      if (t === 44) tips.push([x | 0, y | 0]);
      px_ = x; py = y;
    }
  }
  for (const [x, y] of tips) { glow(cv, x, y, 5, CYAN, 110); px(cv, x, y, CYAN_HI, 220); }
  selout(cv, METAL_D);
  save(cv, name);
}
fiberBundle('l2s_fiber_bundle.png',   { seed: 82050, n: 9,  spread: 26, skew: 0,  sag: 14, droop: 10 });
fiberBundle('l2s_fiber_bundle_b.png', { seed: 82051, n: 7,  spread: 20, skew: 8,  sag: 20, droop: 14 });
fiberBundle('l2s_fiber_bundle_c.png', { seed: 82052, n: 12, spread: 30, skew: -6, sag: 10, droop: 7  });

// l2s_coolant_gel — J11. A translucent hardening blue-green gel puddle, faint cyan.
function coolantGel(name, cfg) {
  const W = 96, H = 72, cv = C(W, H), cx = W / 2, s = cfg.seed;
  ao(cv, cx, H - 8, cfg.rx + 2, 6, 48);
  glow(cv, cx, H - 16, cfg.rx, mix(GEL, CYAN, 0.3), 60);
  // translucent gel dome (semi-transparent so the underground floor reads through)
  for (let y = -cfg.ry; y <= cfg.ry; y++) for (let x = -cfg.rx; x <= cfg.rx; x++) {
    const nx = x / cfg.rx, ny = y / cfg.ry; const d = nx * nx + ny * ny; if (d > 1) continue;
    const lit = clamp(0.5 - nx * 0.5 - ny * 0.5, 0, 1);
    const c = mix(GEL_D, GEL_L, lit);
    px(cv, cx + x, H - 16 + y, c, 200 - Math.round(d * 60));
  }
  // hardening surface flecks + a cyan sheen
  const rnd = deterministic(s + 3);
  for (let i = 0; i < cfg.fleck; i++) {
    const gx = cx - cfg.rx + Math.floor(rnd() * cfg.rx * 2), gy = H - 16 - Math.floor(rnd() * cfg.ry);
    if (cv.data[(gy * W + gx) * 4 + 3] > 20) px(cv, gx, gy, rnd() < 0.5 ? GEL_L : CYAN, 180);
  }
  glow(cv, cx - cfg.rx * 0.4, H - 20, 6, rgb('#ffffff'), 90);
  selout(cv, rgb('#123838'));
  save(cv, name);
}
coolantGel('l2s_coolant_gel.png',   { seed: 82070, rx: 26, ry: 13, fleck: 40 });
coolantGel('l2s_coolant_gel_b.png', { seed: 82071, rx: 20, ry: 15, fleck: 30 });
coolantGel('l2s_coolant_gel_c.png', { seed: 82072, rx: 30, ry: 11, fleck: 50 });

// ════════════════════════════════════════════════════════════════════════════
// UNIQUE OBJECTS / STATE PAIRS
// ════════════════════════════════════════════════════════════════════════════

// l2s_backup_core (O / J12) — a tall dim server-core column, faintly pulsing cyan;
// l2s_backup_core_lit — post-purification: fully radiant cyan.
function backupCore(name, lit) {
  const W = 128, H = 176, cv = C(W, H), cx = W / 2, s = 82100;
  ao(cv, cx, H - 10, 34, 10, 70);
  // heavy iso base plinth
  isoBox(cv, cx, H - 44, 30, 22, METAL_M, mix(METAL_M, METAL_L, 0.4), METAL);
  // tall ribbed core tower
  const towerTop = 20, towerBot = H - 40;
  rect(cv, cx - 18, towerTop, cx + 18, towerBot, METAL);
  for (let y = towerTop; y < towerBot; y++) for (let x = cx - 18; x < cx + 18; x++) px(cv, x, y, x > cx + 6 ? METAL_M : (x < cx - 10 ? METAL_D : METAL));
  rect(cv, cx - 18, towerTop, cx + 18, towerTop + 3, METAL_L);
  // side rib shadows
  for (let y = towerTop + 6; y < towerBot; y += 8) rect(cv, cx - 18, y, cx + 18, y + 2, METAL_D);
  // central data column window running the height
  const glowCol = lit ? CYAN : CYAN_D, peak = lit ? 150 : 70;
  glow(cv, cx, (towerTop + towerBot) / 2, lit ? 60 : 34, CYAN, peak);
  rect(cv, cx - 6, towerTop + 8, cx + 6, towerBot - 6, PANEL_D);
  for (let y = towerTop + 12; y < towerBot - 8; y += 6) {
    const a = lit ? 240 : 130;
    rect(cv, cx - 5, y, cx + 5, y + 3, glowCol, a);
    if (lit) px(cv, cx, y + 1, CYAN_HI, 240);
  }
  // crowning core orb
  glow(cv, cx, towerTop, lit ? 30 : 16, CYAN, lit ? 160 : 80);
  for (let y = -9; y <= 9; y++) for (let x = -9; x <= 9; x++) { if (x * x + y * y > 81) continue; const litT = clamp(0.5 - x / 18 - y / 18, 0, 1); px(cv, cx + x, towerTop + y, mix(lit ? CYAN : CYAN_D, CYAN_HI, litT * (lit ? 0.7 : 0.3)), 255); }
  if (lit) { px(cv, cx - 3, towerTop - 3, CYAN_HI, 255); }
  selout(cv, METAL_D);
  save(cv, name);
}
backupCore('l2s_backup_core.png', false);
backupCore('l2s_backup_core_lit.png', true);

// l2s_archivist_drone (N) — a small stopped/hovering maintenance drone, single cyan eye.
(function archivistDrone() {
  const W = 96, H = 96, cv = C(W, H), cx = W / 2, s = 82150;
  ao(cv, cx, H - 12, 20, 6, 55);   // soft floating shadow (hovering, but stalled low)
  const bodyCy = 44;
  // spherical body
  for (let y = -18; y <= 18; y++) for (let x = -20; x <= 20; x++) {
    const nx = x / 20, ny = y / 18; if (nx * nx + ny * ny > 1) continue;
    const lit = clamp(0.5 - nx * 0.5 - ny * 0.5, 0, 1);
    px(cv, cx + x, bodyCy + y, mix(METAL, METAL_L, lit), 255);
  }
  // side thruster pods (stopped — no glow)
  rect(cv, cx - 26, bodyCy - 4, cx - 18, bodyCy + 6, METAL_M);
  rect(cv, cx + 18, bodyCy - 4, cx + 26, bodyCy + 6, METAL_M);
  rect(cv, cx - 26, bodyCy - 4, cx - 18, bodyCy - 2, METAL_L);
  // dangling folded legs (powered down)
  for (let i = 0; i < 12; i++) { px(cv, cx - 8 - i * 0.3, bodyCy + 16 + i, METAL_M); px(cv, cx + 8 + i * 0.3, bodyCy + 16 + i, METAL_M); }
  // single cyan eye (dim — the drone is stopped, only a flicker of charge)
  glow(cv, cx, bodyCy - 2, 12, CYAN, 90);
  for (let y = -6; y <= 6; y++) for (let x = -6; x <= 6; x++) { if (x * x + y * y > 36) continue; px(cv, cx + x, bodyCy - 2 + y, mix(CYAN_D, CYAN, clamp(0.5 - x / 12 - y / 12, 0, 1)), 255); }
  px(cv, cx - 2, bodyCy - 4, CYAN_HI, 220);
  // a dark iris ring around the eye
  for (let a = 0; a < 360; a += 8) px(cv, cx + Math.cos(a * Math.PI / 180) * 7, bodyCy - 2 + Math.sin(a * Math.PI / 180) * 7, METAL_D, 220);
  selout(cv, METAL_D);
  save(cv, 'l2s_archivist_drone.png');
})();

// l2s_sealed_bulkhead (D / GB2) — heavy locked metal bulkhead door, dark;
// l2s_sealed_bulkhead_open — retracted / open state (door slid up into the frame).
function sealedBulkhead(name, open) {
  const W = 128, H = 160, cv = C(W, H), cx = W / 2, s = 82200;
  ao(cv, cx, H - 10, 44, 11, 66);
  // door frame (heavy iso-fronted jamb)
  rect(cv, 16, 16, W - 16, H - 12, METAL_D);
  rect(cv, 20, 20, W - 20, H - 14, METAL);
  rect(cv, 20, 20, W - 20, 24, METAL_L);            // lit top lintel
  // frame side pistons
  for (const fx of [24, W - 28]) { rect(cv, fx, 24, fx + 4, H - 16, METAL_M); rect(cv, fx, 24, fx + 2, H - 16, METAL_L); }
  const dTop = open ? 20 : 30, dBot = open ? 56 : H - 20;   // open = door retracted up
  if (open) {
    // dark recessed passage revealed below the retracted door
    rect(cv, 30, 56, W - 30, H - 16, PANEL_D);
    glow(cv, cx, H - 40, 40, CYAN, 40);              // faint cyan draft from within
    // retracted door slab pressed into the lintel
    rect(cv, 30, dTop, W - 30, dBot, METAL_M);
    for (let y = dTop; y < dBot; y += 5) rect(cv, 30, y, W - 30, y + 2, METAL_D);
    rect(cv, 30, dTop, W - 30, dTop + 2, METAL_L);
  } else {
    // solid closed slab with heavy horizontal ribs + central lock wheel
    rect(cv, 30, dTop, W - 30, dBot, METAL);
    for (let y = dTop; y < dBot; y++) for (let x = 30; x < W - 30; x++) px(cv, x, y, x > cx + 10 ? METAL_M : (x < cx - 20 ? METAL_D : METAL));
    for (let y = dTop + 6; y < dBot; y += 14) { rect(cv, 34, y, W - 34, y + 4, METAL_D); rect(cv, 34, y, W - 34, y + 1, METAL_M); }
    // lock wheel
    const wy = (dTop + dBot) / 2;
    for (let a = 0; a < 360; a += 3) { px(cv, cx + Math.cos(a * Math.PI / 180) * 20, wy + Math.sin(a * Math.PI / 180) * 20, METAL_L); px(cv, cx + Math.cos(a * Math.PI / 180) * 16, wy + Math.sin(a * Math.PI / 180) * 16, METAL_M); }
    for (let a = 0; a < 360; a += 45) { const r = a * Math.PI / 180; for (let t = 0; t < 20; t++) px(cv, cx + Math.cos(r) * t, wy + Math.sin(r) * t, METAL_M); }
    px(cv, cx, wy, METAL_D);
    // red lock indicator (inert data-lock, dim)
    glow(cv, cx, dTop + 10, 8, rgb('#c74a4a'), 90); px(cv, cx, dTop + 10, rgb('#f08a8a'), 220);
  }
  selout(cv, METAL_D);
  save(cv, name);
}
sealedBulkhead('l2s_sealed_bulkhead.png', false);
sealedBulkhead('l2s_sealed_bulkhead_open.png', true);

// l2s_backup_altar (H / GB4) — an offering pedestal/mount for the restoration core.
(function backupAltar() {
  const W = 128, H = 128, cv = C(W, H), cx = W / 2, s = 82250;
  ao(cv, cx, H - 10, 40, 11, 66);
  // tiered iso stone-metal pedestal
  isoCylinder(cv, cx, H - 44, 40, 20, METAL_M, mix(METAL_M, METAL_L, 0.3), METAL, 0.94);
  isoCylinder(cv, cx, H - 66, 28, 18, METAL_M, mix(METAL_M, METAL_L, 0.3), METAL, 0.94);
  // mount cradle on top — a hexagonal socket ringed with dim cyan nodes (empty offering slot)
  const topY = H - 74;
  const pts = [];
  for (let a = 0; a < 6; a++) { const r = a * Math.PI / 3 - Math.PI / 2; pts.push([cx + Math.cos(r) * 16, topY + Math.sin(r) * 8]); }
  for (let i = 0; i < 6; i++) { const a = pts[i], b = pts[(i + 1) % 6]; const st = Math.round(Math.hypot(b[0] - a[0], b[1] - a[1])); for (let t = 0; t <= st; t++) px(cv, a[0] + (b[0] - a[0]) * t / st, a[1] + (b[1] - a[1]) * t / st, METAL_L); }
  for (const [x, y] of pts) { glow(cv, x, y, 5, CYAN, 80); px(cv, x, y, CYAN, 210); }
  // empty dark socket in the middle (where the core will be placed)
  for (let y = -6; y <= 6; y++) for (let x = -12; x <= 12; x++) { const d = Math.abs(x) / 12 + Math.abs(y) / 6; if (d <= 1) px(cv, cx + x, topY + y, PANEL_D, 255); }
  glow(cv, cx, topY, 10, CYAN, 40);
  px(cv, cx, topY, CYAN_D, 160);
  // conduit lines up the pedestal front
  for (const dx of [-10, 0, 10]) for (let y = H - 46; y < H - 14; y += 3) px(cv, cx + dx, y, CYAN_D, 150);
  selout(cv, METAL_D);
  save(cv, 'l2s_backup_altar.png');
})();

// l2s_power_residue (E) — a small residual power node, cyan-glowing conduit box.
(function powerResidue() {
  const W = 80, H = 80, cv = C(W, H), cx = W / 2, s = 82300;
  ao(cv, cx, H - 8, 22, 6, 58);
  // small iso conduit box
  const topY = H - 40, rx = 18, h = 18;
  isoBox(cv, cx, topY, rx, h, METAL_M, mix(METAL_M, METAL_L, 0.4), METAL);
  // glowing cyan port on the lit face
  glow(cv, cx + 6, topY + rx / 2 + 6, 14, CYAN, 120);
  rect(cv, cx - 2, topY + rx / 2 + 2, cx + 12, topY + rx / 2 + 12, PANEL_D);
  rect(cv, cx, topY + rx / 2 + 4, cx + 10, topY + rx / 2 + 10, CYAN, 235);
  px(cv, cx + 5, topY + rx / 2 + 7, CYAN_HI, 240);
  // a couple frayed conduit stubs leaking cyan sparks
  for (let i = 0; i < 8; i++) px(cv, cx - rx + 2 - i, topY + rx / 2 + 4 + Math.round(Math.sin(i) * 2), METAL_L, 220);
  glow(cv, cx - rx - 4, topY + rx / 2 + 4, 5, CYAN, 110); px(cv, cx - rx - 4, topY + rx / 2 + 4, CYAN_HI, 220);
  selout(cv, METAL_D);
  save(cv, 'l2s_power_residue.png');
})();

// l2s_data_door (M / GB3) — a sealed data gate; l2s_data_door_open — read/open state.
function dataDoor(name, open) {
  const W = 128, H = 160, cv = C(W, H), cx = W / 2, s = 82350;
  ao(cv, cx, H - 10, 42, 11, 64);
  // slim tech door frame with circuit-etched jambs
  rect(cv, 20, 14, W - 20, H - 12, METAL_D);
  rect(cv, 24, 18, W - 24, H - 14, METAL);
  rect(cv, 24, 18, W - 24, 22, METAL_L);
  for (const fx of [28, W - 32]) { rect(cv, fx, 22, fx + 5, H - 16, METAL_M); for (let y = 26; y < H - 18; y += 6) px(cv, fx + 2, y, CYAN_D, 180); }
  const inX0 = 36, inX1 = W - 36, inY0 = 26, inY1 = H - 20;
  if (open) {
    // door split to the sides — a bright cyan data-gate reads open
    rect(cv, inX0, inY0, inX1, inY1, PANEL_D);
    glow(cv, cx, (inY0 + inY1) / 2, 60, CYAN, 90);
    // scrolling data streams down the open aperture
    const rnd = deterministic(s + 7);
    for (let i = 0; i < 46; i++) {
      const x = inX0 + 4 + Math.floor(rnd() * (inX1 - inX0 - 8));
      const y = inY0 + Math.floor(rnd() * (inY1 - inY0));
      const len = 3 + Math.floor(rnd() * 8);
      for (let k = 0; k < len; k++) px(cv, x, y + k, rnd() < 0.4 ? CYAN_HI : CYAN, 210);
    }
    // parted door halves pressed to each jamb
    rect(cv, inX0, inY0, inX0 + 10, inY1, METAL_M);
    rect(cv, inX1 - 10, inY0, inX1, inY1, METAL_M);
    rect(cv, inX0, inY0, inX0 + 2, inY1, METAL_L);
  } else {
    // closed slab with a dim circuit-etched data glyph + central seam
    rect(cv, inX0, inY0, inX1, inY1, METAL);
    for (let y = inY0; y < inY1; y++) for (let x = inX0; x < inX1; x++) px(cv, x, y, x > cx + 12 ? METAL_M : (x < cx - 16 ? METAL_D : METAL));
    // etched circuit traces (dim cyan)
    const rnd = deterministic(s + 3);
    for (let i = 0; i < 22; i++) {
      let x = inX0 + 6 + Math.floor(rnd() * (inX1 - inX0 - 12)), y = inY0 + 6 + Math.floor(rnd() * (inY1 - inY0 - 12));
      const horiz = rnd() < 0.5, len = 6 + Math.floor(rnd() * 16);
      for (let k = 0; k < len; k++) { px(cv, x, y, CYAN_D, 170); if (horiz) x++; else y++; }
      px(cv, x, y, CYAN, 180);
    }
    // central seam + a dim data-lock diamond
    rect(cv, cx - 1, inY0, cx + 1, inY1, METAL_D);
    const my = (inY0 + inY1) / 2;
    for (let y = -12; y <= 12; y++) for (let x = -12; x <= 12; x++) { if (Math.abs(x) + Math.abs(y) <= 12) px(cv, cx + x, my + y, mix(METAL_D, CYAN_D, 0.4), 255); }
    glow(cv, cx, my, 10, CYAN, 60); px(cv, cx, my, CYAN, 180);
  }
  selout(cv, METAL_D);
  save(cv, name);
}
dataDoor('l2s_data_door.png', false);
dataDoor('l2s_data_door_open.png', true);

console.log('EX-L2 (l2s 지하 데이터 성소) objects done.');
