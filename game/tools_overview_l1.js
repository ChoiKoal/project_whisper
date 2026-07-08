#!/usr/bin/env node
// tools_overview_l1.js — Layer-1 「시작의 숲」 (starting_grove) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l1.js
//
// The in-engine SubViewport render can't run under --headless (dummy driver, no framebuffer),
// so — as with the home / L2~L5 previews — this offline pngjs compositor draws the Layer-1 map
// the SAME way the game does, from the REAL authored data + the NEW procedural L1A art:
//   • reads data/map_layout.txt + data/map_legend.json + data/map_height.txt (single source of
//     truth — no hard-coded map)
//   • projects the 40×40 grid in iso (128×64 diamonds) WITH REAL ELEVATION: the central 풀 언덕
//     (authored rows 17-23) rises +1, its core +2, connected by ramps — every raised cell is
//     lifted -HILL_LIFT(32)*level and the downhill transitions grow rock cliff aprons, exactly
//     like map_loader.gd _build_elevation / _build_cliff_faces (owner review v1.4.0: the old flat
//     preview hid the hill — "프리뷰가 실물과 달랐다"). Ramp cells show a worn dirt slope, AO seats
//     seat the hill on the lower ground.
//   • blits the grass tiles with the EXACT M6a cluster-variant noise (_variant_source mirror),
//     dirt / mud / water / mystic-pond tiles, void + hollow
//   • lays a night-void cliff-skirt on the OUTER border void so the island rim reads as a raised
//     bank rather than a razor edge (mirrors map_loader _build_cliff_skirts intent)
//   • places the authored objects — trees a/b/c (cell-hash %3, matching _object_texture), flowers
//     ×3, rock, stone, bush_dry, night bud gate, cauldron, rest stump, mystic pond glow, and the
//     WORLD TREE (redesigned 660×660 luminous violet landmark, offset -238 / scale .72 per
//     world_tree.gd) at their real legend offsets, height-lifted + y-sorted.
//
// Mood target (art-guide §3, Layer-1 Nature): living greens over a soft navy-violet night void,
// world tree the single luminous violet landmark. Continuity with L2~L5: same iso grammar (128×64),
// same NE lighting, same navy-void backdrop + starfield + vignette lineage as the L2~L5 previews.
//
//   output → /workspace/group/preview-l1.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const OUT = "/workspace/group/preview-l1.png";
const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/map_layout.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/map_legend.json`, "utf8"));
// parallel height map (digits 0/1/2, '/' ramp). Missing → flat, exactly like map_loader.
let heightRows = [];
try { heightRows = read(`${GAME}/data/map_height.txt`); } catch (e) { heightRows = []; }
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// tileset source id → L1 tile png, mirrors data/map_legend.json "tiles" sources.
const TILE_BY_SRC = {
  0: tileArt("t0_void"), 1: tileArt("t1_dirt"), 2: tileArt("t2a_grass"),
  3: tileArt("t2b_grass_flowers"), 4: tileArt("t2c_grass_clover"), 5: tileArt("t2d_flower_grass"),
  7: tileArt("t4_mud"), 8: tileArt("t5a_water"), 9: tileArt("t5b_water2"), 10: tileArt("t5m_mystic"),
};
const MYSTIC_GLOW = tileArt("t5m_mystic_glow");
const VIOLET_POOL = objArt("light_pool_violet");
const VIOLET_POOL_LG = objArt("light_pool_violet_lg");
const WORLD_GLOW = objArt("world_tree_glow");

// ---- deterministic hashes (mirror map_loader.gd _cell_hash / _value_noise / MAP_SEED) --------
const MAP_SEED = 0x9E3779B9;
function cellHash(c, r, salt) {
  // GDScript uses 64-bit ints; replicate with BigInt then mask to 31 bits (game does & 0x7fffffff).
  let h = (BigInt(c) * 73856093n) ^ (BigInt(r) * 19349663n) ^ (BigInt(salt) * 83492791n) ^ BigInt(MAP_SEED);
  h = (h ^ (h >> 13n)) * 1274126177n;
  h = h ^ (h >> 16n);
  return Number(h & 0x7fffffffn);
}
function valueNoise(c, r, cellSize, salt) {
  const gx = c / cellSize, gy = r / cellSize;
  const x0 = Math.floor(gx), y0 = Math.floor(gy);
  let fx = gx - x0, fy = gy - y0;
  fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
  const nh = (a, b) => (cellHash(a, b, salt) & 0xffff) / 65535;
  const n00 = nh(x0, y0), n10 = nh(x0 + 1, y0), n01 = nh(x0, y0 + 1), n11 = nh(x0 + 1, y0 + 1);
  const nx0 = n00 * (1 - fx) + n10 * fx, nx1 = n01 * (1 - fx) + n11 * fx;
  return nx0 * (1 - fy) + nx1 * fy;
}
// M6a grass variant source (exact mirror of map_loader _variant_source).
function variantSource(c, r) {
  const n = valueNoise(c, r, 5, 11) * 0.7 + valueNoise(c, r, 2, 29) * 0.3;
  if (n < 0.52) return 2;   // T2A plain (majority)
  if (n < 0.68) return 4;   // T2C clover
  if (n < 0.84) return 3;   // T2B flowered
  return 5;                 // T2D bright flower-grass
}

// legend tile symbols that draw the grass base with cluster variants.
const GRASS_VARIANT_SYMS = new Set(["g"]);

// ---- iso projection ----------------------------------------------------------
function cellLocal(c, r) { return [(c - r) * HW, (c + r) * HH]; }
function symAt(c, r) {
  if (r < 0 || r >= H) return "";
  const row = layout[r]; if (c < 0 || c >= row.length) return "";
  return row[c];
}
const isVoid = (c, r) => { const s = symAt(c, r); return s === "" || s === "V"; };

// ---- REAL elevation (mirror map_loader.gd _classify_elevation / height_offset) --------------
// Only real island ground carries height (never void/water/mystic), matching the runtime guard.
function rawHeight(c, r) {
  if (r < 0 || r >= heightRows.length) return 0;
  const row = heightRows[r]; if (c < 0 || c >= row.length) return 0;
  const ch = row[c];
  return ch === "2" ? 2 : ch === "1" ? 1 : 0;
}
function heightChar(c, r) {
  if (r < 0 || r >= heightRows.length) return "0";
  const row = heightRows[r]; if (c < 0 || c >= row.length) return "0";
  return row[c];
}
function isRamp(c, r) { return heightChar(c, r) === "/" && !isVoid(c, r); }
// non-ground symbols don't carry height in the runtime.
function carriesHeight(c, r) {
  const s = symAt(c, r);
  return !(s === "" || s === "V" || s === "W" || s === "w" || s === "m");
}
function levelAt(c, r) {
  if (!carriesHeight(c, r)) return 0;
  if (isRamp(c, r)) return 0; // ramps are not a level; handled via mid-level for drawing
  return rawHeight(c, r);
}
// mid-level a ramp bridges (avg of its highest+lowest 4-neighbour levels), mirror _ramp_mid_level.
function rampMidLevel(c, r) {
  let lo = 99, hi = 0;
  for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    const lv = levelAt(c + dc, r + dr);
    lo = Math.min(lo, lv); hi = Math.max(hi, lv);
  }
  if (lo === 99) return rawHeight(c, r);
  return (lo + hi) * 0.5;
}
// screen-space vertical lift (px, positive up) for a cell.
function liftAt(c, r) {
  if (isRamp(c, r)) return LIFT * rampMidLevel(c, r);
  return LIFT * levelAt(c, r);
}

// ---- rock cliff apron (EXACT mirror of CliffGen.make_apron, grove ROCK palette) --------------
const ROCK_BASE = [120, 96, 78], ROCK_DARK = [72, 56, 44], ROCK_LIGHT = [150, 122, 102],
      ROCK_SHADOW = [46, 36, 30], GRASS_LIP = [86, 128, 60], GRASS_LIP_DK = [58, 92, 42];
function hash2(c, r, salt) {
  let h = (((c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ 0x9E3779B9) >>> 0);
  h = (Math.imul((h ^ (h >>> 13)) >>> 0, 1274126177) >>> 0);
  return ((h ^ (h >>> 16)) >>> 0) & 0x7FFFFFFF;
}
function rockNoise(px, py, seed) { return (hash2(px | 0, py | 0, seed) & 0xFFFF) / 65535; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function rockCol(s) {
  s = Math.min(Math.max(s, 0), 1.4);
  if (s < 0.7) return lerpC(ROCK_SHADOW, ROCK_DARK, s / 0.7);
  if (s < 1.0) return lerpC(ROCK_DARK, ROCK_BASE, (s - 0.7) / 0.3);
  return lerpC(ROCK_BASE, ROCK_LIGHT, Math.min((s - 1.0) / 0.4, 1));
}
// draw one apron for a raised cell whose LIFTED diamond centre is at (baseX, baseY). Geometry is
// a per-column vertical extrusion of the front rim, exactly like make_apron. `drop` in levels.
function drawApron(baseX, baseY, drop, exposeSE, exposeSW, salt) {
  const wall = LIFT * drop;
  const x0 = Math.round(baseX - HW), y0 = Math.round(baseY - HH);
  for (let x = 0; x < TW; x++) {
    const isLeft = x < HW;
    const exposed = isLeft ? exposeSW : exposeSE;
    if (!exposed) continue;
    const rim = isLeft ? (HH + x * 0.5) : ((TW - x) * 0.5 + HH);
    const rimY = Math.round(rim);
    const sideLight = isLeft ? 0.74 : 1.10;
    for (let y = rimY; y < rimY + wall; y++) {
      const t = (y - rimY) / Math.max(1, wall);
      const vshade = 1.0 - 0.30 * t;
      const strata = Math.floor(rockNoise((x / 6) | 0, (y / 5) | 0, salt) * 5.0) / 5.0;
      const facet = (strata - 0.4) * 0.5;
      const crack = (rockNoise((x / 3) | 0, (y / 7) | 0, salt + 5) < 0.14) ? -0.34 : 0.0;
      const n = rockNoise(x, y, salt) * 0.12 - 0.06;
      const col = rockCol(sideLight * vshade + facet + crack + n);
      put(x0 + x, y0 + y, col, 1);
    }
    // grass cap lip (5px, ragged bottom)
    const lipH = 5, jag = Math.floor(rockNoise(x, 7, salt) * 3.0);
    for (let y = rimY; y < rimY + lipH - jag; y++) {
      const g = ((x + y) % 3 !== 0) ? GRASS_LIP : GRASS_LIP_DK;
      put(x0 + x, y0 + y, g, 1);
    }
  }
}
// AO seat diamond on the LOWER ground at a cliff foot (mirror make_ao_diamond, strength 0.6).
function drawAoSeat(baseX, baseY) {
  const x0 = Math.round(baseX - HW), y0 = Math.round(baseY - HH);
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
    const dx = Math.abs(x - HW) / HW, dy = Math.abs(y - HH) / HH;
    const d = dx + dy; if (d > 1) continue;
    const a = Math.min(1, Math.max(0, (1 - d) / 0.62));
    put(x0 + x, y0 + y, [0, 0, 0], a * a * 0.6);
  }
}
// ramp climb-direction (toward highest 4-neighbour), mirror _ramp_climb_dir.
function rampDir(c, r) {
  let best = "ne", bestLv = -1;
  for (const [dc, dr, name] of [[1, 0, "se"], [-1, 0, "nw"], [0, 1, "sw"], [0, -1, "ne"]]) {
    const lv = levelAt(c + dc, r + dr);
    if (lv > bestLv) { bestLv = lv; best = name; }
  }
  return best;
}
// worn-dirt ramp slope diamond + short front wall (mirror make_ramp, simplified shading).
const DIRT = [150, 120, 84], DIRT_DK = [110, 86, 58], DIRT_LT = [178, 146, 104];
function rampGrad(x, y, dir) {
  if (dir === "se") return Math.min(Math.max(x / TW, 0), 1);
  if (dir === "nw") return Math.min(Math.max(1 - x / TW, 0), 1);
  if (dir === "sw") return Math.min(Math.max(y / TH, 0), 1);
  return Math.min(Math.max(1 - y / TH, 0), 1); // ne
}
function drawRamp(baseX, baseY, dir, salt) {
  const x0 = Math.round(baseX - HW), y0 = Math.round(baseY - HH);
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
    const dx = Math.abs(x - HW) / HW, dy = Math.abs(y - HH) / HH;
    if (dx + dy > 1) continue;
    const g = rampGrad(x, y, dir);
    const band = (Math.floor(g * 6) % 2 === 0);
    const n = rockNoise(x, y, salt) * 0.12 - 0.06;
    let base = band ? lerpC(DIRT, DIRT_LT, g) : lerpC(DIRT, DIRT_DK, 1 - g);
    base = [base[0] + n * 255 * 0.6, base[1] + n * 255 * 0.6, base[2] + n * 255 * 0.6];
    put(x0 + x, y0 + y, base, 1);
  }
  // short front wall
  for (let x = 0; x < TW; x++) {
    const isLeft = x < HW;
    const rim = isLeft ? (HH + x * 0.5) : ((TW - x) * 0.5 + HH);
    const rimY = Math.round(rim);
    for (let y = rimY; y < rimY + LIFT; y++) {
      const t = (y - rimY) / LIFT;
      put(x0 + x, y0 + y, lerpC(DIRT_DK, [74, 58, 40], t), 1);
    }
  }
}

// ---- bounds (tile diamonds + tall object sprites so nothing clips) ----------
let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (symAt(c, r) === "") continue;
  const [lx, ly] = cellLocal(c, r);
  const lift = liftAt(c, r);
  minX = Math.min(minX, lx - HW); maxX = Math.max(maxX, lx + HW);
  minY = Math.min(minY, ly - lift - TH); maxY = Math.max(maxY, ly + TH * 2);
}
// world tree is tall (660px, offset -238, scale .72) — pad the top so its canopy fits.
minY -= 300;
const PAD = 60;
const worldW = maxX - minX + PAD * 2, worldH = maxY - minY + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;
const png = new PNG({ width: Math.ceil(worldW), height: Math.ceil(worldH) });

// ---- background: navy-violet night void + starfield (L2~L5 preview lineage) --
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
function bgAt(x, y) {
  // vertical gradient mirroring backdrop_canvas.gd L1 default (#12121c top → #1e1a2e bottom),
  // lifted a touch so the void tiles read against it (their corner fill is #101019).
  const t = y / worldH;
  const r = 0x12 + t * 0x0c, g = 0x12 + t * 0x08, b = 0x1c + t * 0x12;
  return [r, g, b];
}
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = 255;
}
for (let i = 0; i < 700; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 110 + h32(i, 3, 9) * 120;
  const violet = h32(i, 17, 2) > 0.65;
  put(x, y, violet ? [br * 0.85, br * 0.7, br] : [br, br, br], 0.8);
}

function put(x, y, rgb, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (y * png.width + x) << 2;
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
function blit(src, sx, sy, { alpha = 1, additive = false, scale = 1 } = {}) {
  if (!src) return;
  if (scale === 1) {
    for (let py = 0; py < src.height; py++) for (let px = 0; px < src.width; px++) {
      const si = (py * src.width + px) << 2;
      const a = (src.data[si + 3] / 255) * alpha;
      if (a <= 0.003) continue;
      const rgb = [src.data[si], src.data[si + 1], src.data[si + 2]];
      if (additive) add(sx + px, sy + py, rgb, a); else put(sx + px, sy + py, rgb, a);
    }
    return;
  }
  // nearest-neighbour scaled blit (world tree draws at scale 0.72, matching world_tree.gd).
  const dw = Math.round(src.width * scale), dh = Math.round(src.height * scale);
  for (let dy = 0; dy < dh; dy++) for (let dx = 0; dx < dw; dx++) {
    const px = Math.min(src.width - 1, Math.floor(dx / scale)), py = Math.min(src.height - 1, Math.floor(dy / scale));
    const si = (py * src.width + px) << 2;
    const a = (src.data[si + 3] / 255) * alpha;
    if (a <= 0.003) continue;
    const rgb = [src.data[si], src.data[si + 1], src.data[si + 2]];
    if (additive) add(sx + dx, sy + dy, rgb, a); else put(sx + dx, sy + dy, rgb, a);
  }
}
function glow(cx, cy, radius, rgb, strength) {
  for (let py = -radius; py <= radius; py++) for (let px = -radius; px <= radius; px++) {
    const d = Math.hypot(px, py) / radius; if (d > 1) continue;
    add(cx + px, cy + py, rgb, (1 - d) * (1 - d) * strength);
  }
}

// ---- draw tiles (painter's order, back rows first), height-lifted ------------
function tileScreen(c, r) { const [lx, ly] = cellLocal(c, r); return [OX + lx - HW, OY + ly - liftAt(c, r) - HH]; }
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = symAt(c, r); if (sym === "") continue;
  const spec = legend.tiles[sym];
  let src;
  if (GRASS_VARIANT_SYMS.has(sym)) src = TILE_BY_SRC[variantSource(c, r)];
  else if (spec) src = TILE_BY_SRC[spec.source];
  else src = TILE_BY_SRC[2]; // unknown → grass (map_loader hole-guard)
  if (!src) continue;
  const [sx, sy] = tileScreen(c, r);
  blit(src, sx, sy);
  // a raised cell also lays its lifted plateau grass (the runtime draws a dedicated elev layer);
  // the single lifted blit above already places the surface at its raised height, so this is it.
  // mystic pond additive glow rim (mirrors mystic_water glow child).
  if (sym === "m" && MYSTIC_GLOW) {
    const [lx, ly] = cellLocal(c, r);
    blit(MYSTIC_GLOW, Math.round(OX + lx - MYSTIC_GLOW.width / 2), Math.round(OY + ly - liftAt(c, r) - MYSTIC_GLOW.height / 2), { additive: true, alpha: 0.8 });
  }
}

// ---- ELEVATION: AO seats (under aprons) → cliff aprons → ramp slopes ---------
// Mirror map_loader _build_ao_seats / _build_cliff_faces / _build_ramp_slopes so the raised 풀 언덕
// reads as real height (the v1.4.0 owner review fix). AO seats first (lowest z), on the LOWER
// neighbour ground; then the rock aprons on every downhill S/E transition; then ramp slopes.
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isRamp(c, r)) continue;
  const lv = levelAt(c, r); if (lv <= 0) continue;
  for (const [dc, dr] of [[1, 0], [0, 1]]) {
    const nc = c + dc, nr = r + dr;
    if (levelAt(nc, nr) < lv && !isRamp(nc, nr)) {
      const [lx, ly] = cellLocal(nc, nr);
      drawAoSeat(OX + lx, OY + ly - liftAt(nc, nr));
    }
  }
}
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isRamp(c, r)) continue;
  const lv = levelAt(c, r); if (lv <= 0) continue;
  const east = levelAt(c + 1, r), south = levelAt(c, r + 1);
  const seDrop = (east < lv && !isRamp(c + 1, r)) ? (lv - east) : 0;
  const swDrop = (south < lv && !isRamp(c, r + 1)) ? (lv - south) : 0;
  const drop = Math.max(seDrop, swDrop);
  if (drop <= 0) continue;
  const [lx, ly] = cellLocal(c, r);
  const salt = hash2(c, r, 611);
  drawApron(OX + lx, OY + ly - LIFT * lv, drop, seDrop > 0, swDrop > 0, salt);
}
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (!isRamp(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  drawRamp(OX + lx, OY + ly - liftAt(c, r), rampDir(c, r), hash2(c, r, 41));
}

// ---- border-void cliff skirt: darken the outer void rim so the island bank reads as raised ----
// Mirrors the INTENT of _build_cliff_skirts (a night-void bank under the fringe). Purely a preview
// shade — the void tile already seals the corner holes; this just adds rim depth so the border does
// not read as a flat black band. Only outer-border void (a void cell adjacent to land) gets it.
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (!isVoid(c, r)) continue;
  // is this void bordered by land (→ it's the island fringe, not deep outer void)?
  let fringe = false;
  for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
    const s = symAt(c + dc, r + dr);
    if (s !== "" && s !== "V") { fringe = true; break; }
  }
  if (!fringe) continue;
  const [lx, ly] = cellLocal(c, r);
  const bx = OX + lx, by = OY + ly;
  // a soft violet-navy rim glow just under the fringe (the floating-island silhouette edge).
  glow(Math.round(bx), Math.round(by + HH * 0.3), 30, [0x3a, 0x2a, 0x5c], 0.22);
}

// ---- objects (y-sorted), height-lifted --------------------------------------
// art + offset table — EXACT mirror of map_loader.gd _object_texture / per-symbol spawn offsets.
function treeArt(c, r) {
  const pick = cellHash(c, r, 7) % 3;
  if (pick === 0) return ["tree_a", [0, -110]];
  if (pick === 1) return ["tree_b", [0, -116]];
  return ["tree_c", [0, -105]];
}
function flowerArt(c, r) {
  const pick = cellHash(c, r, 7) % 3;
  if (pick === 0) return ["flower", [0, -24]];
  if (pick === 1) return ["flower_violet", [0, -24]];
  return ["flower_pink", [0, -24]];
}
const draws = [];
function pushObj(c, r, art, off, extra = {}) {
  const src = objArt(art); if (!src) return;
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const scale = extra.scale || 1;
  const sw = src.width * scale, sh = src.height * scale;
  const sx = Math.round(baseX - sw / 2 + off[0]);
  const sy = Math.round(baseY - sh + HH + off[1]);
  draws.push({ depth: c + r, sx, sy, src, scale, gx: baseX, gy: baseY, off, ...extra });
}

// track world-tree O block for a single centroid placement (matches _spawn: first O cell only).
let worldTreeDone = false;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = symAt(c, r);
  switch (sym) {
    case "T": { const [a, o] = treeArt(c, r); pushObj(c, r, a, o); break; }
    case "F": { const [a, o] = flowerArt(c, r); pushObj(c, r, a, o); break; }
    case "R": pushObj(c, r, "rock", [0, -22]); break;
    case "s": pushObj(c, r, "stone", [0, -14]); break;
    case "B": pushObj(c, r, "bush_dry", [0, -64]); break;         // bush_dry.gd offset
    case "N": pushObj(c, r, "night_bud_closed", [0, -60]); break; // night_gate.gd closed bud
    case "C": {                                                    // cauldron + violet pool
      const [lx, ly] = cellLocal(c, r);
      const yl = OY + ly - liftAt(c, r);
      if (VIOLET_POOL) blit(VIOLET_POOL, Math.round(OX + lx - VIOLET_POOL.width / 2), Math.round(yl - VIOLET_POOL.height / 2 - 8), { additive: true, alpha: 0.7 });
      pushObj(c, r, "cauldron", [0, -64]);
      break;
    }
    case "U": pushObj(c, r, "rest_stump", [0, -80]); break;        // rest_stump.gd offset
    case "O": {
      if (!worldTreeDone) {
        worldTreeDone = true;
        // centroid of the 2×2 O block = this cell + (0,32) local nudge (matches _spawn).
        const [lx, ly] = cellLocal(c, r);
        const cx = OX + lx, cy = OY + ly - liftAt(c, r) + 32;
        // large violet light pool washing the base (light_pool_violet_lg).
        if (VIOLET_POOL_LG) blit(VIOLET_POOL_LG, Math.round(cx - VIOLET_POOL_LG.width / 2), Math.round(cy - VIOLET_POOL_LG.height / 2), { additive: true, alpha: 0.9 });
        // radial violet ground bloom so the world-tree base reads as the single luminous
        // landmark of the grove (art-guide §3: "world tree the single violet landmark").
        glow(Math.round(cx), Math.round(cy - HH * 0.4), 210, [0x6b, 0x4a, 0x9e], 0.5);
        // world tree body: 660×660 @ scale .72, offset (0,-238) from world_tree.gd. Match the
        // RUNTIME render (world_tree.gd loads world_tree.png — the living violet-lit tree — plus
        // an additive glow child). The dormant variant stays unwired (future pre-purification).
        const body = objArt("world_tree") || objArt("world_tree_dormant");
        const sc = 0.72, o = [0, -238];
        if (body) {
          const sw = body.width * sc, sh = body.height * sc;
          draws.push({ depth: c + r + 100, isWorldTree: true, src: body, scale: sc,
            sx: Math.round(cx - sw / 2 + o[0] * sc), sy: Math.round(cy - sh + HH + o[1] * sc),
            gx: cx, gy: cy });
        }
      }
      break;
    }
  }
}
draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  blit(d.src, d.sx, d.sy, { scale: d.scale });
  if (d.isWorldTree && WORLD_GLOW) {
    // additive violet bloom, same bottom-center origin/scale as the body (world_tree.gd glow child).
    // Layered twice — a wide soft halo + a tighter core — so the canopy glows as the grove's one
    // luminous landmark against the navy void (matches the L2~L5 lit-landmark bloom strength).
    const sc = 0.72, o = [0, -238];
    const gw = WORLD_GLOW.width * sc, gh = WORLD_GLOW.height * sc;
    const gx = Math.round(d.gx - gw / 2 + o[0] * sc), gy = Math.round(d.gy - gh + HH + o[1] * sc);
    // core bloom over the canopy (same offset/scale as the body → registers on the foliage).
    blit(WORLD_GLOW, gx, gy, { additive: true, alpha: 0.9, scale: sc });
    // a gentle oversized ambient halo, only SLIGHTLY larger and re-centred on the SAME canopy
    // point (so it hugs the foliage instead of floating up as a separate ring). Centre = the core
    // glow's centre; scale about that centre so the extra size grows symmetrically, not upward.
    const hsc = sc * 1.18;
    const ccx = gx + gw / 2, ccy = gy + gh / 2;
    const hgw = WORLD_GLOW.width * hsc, hgh = WORLD_GLOW.height * hsc;
    blit(WORLD_GLOW, Math.round(ccx - hgw / 2), Math.round(ccy - hgh / 2), { additive: true, alpha: 0.32, scale: hsc });
  }
}

// ---- vignette (L2~L5 preview lineage: gentle, never crush the rim to black) --
const vcx = png.width / 2, vcy = png.height / 2, vmax = Math.hypot(vcx, vcy);
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const d = Math.hypot(x - vcx, y - vcy) / vmax;
  const v = Math.max(0, d - 0.66) * 0.45;
  if (v <= 0) continue;
  const i = (y * png.width + x) << 2;
  png.data[i] *= (1 - v); png.data[i + 1] *= (1 - v); png.data[i + 2] *= (1 - v);
}

fs.writeFileSync(OUT, PNG.sync.write(png));
console.log(`wrote ${OUT} (${png.width}x${png.height})`);
