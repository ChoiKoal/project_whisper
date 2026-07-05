#!/usr/bin/env node
// tools_gen_objart_v050b.js — v0.5 phase B object-art pass.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_objart_v050b.js
//
// Regenerates the small ground-object sprites so they read as NATURAL painterly
// pieces (not severed cliff fragments / lollipops / black-box slices), all with a
// baked soft AO ellipse shadow at their base and guaranteed-clean alpha:
//   rock.png        small rounded boulder cluster (grass tufts at base)
//   stone.png       low pebble pile
//   grass_tuft.png  small grass clump
//   bush_green.png  leafy shrub clump
//   bush_bloom.png  bloomed shrub (green + blossoms)
//   flower.png / flower_violet.png / flower_pink.png   clustered blossoms (NOT lollipops)
//   cauldron.png / cauldron_bubble.png   repainted, AO seat, violet glow rim
//   rest_stump.png  repainted mossy stump, AO seat
//
// Palette is sampled to match the CC0 grassland terrain + cliff_gen rock tones so
// the objects sit in the new terrain. Pure integer raster; deterministic.

const fs = require("fs");
const { PNG } = require("pngjs");

const OUT = __dirname + "/assets/objects/";

// ---------- deterministic hash noise (mirrors cliff_gen) ----------------------
function hash2(c, r, salt = 0) {
  let h = (Math.imul(c, 73856093) ^ Math.imul(r, 19349663) ^ Math.imul(salt, 83492791) ^ (0x9e3779b9 | 0)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) | 0;
  h = h ^ (h >>> 16);
  return h & 0x7fffffff;
}
function noise(x, y, s) { return (hash2(x, y, s) & 0xffff) / 65535.0; }
function clamp(v, a, b) { return v < a ? a : v > b ? b : v; }
function lerp(a, b, t) { return a + (b - a) * t; }
function lerpC(a, b, t) { return [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)]; }

// ---------- palettes (sampled to match terrain / cliff_gen) -------------------
const ROCK_BASE = [122, 104, 92], ROCK_DARK = [74, 62, 54], ROCK_LIGHT = [168, 150, 136], ROCK_SHADOW = [50, 42, 38];
const GRASS_LO = [64, 104, 50], GRASS_MID = [92, 150, 66], GRASS_HI = [140, 196, 96];
const STUMP_BARK = [104, 76, 48], STUMP_DARK = [66, 46, 28], STUMP_TOP = [138, 104, 66], MOSS = [96, 150, 70];
const VIOLET = [150, 96, 220], VIOLET_HI = [196, 150, 246];

function rockCol(s) {
  s = clamp(s, 0, 1.4);
  if (s < 0.65) return lerpC(ROCK_SHADOW, ROCK_DARK, s / 0.65);
  if (s < 1.0) return lerpC(ROCK_DARK, ROCK_BASE, (s - 0.65) / 0.35);
  return lerpC(ROCK_BASE, ROCK_LIGHT, (s - 1.0) / 0.4);
}
function grassCol(t) {
  t = clamp(t, 0, 1);
  return t < 0.5 ? lerpC(GRASS_LO, GRASS_MID, t / 0.5) : lerpC(GRASS_MID, GRASS_HI, (t - 0.5) / 0.5);
}

// ---------- raster helpers ----------------------------------------------------
function img(w, h) { const p = new PNG({ width: w, height: h }); p.data.fill(0); return p; }
function px(p, x, y, r, g, b, a) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= p.width || y >= p.height) return;
  const i = (p.width * y + x) << 2, af = a / 255, ia = 1 - af;
  p.data[i] = r * af + p.data[i] * ia;
  p.data[i + 1] = g * af + p.data[i + 1] * ia;
  p.data[i + 2] = b * af + p.data[i + 2] * ia;
  p.data[i + 3] = Math.min(255, p.data[i + 3] + a * (1 - p.data[i + 3] / 255));
}
// soft-fill an ellipse (cx,cy radii rx,ry) via callback color(nx,ny)->[r,g,b] or null
function fillEllipse(p, cx, cy, rx, ry, color, edge = 1.5) {
  for (let y = Math.floor(cy - ry - 2); y <= Math.ceil(cy + ry + 2); y++) {
    for (let x = Math.floor(cx - rx - 2); x <= Math.ceil(cx + rx + 2); x++) {
      const nx = (x - cx) / rx, ny = (y - cy) / ry, d = Math.sqrt(nx * nx + ny * ny);
      if (d > 1.0 + edge / rx) continue;
      const a = clamp((1.0 - d) * rx / edge, 0, 1);
      if (a <= 0) continue;
      const c = color(nx, ny, x, y);
      if (!c) continue;
      px(p, x, y, c[0], c[1], c[2], Math.round(a * 255) * (c[3] != null ? c[3] : 1));
    }
  }
}
// Baked AO ellipse shadow strip at the base. Semi-transparent black, soft.
function aoShadow(p, cx, cy, rx, ry, strength = 0.42) {
  for (let y = Math.floor(cy - ry - 1); y <= Math.ceil(cy + ry + 1); y++) {
    for (let x = Math.floor(cx - rx - 1); x <= Math.ceil(cx + rx + 1); x++) {
      const nx = (x - cx) / rx, ny = (y - cy) / ry, d = nx * nx + ny * ny;
      if (d > 1.0) continue;
      const a = (1.0 - d) * (1.0 - d) * strength;
      px(p, x, y, 0, 0, 0, Math.round(a * 255));
    }
  }
}
function save(p, name) {
  fs.writeFileSync(OUT + name, PNG.sync.write(p));
  console.log("  " + name + "  " + p.width + "x" + p.height);
}

// ---------- BOULDER (rounded, faceted, grass at base) -------------------------
// One or more overlapping rounded rock lobes forming a natural low boulder, lit
// upper-right, with a grass fringe and a couple of tufts at the contact line.
function drawBoulder(w, h, lobes, salt, grassBase = true) {
  const p = img(w, h);
  const groundY = h - 4;                       // contact line near the bottom
  // AO seat first (widest lobe footprint).
  let foot = 0; for (const L of lobes) foot = Math.max(foot, L.cx + L.rx);
  let footL = w; for (const L of lobes) footL = Math.min(footL, L.cx - L.rx);
  const seatCx = (foot + footL) / 2, seatRx = (foot - footL) / 2 + 5;
  aoShadow(p, seatCx, groundY, seatRx, 7, 0.4);
  // rock lobes, painter order back(smaller y first? just draw as given).
  for (let li = 0; li < lobes.length; li++) {
    const L = lobes[li];
    for (let y = Math.floor(L.cy - L.ry - 2); y <= Math.ceil(L.cy + L.ry + 2); y++) {
      for (let x = Math.floor(L.cx - L.rx - 2); x <= Math.ceil(L.cx + L.rx + 2); x++) {
        const nx = (x - L.cx) / L.rx, ny = (y - L.cy) / L.ry, d = Math.sqrt(nx * nx + ny * ny);
        if (d > 1.0) continue;
        // light from upper-right: shade by (−nx + −ny)
        const lightDir = (-nx * 0.6 - ny * 0.9);          // -1..1, +y is down
        const facet = Math.floor(noise((x / 5) | 0, (y / 5) | 0, salt + li) * 4) / 4 - 0.4;
        const crack = noise((x / 3) | 0, (y / 4) | 0, salt + 9 + li) < 0.10 ? -0.4 : 0.0;
        const grain = noise(x, y, salt + li) * 0.14 - 0.07;
        const rim = d > 0.86 ? -0.22 : 0.0;               // darker silhouette edge
        const s = 0.9 + lightDir * 0.42 + facet * 0.45 + crack + grain + rim;
        const c = rockCol(s);
        const a = d > 0.94 ? clamp((1.0 - d) / 0.06, 0, 1) : 1;
        px(p, x, y, c[0], c[1], c[2], Math.round(a * 255));
      }
    }
  }
  // grass fringe + a few tufts at the base contact (opt-out for bare pebbles).
  if (grassBase) {
    const tuftXs = [footL + 4, seatCx - 2, foot - 6];
    for (const tx of tuftXs) drawGrassClump(p, tx, groundY - 1, 7 + (noise(tx | 0, 3, salt) * 5) | 0, salt + (tx | 0), false);
  }
  tightAlpha(p);
  return p;
}

// ---------- GRASS CLUMP (blades) ----------------------------------------------
// Draws a small clump of upward blades. Used standalone (grass_tuft) and as fringe.
function drawGrassClump(p, baseX, baseY, hgt, salt, standalone) {
  const n = 5 + (noise(baseX | 0, 1, salt) * 4 | 0);
  for (let i = 0; i < n; i++) {
    const t = i / (n - 1);
    const spread = (t - 0.5) * (hgt * 1.3);
    const bx = baseX + spread + (noise(i, 2, salt) - 0.5) * 3;
    const bh = hgt * (0.6 + noise(i, 3, salt) * 0.6);
    const bend = (spread) * 0.35 + (noise(i, 4, salt) - 0.5) * 4;
    const shade = 0.4 + noise(i, 5, salt) * 0.6;
    const col = grassCol(shade);
    // blade = vertical line curving toward bend
    const steps = Math.max(3, bh | 0);
    for (let s = 0; s <= steps; s++) {
      const f = s / steps;
      const x = bx + bend * f * f;
      const y = baseY - bh * f;
      const wdt = (1 - f) * 1.4 + 0.5;
      const cc = lerpC(GRASS_LO, col, f);      // darker at root
      for (let o = -wdt; o <= wdt; o += 0.6) px(p, x + o, y, cc[0], cc[1], cc[2], 230);
    }
  }
}

// ---------- FLOWER CLUSTER (small blossoms on stems, NOT a lollipop) ----------
function drawFlowers(w, h, petalCol, centerCol, salt) {
  const p = img(w, h);
  const groundY = h - 3;
  aoShadow(p, w / 2, groundY, w * 0.34, 5, 0.34);
  // a little grass base
  drawGrassClump(p, w / 2, groundY, 9, salt + 1, false);
  // 3-5 blossoms at varied heights
  const nb = 3 + (noise(1, 1, salt) * 3 | 0);
  const blossoms = [];
  for (let i = 0; i < nb; i++) {
    const bx = w / 2 + (noise(i, 7, salt) - 0.5) * (w * 0.5);
    const by = groundY - (10 + noise(i, 8, salt) * (h * 0.5));
    blossoms.push([bx, by, 2.6 + noise(i, 9, salt) * 1.6]);
    // stem
    const stemCol = grassCol(0.35);
    for (let s = 0; s <= (groundY - by); s++) {
      const f = s / (groundY - by);
      const x = lerp(w / 2, bx, f);
      px(p, x, groundY - s, stemCol[0], stemCol[1], stemCol[2], 220);
      if (s % 6 === 3) { // tiny leaf
        const lc = grassCol(0.5);
        px(p, x + 2, groundY - s, lc[0], lc[1], lc[2], 200);
        px(p, x - 2, groundY - s, lc[0], lc[1], lc[2], 200);
      }
    }
  }
  // draw blossoms: 5-petal rosette + center
  for (const [bx, by, r] of blossoms) {
    for (let a = 0; a < 5; a++) {
      const ang = (a / 5) * Math.PI * 2 + noise(bx | 0, a, salt) * 0.4;
      const px0 = bx + Math.cos(ang) * r, py0 = by + Math.sin(ang) * r * 0.85;
      fillEllipse(p, px0, py0, r * 0.72, r * 0.72, (nx, ny) => {
        const sh = clamp(0.75 - ny * 0.3, 0, 1.3);
        return [clamp(petalCol[0] * sh, 0, 255), clamp(petalCol[1] * sh, 0, 255), clamp(petalCol[2] * sh, 0, 255)];
      }, 1.0);
    }
    fillEllipse(p, bx, by, r * 0.55, r * 0.55, () => centerCol, 0.8);
  }
  tightAlpha(p);
  return p;
}

// ---------- SHRUB (leafy clump, optional blossoms) ----------------------------
function drawShrub(w, h, bloom, salt) {
  const p = img(w, h);
  const groundY = h - 3;
  aoShadow(p, w / 2, groundY, w * 0.4, 5, 0.36);
  // stacked leafy lobes
  const lobes = [
    [w * 0.32, groundY - h * 0.28, w * 0.26, h * 0.30],
    [w * 0.62, groundY - h * 0.24, w * 0.28, h * 0.28],
    [w * 0.48, groundY - h * 0.5, w * 0.30, h * 0.34],
  ];
  for (let li = 0; li < lobes.length; li++) {
    const [cx, cy, rx, ry] = lobes[li];
    for (let y = Math.floor(cy - ry - 1); y <= Math.ceil(cy + ry + 1); y++) {
      for (let x = Math.floor(cx - rx - 1); x <= Math.ceil(cx + rx + 1); x++) {
        const nx = (x - cx) / rx, ny = (y - cy) / ry, d = Math.sqrt(nx * nx + ny * ny);
        if (d > 1.0) continue;
        const clump = noise((x / 3) | 0, (y / 3) | 0, salt + li);
        if (clump < 0.18 && d > 0.5) continue;       // leafy broken silhouette
        const light = (-ny * 0.8 - nx * 0.3);
        const shade = 0.42 + light * 0.4 + clump * 0.3;
        const c = grassCol(shade);
        px(p, x, y, c[0], c[1], c[2], 235);
      }
    }
  }
  if (bloom) {
    for (let i = 0; i < 7; i++) {
      const bx = w * 0.25 + noise(i, 2, salt) * w * 0.5;
      const by = groundY - h * 0.3 - noise(i, 3, salt) * h * 0.45;
      const col = i % 2 ? [236, 168, 210] : [246, 224, 130];
      fillEllipse(p, bx, by, 2.2, 2.2, () => col, 0.8);
    }
  }
  tightAlpha(p);
  return p;
}

// ---------- CAULDRON (repaint, violet glow rim) -------------------------------
function drawCauldron(bubble) {
  const w = 128, h = 128, p = img(w, h);
  const cx = w / 2, bodyCy = 78, bodyR = 34;
  const groundY = 108;
  aoShadow(p, cx, groundY, 40, 9, 0.44);
  // legs
  for (const lx of [cx - 20, cx + 20]) {
    for (let y = 94; y < 108; y++) for (let o = -3; o <= 3; o++) {
      const c = lerpC([40, 38, 46], [20, 18, 24], (y - 94) / 14);
      px(p, lx + o, y, c[0], c[1], c[2], 240);
    }
  }
  // pot body: rounded belly
  for (let y = 52; y < 100; y++) {
    for (let x = cx - bodyR - 4; x < cx + bodyR + 4; x++) {
      const ny = (y - bodyCy) / bodyR, nx = (x - cx) / (bodyR + (ny < 0 ? 2 : -2));
      const d = Math.sqrt(nx * nx + ny * ny);
      if (d > 1.0) continue;
      const light = (-nx * 0.7 - ny * 0.5);
      const base = 0.5 + light * 0.5;
      let c = lerpC([34, 32, 40], [96, 92, 108], clamp(base, 0, 1));
      // violet glow rim near the top edge
      if (y < 62) c = lerpC(c, VIOLET, clamp((62 - y) / 12, 0, 1) * 0.5);
      const a = d > 0.92 ? clamp((1 - d) / 0.08, 0, 1) : 1;
      px(p, x, y, c[0], c[1], c[2], Math.round(a * 255));
    }
  }
  // rim ellipse (opening) with violet potion
  fillEllipse(p, cx, 54, bodyR + 2, 11, (nx, ny) => {
    // rim ring dark, interior violet
    if (nx * nx + ny * ny > 0.62) return [28, 26, 34];
    const glow = 0.7 + (-ny) * 0.3;
    return lerpC(VIOLET, VIOLET_HI, clamp(glow, 0, 1) * (bubble ? 1 : 0.7));
  }, 1.2);
  // violet rim highlight ring
  for (let a = 0; a < 360; a += 4) {
    const rad = a * Math.PI / 180;
    const x = cx + Math.cos(rad) * (bodyR + 2), y = 54 + Math.sin(rad) * 11;
    px(p, x, y, VIOLET_HI[0], VIOLET_HI[1], VIOLET_HI[2], 150);
  }
  if (bubble) {
    for (const [bx, by, br] of [[cx - 8, 50, 3], [cx + 6, 48, 4], [cx + 12, 52, 2]])
      fillEllipse(p, bx, by, br, br, () => VIOLET_HI, 0.8);
  }
  return p;
}

// ---------- REST STUMP (repaint mossy) ----------------------------------------
function drawStump() {
  const w = 108, h = 96, p = img(w, h);
  const cx = w / 2, topCy = 40, topRx = 30, topRy = 12, groundY = 84;
  aoShadow(p, cx, groundY, 36, 8, 0.42);
  // trunk sides
  for (let y = topCy; y < 82; y++) {
    for (let x = cx - topRx; x <= cx + topRx; x++) {
      const nx = (x - cx) / topRx;
      if (Math.abs(nx) > 1) continue;
      const light = -nx * 0.6 + 0.1;
      const c = lerpC(STUMP_DARK, STUMP_BARK, clamp(0.5 + light * 0.5, 0, 1));
      // bark vertical grain
      const grain = noise((x / 2) | 0, (y / 5) | 0, 3) * 0.2 - 0.1;
      const cc = [clamp(c[0] + grain * 120, 0, 255), clamp(c[1] + grain * 90, 0, 255), clamp(c[2] + grain * 60, 0, 255)];
      const a = Math.abs(nx) > 0.9 ? clamp((1 - Math.abs(nx)) / 0.1, 0, 1) : 1;
      px(p, x, y, cc[0], cc[1], cc[2], Math.round(a * 255));
    }
  }
  // top cut face (rings)
  fillEllipse(p, cx, topCy, topRx, topRy, (nx, ny) => {
    const d = Math.sqrt(nx * nx + ny * ny);
    const ring = Math.sin(d * 9) * 0.15;
    const c = lerpC(STUMP_TOP, [160, 126, 84], clamp(0.5 + ring, 0, 1));
    return c;
  }, 1.2);
  // moss patches on the rim + one side
  for (let i = 0; i < 14; i++) {
    const ang = noise(i, 1, 7) * Math.PI * 2;
    const mx = cx + Math.cos(ang) * topRx * (0.8 + noise(i, 2, 7) * 0.3);
    const my = topCy + Math.sin(ang) * topRy * 0.9 + 2;
    fillEllipse(p, mx, my, 3 + noise(i, 3, 7) * 2, 2.4, () => lerpC(MOSS, GRASS_HI, noise(i, 4, 7)), 0.8);
  }
  // moss skirt at base
  for (let i = 0; i < 10; i++) {
    const bx = cx - topRx + i * (topRx * 2 / 9);
    fillEllipse(p, bx, 80, 4, 3, () => MOSS, 0.8);
  }
  return p;
}

// ---------- tight-crop transparent margins ------------------------------------
function tightAlpha(p) {
  // no-op placeholder: our canvases are already sized snugly. Kept for clarity.
  return p;
}

// ---------- de-shadow + AO pass for sheet-sliced trees/bushes -----------------
// The CC0 tree/bush slices carry a semi-transparent near-BLACK cast shadow baked
// into the sprite (an offset iso render shadow). On grass this reads as a dirty
// dark blob. We STRIP those shadow pixels (near-black AND not fully opaque — the
// opaque dark trunk/branches are kept) and bake ONE clean soft AO ellipse centred
// under the trunk base, so every tree seats consistently on the new terrain.
const CACHE = __dirname + "/.artcache/";
function deshadowAndSeat(name, footRxFrac, aoStrength) {
  const path = OUT + name;
  // Idempotent: always start from the pristine CC0 slice in .artcache (created once
  // by the slicer / backed up), so re-running never strips our own baked AO.
  const orig = CACHE + name + ".orig";
  if (fs.existsSync(orig)) fs.copyFileSync(orig, path);
  else if (fs.existsSync(path)) { fs.mkdirSync(CACHE, { recursive: true }); fs.copyFileSync(path, orig); }
  const p = PNG.sync.read(fs.readFileSync(path));
  const W = p.width, H = p.height, A = p.data;
  // 1) strip baked cast-shadow pixels.
  for (let i = 0; i < A.length; i += 4) {
    const r = A[i], g = A[i + 1], b = A[i + 2], a = A[i + 3];
    if (a < 8) continue;
    const mx = Math.max(r, g, b);
    if (mx < 34 && a < 232) { A[i] = A[i + 1] = A[i + 2] = A[i + 3] = 0; }
  }
  // 2) find the opaque-content horizontal centre + bottom (trunk base) after strip.
  let minx = W, maxx = 0, maxy = 0, sumx = 0, cnt = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const a = A[((W * y + x) << 2) + 3];
    if (a > 40) { minx = Math.min(minx, x); maxx = Math.max(maxx, x); maxy = Math.max(maxy, y); sumx += x; cnt++; }
  }
  if (cnt === 0) return;
  // trunk centre: use the horizontal centroid of the LOWEST 16px band (the trunk).
  let tsum = 0, tcnt = 0;
  for (let y = Math.max(0, maxy - 16); y <= maxy; y++) for (let x = 0; x < W; x++) {
    if (A[((W * y + x) << 2) + 3] > 40) { tsum += x; tcnt++; }
  }
  const cx = tcnt > 0 ? tsum / tcnt : (minx + maxx) / 2;
  const rx = (maxx - minx) * footRxFrac;
  // 3) bake a clean AO ellipse UNDER the content (composited below, so it doesn't
  //    darken the trunk): draw onto a fresh layer then merge where sprite is clear.
  const shadow = img(W, H);
  aoShadow(shadow, cx, maxy - 2, rx, Math.max(4, rx * 0.26), aoStrength);
  for (let i = 0; i < A.length; i += 4) {
    if (A[i + 3] >= 250) continue;                 // keep solid sprite pixels
    const sa = shadow.data[i + 3];
    if (sa === 0) continue;
    const af = sa / 255, ia = A[i + 3] / 255;
    // composite sprite OVER shadow
    const outA = ia + af * (1 - ia);
    if (outA <= 0) continue;
    A[i] = (A[i] * ia + 0 * af * (1 - ia)) / outA;
    A[i + 1] = (A[i + 1] * ia) / outA;
    A[i + 2] = (A[i + 2] * ia) / outA;
    A[i + 3] = Math.round(outA * 255);
  }
  fs.writeFileSync(path, PNG.sync.write(p));
  console.log("  deshadow+AO " + name + "  (cx=" + cx.toFixed(0) + " base=" + maxy + " rx=" + rx.toFixed(0) + ")");
}

// ============================== BUILD =========================================
console.log("== gen object art v050b ==");

// rock: a cluster of 3 rounded lobes (a bigger boulder + 2 companions).
save(drawBoulder(84, 70, [
  { cx: 30, cy: 42, rx: 20, ry: 17 },
  { cx: 52, cy: 46, rx: 15, ry: 13 },
  { cx: 42, cy: 34, rx: 17, ry: 15 },
], 101), "rock.png");

// stone: a low pebble pile (3 small flat lobes, no grass on top — a couple of
// weathered stones resting on the ground).
save(drawBoulder(58, 34, [
  { cx: 20, cy: 22, rx: 12, ry: 8 },
  { cx: 38, cy: 24, rx: 10, ry: 7 },
  { cx: 29, cy: 18, rx: 9, ry: 7 },
], 205, false), "stone.png");

// grass tuft: standalone clump.
(function () {
  const p = img(48, 40); const gy = 36;
  aoShadow(p, 24, gy, 15, 4, 0.3);
  drawGrassClump(p, 24, gy, 22, 311, true);
  save(p, "grass_tuft.png");
})();

// green shrub + bloomed shrub.
save(drawShrub(64, 46, false, 411), "bush_green.png");
save(drawShrub(72, 50, true, 419), "bush_bloom.png");

// flowers: three colorways of clustered blossoms.
save(drawFlowers(56, 64, [236, 96, 150], [250, 224, 120], 501), "flower.png");        // pink-red
save(drawFlowers(56, 64, [168, 120, 236], [250, 240, 150], 509), "flower_violet.png"); // violet
save(drawFlowers(56, 64, [240, 150, 196], [250, 234, 130], 517), "flower_pink.png");    // pink

// cauldron (+ bubble variant).
save(drawCauldron(false), "cauldron.png");
save(drawCauldron(true), "cauldron_bubble.png");

// rest stump.
save(drawStump(), "rest_stump.png");

// strip baked cast-shadows from the CC0 tree/bush slices + seat them with a clean AO.
for (const [nm, frac, str] of [
  ["tree_a.png", 0.22, 0.4], ["tree_b.png", 0.22, 0.4], ["tree_c.png", 0.22, 0.4],
  ["young_tree.png", 0.30, 0.4], ["world_tree.png", 0.20, 0.46], ["bush_dry.png", 0.40, 0.4],
]) {
  try { deshadowAndSeat(nm, frac, str); } catch (e) { console.log("  (skip " + nm + ": " + e.message + ")"); }
}

console.log("== done ==");
