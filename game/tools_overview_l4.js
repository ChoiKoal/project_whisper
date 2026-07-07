#!/usr/bin/env node
// tools_overview_l4.js — Layer-4 「봉인이 풀린 마탑」 (mage_tower) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l4.js [--closeup]
//
// Adapted from the owner-approved tools_overview_l3.js. Same story: the in-engine SubViewport
// can't run under --headless (dummy driver, no framebuffer), so this offline pngjs compositor
// draws the Layer-4 map the way the game does: reads l4_map_layout.txt + l4_map_legend.json +
// l4_map_height.txt, projects the 40×40 grid in iso, blits the REAL magic tiles (amethyst/rune-
// conduit/rune-corridor/floating-shard(+1)/chamber(+2)/dark/crack) with an amethyst-violet
// CanvasModulate tone + GOLD additive glow on lit objects, then the authored objects
// (rune_node/mana_geode/silver_vein/vellum_roll/wax_lump/dew_pool/void_shard/mana_spring/
// ward_pillar/rune_bridge/ward_door/crack_gate/seal_neck/seal_core/…) at their legend offsets,
// elevation-lifted per l4_map_height.txt (shard-district +1, chamber/seal-vault +2).
//
// Floating debris / cracks are carried by the authored object art (l4_float_shard, l4_debris_*,
// the crack tile source 32) placed at legend offsets — the compositor just blits them; no extra
// procedural fracture pass needed (design §A-1: "부유 파편/균열은 아트로").
//
// The G1 rune 제단 (rune_altar) + G4 봉인 코어 배전반 (seal_mount) are NOT layout symbols — the
// in-game gate controller spawns them at gates.G1.altar / gates.G4.mount. We mirror that here so
// the seal-vault reads complete.
//
// Mood target (design §A-1): 자수정 보라 base + 금 룬 발광 + 창백한 마력 안개. "봉인이 풀린 마탑".
//
// --closeup → tight crop on the 최심부 봉인실 (seal core chamber, rows 0-5) → preview-l4-closeup.png
// overview  → preview-l4.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const CLOSEUP = process.argv.includes("--closeup");
const OUT = CLOSEUP ? "/workspace/group/preview-l4-closeup.png"
                    : "/workspace/group/preview-l4.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/l4_map_layout.txt`);
const height = read(`${GAME}/data/l4_map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/l4_map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// map tileset source id → l4 tile png. Mirrors l4_map_legend.json tile sources (26-32) and the
// whisper_tileset.tres ext_resource ids (26_l4a … 32_l4x).
const TILE_BY_SRC = {
  26: tileArt("l4_amethyst"), 27: tileArt("l4_pipe"), 28: tileArt("l4_rune"),
  29: tileArt("l4_platform"), 30: tileArt("l4_chamber"), 31: tileArt("l4_dark"),
  32: tileArt("l4_crack"),
  0: tileArt("l4_dark"),
};
const RAMP = tileArt("l4_ramp");

// amethyst-violet CanvasModulate mirror, eased toward neutral vs the in-game night tint (owner
// review lesson from L3: the full tint crushed the still to mud — the dynamic lights compensate
// in-engine, a static preview can't). Cool violet ratio kept (B≳R>G).
const TONE = [0.94, 0.80, 1.06];
const GLOW_RGB = [0xff, 0xcf, 0x5a]; // 금 룬 발광 (gold)

// ---------------- CliffGen.make_apron mirror (amethyst palette, L4) -----------
// Mirrors scripts/world/cliff_gen.gd make_apron(...): the in-game map loader runtime-generates
// amethyst cliff aprons at every exposed elevation boundary so raised districts CONNECT to the
// lower ground (owner reject on the clipped-art approach: "높이가 전혀 안 이어져 보임"). Same
// geometry as L3: front rim of the raised diamond extruded down `drop` levels, gold rune bands
// every 20px, gold 마력 잔광 weeps, amethyst cap lip.
const B_BASE = [86, 66, 104], B_DARK = [54, 40, 68], B_LIGHT = [176, 138, 214],
      B_SHADOW = [32, 22, 42], B_LIP = [126, 96, 158], B_LIP_DK = [82, 60, 104],
      B_EMBER = [236, 200, 96]; // gold rune weep
function hash2(c, r, salt) {
  let h = (((c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ 0x9E3779B9) >>> 0);
  h = (Math.imul((h ^ (h >>> 13)) >>> 0, 1274126177) >>> 0);
  return ((h ^ (h >>> 16)) >>> 0) & 0x7FFFFFFF;
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xFFFF) / 65535; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function brassCol(s) {
  s = Math.min(Math.max(s, 0), 1.4);
  if (s < 0.7) return lerpC(B_SHADOW, B_DARK, s / 0.7);
  if (s < 1.0) return lerpC(B_DARK, B_BASE, (s - 0.7) / 0.3);
  return lerpC(B_BASE, B_LIGHT, Math.min((s - 1.0) / 0.4, 1));
}
function drawApron(baseX, baseY, drop, exposeSE, exposeSW, salt, fade) {
  const wall = Math.round(LIFT * drop);
  const x0 = Math.round(baseX - HW), y0 = Math.round(baseY - HH);
  for (let x = 0; x < TW; x++) {
    const isLeft = x < HW;
    const exposed = isLeft ? exposeSW : exposeSE;
    if (!exposed) continue;
    const rimY = Math.round(isLeft ? (HH + x * 0.5) : ((TW - x) * 0.5 + HH));
    const sideLight = isLeft ? 0.74 : 1.10;
    for (let y = rimY; y < rimY + wall; y++) {
      const t = (y - rimY) / Math.max(1, wall);
      const vshade = 1.0 - 0.30 * t;
      const strata = Math.floor(rockNoise((x / 6) | 0, (y / 5) | 0, salt) * 5.0) / 5.0;
      const facet = (strata - 0.4) * 0.5;
      const crack = (rockNoise((x / 3) | 0, (y / 7) | 0, salt + 5) < 0.14) ? -0.34 : 0.0;
      const n = rockNoise(x, y, salt) * 0.12 - 0.06;
      let col = brassCol(sideLight * vshade + facet + crack + n);
      if ((y - rimY) % 20 < 1) col = lerpC(col, B_LIGHT, 0.4);            // gold-ish rune band
      else if (!isLeft && rockNoise((x / 9) | 0, 0, salt + 3) < 0.06) col = lerpC(col, B_EMBER, 0.5); // 마력 잔광 weep
      const a = fade ? Math.min(1, Math.max(0, (1 - t) / 0.5)) : 1;
      put(x0 + x, y0 + y, col, a);
    }
    const lipH = 5, jag = Math.floor(rockNoise(x, 7, salt) * 3.0);
    for (let y = rimY; y < rimY + lipH - jag; y++) {
      const g = ((x + y) % 3 !== 0) ? B_LIP : B_LIP_DK;
      put(x0 + x, y0 + y, g, 1);
    }
  }
}

// ---------------- iso projection --------------------------------------------
function cellLocal(c, r) { return [(c - r) * HW, (c + r) * HH]; }
function heightAt(c, r) {
  if (r < 0 || r >= height.length) return 0;
  const row = height[r]; if (c < 0 || c >= row.length) return 0;
  const ch = row[c]; return ch === "2" ? 2 : ch === "1" ? 1 : 0;
}
function isVoid(c, r) {
  return !(r >= 0 && r < H && c >= 0 && c < layout[r].length) || layout[r][c] === "V";
}
function isRamp(c, r) { return !isVoid(c, r) && layout[r][c] === "/"; }
function liftAt(c, r) {
  if (isRamp(c, r)) return (heightAt(c, r - 1) + heightAt(c, r + 1)) / 2 * LIFT;
  return heightAt(c, r) * LIFT;
}
function levelAt(c, r) { return liftAt(c, r) / LIFT; }

// gate mounts spawned by the controller (not layout symbols): render them so the seal-vault reads
// complete. G1 rune_altar at gates.G1.altar, G4 seal_mount at gates.G4.mount.
const SPAWNED = [];
if (legend.gates) {
  const g1 = legend.gates.G1, g4 = legend.gates.G4;
  if (g1 && g1.altar) g1.altar.forEach(([c, r]) => SPAWNED.push({ c, r, art: "l4_rune_altar", off: [0, -34], glow: 0.35 }));
  if (g4 && g4.mount) g4.mount.forEach(([c, r]) => SPAWNED.push({ c, r, art: "l4_seal_mount", off: [0, -40], glow: 0.4 }));
}

// bounds over non-void cells AND authored objects AND spawned mounts (tall art rises above the
// cell baseline — include full sprite rects so nothing is clipped).
let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
function extendBounds(lx, ly, lift, src, off) {
  const o = off || [0, -8];
  const topY = ly - lift - src.height + HH + o[1];
  minY = Math.min(minY, topY);
  minX = Math.min(minX, lx - src.width / 2 + o[0]);
  maxX = Math.max(maxX, lx + src.width / 2 + o[0]);
}
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  const lift = liftAt(c, r);
  minX = Math.min(minX, lx - HW); maxX = Math.max(maxX, lx + HW);
  minY = Math.min(minY, ly - lift - TH); maxY = Math.max(maxY, ly + TH * 3);
  const objSpec = legend.objects[layout[r][c]];
  if (objSpec) { const src = objArt(objSpec.art); if (src) extendBounds(lx, ly, lift, src, objSpec.offset); }
}
for (const s of SPAWNED) {
  const [lx, ly] = cellLocal(s.c, s.r); const src = objArt(s.art);
  if (src) extendBounds(lx, ly, liftAt(s.c, s.r), src, s.off);
}
const PAD = 60;
const worldW = maxX - minX + PAD * 2, worldH = maxY - minY + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;

const png = new PNG({ width: Math.ceil(worldW), height: Math.ceil(worldH) });

// ---------------- background: pale mana fog + violet void + gold rune motes ----
function bgAt(x, y) {
  const t = y / worldH;
  // deep amethyst void → darker toward the bottom (마력 안개 낀 봉인의 어둠)
  let r = 0x22 + (1 - t) * 0x12, g = 0x18 + (1 - t) * 0x0c, b = 0x30 + (1 - t) * 0x1a;
  // gold wash toward the centre-top (the seal core's residual glow bleeding into the fog)
  const cx = worldW * 0.5, cy = worldH * 0.24;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const gold = Math.max(0, 1 - d) * 34;
  r += gold * 0.85; g += gold * 0.66; b += gold * 0.30;
  // pale mana fog band across the middle (창백한 마력 안개)
  const fog = Math.max(0, 1 - Math.abs(t - 0.5) / 0.5) * 10;
  r += fog * 0.7; g += fog * 0.6; b += fog * 0.85;
  return [r, g, b];
}
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = 255;
}
// gold rune motes (warm gold sparks drifting in violet fog)
for (let i = 0; i < 800; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 100 + h32(i, 3, 9) * 130;
  const gold = h32(i, 17, 2) > 0.35;
  put(x, y, gold ? [br, br * 0.82, br * 0.36] : [br * 0.82, br * 0.8, br], 0.75);
  if (h32(i, 23, 4) > 0.94) { put(x + 1, y, [br, br * 0.8, br * 0.4], 0.35); put(x, y + 1, [br, br * 0.8, br * 0.4], 0.35); }
}

function put(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  // clamp to [0,255]: the amethyst TONE (B channel >1) can push a bright highlight past 255, and
  // png.data is a Uint8Array (wraps mod 256) — an un-clamped >255 would wrap and paint a false
  // colour speck. Clamp so bright pixels saturate instead of wrapping.
  png.data[i] = Math.min(255, png.data[i] * (1 - a) + rgb[0] * a);
  png.data[i + 1] = Math.min(255, png.data[i + 1] * (1 - a) + rgb[1] * a);
  png.data[i + 2] = Math.min(255, png.data[i + 2] * (1 - a) + rgb[2] * a);
  png.data[i + 3] = 255;
}
function add(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  png.data[i] = Math.min(255, png.data[i] + rgb[0] * a);
  png.data[i + 1] = Math.min(255, png.data[i + 1] + rgb[1] * a);
  png.data[i + 2] = Math.min(255, png.data[i + 2] + rgb[2] * a);
}

function blit(src, sx, sy, { tone = false, alpha = 1, additive = false, srcW = null } = {}) {
  if (!src) return;
  const sw = srcW || src.width;
  for (let py = 0; py < src.height; py++) for (let px = 0; px < sw; px++) {
    const si = (py * src.width + px) << 2;
    const a = (src.data[si + 3] / 255) * alpha;
    if (a <= 0.003) continue;
    let r = src.data[si], g = src.data[si + 1], b = src.data[si + 2];
    if (tone) { r *= TONE[0]; g *= TONE[1]; b *= TONE[2]; }
    if (additive) add(sx + px, sy + py, [r, g, b], a);
    else put(sx + px, sy + py, [r, g, b], a);
  }
}

// gold additive glow blob
function glow(cx, cy, radius, strength) {
  for (let py = -radius; py <= radius; py++) for (let px = -radius; px <= radius; px++) {
    const d = Math.hypot(px, py) / radius; if (d > 1) continue;
    const a = (1 - d) * (1 - d) * strength;
    add(cx + px, cy + py, GLOW_RGB, a);
  }
}

// ---------------- draw tiles (painter's order: back rows first) --------------
function tileScreen(c, r) {
  const [lx, ly] = cellLocal(c, r);
  return [OX + lx - HW, OY + ly - liftAt(c, r) - HH];
}
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = layout[r][c];
  if (sym === "V") continue;
  let src;
  if (sym === "/") { src = RAMP; }
  else {
    const spec = legend.tiles[sym];
    if (!spec) continue;
    src = TILE_BY_SRC[spec.source];
  }
  if (!src) continue;
  const [sx, sy] = tileScreen(c, r);
  blit(src, sx, sy, { tone: true, srcW: Math.min(src.width, TW) });
}

// cliff aprons (CliffGen mirror): every exposed S/E front edge gets an amethyst apron so the
// elevation transitions CONNECT — raised chamber/shard districts step down to the lower plaza,
// and district rims plunge into the chasm void (drawn deeper, bottom-faded, so the gaps read as
// a canyon with depth rather than floating plates).
const CHASM_DROP = 2.4;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const lv = levelAt(c, r);
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const salt = hash2(c, r, 733);
  for (const [edge, nc, nr] of [["S", c, r + 1], ["E", c + 1, r]]) {
    const se = edge === "E", sw = edge === "S";
    if (isVoid(nc, nr)) {
      drawApron(baseX, baseY, lv + CHASM_DROP, se, sw, salt, true);
    } else if (levelAt(nc, nr) < lv) {
      drawApron(baseX, baseY, lv - levelAt(nc, nr), se, sw, salt, false);
    }
  }
}

// ---------------- draw objects (with glow) ----------------------------------
// preview-only glow boost: the legend's glow_scale drives a large in-engine PointLight2D; a small
// additive blob is invisible in a still, so the lit machines (mana_geode, dew_pool, mana_spring,
// the seal_core face, spawned rune_altar/seal_mount) get halos strong enough to read. 금 발광 =
// the mood anchor.
const GLOW_PREVIEW = { m: 0.6, d: 0.55, E: 0.7, 2: 0.7, 1: 1.0, L: 0.45, 3: 0.45, C: 0.35 };
const MIST_SYMS = new Set(["E", "2", "d"]); // mana spring + dew: rising pale mana mist wisps
const draws = [];
function pushDraw(sym, art, off, glowStrength, c, r, mist) {
  const src = objArt(art);
  if (!src) return;
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const sx = Math.round(baseX - src.width / 2 + off[0]);
  const sy = Math.round(baseY - src.height + HH + off[1]);
  draws.push({ depth: c + r, sx, sy, src, glowStrength, mist,
    gx: baseX, gy: baseY - src.height * 0.4 + off[1] * 0.4 + HH, seed: hash2(c, r, 41) });
}
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = layout[r][c];
  const objSpec = legend.objects[sym];
  if (!objSpec) continue;
  const off = objSpec.offset || [0, -8];
  const legendGlow = objSpec.glow === "gold" ? (objSpec.glow_scale || 0.4) : 0;
  const glowStrength = Math.max(legendGlow, GLOW_PREVIEW[sym] || 0);
  pushDraw(sym, objSpec.art, off, glowStrength, c, r, MIST_SYMS.has(sym));
}
// spawned gate mounts (rune_altar / seal_mount)
for (const s of SPAWNED) pushDraw("_spawn", s.art, s.off, s.glow, s.c, s.r, false);

draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) {
    const rad = Math.max(44, Math.round(d.src.width * 0.45));
    glow(Math.round(d.gx), Math.round(d.gy), rad, d.glowStrength);
  }
  blit(d.src, d.sx, d.sy, { tone: true });
  if (d.mist) { // rising pale-gold mana mist wisps
    const topY = d.sy + 6;
    for (let k = 0; k < 5; k++) {
      const t = k / 5;
      const wx = d.gx + Math.sin(d.seed % 7 + k * 1.9) * (6 + 14 * t);
      const wy = topY - 10 - k * 13;
      const wr = 7 + k * 3, wa = 0.16 * (1 - t * 0.7);
      for (let py = -wr; py <= wr; py++) for (let px = -wr; px <= wr; px++) {
        const dd = Math.hypot(px, py) / wr; if (dd > 1) continue;
        add(wx + px, wy + py, [236, 224, 190], (1 - dd) * (1 - dd) * wa);
      }
    }
  }
}

// workbench (spawned by the session, not a layout symbol) at special.workbench_cell
const wb = legend.special && legend.special.workbench_cell;
if (wb) {
  const src = objArt("l4_workbench");
  if (src) {
    const [lx, ly] = cellLocal(wb[0], wb[1]);
    const bx = OX + lx, by = OY + ly - liftAt(wb[0], wb[1]);
    glow(Math.round(bx), Math.round(by - 24), 30, 0.35);
    blit(src, Math.round(bx - src.width / 2), Math.round(by - src.height + HH - 20), { tone: true });
  }
}

// ---------------- vignette ---------------------------------------------------
const vcx = png.width / 2, vcy = png.height / 2, vmax = Math.hypot(vcx, vcy);
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const d = Math.hypot(x - vcx, y - vcy) / vmax;
  const v = Math.max(0, (d - 0.62)) * 0.5;
  if (v <= 0) continue;
  const i = (y * png.width + x) << 2;
  png.data[i] *= (1 - v); png.data[i + 1] *= (1 - v); png.data[i + 2] *= (1 - v);
}

// ---------------- closeup crop ----------------------------------------------
let outPng = png;
if (CLOSEUP) {
  // crop on the 최심부 봉인실 (seal core chamber = the top +2 chamber district, rows 0-6), tight on
  // the seal_core '1' + spawned seal_mount neck rising far above the cell baseline.
  let cminX = 1e9, cminY = 1e9, cmaxX = -1e9, cmaxY = -1e9;
  for (let r = 0; r <= 6; r++) for (let c = 12; c <= 26; c++) {
    if (isVoid(c, r)) continue;
    const [lx, ly] = cellLocal(c, r);
    const x = OX + lx, y = OY + ly - liftAt(c, r);
    cminX = Math.min(cminX, x - HW); cmaxX = Math.max(cmaxX, x + HW);
    cminY = Math.min(cminY, y - TH); cmaxY = Math.max(cmaxY, y + TH * 2);
    const objSpec = legend.objects[layout[r][c]];
    if (objSpec) {
      const src = objArt(objSpec.art);
      if (src) {
        const off = objSpec.offset || [0, -8];
        cminY = Math.min(cminY, y - src.height + HH + off[1] - 8);
        cminX = Math.min(cminX, x - src.width / 2 + off[0]);
        cmaxX = Math.max(cmaxX, x + src.width / 2 + off[0]);
      }
    }
  }
  // include spawned seal_mount at (19,2)
  for (const s of SPAWNED) {
    if (s.r > 6) continue;
    const [lx, ly] = cellLocal(s.c, s.r); const src = objArt(s.art);
    if (!src) continue;
    const x = OX + lx, y = OY + ly - liftAt(s.c, s.r);
    cminY = Math.min(cminY, y - src.height + HH + s.off[1] - 8);
    cminX = Math.min(cminX, x - src.width / 2 + s.off[0]);
    cmaxX = Math.max(cmaxX, x + src.width / 2 + s.off[0]);
  }
  const cw = Math.ceil(cmaxX - cminX), ch = Math.ceil(cmaxY - cminY);
  const crop = new PNG({ width: cw, height: ch });
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const sx = Math.floor(cminX) + x, sy = Math.floor(cminY) + y;
    const di = (y * cw + x) << 2;
    if (sx < 0 || sy < 0 || sx >= png.width || sy >= png.height) { crop.data[di + 3] = 255; continue; }
    const si = (sy * png.width + sx) << 2;
    crop.data[di] = png.data[si]; crop.data[di + 1] = png.data[si + 1];
    crop.data[di + 2] = png.data[si + 2]; crop.data[di + 3] = 255;
  }
  outPng = crop;
}

fs.writeFileSync(OUT, PNG.sync.write(outPng));
console.log(`wrote ${OUT} (${outPng.width}x${outPng.height})`);
