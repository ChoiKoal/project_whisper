#!/usr/bin/env node
// tools_overview_l2.js — Layer-2 「꺼진 관문 기지」 (terminal_station) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l2.js [--closeup]
//
// The in-engine SubViewport render can't run under --headless (dummy driver, no framebuffer),
// so — as with the home/grove previews — this offline pngjs compositor draws the Layer-2 map
// the same way the game does: reads l2_map_layout.txt + l2_map_legend.json + l2_map_height.txt,
// projects the 40×40 grid in iso, blits the REAL science tiles (metal/concrete/waste/ash/
// coolant/dark) with the navy CanvasModulate tone + cyan additive glow on lit objects, then the
// authored objects (tower/screens/antenna/generators/breakers/bridge/door/neon/debris/crates/
// domes/lamps/workbench) at their legend y-offsets, elevation-lifted per l2_map_height.txt.
//
// Mood target (design §A-1): 남색 base #1a2438 + 시안 발광 #4ad9c8 + 금속 회색. "기계의 정적".
//
// --closeup → tight crop on the coolant canyon + energy bridge → /workspace/group/preview-l2-closeup.png
// overview  → /workspace/group/preview-l2.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const CLOSEUP = process.argv.includes("--closeup");
// (L2-6) --powered → render the POST-G4 station: bridge lit + walkable, shield door open, control
// tower + screens + generators + street lamps all ON, blackout bottleneck lifted. This is the
// state the player leaves the world in after the Layer-2 정화 컷신 — "다시 깨어난 기지".
const POWERED = process.argv.includes("--powered");
const OUT = CLOSEUP ? "/workspace/group/preview-l2-closeup.png"
          : POWERED ? "/workspace/group/preview-l2-powered.png"
                    : "/workspace/group/preview-l2.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/l2_map_layout.txt`);
const height = read(`${GAME}/data/l2_map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/l2_map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// map tileset source id → l2 tile png. Mirrors l2_map_legend.json tile sources.
const TILE_BY_SRC = {
  12: tileArt("l2_metal"), 13: tileArt("l2_metal_broken"), 14: tileArt("l2_concrete"),
  15: tileArt("l2_concrete_crack"), 16: tileArt("l2_waste"), 17: tileArt("l2_ash"),
  18: tileArt("l2_coolant_anim"), 19: tileArt("l2_dark"), 0: tileArt("l2_dark"),
};
const CYAN_POOL = objArt("light_pool_cyan");

// navy CanvasModulate mirror, eased ~40% toward neutral vs the in-game night tint (owner review:
// the full navy tint crushed the still image to a black남색 판독불가 murk — in-engine the dynamic
// lights + coolant glow compensate, a static preview can't). Ported from the owner-approved L3/L4
// treatment. Cool navy ratio kept (B>G>R) but lifted to L4/L5 readability.
const TONE = [0.86, 0.94, 1.06];
const GLOW_RGB = [0x4a, 0xd9, 0xc8]; // 시안 네온/냉각수 발광

// ---------------- CliffGen.make_apron mirror (steel/navy palette, L2) ---------
// Mirrors scripts/world/cliff_gen.gd make_apron(...): the in-game map loader runtime-generates
// steel cliff aprons at every exposed elevation boundary so the raised 관제 구역들 CONNECT to the
// lower ground (owner reject on the old clipped-skirt approach: "고도 구역들이 떠 있는 판처럼 조각남").
// Same geometry as the owner-approved L3/L4: front rim of the raised diamond extruded down `drop`
// levels, 시안 리벳 밴드 every 20px, cyan 냉각수 잔광 weeps, steel cap lip. Cool navy/steel palette
// so it reads as station bulkhead plating rather than rock.
const B_BASE = [58, 70, 92], B_DARK = [36, 46, 64], B_LIGHT = [120, 150, 180],
      B_SHADOW = [20, 28, 42], B_LIP = [82, 100, 126], B_LIP_DK = [46, 58, 78],
      B_EMBER = [74, 217, 200]; // 시안 냉각수 weep
function hash2(c, r, salt) {
  let h = (((c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ 0x9E3779B9) >>> 0);
  h = (Math.imul((h ^ (h >>> 13)) >>> 0, 1274126177) >>> 0);
  return ((h ^ (h >>> 16)) >>> 0) & 0x7FFFFFFF;
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xFFFF) / 65535; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function steelCol(s) {
  s = Math.min(Math.max(s, 0), 1.4);
  if (s < 0.7) return lerpC(B_SHADOW, B_DARK, s / 0.7);
  if (s < 1.0) return lerpC(B_DARK, B_BASE, (s - 0.7) / 0.3);
  return lerpC(B_BASE, B_LIGHT, Math.min((s - 1.0) / 0.4, 1));
}
// draw one exposed front edge (se = +col/down-right, sw = +row/down-left) of the cell whose
// LIFTED diamond centre is at (baseX, baseY). `drop` in levels (may be fractional for chasm edges);
// `fade` melts the bottom of the wall into the void so district rims read as bulkheads over a deep
// canyon instead of razor-cut floating plates.
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
      let col = steelCol(sideLight * vshade + facet + crack + n);
      if ((y - rimY) % 20 < 1) col = lerpC(col, B_LIGHT, 0.4);            // 시안-lit rivet band
      else if (!isLeft && rockNoise((x / 9) | 0, 0, salt + 3) < 0.06) col = lerpC(col, B_EMBER, 0.5); // 냉각수 잔광 weep
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
// ramp cells ('/') bridge two levels along the row axis: lift them to the average of their N/S
// neighbours (flat if both sides are level, half-step if transitioning down). Mirrors L3/L4.
function isRamp(c, r) { return !isVoid(c, r) && layout[r][c] === "/"; }
function liftAt(c, r) {
  if (isRamp(c, r)) return (heightAt(c, r - 1) + heightAt(c, r + 1)) / 2 * LIFT;
  return heightAt(c, r) * LIFT;
}
function levelAt(c, r) { return liftAt(c, r) / LIFT; }

// bounds over non-void cells (tile diamonds) AND authored objects (tall art like the control tower
// / big screen rises far above the cell baseline — include its full sprite rect so it isn't clipped).
let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  const lift = liftAt(c, r);
  minX = Math.min(minX, lx - HW); maxX = Math.max(maxX, lx + HW);
  minY = Math.min(minY, ly - lift - TH); maxY = Math.max(maxY, ly + TH * 3);
  const objSpec = legend.objects[layout[r][c]];
  if (objSpec) {
    const src = objArt(objSpec.art);
    if (src) {
      const off = objSpec.offset || [0, -8];
      minY = Math.min(minY, ly - lift - src.height + HH + off[1]);
      minX = Math.min(minX, lx - src.width / 2 + off[0]);
      maxX = Math.max(maxX, lx + src.width / 2 + off[0]);
    }
  }
}
const PAD = 60;
const worldW = maxX - minX + PAD * 2, worldH = maxY - minY + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;

const png = new PNG({ width: Math.ceil(worldW), height: Math.ceil(worldH) });

// ---------------- background: navy void + cyan nebula + starfield ------------
function bgAt(x, y) {
  const t = y / worldH;
  // navy base #1a2438 (design §A-1), lifted off near-black so오브젝트 read against it (owner
  // reject: "전체가 새까만 남색"). Slight darken toward the bottom, never crushing to black.
  let r = 0x1a + (1 - t) * 0x0c, g = 0x24 + (1 - t) * 0x0e, b = 0x38 + (1 - t) * 0x16;
  // cyan wash toward the centre-top (the tower's residual coolant glow bleeding into the void)
  const cx = worldW * 0.5, cy = worldH * 0.28;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const neb = Math.max(0, 1 - d) * 30;
  r += neb * 0.28; g += neb * 0.85; b += neb * 0.82;
  return [r, g, b];
}
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = 255;
}
// starfield
for (let i = 0; i < 900; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 120 + h32(i, 3, 9) * 120;
  const cyan = h32(i, 17, 2) > 0.6;
  put(x, y, cyan ? [br * 0.6, br, br] : [br, br, br], 0.8);
  if (h32(i, 23, 4) > 0.93) { // a few larger twinklers
    put(x + 1, y, [br, br, br], 0.4); put(x - 1, y, [br, br, br], 0.4);
    put(x, y + 1, [br, br, br], 0.4); put(x, y - 1, [br, br, br], 0.4);
  }
}

function put(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  // clamp to [0,255] (ported bugfix from L4/L5): the lifted TONE (B channel >1) + additive nebula
  // can push a bright highlight past 255, and png.data is a Uint8Array (wraps mod 256) — an
  // un-clamped >255 would wrap and paint a false magenta/black colour speck. Saturate instead.
  png.data[i] = Math.min(255, png.data[i] * (1 - a) + rgb[0] * a);
  png.data[i + 1] = Math.min(255, png.data[i + 1] * (1 - a) + rgb[1] * a);
  png.data[i + 2] = Math.min(255, png.data[i + 2] * (1 - a) + rgb[2] * a);
  png.data[i + 3] = 255;
}
// additive (for glows)
function add(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  png.data[i] = Math.min(255, png.data[i] + rgb[0] * a);
  png.data[i + 1] = Math.min(255, png.data[i + 1] + rgb[1] * a);
  png.data[i + 2] = Math.min(255, png.data[i + 2] + rgb[2] * a);
}

// blit a source png at screen (sx,sy) = top-left, with tone multiply + optional additive
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

// cyan additive glow blob
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
  // ramp cells ('/') have no dedicated L2 tile — they are metal walkway transitions between the
  // raised 관제 구역 and the door bottleneck, so render them as metal (source 12).
  const src = sym === "/" ? TILE_BY_SRC[12] : (() => {
    const spec = legend.tiles[sym]; return spec ? TILE_BY_SRC[spec.source] : null;
  })();
  if (!src) continue;
  const [sx, sy] = tileScreen(c, r);
  blit(src, sx, sy, { tone: true, srcW: Math.min(src.width, TW) });
}

// cliff aprons (CliffGen mirror): every exposed S/E front edge gets a steel apron so the elevation
// transitions CONNECT — raised 관제 구역 → ground steps, and district rims → the chasm void (drawn
// deeper, bottom-faded, so the gaps between the floating 판 read as a canyon with depth rather than
// razor-cut floating plates / 조각난 판). Ported from the owner-approved L3/L4 treatment.
const CHASM_DROP = 2.4; // how far district rims plunge past their own level into the void
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const lv = levelAt(c, r);
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const salt = hash2(c, r, 733);
  // per-edge drop: S (+row, screen down-left) and E (+col, screen down-right)
  for (const [edge, nc, nr] of [["S", c, r + 1], ["E", c + 1, r]]) {
    const se = edge === "E", sw = edge === "S";
    if (isVoid(nc, nr)) {
      // only skirt into the void from a RAISED rim — flat ground cells beside the void must not
      // grow a full chasm wall (the lower half of the map is a flat level-0 apron between voids).
      if (lv > 0) drawApron(baseX, baseY, lv + CHASM_DROP, se, sw, salt, true);
    } else if (levelAt(nc, nr) < lv) {
      drawApron(baseX, baseY, lv - levelAt(nc, nr), se, sw, salt, false);
    }
  }
}

// ---------------- draw objects (with glow) ----------------------------------
const OBJ_ART = POWERED ? { // (L2-6) POST-G4 powered state: lit/on/open variants + brighter glow.
  m: ["l2_debris_scrap", 0], R: ["l2_scrap", 0], s: ["l2_crate", 0], F: ["l2_dome", 0.25],
  N: ["l2_neon", 0.95], T: ["l2_lamp_lit", 0.55], E: ["l2_gen_main_on", 0.5], e: ["l2_gen_sub_on", 0.45],
  K: ["l2_breaker", 0.2], B: ["l2_bridge_on", 0.6], D: ["l2_door_open", 0],
  O: ["l2_tower_lit", 0.7], "1": ["l2_screen_on", 0.45], "2": ["l2_antenna", 0.55], "4": ["l2_crate", 0],
} : { // l2 legend object sym → art png name + is-lit glow (dead/dormant baseline)
  m: ["l2_debris_scrap", 0], R: ["l2_scrap", 0], s: ["l2_crate", 0], F: ["l2_dome", 0.15],
  N: ["l2_neon", 0.9], T: ["l2_lamp", 0], E: ["l2_gen_main", 0], e: ["l2_gen_sub", 0],
  K: ["l2_breaker", 0], B: ["l2_bridge_off", 0], D: ["l2_door_closed", 0],
  O: ["l2_tower", 0.25], "1": ["l2_screen_off", 0.2], "2": ["l2_antenna", 0.4], "4": ["l2_crate", 0],
};
// collect object draws with a depth key so they y-sort over tiles correctly.
const draws = [];
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = layout[r][c];
  const objSpec = legend.objects[sym];
  const artInfo = OBJ_ART[sym];
  if (!objSpec && !artInfo) continue;
  // blackout gate cells: the sealed N bottleneck (rows<17, central) get the blackout overlay —
  // UNLESS powered (the G3 정전 병목 is lit once the station reawakens; the neon reads bright).
  let art, off, glowStrength;
  const isBlackoutN = !POWERED && sym === "N" && r < 17 && c >= 16 && c <= 21;
  if (isBlackoutN) { art = "l2_blackout"; off = [0, -8]; glowStrength = 0; }
  else if (artInfo) {
    art = artInfo[0]; glowStrength = artInfo[1];
    off = (objSpec && objSpec.offset) ? objSpec.offset : [0, -8];
  } else continue;
  const src = objArt(art);
  if (!src) continue;
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const sx = Math.round(baseX - src.width / 2 + off[0]);
  const sy = Math.round(baseY - src.height + HH + off[1]);
  draws.push({ depth: c + r, sx, sy, src, glowStrength,
    gx: baseX, gy: baseY - src.height * 0.4 + off[1] * 0.4 + HH });
}
draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) {
    // preview-only glow boost: the legend's glow_scale drives a large in-engine PointLight2D; a
    // small additive blob is invisible in a still, so lit machines (neon/antenna/tower/screens/
    // generators) get a halo scaled to their sprite so the 시안 발광 reads. Ported from L3/L4.
    const rad = Math.max(34, Math.round(d.src.width * 0.45));
    glow(Math.round(d.gx), Math.round(d.gy), rad, d.glowStrength);
  }
  blit(d.src, d.sx, d.sy, { tone: true });
}

// (L2-6) POWERED: lay cyan light pools + floor glow on the now-lit walkways — the energy bridge
// (B) and the opened shield door (D) read as illuminated, walkable paths (post-G1/G2). Mirrors
// the in-game _light_bridge / _open_door cyan pool decals.
if (POWERED) {
  for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
    const sym = layout[r][c];
    if (sym !== "B" && sym !== "D") continue;
    const [lx, ly] = cellLocal(c, r);
    const bx = OX + lx, by = OY + ly - liftAt(c, r);
    if (CYAN_POOL) blit(CYAN_POOL, Math.round(bx - CYAN_POOL.width / 2),
      Math.round(by - CYAN_POOL.height / 2 + HH * 0.4), { additive: true, alpha: 0.6 });
    glow(Math.round(bx), Math.round(by + HH * 0.3), 26, 0.4);
  }
}

// workbench (spawned by the session, not a layout symbol) at special.workbench_cell
const wb = legend.special && legend.special.workbench_cell;
if (wb) {
  const src = objArt("l2_workbench");
  if (src) {
    const [lx, ly] = cellLocal(wb[0], wb[1]);
    const bx = OX + lx, by = OY + ly - liftAt(wb[0], wb[1]);
    glow(Math.round(bx), Math.round(by - 20), 30, 0.5);
    blit(src, Math.round(bx - src.width / 2), Math.round(by - src.height + HH - 44), { tone: true });
  }
}

// ---------------- vignette ---------------------------------------------------
const vcx = png.width / 2, vcy = png.height / 2, vmax = Math.hypot(vcx, vcy);
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const d = Math.hypot(x - vcx, y - vcy) / vmax;
  // eased vignette (L3/L4 lineage): a gentler falloff so the outer 관제 구역 don't crush to black —
  // the old (d-0.55)*0.7 curve was part of what made the frame read "전체가 새까만 남색".
  const v = Math.max(0, (d - 0.62)) * 0.5;
  if (v <= 0) continue;
  const i = (y * png.width + x) << 2;
  png.data[i] *= (1 - v); png.data[i + 1] *= (1 - v); png.data[i + 2] *= (1 - v);
}

// ---------------- closeup crop ----------------------------------------------
let outPng = png;
if (CLOSEUP) {
  // crop on the coolant canyon (rows 24-28) + energy bridge (col 18-19). Compute screen box.
  let cminX = 1e9, cminY = 1e9, cmaxX = -1e9, cmaxY = -1e9;
  for (let r = 22; r <= 30; r++) for (let c = 6; c <= 33; c++) {
    if (isVoid(c, r)) continue;
    const [lx, ly] = cellLocal(c, r);
    const x = OX + lx, y = OY + ly;
    cminX = Math.min(cminX, x - HW); cmaxX = Math.max(cmaxX, x + HW);
    cminY = Math.min(cminY, y - TH); cmaxY = Math.max(cmaxY, y + TH * 2);
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
