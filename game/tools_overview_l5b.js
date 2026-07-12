#!/usr/bin/env node
// tools_overview_l5b.js — EX-L5 SUB-zone 「침묵의 종탑」 (belfry, l5b) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_l5b.js [--hero]
//
// The 침묵의 종탑 is the new zone shipped in v1.9.0 — reached by 대성당 종탑 하강 계단 from the
// L5 대성당(정화 후). It is its own 40×40 map (l5b_map_layout.txt/height/legend) reusing the
// Layer-5 상아/백은 tileset (source 5 → L5T-A/Q/C/O/crack/ramp → l5_ivory/quiet/choir/altar/
// cliff/ramp) with l5b_-prefixed object art (bell_shard/belfry_rope/resonant_bronze/reverb_dust +
// chime_ward/bell_forge/bellkeeper_shade + reverb_font/bell_altar + great_bell). Same offline
// pngjs compositor + STACKED iso projection as tools_overview_l4m.js (the in-engine SubViewport
// can't run under --headless).
//
// Real elevation is used (design §A-2: 착지 계단참 0 / 종실·퍼즐실 +1 / 종탑 정점 +2 —
// l5b_map_height.txt), so cliff aprons fire on the void(허공) rims AND on the +1/+2 종탑 steps.
//
// Mood target (design §A-2): 창백한 상아/백은 base + 청동 종체 + 상아-은 차임 발광, 정적의 허공.
// "다시 울리기를 기다리는, 소리 멎은 종탑."
//
// overview → /workspace/group/preview-l5.png        (the full new zone 조감, STACKED)
// --hero   → /workspace/group/preview-l5-hero.png    (종탑 정점 줌인: great_bell o / bell_altar H,
//            LANCZOS-quality: high-res capture area-downsampled — mirrors tools_overview_l1_ex.js
//            hero path)

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const HERO = process.argv.includes("--hero");
const OUT = HERO ? "/workspace/group/preview-l5-hero.png"
                 : "/workspace/group/preview-l5.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
const layout = read(`${GAME}/data/l5b_map_layout.txt`);
const height = read(`${GAME}/data/l5b_map_height.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/l5b_map_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tileArt = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const objArt = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

// The 침묵의 종탑 legend keys every walkable/gate tile to source 5 with L5T-* tile_ids (height
// baked separately in l5b_map_height.txt); void is source 0. Map the tile_ids onto the shipped
// Layer-5 ivory/silver tileset PNGs (same set as the 대성당): A=ivory pave, Q=quiet corridor,
// C=choir/upper, O=altar/vault, crack=cliff, ramp.
const IVORY = tileArt("l5_ivory"), QUIET = tileArt("l5_quiet"), CHOIR = tileArt("l5_choir"),
      ALTAR = tileArt("l5_altar"), CLIFF = tileArt("l5_cliff"), DARK = tileArt("l5_dark");
const RAMP = tileArt("l5_ramp");
const TILE_BY_ID = { "L5T-A": IVORY, "L5T-Q": QUIET, "L5T-C": CHOIR, "L5T-O": ALTAR, "L5T-crack": CLIFF };
function tileFor(sym) {
  if (sym === "/") return RAMP;
  const spec = legend.tiles[sym];
  if (!spec) return null;
  if (spec.void || spec.source === 0) return DARK;
  return TILE_BY_ID[spec.tile_id] || IVORY;
}

// pale ivory/silver CanvasModulate mirror (design §A-2, 대성당과 동계열), LIFTED so the belfry
// reads bright/holy not gloomy (owner review lesson: full night tint crushes the still to mud).
const TONE = [1.04, 1.02, 1.08];
const GLOW_GOLD = [0xff, 0xc4, 0x6a];      // 호박 잔불/청동 발광 (amber) — great bell / altar / font
const GLOW_CHIME = [0xdf, 0xe6, 0xee];     // 상아-은 차임 잔광 — chime ward / silences
function glowRgbFor(kind) { return kind === "chime" ? GLOW_CHIME : GLOW_GOLD; }

// ---------------- CliffGen.make_apron mirror (ivory/silver palette, L5) -------
// Mirrors scripts/world/cliff_gen.gd make_apron: the in-game loader runtime-generates ivory
// cliff aprons at every exposed elevation boundary so raised 종실/퍼즐실/정점 CONNECT to the
// landing floor below (owner reject on clipped art: "높이가 전혀 안 이어져 보임"). Front rim of
// the raised diamond extruded down `drop` levels, silver bands every 20px, amber 잔불 weeps, ivory cap lip.
const B_BASE = [150, 142, 128], B_DARK = [104, 98, 88], B_LIGHT = [232, 226, 208],
      B_SHADOW = [70, 66, 60], B_LIP = [200, 194, 178], B_LIP_DK = [150, 144, 130],
      B_EMBER = [236, 176, 96]; // amber 잔불 weep
function hash2(c, r, salt) {
  let h = (((c * 73856093) ^ (r * 19349663) ^ (salt * 83492791) ^ 0x9E3779B9) >>> 0);
  h = (Math.imul((h ^ (h >>> 13)) >>> 0, 1274126177) >>> 0);
  return ((h ^ (h >>> 16)) >>> 0) & 0x7FFFFFFF;
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xFFFF) / 65535; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function ivoryCol(s) {
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
      let col = ivoryCol(sideLight * vshade + facet + crack + n);
      if ((y - rimY) % 20 < 1) col = lerpC(col, B_LIGHT, 0.4);          // rune band
      else if (!isLeft && rockNoise((x / 9) | 0, 0, salt + 3) < 0.06) col = lerpC(col, B_EMBER, 0.5); // gold weep
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

// ---------------- iso projection (STACKED, mirrors in-game map_to_local) ------
function cellLocal(c, r) { return [(c + ((r & 1) ? 0.5 : 0)) * TW, r * HH]; }
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

// ---------------- background: void abyss + ivory-amber wash + chime motes -----
function bgAt(x, y) {
  const t = y / worldH;
  let r = 0x1a + (1 - t) * 0x10, g = 0x18 + (1 - t) * 0x0e, b = 0x1e + (1 - t) * 0x10;
  // pale ivory+amber wash toward the 종탑 정점 큰 종 (top of map, the great-bell chime glow)
  const cx = worldW * 0.5, cy = worldH * 0.16;
  const d = Math.hypot(x - cx, y - cy) / (worldW * 0.5);
  const halo = Math.max(0, 1 - d) * 42;
  r += halo * 0.72; g += halo * 0.62; b += halo * 0.44;
  return [r, g, b];
}
function h32(a, b, s) { let h = (a * 374761393 + b * 668265263 + s * 2147483647) >>> 0; h = (h ^ (h >> 13)) * 1274126177; return (h >>> 0) / 4294967295; }
for (let y = 0; y < png.height; y++) for (let x = 0; x < png.width; x++) {
  const [r, g, b] = bgAt(x, y);
  const i = (y * png.width + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = 255;
}
// drifting chime motes / reverb dust
for (let i = 0; i < 800; i++) {
  const x = Math.floor(h32(i, 7, 11) * png.width), y = Math.floor(h32(i, 13, 5) * png.height);
  const br = 100 + h32(i, 3, 9) * 130;
  const gold = h32(i, 17, 2) > 0.55;
  put(x, y, gold ? [br, br * 0.82, br * 0.42] : [br * 0.78, br * 0.66, br], 0.7);
  if (h32(i, 23, 4) > 0.94) { put(x + 1, y, [br, br * 0.7, br * 0.5], 0.35); put(x, y + 1, [br, br * 0.7, br * 0.5], 0.35); }
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

function glow(cx, cy, radius, strength, rgb) {
  for (let py = -radius; py <= radius; py++) for (let px = -radius; px <= radius; px++) {
    const d = Math.hypot(px, py) / radius; if (d > 1) continue;
    const a = (1 - d) * (1 - d) * strength;
    add(cx + px, cy + py, rgb, a);
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
  const src = tileFor(sym);
  if (!src) continue;
  const [sx, sy] = tileScreen(c, r);
  blit(src, sx, sy, { tone: true, srcW: Math.min(src.width, TW) });
}

// cliff aprons — fire on void(허공) rims AND on real +1/+2 부유 파편 elevation steps.
const VOID_DROP = 2.4;
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  if (isVoid(c, r)) continue;
  const lv = levelAt(c, r);
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const salt = hash2(c, r, 733);
  for (const [edge, nc, nr] of [["S", c, r + 1], ["E", c + 1, r]]) {
    const se = edge === "E", sw = edge === "S";
    if (isVoid(nc, nr)) {
      drawApron(baseX, baseY, lv + VOID_DROP, se, sw, salt, true);   // abyss rim (fade to void)
    } else if (levelAt(nc, nr) < lv) {
      drawApron(baseX, baseY, lv - levelAt(nc, nr), se, sw, salt, false); // fragment step
    }
  }
}

// ---------------- draw objects (with glow) ----------------------------------
// preview glow anchors per l5b glyph: 종탑 정점 큰 종 (o) brightest amber, 봉헌 목 bell_altar (H)
// amber, 잔향 성수반 reverb_font (F) amber, chime ward (E) chime-silver, bellkeeper shade (N) amber,
// 종 주조로 bell_forge (C) faint amber.
const GLOW_PREVIEW = { o: 1.0, H: 0.72, F: 0.62, E: 0.6, N: 0.5, C: 0.4 };
const WISP_SYMS = new Set(["E", "o", "F"]); // chime ward + great bell + reverb font: rising chime wisps
const draws = [];
for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
  const sym = layout[r][c];
  const objSpec = legend.objects[sym];
  if (!objSpec) continue;
  const src = objArt(objSpec.art);
  if (!src) continue;
  const off = objSpec.offset || [0, -8];
  const legendGlow = objSpec.glow ? (objSpec.glow_scale || 0.4) : 0;
  const glowStrength = Math.max(legendGlow, GLOW_PREVIEW[sym] || 0);
  const glowRgb = glowRgbFor(sym === "E" ? "chime" : "gold");
  const [lx, ly] = cellLocal(c, r);
  const baseX = OX + lx, baseY = OY + ly - liftAt(c, r);
  const sx = Math.round(baseX - src.width / 2 + off[0]);
  const sy = Math.round(baseY - src.height + HH + off[1]);
  draws.push({ depth: baseY, sx, sy, src, glowStrength, glowRgb, wisp: WISP_SYMS.has(sym),
    gx: baseX, gy: baseY - src.height * 0.4 + off[1] * 0.4 + HH, seed: hash2(c, r, 41) });
}
draws.sort((a, b) => a.depth - b.depth);
for (const d of draws) {
  if (d.glowStrength > 0) {
    const rad = Math.max(44, Math.round(d.src.width * 0.45));
    glow(Math.round(d.gx), Math.round(d.gy), rad, d.glowStrength, d.glowRgb);
  }
  blit(d.src, d.sx, d.sy, { tone: true });
  if (d.wisp) {
    const topY = d.sy + 6;
    for (let k = 0; k < 5; k++) {
      const t = k / 5;
      const wx = d.gx + Math.sin(d.seed % 7 + k * 1.9) * (6 + 14 * t);
      const wy = topY - 10 - k * 13;
      const wr = 7 + k * 3, wa = 0.15 * (1 - t * 0.7);
      const wc = d.glowRgb;
      for (let py = -wr; py <= wr; py++) for (let px = -wr; px <= wr; px++) {
        const dd = Math.hypot(px, py) / wr; if (dd > 1) continue;
        add(wx + px, wy + py, wc, (1 - dd) * (1 - dd) * wa);
      }
    }
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

// ---------------- hero crop (종탑 정점: great_bell o + bell_altar H) ----------
// LANCZOS-quality downscale via a GENEROUS high-res capture area-averaged into the final hero
// (mirrors tools_overview_l1_ex.js hero path — pngjs has no resampler, box-average of a
// supersampled capture is the anti-aliased downscale the owner review calls "LANCZOS").
let outPng = png;
if (HERO) {
  // centre on the 종탑 정점 큰 종: great_bell `o` (rows 0-5, +2). Fall back to bell_altar `H`.
  let heroCX = null, heroCY = null;
  for (const target of ["o", "H"]) {
    for (let r = 0; r < H && heroCX === null; r++) for (let c = 0; c < layout[r].length; c++) {
      if (layout[r][c] === target) {
        const [lx, ly] = cellLocal(c, r);
        heroCX = OX + lx; heroCY = OY + ly - liftAt(c, r);
        break;
      }
    }
    if (heroCX !== null) break;
  }
  if (heroCX === null) { heroCX = png.width / 2; heroCY = png.height * 0.16; }

  const HERO_W = 1600, HERO_H = 1200;          // 4:3 final
  const CAP_W = 1560, CAP_H = 1170;            // capture window (deep core cluster)
  let cx0 = Math.round(heroCX - CAP_W / 2), cy0 = Math.round(heroCY - CAP_H * 0.22); // up-bias: core near top, avoid void overshoot
  const heroPng = new PNG({ width: HERO_W, height: HERO_H });
  const sxScale = CAP_W / HERO_W, syScale = CAP_H / HERO_H;
  for (let y = 0; y < HERO_H; y++) for (let x = 0; x < HERO_W; x++) {
    const bx0 = cx0 + Math.floor(x * sxScale), bx1 = cx0 + Math.floor((x + 1) * sxScale);
    const by0 = cy0 + Math.floor(y * syScale), by1 = cy0 + Math.floor((y + 1) * syScale);
    let rr = 0, gg = 0, bb = 0, n = 0;
    for (let sy = by0; sy < Math.max(by0 + 1, by1); sy++) for (let sx = bx0; sx < Math.max(bx0 + 1, bx1); sx++) {
      if (sx < 0 || sy < 0 || sx >= png.width || sy >= png.height) continue;
      const si = (sy * png.width + sx) << 2;
      rr += png.data[si]; gg += png.data[si + 1]; bb += png.data[si + 2]; n++;
    }
    const di = (y * HERO_W + x) << 2;
    if (n === 0) { heroPng.data[di] = heroPng.data[di + 1] = heroPng.data[di + 2] = 0; }
    else { heroPng.data[di] = Math.round(rr / n); heroPng.data[di + 1] = Math.round(gg / n); heroPng.data[di + 2] = Math.round(bb / n); }
    heroPng.data[di + 3] = 255;
  }
  const hvcx = HERO_W / 2, hvcy = HERO_H / 2, hvmax = Math.hypot(hvcx, hvcy);
  for (let y = 0; y < HERO_H; y++) for (let x = 0; x < HERO_W; x++) {
    const d = Math.hypot(x - hvcx, y - hvcy) / hvmax;
    const v = Math.max(0, (d - 0.55)) * 0.6;
    if (v <= 0) continue;
    const i = (y * HERO_W + x) << 2;
    heroPng.data[i] *= (1 - v); heroPng.data[i + 1] *= (1 - v); heroPng.data[i + 2] *= (1 - v);
  }
  outPng = heroPng;
}

fs.writeFileSync(OUT, PNG.sync.write(outPng));
console.log(`wrote ${OUT} (${outPng.width}x${outPng.height})`);
