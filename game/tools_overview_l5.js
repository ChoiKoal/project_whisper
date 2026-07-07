#!/usr/bin/env node
// tools_overview_l5.js — Layer-5 「응답 없는 대성당」 (cathedral) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l5.js [--closeup]
//
// Adapted from the owner-approved tools_overview_l3.js (→l4). Same story: the in-engine
// SubViewport can't run under --headless, so this offline pngjs compositor draws the Layer-5 map
// the way the game does: reads l5_map_layout.txt + l5_map_legend.json + l5_map_height.txt,
// projects the 40×40 grid in iso, blits the REAL sanctity tiles (ivory-pave/silver-plaza/
// silence-corridor(+1)/upper-choir(+1)/great-altar(+2)/dark/ramp) with a pale ivory/silver
// CanvasModulate tone + warm AMBER ember additive glow on lit objects, then the authored objects
// (holy_font/relic_pile/marble_chunk/bead_string/hymn_sheet/ash_wing/divine_ember/lantern_altar/
// life_spring/choir_stand/pilgrim_dynamo/mana_reliquary/silence_gate/great_altar/…) at their
// legend offsets, elevation-lifted per l5_map_height.txt (choir/corridor +1, altar-vault +2).
//
// The G4 대제단 봉헌대 (offering_altar) is NOT a layout symbol — the in-game gate controller
// spawns it at gates.G4.mount (19,2). We mirror that so the great altar reads complete.
//
// Mood target (design §A-1): 창백한 상아/백은 base + 호박 잔불 글로우 + 정적. "응답 없는 대성당".
//
// --closeup → tight crop on the 대제단 (great altar, rows 0-5) → preview-l5-closeup.png
// overview  → preview-l5.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const CLOSEUP = process.argv.includes("--closeup");
const OUT = CLOSEUP ? "/workspace/group/preview-l5-closeup.png"
                    : "/workspace/group/preview-l5.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/l5_map_layout.txt`);
const height = read(`${GAME}/data/l5_map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/l5_map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// map tileset source id → l5 tile png. Mirrors l5_map_legend.json tile sources (33-39) and the
// whisper_tileset.tres ext_resource ids (33_l5i … 39_l5r).
const TILE_BY_SRC = {
  33: tileArt("l5_ivory"), 34: tileArt("l5_silver"), 35: tileArt("l5_quiet"),
  36: tileArt("l5_choir"), 37: tileArt("l5_altar"), 38: tileArt("l5_dark"),
  39: tileArt("l5_ramp"),
  0: tileArt("l5_dark"),
};
const RAMP = tileArt("l5_ramp");

// pale ivory/silver CanvasModulate mirror, eased toward neutral (owner review lesson from L3:
// the full night tint crushed the still to mud). Cool-pale ratio kept but LIFTED overall so the
// cathedral reads bright/holy, not gloomy (design §A-1: 창백한 상아/백은 — the palest of the 5).
const TONE = [1.04, 1.02, 1.08];
const GLOW_RGB = [0xff, 0xc4, 0x6a]; // 호박 잔불 (amber ember)

// ---------------- CliffGen.make_apron mirror (ivory/silver palette, L5) -------
// Mirrors scripts/world/cliff_gen.gd make_apron(...): amethyst→ivory palette. Elevation boundary
// aprons so raised choir/corridor/altar districts CONNECT to the lower ivory floor. Same geometry
// as L3/L4: front rim extruded down `drop` levels, silver bands every 20px, amber 잔불 weeps,
// ivory cap lip.
const B_BASE = [150, 142, 128], B_DARK = [104, 98, 88], B_LIGHT = [232, 226, 208],
      B_SHADOW = [70, 66, 60], B_LIP = [200, 194, 178], B_LIP_DK = [150, 144, 130],
      B_EMBER = [236, 176, 96]; // amber ember weep
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
    const sideLight = isLeft ? 0.78 : 1.10;
    for (let y = rimY; y < rimY + wall; y++) {
      const t = (y - rimY) / Math.max(1, wall);
      const vshade = 1.0 - 0.26 * t;
      const strata = Math.floor(rockNoise((x / 6) | 0, (y / 5) | 0, salt) * 5.0) / 5.0;
      const facet = (strata - 0.4) * 0.5;
      const crack = (rockNoise((x / 3) | 0, (y / 7) | 0, salt + 5) < 0.12) ? -0.30 : 0.0;
      const n = rockNoise(x, y, salt) * 0.12 - 0.06;
      let col = brassCol(sideLight * vshade + facet + crack + n);
      if ((y - rimY) % 20 < 1) col = lerpC(col, B_LIGHT, 0.4);            // silver band
      else if (!isLeft && rockNoise((x / 9) | 0, 0, salt + 3) < 0.06) col = lerpC(col, B_EMBER, 0.5); // 잔불 weep
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

// gate mount spawned by the controller (not a layout symbol): G4 offering_altar at gates.G4.mount.
const SPAWNED = [];
if (legend.gates && legend.gates.G4 && legend.gates.G4.mount) {
  legend.gates.G4.mount.forEach(([c, r]) => SPAWNED.push({ c, r, art: "l5_offering_altar", off: [0, -40], glow: 0.4 }));
}

// bounds over non-void cells AND authored objects AND spawned mount.
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

// ---------------- background: pale silence + amber altar wash + ember motes ----
function bgAt(x, y) {
  const t = y / worldH;
  // pale twilight nave — lighter than the other worlds (창백한 상아). Cool grey-blue.
  let r = 0x34 + (1 - t) * 0x16, g = 0x36 + (1 - t) * 0x16, b = 0x40 + (1 - t) * 0x18;
  // amber wash toward the centre-top (the great altar's residual ember glow)
  const cx = worldW * 0.5, cy = worldH * 0.24;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const amber = Math.max(0, 1 - d) * 36;
  r += amber * 0.95; g += amber * 0.62; b += amber * 0.28;
  return [r, g, b];
}
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = Math.min(255, r); png.data[i + 1] = Math.min(255, g); png.data[i + 2] = Math.min(255, b); png.data[i + 3] = 255;
}
// pale/amber dust motes (drifting embers + pale silence specks)
for (let i = 0; i < 800; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 120 + h32(i, 3, 9) * 120;
  const amber = h32(i, 17, 2) > 0.5;
  put(x, y, amber ? [br, br * 0.78, br * 0.42] : [br * 0.94, br * 0.96, br], 0.7);
  if (h32(i, 23, 4) > 0.94) { put(x + 1, y, [br, br * 0.82, br * 0.5], 0.32); put(x, y + 1, [br, br * 0.82, br * 0.5], 0.32); }
}

function put(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  // clamp to [0,255]: the pale ivory TONE (all channels >1) can push a bright highlight past 255,
  // and png.data is a Uint8Array (wraps mod 256) — an un-clamped 260 would wrap to 4 and paint a
  // false magenta speck at the tile seams. Clamp so bright pixels stay white instead of wrapping.
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

// amber additive glow blob
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

// cliff aprons (CliffGen mirror): ivory aprons at every exposed S/E front edge so raised
// choir/corridor/altar districts CONNECT to the lower floor, and district rims plunge into the
// chasm void (deeper, bottom-faded).
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
// preview-only glow boost so the lit objects read in a still: divine_ember, life_spring, the
// great_altar face, pilgrim_dynamo/mana_reliquary reward nodes, spawned offering_altar. 호박 발광.
const GLOW_PREVIEW = { k: 0.5, E: 0.7, 2: 0.7, 1: 1.0, A: 0.4, B: 0.4, Y: 0.4, 3: 0.4, W: 0.35, X: 0.35 };
const MIST_SYMS = new Set(["E", "2"]); // life spring: rising pale mist
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
// spawned gate mount (offering_altar)
for (const s of SPAWNED) pushDraw("_spawn", s.art, s.off, s.glow, s.c, s.r, false);

draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) {
    const rad = Math.max(44, Math.round(d.src.width * 0.45));
    glow(Math.round(d.gx), Math.round(d.gy), rad, d.glowStrength);
  }
  blit(d.src, d.sx, d.sy, { tone: true });
  if (d.mist) { // rising pale mist wisps
    const topY = d.sy + 6;
    for (let k = 0; k < 5; k++) {
      const t = k / 5;
      const wx = d.gx + Math.sin(d.seed % 7 + k * 1.9) * (6 + 14 * t);
      const wy = topY - 10 - k * 13;
      const wr = 7 + k * 3, wa = 0.15 * (1 - t * 0.7);
      for (let py = -wr; py <= wr; py++) for (let px = -wr; px <= wr; px++) {
        const dd = Math.hypot(px, py) / wr; if (dd > 1) continue;
        add(wx + px, wy + py, [244, 240, 226], (1 - dd) * (1 - dd) * wa);
      }
    }
  }
}

// workbench (spawned by the session, not a layout symbol) at special.workbench_cell
const wb = legend.special && legend.special.workbench_cell;
if (wb) {
  const src = objArt("l5_workbench");
  if (src) {
    const [lx, ly] = cellLocal(wb[0], wb[1]);
    const bx = OX + lx, by = OY + ly - liftAt(wb[0], wb[1]);
    glow(Math.round(bx), Math.round(by - 24), 30, 0.3);
    blit(src, Math.round(bx - src.width / 2), Math.round(by - src.height + HH - 20), { tone: true });
  }
}

// ---------------- vignette (lighter than L3/L4 — the cathedral stays pale) ----
const vcx = png.width / 2, vcy = png.height / 2, vmax = Math.hypot(vcx, vcy);
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const d = Math.hypot(x - vcx, y - vcy) / vmax;
  const v = Math.max(0, (d - 0.66)) * 0.42;
  if (v <= 0) continue;
  const i = (y * png.width + x) << 2;
  png.data[i] *= (1 - v); png.data[i + 1] *= (1 - v); png.data[i + 2] *= (1 - v);
}

// ---------------- closeup crop ----------------------------------------------
let outPng = png;
if (CLOSEUP) {
  // crop on the 대제단 (great altar = the top +2 altar district, rows 0-6), tight on the
  // great_altar '1' + spawned offering_altar neck rising far above the cell baseline.
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
