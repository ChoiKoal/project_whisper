#!/usr/bin/env node
// tools_overview_l3.js — Layer-3 「태엽이 멈춘 도시」 (clockwork_city) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l3.js [--closeup]
//
// Same story as the L2 render: the in-engine SubViewport can't run under --headless (dummy driver,
// no framebuffer), so this offline pngjs compositor draws the Layer-3 map the way the game does:
// reads l3_map_layout.txt + l3_map_legend.json + l3_map_height.txt, projects the grid in iso,
// blits the REAL machine tiles (brass/pipe/grate/platform(+1)/plaza(+2)/dark) with a warm
// copper/brass tone + orange additive glow on lit objects, then the authored objects
// (spring_debris/gear_pile/brass_scrap/condensate/belt_spool/coal_seam/grimy_glass/gear_assembly/
// boiler/elevator_ctrl/clock_mount/gear_bridge/valve_door/elevator/grand_clock/parts_pile) at their
// legend offsets, elevation-lifted per l3_map_height.txt (platform +1, plaza/clocktower +2).
//
// Mood target (design §A-1): 구리/황동 base + 주황 발광 + 그을음. "멈춘 태엽 도시".
//
// --closeup → tight crop on the 대시계 광장 (grand clock plaza, rows 1-6) → preview-l3-closeup.png
// overview  → preview-l3.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const CLOSEUP = process.argv.includes("--closeup");
const OUT = CLOSEUP ? "/workspace/group/preview-l3-closeup.png"
                    : "/workspace/group/preview-l3.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/l3_map_layout.txt`);
const height = read(`${GAME}/data/l3_map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/l3_map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// map tileset source id → l3 tile png. Mirrors l3_map_legend.json tile sources (20-25).
const TILE_BY_SRC = {
  20: tileArt("l3_brass"), 21: tileArt("l3_pipe"), 22: tileArt("l3_grate"),
  23: tileArt("l3_platform"), 24: tileArt("l3_plaza"), 25: tileArt("l3_dark"),
  0: tileArt("l3_dark"),
};
const RAMP = tileArt("l3_ramp");

// warm copper/brass CanvasModulate mirror, eased ~40%+ toward neutral vs the in-game night
// tint (owner review: the full tint crushed the still image to brown mud — in-engine the
// dynamic lights compensate, a static preview can't). Warm ratio kept (R>G>B).
const TONE = [1.02, 0.86, 0.62];
const GLOW_RGB = [0xff, 0x9a, 0x3c]; // 주황 발광

// ---------------- CliffGen.make_apron mirror (brass palette, L3-1) -----------
// Mirrors scripts/world/cliff_gen.gd make_apron(..., brass=true): the in-game map loader
// runtime-generates copper/brass cliff aprons at every exposed elevation boundary so raised
// districts CONNECT to the lower ground (owner reject on the old clipped-art approach:
// "높이가 전혀 안 이어져 보임"). Same geometry: front rim of the raised diamond extruded down
// `drop` levels, brass rivet bands every 20px, 주황 잔열 ember weeps, brass cap lip.
const B_BASE = [90, 74, 52], B_DARK = [58, 44, 30], B_LIGHT = [200, 162, 74],
      B_SHADOW = [36, 26, 16], B_LIP = [138, 106, 52], B_LIP_DK = [90, 68, 36],
      B_EMBER = [232, 132, 44];
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
// draw one exposed front edge (se = +col/down-right, sw = +row/down-left) of the cell whose
// LIFTED diamond centre is at (baseX, baseY). `drop` in levels (may be fractional for chasm
// edges); `fade` melts the bottom of the wall into the void so district rims read as cliffs
// over a deep chasm instead of razor-cut floating plates.
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
      if ((y - rimY) % 20 < 1) col = lerpC(col, B_LIGHT, 0.4);            // brass rivet band
      else if (!isLeft && rockNoise((x / 9) | 0, 0, salt + 3) < 0.06) col = lerpC(col, B_EMBER, 0.5); // 잔열 weep
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
// STACKED isometric projection — mirrors the GAME's real map_to_local (whisper TileSet:
// ISOMETRIC, tile_layout=0 STACKED, tile_offset_axis=0 HORIZONTAL, 128×64). The old
// (c-r,c+r) diamond formula rotated the map ~45° vs in-game (bug: 렌더↔인게임 방위 불일치).
// x = (col + 0.5·(row odd))·TW ; y = row·(TH/2). See tools_overview_l1.js for full note.
function cellLocal(c, r) { return [(c + ((r & 1) ? 0.5 : 0)) * TW, r * HH]; }
function heightAt(c, r) {
  if (r < 0 || r >= height.length) return 0;
  const row = height[r]; if (c < 0 || c >= row.length) return 0;
  const ch = row[c]; return ch === "2" ? 2 : ch === "1" ? 1 : 0;
}
function isVoid(c, r) {
  return !(r >= 0 && r < H && c >= 0 && c < layout[r].length) || layout[r][c] === "V";
}
// ramp cells ('/') bridge two levels along the row axis: lift them to the average of their
// N/S neighbours (flat if both sides are level, half-step if transitioning down).
function isRamp(c, r) { return !isVoid(c, r) && layout[r][c] === "/"; }
function liftAt(c, r) {
  if (isRamp(c, r)) return (heightAt(c, r - 1) + heightAt(c, r + 1)) / 2 * LIFT;
  return heightAt(c, r) * LIFT;
}
// effective level (in LIFT units) for apron drop math — ramps included at their visual lift.
function levelAt(c, r) { return liftAt(c, r) / LIFT; }

// bounds over non-void cells (tile diamonds) AND authored objects (tall art like the grand
// clock rises far above the cell baseline — include its full sprite rect so it isn't clipped).
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
      const topY = ly - lift - src.height + HH + off[1];
      minY = Math.min(minY, topY);
      minX = Math.min(minX, lx - src.width / 2 + off[0]);
      maxX = Math.max(maxX, lx + src.width / 2 + off[0]);
    }
  }
}
const PAD = 60;
const worldW = maxX - minX + PAD * 2, worldH = maxY - minY + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;

const png = new PNG({ width: Math.ceil(worldW), height: Math.ceil(worldH) });

// ---------------- background: warm soot void + amber wash + ember dust --------
function bgAt(x, y) {
  const t = y / worldH;
  // warm brown smog → darker toward the bottom (그을린 도시 하늘)
  let r = 0x2e + (1 - t) * 0x16, g = 0x20 + (1 - t) * 0x0e, b = 0x16 + (1 - t) * 0x08;
  // amber wash toward the centre-top (the grand clock's residual glow bleeding into the smog)
  const cx = worldW * 0.5, cy = worldH * 0.24;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const amber = Math.max(0, 1 - d) * 34;
  r += amber * 0.95; g += amber * 0.55; b += amber * 0.20;
  return [r, g, b];
}
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = 255;
}
// ember dust (warm motes instead of cyan stars)
for (let i = 0; i < 800; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 100 + h32(i, 3, 9) * 130;
  const warm = h32(i, 17, 2) > 0.35;
  put(x, y, warm ? [br, br * 0.62, br * 0.28] : [br * 0.9, br * 0.9, br], 0.75);
  if (h32(i, 23, 4) > 0.94) { put(x + 1, y, [br, br * 0.6, br * 0.3], 0.35); put(x, y + 1, [br, br * 0.6, br * 0.3], 0.35); }
}

function put(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
  png.data[i] = png.data[i] * (1 - a) + rgb[0] * a;
  png.data[i + 1] = png.data[i + 1] * (1 - a) + rgb[1] * a;
  png.data[i + 2] = png.data[i + 2] * (1 - a) + rgb[2] * a;
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

// orange additive glow blob
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

// cliff aprons (CliffGen mirror): every exposed S/E front edge gets a brass apron so the
// elevation transitions CONNECT — raised platform → ground steps, and district rims → the
// chasm void (drawn deeper, with a bottom fade, so the gaps between districts read as a
// canyon with depth rather than floating plates or missing tiles).
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
      drawApron(baseX, baseY, lv + CHASM_DROP, se, sw, salt, true);
    } else if (levelAt(nc, nr) < lv) {
      drawApron(baseX, baseY, lv - levelAt(nc, nr), se, sw, salt, false);
    }
  }
}

// ---------------- draw objects (with glow) ----------------------------------
// preview-only glow boost: the legend's glow_scale drives a large in-engine PointLight2D;
// a small additive blob at the same scale is invisible in a still, so the machines that ARE
// lit in-game (condensate steam vents, the boiler fireboxes, the grand clock face) get halos
// strong enough to read. 주황 발광 = the mood anchor.
const GLOW_PREVIEW = { w: 0.8, E: 0.7, 2: 0.7, 1: 1.0, L: 0.45, 3: 0.45, C: 0.35, X: 0.4, K: 0.4 };
const STEAM_SYMS = new Set(["E", "2", "w"]); // boilers + condensate: rising steam wisps
// collect object draws with a depth key so they y-sort over tiles correctly.
const draws = [];
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = layout[r][c];
  const objSpec = legend.objects[sym];
  if (!objSpec) continue;
  const art = objSpec.art;
  const src = objArt(art);
  if (!src) continue;
  const off = objSpec.offset || [0, -8];
  const legendGlow = objSpec.glow === "orange" ? (objSpec.glow_scale || 0.4) : 0;
  const glowStrength = Math.max(legendGlow, GLOW_PREVIEW[sym] || 0);
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const sx = Math.round(baseX - src.width / 2 + off[0]);
  const sy = Math.round(baseY - src.height + HH + off[1]);
  draws.push({ depth: (typeof baseY !== "undefined" ? baseY : sy), sx, sy, src, glowStrength, steam: STEAM_SYMS.has(sym),
    gx: baseX, gy: baseY - src.height * 0.4 + off[1] * 0.4 + HH, seed: hash2(c, r, 41) });
}
draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) {
    const rad = Math.max(44, Math.round(d.src.width * 0.45));
    glow(Math.round(d.gx), Math.round(d.gy), rad, d.glowStrength);
  }
  blit(d.src, d.sx, d.sy, { tone: true });
  if (d.steam) { // rising steam wisps, amber-lit from below (주황 증기)
    const topY = d.sy + 6;
    for (let k = 0; k < 5; k++) {
      const t = k / 5;
      const wx = d.gx + Math.sin(d.seed % 7 + k * 1.9) * (6 + 14 * t);
      const wy = topY - 10 - k * 13;
      const wr = 7 + k * 3, wa = 0.16 * (1 - t * 0.7);
      for (let py = -wr; py <= wr; py++) for (let px = -wr; px <= wr; px++) {
        const dd = Math.hypot(px, py) / wr; if (dd > 1) continue;
        add(wx + px, wy + py, [255, 214, 170], (1 - dd) * (1 - dd) * wa);
      }
    }
  }
}

// workbench (spawned by the session, not a layout symbol) at special.workbench_cell
const wb = legend.special && legend.special.workbench_cell;
if (wb) {
  const src = objArt("l3_workbench");
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
  // crop on the 대시계 광장 (grand clock plaza, rows 1-6, incl. the clock tower + mount neck).
  let cminX = 1e9, cminY = 1e9, cmaxX = -1e9, cmaxY = -1e9;
  for (let r = 0; r <= 12; r++) for (let c = 10; c <= 28; c++) {
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
