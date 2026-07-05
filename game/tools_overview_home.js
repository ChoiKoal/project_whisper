#!/usr/bin/env node
// tools_overview_home.js — v0.5 phase-C 제0세계 (home island) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_home.js
//
// The in-engine SubViewport render can't run under --headless (dummy rendering driver has
// no framebuffer to read back), so — as with the v050a2/v050b previews — this offline
// pngjs compositor draws the home island the same way the game does:
//   * reads the REAL data/home_layout.txt + data/home_legend.json (so the dais/portal/
//     cauldron cells are exactly where the game spawns them),
//   * starry void-sky background (the island floats in the void),
//   * iso tiles (dirt D + grass patches g) for the island slab,
//   * a small round stone dais under the spawn (mirrors HomeSession._draw_dais),
//   * the CC0 cauldron + a stone observation marker,
//   * 5 portal stone arches in the authored arc — nature (Layer 1) FLICKERING (violet
//     glow), the other four DORMANT (dark, cold stone) — mirroring portal.gd geometry
//     (two legs + a rounded lintel + a soft violet glow disc in the opening).
//
// Output: /workspace/group/preview-home.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const OUT = "/workspace/group/preview-home.png";

const TW = 128, TH = 64, HW = 64, HH = 32;

const layout = read(`${GAME}/data/home_layout.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/home_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tile = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const obj = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

const SRC = {
  0: tile("t0_void"), 1: tile("t1_dirt"), 2: tile("t2a_grass"),
  3: tile("t2b_grass_flowers"), 4: tile("t2c_grass_clover"), 5: tile("t2d_flower_grass"),
};
const CAULDRON = obj("cauldron"), STONE = obj("stone"), TUFT = obj("grass_tuft");

// ---------------- iso projection --------------------------------------------
function cellLocal(c, r) { return [(c - r) * HW, (c + r) * HH]; }

// ---------------- portal.gd geometry mirror ---------------------------------
const ARCH_W = 96, ARCH_H = 150, LEG_W = 20, OPENING_W = ARCH_W - LEG_W * 2, GLOW_R = 30;
const ROCK_BASE = [120, 96, 78], ROCK_DARK = [72, 56, 44], ROCK_LIGHT = [150, 122, 102];
const VIOLET = [158, 122, 217], VIOLET_BRIGHT = [200, 168, 242];
function hash2(c, r, salt = 0) {
  let h = (Math.imul(c, 73856093) ^ Math.imul(r, 19349663) ^ Math.imul(salt, 83492791) ^ (0x9e3779b9 | 0)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) | 0; h = h ^ (h >>> 16); return (h & 0x7fffffff);
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xffff) / 65535.0; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function rockCol(s) {
  s = Math.max(0, Math.min(1.4, s));
  if (s < 1.0) return lerpC(ROCK_DARK, ROCK_BASE, Math.max(0, Math.min(1, s)));
  return lerpC(ROCK_BASE, ROCK_LIGHT, Math.max(0, Math.min(1, (s - 1.0) / 0.4)));
}
// Build the stone-arch sprite exactly like portal._build_arch (base-centre anchored).
function buildArch(state) {
  const img = new PNG({ width: ARCH_W, height: ARCH_H });
  img.data.fill(0);
  const cx = ARCH_W >> 1, innerHalf = OPENING_W >> 1, archSpring = Math.floor(ARCH_H * 0.42);
  // dormant portals read cold/dark; flickering reads a touch warmer (matches _apply_state modulate)
  const mod = state === "flickering" ? [0.86, 0.84, 0.9] : [0.62, 0.60, 0.66];
  for (let y = 0; y < ARCH_H; y++) {
    for (let x = 0; x < ARCH_W; x++) {
      let inside = false;
      if (y >= archSpring) {
        const leftLeg = x >= (cx - innerHalf - LEG_W) && x < (cx - innerHalf);
        const rightLeg = x >= (cx + innerHalf) && x < (cx + innerHalf + LEG_W);
        if (leftLeg || rightLeg) inside = true;
      }
      const dx = x - cx, dy = y - archSpring, outerR = innerHalf + LEG_W, innerR = innerHalf;
      if (dy <= 0) { const d = Math.sqrt(dx * dx + dy * dy); if (d <= outerR && d >= innerR) inside = true; }
      if (!inside) continue;
      let lit = x < cx ? 0.82 : 1.06;
      const strata = Math.floor(rockNoise((x / 5) | 0, (y / 6) | 0, 71) * 4.0) / 4.0;
      const facet = (strata - 0.4) * 0.4;
      const n = rockNoise(x, y, 71) * 0.10 - 0.05;
      let col = rockCol(lit + facet + n);
      col = [col[0] * mod[0], col[1] * mod[1], col[2] * mod[2]];
      put(img, x, y, col[0], col[1], col[2], 255);
    }
  }
  return img;
}
// Additive violet glow disc (portal._build_glow) — only drawn for flickering/open portals.
function buildGlow(alphaScale) {
  const s = GLOW_R * 2, img = new PNG({ width: s, height: s });
  img.data.fill(0);
  for (let y = 0; y < s; y++) for (let x = 0; x < s; x++) {
    const d = Math.hypot(x + 0.5 - GLOW_R, y + 0.5 - GLOW_R) / GLOW_R;
    if (d <= 1.0) { const a = (1 - d) * (1 - d) * alphaScale; put(img, x, y, VIOLET_BRIGHT[0], VIOLET_BRIGHT[1], VIOLET_BRIGHT[2], Math.round(a * 255)); }
  }
  return img;
}

function put(png, x, y, r, g, b, a) {
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (png.width * y + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = a;
}

// ---------------- canvas -----------------------------------------------------
let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const [x, y] = cellLocal(c, r);
  minX = Math.min(minX, x - HW); maxX = Math.max(maxX, x + HW);
  minY = Math.min(minY, y - HH - ARCH_H - 40); maxY = Math.max(maxY, y + HH + 60);
}
const PAD = 60;
const CW = Math.ceil(maxX - minX) + PAD * 2, CH = Math.ceil(maxY - minY) + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;
const canvas = new PNG({ width: CW, height: CH });

// Starry void-sky background: a deep violet-black gradient + scattered stars/motes.
for (let y = 0; y < CH; y++) {
  const t = y / CH;
  const br = 8 + t * 6, bg = 6 + t * 5, bb = 16 + t * 12;
  for (let x = 0; x < CW; x++) { const i = (CW * y + x) << 2; canvas.data[i] = br; canvas.data[i + 1] = bg; canvas.data[i + 2] = bb; canvas.data[i + 3] = 255; }
}
for (let s = 0; s < 900; s++) {
  const sx = hash2(s, 3, 7) % CW, sy = hash2(s, 11, 19) % CH;
  const b = 90 + (hash2(s, 5, 23) % 130);
  const violet = (hash2(s, 9, 31) % 5) === 0;
  put(canvas, sx, sy, violet ? b : b, violet ? Math.round(b * 0.7) : b, violet ? Math.round(b * 1.1) : Math.round(b * 0.95), 255);
  if ((hash2(s, 2, 41) % 7) === 0) { put(canvas, sx + 1, sy, b >> 1, b >> 1, b >> 1, 255); put(canvas, sx, sy + 1, b >> 1, b >> 1, b >> 1, 255); }
}

function blit(src, dx, dy, tint, aScale) {
  if (!src) return;
  const sw = src.width, sh = src.height;
  for (let y = 0; y < sh; y++) {
    const cy = Math.round(dy) + y; if (cy < 0 || cy >= CH) continue;
    for (let x = 0; x < sw; x++) {
      const cx = Math.round(dx) + x; if (cx < 0 || cx >= CW) continue;
      const si = (sw * y + x) << 2; let a = src.data[si + 3]; if (a === 0) continue;
      if (aScale != null) a = Math.min(255, a * aScale);
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
// Additive blit for glows (violet blooms over dark stone, like BLEND_MODE_ADD).
function blitAdd(src, dx, dy) {
  if (!src) return;
  for (let y = 0; y < src.height; y++) { const cy = Math.round(dy) + y; if (cy < 0 || cy >= CH) continue;
    for (let x = 0; x < src.width; x++) { const cx = Math.round(dx) + x; if (cx < 0 || cx >= CW) continue;
      const si = (src.width * y + x) << 2, a = src.data[si + 3]; if (a === 0) continue;
      const di = (CW * cy + cx) << 2, af = a / 255;
      canvas.data[di] = Math.min(255, canvas.data[di] + src.data[si] * af);
      canvas.data[di + 1] = Math.min(255, canvas.data[di + 1] + src.data[si + 1] * af);
      canvas.data[di + 2] = Math.min(255, canvas.data[di + 2] + src.data[si + 2] * af);
    } }
}

// A round stone dais (mirror HomeSession._draw_dais): iso-squashed disc, r=42.
function drawDais(c, r) {
  const [lx, ly] = cellLocal(c, r), R = 42;
  const px = OX + lx, py = OY + ly;
  for (let y = -Math.round(R * 0.5); y <= Math.round(R * 0.5); y++)
    for (let x = -R; x <= R; x++) {
      const dx = x / R, dy = y / (R * 0.5), d2 = dx * dx + dy * dy;
      if (d2 <= 1.0) { const shade = 0.62 + 0.14 * (1 - d2); put(canvas, px + x, py + y, 0.46 * 255 * shade, 0.44 * 255 * shade, 0.42 * 255 * shade, 255); }
    }
}

// ---------------- render passes (back-to-front by c+r) ----------------------
const order = [];
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) order.push([c, r]);
order.sort((a, b) => (a[0] + a[1]) - (b[0] + b[1]));

function srcFor(sym) {
  const spec = legend.tiles[sym]; if (!spec) return null;
  // grass 'g' picks a variant deterministically for texture; portals/cauldron/spawn are dirt.
  if (spec.variant_random) { const v = 2 + (hash2(sym.charCodeAt(0), 0, 3) % 4); return v; }
  return spec.source != null ? spec.source : 2;
}

// Pass A: island ground (skip pure void so the slab reads as floating).
for (const [c, r] of order) {
  const sym = layout[r][c]; if (sym === "V") continue;
  const [lx, ly] = cellLocal(c, r);
  // grass variant per-cell for a little texture
  let src = 1;
  if (sym === "g" || sym === "G") src = 2 + ((hash2(c, r, 3) & 3));
  const tex = SRC[src] || SRC[1];
  blit(tex, OX + lx - HW, OY + ly - HH);
}

// Pass B: dais under the spawn cell.
const spawnCell = findSym("S");
if (spawnCell) drawDais(spawnCell[0], spawnCell[1]);

// Pass C: objects (cauldron, observation stone, portals) back-to-front.
for (const [c, r] of order) {
  const sym = layout[r][c];
  const [lx, ly] = cellLocal(c, r);
  const px = OX + lx, py = OY + ly;   // cell centre (object base sits here)
  if (sym === "C" && CAULDRON) { blit(CAULDRON, px - CAULDRON.width / 2, py - CAULDRON.height + 16); }
  else if (sym === "Y" && STONE) { blit(STONE, px - STONE.width / 2, py - STONE.height + 12); }
  else if ("12345".includes(sym)) {
    const objSpec = legend.objects[sym];
    const isNature = objSpec && objSpec.layer === "nature";
    const state = isNature ? "flickering" : "dormant";
    // violet light pool at the base for the awake portal
    if (isNature) { const pool = buildGlow(0.5); blitAdd(pool, px - GLOW_R, py - GLOW_R * 0.5); }
    const arch = buildArch(state);
    blit(arch, px - ARCH_W / 2, py - ARCH_H);   // base-centre anchored
    if (isNature) { const glow = buildGlow(0.6); blitAdd(glow, px - GLOW_R, py - ARCH_H * 0.52 - GLOW_R); }
  }
}

function findSym(s) { for (let r = 0; r < H; r++) { const c = layout[r].indexOf(s); if (c >= 0) return [c, r]; } return null; }

// ---------------- write ------------------------------------------------------
writeScaled(canvas, CW, CH, OUT, 1500);

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
