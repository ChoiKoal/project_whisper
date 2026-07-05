#!/usr/bin/env node
// tools_overview_v050a.js — composite a full-map overview PNG for owner review of the
// v0.5 phase-A/B terrain: the new CC0 tileset + REAL elevation (풀 언덕 plateau, cliff
// faces, water). Mirrors MapLoader's iso placement so the render matches the game.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_v050a.js
//
// Reads the same data the game does — data/map_layout.txt, data/map_height.txt, the
// legend, and the actual atlas tile / object PNGs — and blits them onto one big canvas
// in painter's order (back-to-front by row+col+height), then downscales to the target.
// Output: /workspace/group/preview-v050a.png

const fs = require("fs");
const path = require("path");
const { PNG } = require("pngjs");

const GAME = __dirname;
const OUT = "/workspace/group/preview-v050a.png";

// ---- iso geometry (matches whisper_tileset.tres: 128×64 staggered iso) --------
const TW = 128, TH = 64, HW = 64, HH = 32;
const LIFT = 32; // HILL_LIFT

const layout = read(`${GAME}/data/map_layout.txt`);
const height = read(`${GAME}/data/map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tile = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const obj = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// Tile textures by source id (matches legend source ids).
const SRC = {
  0: tile("t0_void"), 1: tile("t1_dirt"), 2: tile("t2a_grass"), 3: tile("t2b_grass_flowers"),
  4: tile("t2c_grass_clover"), 5: tile("t2d_flower_grass"), 7: tile("t4_mud"),
  8: tile("t5a_water_anim"), 9: tile("t5b_water2_anim"), 10: tile("t5m_mystic"), 11: tile("t0_hollow"),
};
const CLIFF = [tile("cliff_face_a"), tile("cliff_face_b"), tile("cliff_face_c"), tile("cliff_face_d")].filter(Boolean);
const RIDGE = [tile("ridge_rock"), tile("ridge_rock_b")].filter(Boolean);
const OBJ = {
  T: [obj("tree_a"), obj("tree_b"), obj("tree_c")].filter(Boolean),
  F: [obj("flower"), obj("flower_violet"), obj("flower_pink")].filter(Boolean),
  R: [obj("rock")], s: [obj("stone")], t: [obj("grass_tuft")], h: [obj("bush_green")],
  O: [obj("world_tree")], C: [obj("cauldron")], B: [obj("bush_dry")],
};

// Deterministic cell hash (mirror of MapLoader._cell_hash for variant parity).
function cellHash(c, r, salt = 0) {
  let h = (Math.imul(c, 73856093) ^ Math.imul(r, 19349663) ^ Math.imul(salt, 83492791) ^ (0x9e3779b9 | 0)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) | 0;
  h = h ^ (h >>> 16);
  return (h & 0x7fffffff);
}

// map_to_local for a staggered iso (Godot TileMapLayer, tile_layout=0, offset_axis X).
function cellLocal(c, r) {
  // Godot staggered X: x = (c - r) * HW ... actually for this project the grid is a plain
  // diamond (each +col => +HW,+HH ; +row => -HW,+HH). Empirically the map is a full diamond
  // island, so use the diamond mapping which matches map_to_local here.
  const x = (c - r) * HW;
  const y = (c + r) * HH;
  return [x, y];
}

// Height helpers.
function hAt(c, r) {
  if (r < 0 || r >= height.length) return 0;
  const row = height[r];
  if (c < 0 || c >= row.length) return 0;
  const ch = row[c];
  return ch === "1" ? 1 : ch === "2" ? 2 : 0;
}
function isRamp(c, r) {
  if (r < 0 || r >= height.length) return false;
  const row = height[r];
  return c >= 0 && c < row.length && row[c] === "/";
}
function heightOff(c, r) {
  if (isRamp(c, r)) {
    // mid of neighbours
    let lo = 99, hi = 0;
    for (const [dc, dr] of [[1,0],[-1,0],[0,1],[0,-1]]) { const l = hAt(c+dc, r+dr); lo = Math.min(lo,l); hi = Math.max(hi,l); }
    if (lo === 99) return 0;
    return -LIFT * ((lo + hi) / 2);
  }
  return -LIFT * hAt(c, r);
}

// ---- canvas ------------------------------------------------------------------
// Compute bounds over all cells (+ margins for tall cliffs/objects).
let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const [x, y] = cellLocal(c, r);
  minX = Math.min(minX, x - HW); maxX = Math.max(maxX, x + HW);
  minY = Math.min(minY, y - HH - LIFT * 2 - 240); maxY = Math.max(maxY, y + HH + 260);
}
const PAD = 40;
const CW = Math.ceil(maxX - minX) + PAD * 2;
const CH = Math.ceil(maxY - minY) + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;
const canvas = new PNG({ width: CW, height: CH });
// Dark void backdrop (the diorama sits in darkness).
for (let i = 0; i < canvas.data.length; i += 4) {
  canvas.data[i] = 12; canvas.data[i + 1] = 10; canvas.data[i + 2] = 18; canvas.data[i + 3] = 255;
}

function blit(src, dx, dy, frameW) {
  if (!src) return;
  const sw = frameW || src.width, sh = src.height;
  for (let y = 0; y < sh; y++) {
    const cy = Math.round(dy) + y;
    if (cy < 0 || cy >= CH) continue;
    for (let x = 0; x < sw; x++) {
      const cx = Math.round(dx) + x;
      if (cx < 0 || cx >= CW) continue;
      const si = (src.width * y + x) << 2;
      const a = src.data[si + 3];
      if (a === 0) continue;
      const di = (CW * cy + cx) << 2;
      const af = a / 255;
      canvas.data[di] = src.data[si] * af + canvas.data[di] * (1 - af);
      canvas.data[di + 1] = src.data[si + 1] * af + canvas.data[di + 1] * (1 - af);
      canvas.data[di + 2] = src.data[si + 2] * af + canvas.data[di + 2] * (1 - af);
      canvas.data[di + 3] = 255;
    }
  }
}

// Resolve the source id + variant a cell renders (mirror of legend/_variant_source).
function valueNoise(c, r, cs, salt) {
  const gx = c / cs, gy = r / cs;
  const x0 = Math.floor(gx), y0 = Math.floor(gy);
  let fx = gx - x0, fy = gy - y0;
  fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
  const n = (a, b) => (cellHash(a, b, salt) & 0xffff) / 65535;
  const nx0 = n(x0, y0) * (1 - fx) + n(x0 + 1, y0) * fx;
  const nx1 = n(x0, y0 + 1) * (1 - fx) + n(x0 + 1, y0 + 1) * fx;
  return nx0 * (1 - fy) + nx1 * fy;
}
function variantSrc(c, r) {
  const n = valueNoise(c, r, 5, 11) * 0.7 + valueNoise(c, r, 2, 29) * 0.3;
  if (n < 0.52) return 2; if (n < 0.68) return 4; if (n < 0.84) return 3; return 5;
}
function srcFor(c, r) {
  const sym = layout[r][c];
  const spec = legend.tiles[sym];
  if (!spec) return 2;
  let src = spec.source != null ? spec.source : 2;
  if (spec.variant_random) src = variantSrc(c, r);
  return src;
}

// Painter order: back-to-front. Ground pass first (all base + elevation tiles), then a
// second pass for objects, so tall pieces overlay correctly.
const order = [];
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) order.push([c, r]);
order.sort((a, b) => (a[0] + a[1]) - (b[0] + b[1]));

// -- ground + elevation + cliffs --
for (const [c, r] of order) {
  const sym = layout[r][c];
  const [lx, ly] = cellLocal(c, r);
  const bx = OX + lx - HW, by = OY + ly - HH; // top-left of the 128×64 diamond box
  const src = srcFor(c, r);
  const tex = SRC[src];
  const frameW = (src === 8 || src === 9) ? 128 : undefined; // water anim frame 0
  // base ground tile (always draw so cliffs sit on solid ground)
  blit(tex, bx, by, frameW);
  // elevation: draw the lifted surface + cliff face
  const off = heightOff(c, r);
  if (off < 0 && sym !== "V") {
    // cliff face on the downhill (S/E) transition, drawn BEFORE the lifted surface.
    const lvl = hAt(c, r);
    const south = hAt(c, r + 1), east = hAt(c + 1, r);
    const drop = Math.max(lvl - (south < lvl ? south : lvl), lvl - (east < lvl ? east : lvl));
    if (drop > 0 && CLIFF.length && !isRamp(c, r)) {
      const cf = CLIFF[cellHash(c, r, 611) % CLIFF.length];
      const faceH = LIFT * drop + HH + 8;
      // region-clip the top faceH px
      const clip = { width: cf.width, height: Math.min(faceH, cf.height), data: cf.data };
      blit(clip, bx, by + off, cf.width);
    }
    // lifted grass surface
    const g = SRC[src >= 2 && src <= 5 ? src : variantSrc(c, r)];
    blit(g, bx, by + off);
  }
}

// -- interior ridge rock pillars (authored V bands between land) --
function reachesLand(c, r, dc, dr) {
  let p = [c + dc, r + dr];
  let steps = W + H;
  while (steps-- > 0) {
    const [cc, rr] = p;
    if (rr < 0 || rr >= H || cc < 0 || cc >= layout[rr].length) return false;
    const s = layout[rr][cc];
    if (s !== "V") return s !== "W" && s !== "w" && s !== "m";
    p = [cc + dc, rr + dr];
  }
  return false;
}
for (const [c, r] of order) {
  if (layout[r][c] !== "V") continue;
  const ns = reachesLand(c, r, 0, -1) && reachesLand(c, r, 0, 1);
  const ew = reachesLand(c, r, -1, 0) && reachesLand(c, r, 1, 0);
  if (!(ns || ew) || !RIDGE.length) continue;
  const [lx, ly] = cellLocal(c, r);
  const t = RIDGE[(cellHash(c, r, 907) & 1)] || RIDGE[0];
  blit(t, OX + lx - HW, OY + ly + HH - t.height, t.width);
}

// -- objects (authored + a light deterministic pass mirroring the scatter symbols) --
function objTex(sym, c, r) {
  const arr = OBJ[sym];
  if (!arr || !arr.length) return null;
  return arr[cellHash(c, r, 7) % arr.length];
}
const OBJ_OFF = { T: -110, F: -24, R: -22, s: -14, t: -12, h: -18, O: -160, C: -64, B: -40 };
for (const [c, r] of order) {
  const sym = layout[r][c];
  if (!OBJ[sym]) continue;
  const t = objTex(sym, c, r);
  if (!t) continue;
  const [lx, ly] = cellLocal(c, r);
  const off = heightOff(c, r);
  // center the sprite on the cell, base near the diamond centre + authored offset
  const dx = OX + lx - t.width / 2;
  const dy = OY + ly - t.height / 2 + (OBJ_OFF[sym] || -20) + off;
  blit(t, dx, dy);
}

// ---- downscale to a review-friendly width ------------------------------------
const TARGET_W = 1600;
const scale = Math.min(1, TARGET_W / CW);
const outW = Math.max(1, Math.round(CW * scale));
const outH = Math.max(1, Math.round(CH * scale));
const out = new PNG({ width: outW, height: outH });
for (let y = 0; y < outH; y++) {
  const sy = Math.min(CH - 1, Math.floor(y / scale));
  for (let x = 0; x < outW; x++) {
    const sx = Math.min(CW - 1, Math.floor(x / scale));
    const si = (CW * sy + sx) << 2, di = (outW * y + x) << 2;
    out.data[di] = canvas.data[si]; out.data[di + 1] = canvas.data[si + 1];
    out.data[di + 2] = canvas.data[si + 2]; out.data[di + 3] = 255;
  }
}
fs.writeFileSync(OUT, PNG.sync.write(out));
console.log(`wrote ${OUT}  (${outW}×${outH}; full canvas ${CW}×${CH})`);
