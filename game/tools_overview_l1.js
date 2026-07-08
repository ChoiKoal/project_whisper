#!/usr/bin/env node
// tools_overview_l1.js — Layer-1 「시작의 숲」 (starting_grove) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l1.js
//
// The in-engine SubViewport render can't run under --headless (dummy driver, no framebuffer),
// so — as with the home / L2~L5 previews — this offline pngjs compositor draws the Layer-1 map
// the SAME way the game does, from the REAL authored data + the NEW procedural L1A art:
//   • reads data/map_layout.txt + data/map_legend.json (single source of truth — no hard-coded map)
//   • projects the 40×40 grid in iso (128×64 diamonds)
//   • blits the grass tiles with the EXACT M6a cluster-variant noise (_variant_source mirror),
//     dirt / mud / water / mystic-pond tiles, void + hollow
//   • lays a night-void cliff-skirt on the OUTER border void so the island rim reads as a raised
//     bank rather than a razor edge (mirrors map_loader _build_cliff_skirts intent)
//   • places the authored objects — trees a/b/c (cell-hash %3, matching _object_texture), flowers
//     ×3, rock, stone, bush_dry, night bud gate, cauldron, rest stump, mystic pond glow, and the
//     WORLD TREE (dormant baseline + additive violet glow + violet light pool) at their real
//     legend offsets, y-sorted.
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
const TW = 128, TH = 64, HW = 64, HH = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/map_layout.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/map_legend.json`, "utf8"));
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

// ---- bounds (tile diamonds + tall object sprites so nothing clips) ----------
let minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (symAt(c, r) === "") continue;
  const [lx, ly] = cellLocal(c, r);
  minX = Math.min(minX, lx - HW); maxX = Math.max(maxX, lx + HW);
  minY = Math.min(minY, ly - TH); maxY = Math.max(maxY, ly + TH * 2);
}
// world tree is tall (490px, offset -240, scale .5) — pad the top so its canopy fits.
minY -= 260;
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
  // nearest-neighbour scaled blit (world tree draws at scale 0.5, matching world_tree.gd).
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

// ---- draw tiles (painter's order, back rows first) --------------------------
function tileScreen(c, r) { const [lx, ly] = cellLocal(c, r); return [OX + lx - HW, OY + ly - HH]; }
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
  // mystic pond additive glow rim (mirrors mystic_water glow child).
  if (sym === "m" && MYSTIC_GLOW) {
    const [lx, ly] = cellLocal(c, r);
    blit(MYSTIC_GLOW, Math.round(OX + lx - MYSTIC_GLOW.width / 2), Math.round(OY + ly - MYSTIC_GLOW.height / 2), { additive: true, alpha: 0.8 });
  }
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

// ---- objects (y-sorted) -----------------------------------------------------
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
  const baseX = OX + lx, baseY = OY + ly;
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
      if (VIOLET_POOL) blit(VIOLET_POOL, Math.round(OX + lx - VIOLET_POOL.width / 2), Math.round(OY + ly - VIOLET_POOL.height / 2 - 8), { additive: true, alpha: 0.7 });
      pushObj(c, r, "cauldron", [0, -64]);
      break;
    }
    case "U": pushObj(c, r, "rest_stump", [0, -80]); break;        // rest_stump.gd offset
    case "O": {
      if (!worldTreeDone) {
        worldTreeDone = true;
        // centroid of the 2×2 O block = this cell + (0,32) local nudge (matches _spawn).
        const [lx, ly] = cellLocal(c, r);
        const cx = OX + lx, cy = OY + ly + 32;
        // large violet light pool washing the base (light_pool_violet_lg).
        if (VIOLET_POOL_LG) blit(VIOLET_POOL_LG, Math.round(cx - VIOLET_POOL_LG.width / 2), Math.round(cy - VIOLET_POOL_LG.height / 2), { additive: true, alpha: 0.9 });
        // world tree body: 490×470 @ scale .5, offset (0,-240) from world_tree.gd. Dormant
        // baseline is the pre-purification look; the grove first shows the world tree asleep.
        const body = objArt("world_tree_dormant") || objArt("world_tree");
        const sc = 0.5, o = [0, -240];
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
    const sc = 0.5, o = [0, -240];
    const gw = WORLD_GLOW.width * sc, gh = WORLD_GLOW.height * sc;
    blit(WORLD_GLOW, Math.round(d.gx - gw / 2 + o[0] * sc), Math.round(d.gy - gh + HH + o[1] * sc), { additive: true, alpha: 0.55, scale: sc });
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
