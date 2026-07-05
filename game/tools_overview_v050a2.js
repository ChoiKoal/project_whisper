#!/usr/bin/env node
// tools_overview_v050a2.js — v0.5 phase-A2 elevation FIX overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_v050a2.js
//
// Rewrite of the v050a overview to draw the corrected elevation: full-perimeter
// programmatic cliff aprons (grass-topped rock, zero gaps), AO seating shadows on the
// lower ground, grass-lip fringe, and ramp slopes. Mirrors scripts/world/cliff_gen.gd
// and map_loader._build_elevation EXACTLY so the render matches the game.
//
// Outputs:
//   /workspace/group/preview-v050a2.png          (full map, downscaled to ~1600w)
//   /workspace/group/preview-v050a2-closeup.png   (2x crop of the hill for review)

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const OUT = "/workspace/group/preview-v050a2.png";
const OUT_CLOSE = "/workspace/group/preview-v050a2-closeup.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

const layout = read(`${GAME}/data/map_layout.txt`);
const height = read(`${GAME}/data/map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tile = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const obj = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

const SRC = {
  0: tile("t0_void"), 1: tile("t1_dirt"), 2: tile("t2a_grass"), 3: tile("t2b_grass_flowers"),
  4: tile("t2c_grass_clover"), 5: tile("t2d_flower_grass"), 7: tile("t4_mud"),
  8: tile("t5a_water_anim"), 9: tile("t5b_water2_anim"), 10: tile("t5m_mystic"), 11: tile("t0_hollow"),
};
const RIDGE = [tile("ridge_rock"), tile("ridge_rock_b")].filter(Boolean);
const OBJ = {
  T: [obj("tree_a"), obj("tree_b"), obj("tree_c")].filter(Boolean),
  F: [obj("flower"), obj("flower_violet"), obj("flower_pink")].filter(Boolean),
  R: [obj("rock")], s: [obj("stone")], t: [obj("grass_tuft")], h: [obj("bush_green")],
  O: [obj("world_tree")], C: [obj("cauldron")], B: [obj("bush_dry")],
};

// ---------------- cliff_gen.gd mirror ----------------------------------------
function hash2(c, r, salt = 0) {
  let h = (Math.imul(c, 73856093) ^ Math.imul(r, 19349663) ^ Math.imul(salt, 83492791) ^ (0x9e3779b9 | 0)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) | 0;
  h = h ^ (h >>> 16);
  return (h & 0x7fffffff);
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xffff) / 65535.0; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
const ROCK_BASE = [120, 96, 78], ROCK_DARK = [72, 56, 44], ROCK_LIGHT = [150, 122, 102], ROCK_SHADOW = [46, 36, 30];
const GRASS_LIP = [86, 128, 60], GRASS_LIP_DK = [58, 92, 42];
function rockCol(s) {
  s = Math.max(0, Math.min(1.4, s));
  if (s < 0.7) return lerpC(ROCK_SHADOW, ROCK_DARK, Math.min(1, s / 0.7));
  if (s < 1.0) return lerpC(ROCK_DARK, ROCK_BASE, Math.min(1, (s - 0.7) / 0.3));
  return lerpC(ROCK_BASE, ROCK_LIGHT, Math.min(1, (s - 1.0) / 0.4));
}
// Returns {img: PNG, h} apron. imgH = LIFT*drop + TH.
function makeApron(drop, exposeSE, exposeSW, salt) {
  const wall = LIFT * drop, imgH = wall + TH;
  const img = new PNG({ width: TW, height: imgH });
  img.data.fill(0);
  for (let x = 0; x < TW; x++) {
    const isLeft = x < HW;
    const rim = isLeft ? (HH + x * 0.5) : ((TW - x) * 0.5 + HH);
    const exposed = isLeft ? exposeSW : exposeSE;
    if (!exposed) continue;
    const rimY = Math.round(rim), wallTop = rimY, wallBottom = rimY + wall;
    const sideLight = isLeft ? 0.74 : 1.10;
    for (let y = wallTop; y < wallBottom; y++) {
      const t = (y - wallTop) / Math.max(1, wall);
      const vshade = 1.0 - 0.30 * t;
      const strata = Math.floor(rockNoise((x / 6) | 0, (y / 5) | 0, salt) * 5.0) / 5.0;
      const facet = (strata - 0.4) * 0.5;
      const crack = (rockNoise((x / 3) | 0, (y / 7) | 0, salt + 5) < 0.14) ? -0.34 : 0.0;
      const n = rockNoise(x, y, salt) * 0.12 - 0.06;
      const c = rockCol(sideLight * vshade + facet + crack + n);
      put(img, x, y, c[0], c[1], c[2], 255);
    }
    const lipH = 5, jag = Math.floor(rockNoise(x, 7, salt) * 3.0);
    for (let y = wallTop; y < Math.min(wallTop + lipH, imgH); y++) {
      if (y < wallTop + lipH - jag) {
        const g = ((x + y) % 3 !== 0) ? GRASS_LIP : GRASS_LIP_DK;
        put(img, x, y, g[0], g[1], g[2], 255);
      }
    }
  }
  return { img, h: imgH };
}
function makeAO(strength) {
  const img = new PNG({ width: TW, height: TH });
  img.data.fill(0);
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
    const dx = Math.abs(x - HW) / HW, dy = Math.abs(y - HH) / HH, d = dx + dy;
    if (d > 1.0) continue;
    const a = Math.max(0, Math.min(1, (1.0 - d) / 0.62));
    put(img, x, y, 0, 0, 0, Math.round(a * a * strength * 255));
  }
  return img;
}
function makeRamp(dir, salt) {
  const h = LIFT + TH, img = new PNG({ width: TW, height: h });
  img.data.fill(0);
  const dirt = [150, 120, 84], dirtDk = [110, 86, 58], dirtLt = [178, 146, 104];
  const grad = (x, y) => {
    if (dir === "se") return Math.max(0, Math.min(1, x / TW));
    if (dir === "nw") return Math.max(0, Math.min(1, 1 - x / TW));
    if (dir === "sw") return Math.max(0, Math.min(1, y / TH));
    return Math.max(0, Math.min(1, 1 - y / TH));
  };
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
    const dx = Math.abs(x - HW) / HW, dy = Math.abs(y - HH) / HH;
    if (dx + dy > 1.0) continue;
    const g = grad(x, y), band = (Math.floor(g * 6) % 2 === 0);
    const n = rockNoise(x, y, salt) * 0.12 - 0.06;
    let base = band ? lerpC(dirt, dirtLt, g) : lerpC(dirt, dirtDk, 1 - g);
    base = [base[0] + n * 255, base[1] + n * 255, base[2] + n * 255];
    put(img, x, y, base[0], base[1], base[2], 255);
  }
  for (let x = 0; x < TW; x++) {
    const isLeft = x < HW, rim = isLeft ? (HH + x * 0.5) : ((TW - x) * 0.5 + HH), rimY = Math.round(rim);
    for (let y = rimY; y < Math.min(rimY + LIFT, h); y++) {
      const t = (y - rimY) / LIFT, c = lerpC(dirtDk, [74, 58, 40], t);
      put(img, x, y, c[0], c[1], c[2], 255);
    }
  }
  return img;
}
function put(png, x, y, r, g, b, a) {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (png.width * y + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = a;
}

// ---------------- height helpers (mirror map_loader) -------------------------
function hAt(c, r) {
  if (r < 0 || r >= height.length) return 0;
  const row = height[r]; if (c < 0 || c >= row.length) return 0;
  // only island ground carries height
  const l = layout[r] && layout[r][c];
  if (l === "V" || l === "W" || l === "w" || l === "m" || l === undefined) return 0;
  const ch = row[c]; return ch === "1" ? 1 : ch === "2" ? 2 : 0;
}
function isRamp(c, r) {
  if (r < 0 || r >= height.length) return false;
  const row = height[r];
  if (!(c >= 0 && c < row.length && row[c] === "/")) return false;
  const l = layout[r] && layout[r][c];
  return !(l === "V" || l === "W" || l === "w" || l === "m" || l === undefined);
}
function rampMid(c, r) {
  let lo = 99, hi = 0;
  for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const l = hAt(c + dc, r + dr); lo = Math.min(lo, l); hi = Math.max(hi, l); }
  if (lo === 99) return 0;
  return (lo + hi) / 2;
}
function heightOff(c, r) { return isRamp(c, r) ? -LIFT * rampMid(c, r) : -LIFT * hAt(c, r); }
function cellLocal(c, r) { return [(c - r) * HW, (c + r) * HH]; }

// ---------------- canvas -----------------------------------------------------
let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const [x, y] = cellLocal(c, r);
  minX = Math.min(minX, x - HW); maxX = Math.max(maxX, x + HW);
  minY = Math.min(minY, y - HH - LIFT * 2 - 240); maxY = Math.max(maxY, y + HH + 260);
}
const PAD = 40;
const CW = Math.ceil(maxX - minX) + PAD * 2, CH = Math.ceil(maxY - minY) + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;
const canvas = new PNG({ width: CW, height: CH });
for (let i = 0; i < canvas.data.length; i += 4) {
  canvas.data[i] = 12; canvas.data[i + 1] = 10; canvas.data[i + 2] = 18; canvas.data[i + 3] = 255;
}
function blit(src, dx, dy, frameW) { blitTinted(src, dx, dy, null, frameW); }
function blitTinted(src, dx, dy, tint, frameW) {
  if (!src) return;
  const sw = frameW || src.width, sh = src.height;
  for (let y = 0; y < sh; y++) {
    const cy = Math.round(dy) + y; if (cy < 0 || cy >= CH) continue;
    for (let x = 0; x < sw; x++) {
      const cx = Math.round(dx) + x; if (cx < 0 || cx >= CW) continue;
      const si = (src.width * y + x) << 2, a = src.data[si + 3]; if (a === 0) continue;
      const di = (CW * cy + cx) << 2, af = a / 255;
      let sr = src.data[si], sg = src.data[si + 1], sb = src.data[si + 2];
      if (tint) { sr = Math.min(255, sr * tint[0]); sg = Math.min(255, sg * tint[1]); sb = Math.min(255, sb * tint[2]); }
      canvas.data[di] = sr * af + canvas.data[di] * (1 - af);
      canvas.data[di + 1] = sg * af + canvas.data[di + 1] * (1 - af);
      canvas.data[di + 2] = sb * af + canvas.data[di + 2] * (1 - af);
      canvas.data[di + 3] = 255;
    }
  }
}

// ---------------- variant selection (mirror) ---------------------------------
function valueNoise(c, r, cs, salt) {
  const gx = c / cs, gy = r / cs, x0 = Math.floor(gx), y0 = Math.floor(gy);
  let fx = gx - x0, fy = gy - y0; fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
  const n = (a, b) => (hash2(a, b, salt) & 0xffff) / 65535;
  const nx0 = n(x0, y0) * (1 - fx) + n(x0 + 1, y0) * fx;
  const nx1 = n(x0, y0 + 1) * (1 - fx) + n(x0 + 1, y0 + 1) * fx;
  return nx0 * (1 - fy) + nx1 * fy;
}
function variantSrc(c, r) {
  const n = valueNoise(c, r, 5, 11) * 0.7 + valueNoise(c, r, 2, 29) * 0.3;
  if (n < 0.52) return 2; if (n < 0.68) return 4; if (n < 0.84) return 3; return 5;
}
function srcFor(c, r) {
  const sym = layout[r][c], spec = legend.tiles[sym];
  if (!spec) return 2;
  let src = spec.source != null ? spec.source : 2;
  if (spec.variant_random) src = variantSrc(c, r);
  return src;
}

// ---------------- render passes ----------------------------------------------
const order = [];
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) order.push([c, r]);
order.sort((a, b) => (a[0] + a[1]) - (b[0] + b[1]));

// downhill front faces of a raised cell (mirror map_loader._downhill_faces).
function downhillFaces(c, r) {
  const out = { se: 0, sw: 0 };
  if (isRamp(c, r)) return out;
  const lv = hAt(c, r); if (lv <= 0) return out;
  const east = hAt(c + 1, r);   // +col => SE screen
  const south = hAt(c, r + 1);  // +row => SW screen
  if (east < lv && !isRamp(c + 1, r)) out.se = lv - east;
  if (south < lv && !isRamp(c, r + 1)) out.sw = lv - south;
  return out;
}

// Pass A: base ground for EVERY cell.
for (const [c, r] of order) {
  const [lx, ly] = cellLocal(c, r);
  const bx = OX + lx - HW, by = OY + ly - HH;
  const src = srcFor(c, r), tex = SRC[src];
  const frameW = (src === 8 || src === 9) ? 128 : undefined;
  blit(tex, bx, by, frameW);
}

// Pass B: AO seating shadows on the LOWER ground at the foot of every exposed cliff.
// Drawn on the lower cell (the neighbour), so it sits on the ground the hill drops to.
const aoImg = makeAO(0.6);
for (const [c, r] of order) {
  const f = downhillFaces(c, r);
  if (f.se > 0) { const [lx, ly] = cellLocal(c + 1, r); blit(aoImg, OX + lx - HW, OY + ly - HH + heightOff(c + 1, r)); }
  if (f.sw > 0) { const [lx, ly] = cellLocal(c, r + 1); blit(aoImg, OX + lx - HW, OY + ly - HH + heightOff(c, r + 1)); }
}

// Pass C: per-cell — cliff apron (below), then raised surface, in painter order.
for (const [c, r] of order) {
  const [lx, ly] = cellLocal(c, r);
  const bx = OX + lx - HW, by = OY + ly - HH;
  const lvl = hAt(c, r);
  const off = heightOff(c, r);
  // ramp cell → slope tile
  if (isRamp(c, r)) {
    const dir = rampDir(c, r);
    const ramp = makeRamp(dir, hash2(c, r, 41));
    // anchor: ramp top diamond at the ramp mid height
    blit(ramp, bx, by + off);
    continue;
  }
  if (lvl <= 0) continue;
  const f = downhillFaces(c, r);
  const drop = Math.max(f.se, f.sw);
  if (drop > 0) {
    const ap = makeApron(drop, f.se > 0, f.sw > 0, hash2(c, r, 611));
    // apron anchored at raised diamond centre: top-left = (center-64, center-32) lifted.
    blit(ap.img, bx, by + off);
  }
  // raised grass surface on top, tonally lifted per tier (matches map_loader layer.modulate).
  const gsrc = (srcFor(c, r) >= 2 && srcFor(c, r) <= 5) ? srcFor(c, r) : variantSrc(c, r);
  const tl = lvl / 2.0;
  const tint = [1.0 + 0.14 * tl, 1.0 + 0.13 * tl, 1.0 + 0.06 * tl];
  blitTinted(SRC[gsrc], bx, by + off, tint);
}

function rampDir(c, r) {
  // climb toward the HIGHER neighbour.
  let best = "ne", bestLv = -1;
  const dirs = [[[1, 0], "se"], [[-1, 0], "nw"], [[0, 1], "sw"], [[0, -1], "ne"]];
  for (const [[dc, dr], name] of dirs) { const l = hAt(c + dc, r + dr); if (l > bestLv) { bestLv = l; best = name; } }
  return best;
}

// Pass D: interior ridge pillars.  (DBG mode skips ridges + objects to isolate the hill)
function reachesLand(c, r, dc, dr) {
  let p = [c + dc, r + dr], steps = W + H;
  while (steps-- > 0) {
    const [cc, rr] = p;
    if (rr < 0 || rr >= H || cc < 0 || cc >= layout[rr].length) return false;
    const s = layout[rr][cc];
    if (s !== "V") return s !== "W" && s !== "w" && s !== "m";
    p = [cc + dc, rr + dr];
  }
  return false;
}
// Interior ridge canyon walls. The game lays a continuous rock WALL band on these cells
// (Y-sorted 128×230 pieces overlap into one band). In painter order the raw monoliths
// leave black seams, so we render the band as a continuous parametric rock plateau: a
// RIDGE_LVL-tall rock apron on each cell's exposed (screen S/E, toward land) edge + a rock
// cap on top. This is gap-free by construction and reads as the same continuous rock wall.
const RIDGE_LVL = 3;  // ~96px rock wall — reads as a canyon rim, not a low step
function ridgeAt(c, r) {
  if (r < 0 || r >= H || c < 0 || c >= (layout[r] ? layout[r].length : 0)) return false;
  if (layout[r][c] !== "V") return false;
  const ns = reachesLand(c, r, 0, -1) && reachesLand(c, r, 0, 1);
  const ew = reachesLand(c, r, -1, 0) && reachesLand(c, r, 1, 0);
  return ns || ew;
}
function makeRockCapDiamond() {
  const img = new PNG({ width: TW, height: TH });
  img.data.fill(0);
  for (let y = 0; y < TH; y++) for (let x = 0; x < TW; x++) {
    const dx = Math.abs(x - HW) / HW, dy = Math.abs(y - HH) / HH;
    if (dx + dy > 1.0) continue;
    const strata = Math.floor(rockNoise((x / 7) | 0, (y / 4) | 0, 3) * 4.0) / 4.0;
    const n = rockNoise(x, y, 3) * 0.14 - 0.07;
    const c = rockCol(0.86 + (strata - 0.4) * 0.4 + n);   // faceted lit rock top
    put(img, x, y, c[0], c[1], c[2], 255);
  }
  return img;
}
const rockCap = makeRockCapDiamond();
if (!process.env.DBG) for (const [c, r] of order) {
  if (!ridgeAt(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  const bx = OX + lx - HW, by = OY + ly - HH, off = -LIFT * RIDGE_LVL;
  // exposed front edges toward non-ridge land (SE = +col, SW = +row).
  const se = !ridgeAt(c + 1, r);
  const sw = !ridgeAt(c, r + 1);
  if (se || sw) {
    const ap = makeApron(RIDGE_LVL, se, sw, hash2(c, r, 907));
    blit(ap.img, bx, by + off);
  }
  // rock cap on top (raised RIDGE_LVL).
  blit(rockCap, bx, by + off);
}

// Pass E: objects (lifted onto plateau).
function objTex(sym, c, r) { const arr = OBJ[sym]; if (!arr || !arr.length) return null; return arr[hash2(c, r, 7) % arr.length]; }
const OBJ_OFF = { T: -110, F: -24, R: -22, s: -14, t: -12, h: -18, O: -160, C: -64, B: -40 };
for (const [c, r] of order) {
  const sym = layout[r][c]; if (!OBJ[sym]) continue;
  const t = objTex(sym, c, r); if (!t) continue;
  const [lx, ly] = cellLocal(c, r), off = heightOff(c, r);
  blit(t, OX + lx - t.width / 2, OY + ly - t.height / 2 + (OBJ_OFF[sym] || -20) + off);
}

// ---------------- output -----------------------------------------------------
writeScaled(canvas, CW, CH, OUT, 1600);
// close-up: crop around the hill band (rows 17-25). Compute pixel bbox.
let cxMin = 1e9, cxMax = -1e9, cyMin = 1e9, cyMax = -1e9;
for (let r = 17; r <= 25; r++) for (let c = 4; c <= 31; c++) {
  const [lx, ly] = cellLocal(c, r);
  cxMin = Math.min(cxMin, OX + lx - HW); cxMax = Math.max(cxMax, OX + lx + HW);
  cyMin = Math.min(cyMin, OY + ly - HH - 90); cyMax = Math.max(cyMax, OY + ly + HH + 40);
}
cropScaled(canvas, CW, CH, OUT_CLOSE, Math.round(cxMin), Math.round(cyMin), Math.round(cxMax - cxMin), Math.round(cyMax - cyMin), 2);

function writeScaled(src, sw, sh, out, targetW) {
  const scale = Math.min(1, targetW / sw);
  const oW = Math.max(1, Math.round(sw * scale)), oH = Math.max(1, Math.round(sh * scale));
  const o = new PNG({ width: oW, height: oH });
  for (let y = 0; y < oH; y++) { const sy = Math.min(sh - 1, Math.floor(y / scale));
    for (let x = 0; x < oW; x++) { const sx = Math.min(sw - 1, Math.floor(x / scale));
      const si = (sw * sy + sx) << 2, di = (oW * y + x) << 2;
      o.data[di] = src.data[si]; o.data[di + 1] = src.data[si + 1]; o.data[di + 2] = src.data[si + 2]; o.data[di + 3] = 255; } }
  fs.writeFileSync(out, PNG.sync.write(o));
  console.log(`wrote ${out}  (${oW}×${oH})`);
}
function cropScaled(src, sw, sh, out, x0, y0, cw, ch, zoom) {
  const oW = cw * zoom, oH = ch * zoom, o = new PNG({ width: oW, height: oH });
  for (let y = 0; y < oH; y++) { const sy = Math.min(sh - 1, y0 + Math.floor(y / zoom));
    for (let x = 0; x < oW; x++) { const sx = Math.min(sw - 1, x0 + Math.floor(x / zoom));
      const si = (sw * sy + sx) << 2, di = (oW * y + x) << 2;
      o.data[di] = src.data[si]; o.data[di + 1] = src.data[si + 1]; o.data[di + 2] = src.data[si + 2]; o.data[di + 3] = 255; } }
  fs.writeFileSync(out, PNG.sync.write(o));
  console.log(`wrote ${out}  (${oW}×${oH})`);
}
