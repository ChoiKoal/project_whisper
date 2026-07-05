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
const CLIFF = tileArt("l3_cliff");
const ORANGE_POOL = objArt("light_pool_orange"); // optional, may be null

// warm copper/brass CanvasModulate mirror. Lifted hard so the metal reads bright & warm instead
// of crushing to soot (the raw tiles are dark; the game's own lighting brightens them in-engine).
const TONE = [0x6a / 255 * 2.15, 0x54 / 255 * 2.05, 0x3a / 255 * 1.85];
const GLOW_RGB = [0xff, 0x9a, 0x3c]; // 주황 발광

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
// ramp cells ('/') sit between a raised platform and the lower grate: lift them to the max
// neighbouring elevation minus a half-step so they visually bridge the two levels.
function isRamp(c, r) { return !isVoid(c, r) && layout[r][c] === "/"; }
function liftAt(c, r) {
  if (isRamp(c, r)) {
    let m = 0;
    for (const [dc, dr] of [[0, -1], [0, 1], [-1, 0], [1, 0]]) m = Math.max(m, heightAt(c + dc, r + dr));
    return Math.max(0, m - 0.5) * LIFT;
  }
  return heightAt(c, r) * LIFT;
}

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
  // deep warm brown → near-black gradient (그을린 도시 하늘)
  let r = 0x1c + (1 - t) * 0x10, g = 0x14 + (1 - t) * 0x0a, b = 0x10 + (1 - t) * 0x06;
  // amber wash toward the centre-top (the grand clock's residual glow bleeding into the smog)
  const cx = worldW * 0.5, cy = worldH * 0.24;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const amber = Math.max(0, 1 - d) * 24;
  r += amber * 0.9; g += amber * 0.5; b += amber * 0.18;
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

// cliff aprons: a copper skirt below any raised cell whose S/E neighbour is lower.
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const lv = heightAt(c, r); if (lv <= 0) continue;
  const s = heightAt(c, r + 1), e = heightAt(c + 1, r);
  const sVoid = isVoid(c, r + 1), eVoid = isVoid(c + 1, r);
  // skirt if either forward neighbour is lower OR void (edge of a raised platform)
  if ((s >= lv || sVoid ? 1 : 0) && (e >= lv || eVoid ? 1 : 0) && !sVoid && !eVoid) continue;
  const [sx, sy] = tileScreen(c, r);
  for (let dy = 0; dy < lv * LIFT + HH; dy++) {
    for (let dx = 0; dx < TW; dx++) {
      const rx = Math.abs(dx - HW), yy = HH + dy;
      if (rx > HW - (yy - HH) * (HW / HH) && yy < TH) continue;
      const shade = 0.6 - dy / (lv * LIFT + HH) * 0.32;
      put(sx + dx, sy + HH + dy, [0x4a * 1.0, 0x36 * 1.0, 0x22 * 1.0], Math.max(0, shade) * 0.5);
    }
  }
}

// ---------------- draw objects (with glow) ----------------------------------
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
  const glowStrength = objSpec.glow === "orange" ? (objSpec.glow_scale || 0.4) : 0;
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const sx = Math.round(baseX - src.width / 2 + off[0]);
  const sy = Math.round(baseY - src.height + HH + off[1]);
  draws.push({ depth: c + r, sx, sy, src, glowStrength,
    gx: baseX, gy: baseY - src.height * 0.4 + off[1] * 0.4 + HH });
}
draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) glow(Math.round(d.gx), Math.round(d.gy), 40, d.glowStrength);
  blit(d.src, d.sx, d.sy, { tone: true });
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
