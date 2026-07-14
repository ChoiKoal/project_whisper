#!/usr/bin/env node
// tools_overview_home.js — v0.5d 제0세계 (home island) overview render.
//
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_overview_home.js [--closeup]
//
// The in-engine SubViewport render can't run under --headless (dummy rendering driver has
// no framebuffer to read back), so — as with the v050a2/v050b previews — this offline
// pngjs compositor draws the home island the same way the game does, mirroring the v0.5d
// art rebuild:
//   * a cool-twilight void: deep violet-black gradient + a large soft violet nebula wash +
//     a DENSE starfield with a few large twinkling stars, and a soft vignette frame,
//   * a FLOATING ROCK SHARD: full-perimeter cliff aprons + a tapering rocky underside +
//     drifting debris islets,
//   * the barren dirt slab, gently lit (mirrors the #8a86b8 CanvasModulate but LIFTED so the
//     gates read as monumental, not murk),
//   * ground traces: worn stone-path decals dais→each gate + a spiral whisper-sigil + cracks,
//   * a raised ROUND stone DAIS (3 concentric weathered slabs + carved sigil ring + violet
//     centre glow) + a cauldron stone pad + the observation stone,
//   * dead/worn grass patches on the `g` cells (olive-tan dry mats, NOT green squares),
//   * 5 MONUMENTAL stone GATES (portal.gd mirror): a stacked-slab stone base + two thick
//     REAL-ROCK-TEXTURED pillars carrying carved violet runes + a heavy lintel + a floating
//     carved SIGIL stone bearing the layer motif glyph (leaf/star/gear/rune/halo). nature
//     (Layer 1) FLICKERING (veil + lit runes + lit sigil), the other four DORMANT.
//
// --closeup renders a tight crop on the flickering nature gate → preview-portal-closeup.png.
// Output (overview): /workspace/group/preview-home.png

const fs = require("fs");
const { PNG } = require("pngjs");

const GAME = __dirname;
const CLOSEUP = process.argv.includes("--closeup");
// --hero: 아치(포탈 5기)+다이스 줌인 크롭 → preview-home-hero.png. home_hero_render.tscn 은
// 실엔진 SubViewport 리드백이라 --headless dummy 드라이버에선 프레임버퍼가 없어 행(hang)한다
// (tools_overview 상단 주석 참조). 그래서 히어로 샷도 이 오프라인 컴포지터에서 크롭한다.
const HERO = process.argv.includes("--hero");
// --capsule: 섬 중심 1.8배 크롭(1920×1080) → preview-home-capsule.png. 언더사이드(부유섬 암반)가
// 프레임에 들어오도록 세로 중심을 섬 상단 rim ~ 매달린 암반 하단 중간에 둔다 (#257).
const CAPSULE = process.argv.includes("--capsule");
const OUT = CLOSEUP ? "/workspace/group/preview-portal-closeup.png"
          : HERO    ? "/workspace/group/preview-home-hero.png"
          : CAPSULE ? "/workspace/group/preview-home-capsule.png"
                    : "/workspace/group/preview-home.png";

const TW = 128, TH = 64, HW = 64, HH = 32, LIFT = 32;

const layout = read(`${GAME}/data/home_layout.txt`);
const legend = JSON.parse(fs.readFileSync(`${GAME}/data/home_legend.json`, "utf8"));
const H = layout.length, W = layout[0].length;

function read(p) { return fs.readFileSync(p, "utf8").split("\n").filter((l) => l.length > 0); }
function loadPng(p) { try { return PNG.sync.read(fs.readFileSync(p)); } catch (e) { return null; } }
const tile = (n) => loadPng(`${GAME}/assets/tiles/${n}.png`);
const obj = (n) => loadPng(`${GAME}/assets/objects/${n}.png`);

const SRC = { 1: tile("t1_dirt") };
const CAULDRON = obj("cauldron"), STONE = obj("stone");
const ROCK_TEX = tile("cliff_face_a");   // real rock material sampled into the gates

// (v1.10.0 L0 확장) homedeco 소품 아트 — 층별 상징(잎/데이터/태엽/서고/종) + 빛 웅덩이 + 잔해.
// 인게임(map_loader _spawn_l2_object)은 이 PNG를 Sprite2D로 셀 중앙 + offset 에 배치한다.
// 이전 프리뷰는 Pass F에서 이 심볼들을 미러하지 않아 신규 데코가 빈 흙 타일로 보였다(카나 검수).
// 이제 legend.objects 의 kind:"homedeco" 스펙(art/art_variants/offset/glow/glow_scale)을 그대로 합성.
const DECO_ART = {};
for (const sym of Object.keys(legend.objects)) {
  const spec = legend.objects[sym];
  if (!spec || spec.kind !== "homedeco") continue;
  const names = [spec.art, ...(spec.art_variants || [])];
  for (const nm of names) if (nm && !(nm in DECO_ART)) DECO_ART[nm] = obj(nm);
}
const GLOW_VIOLET = obj("light_pool_violet");   // violet additive glow decal (map_loader mirror)

// Home twilight tone — mirrors the #8a86b8 CanvasModulate but LIFTED (×1.28) so the barren
// island + monumental gates READ; a pure ×0.54 multiply crushed the scene to murk (owner
// reject). We keep the cool violet cast, brighter.
const TONE = [0x8a / 255 * 1.28, 0x86 / 255 * 1.28, 0xb8 / 255 * 1.20];

// ---------------- iso projection --------------------------------------------
// STACKED isometric projection — mirrors the GAME's real map_to_local (whisper TileSet:
// ISOMETRIC, tile_layout=0 STACKED, tile_offset_axis=0 HORIZONTAL, 128×64). The old
// (c-r,c+r) diamond formula rotated the map ~45° vs in-game (bug: 렌더↔인게임 방위 불일치).
// x = (col + 0.5·(row odd))·TW ; y = row·(TH/2). See tools_overview_l1.js for full note.
function cellLocal(c, r) { return [(c + ((r & 1) ? 0.5 : 0)) * TW, r * HH]; }
function isIsland(c, r) { return r >= 0 && r < H && c >= 0 && c < layout[r].length && layout[r][c] !== "V"; }

// ---------------- hash / rock (cliff_gen.gd mirror) -------------------------
function hash2(c, r, salt = 0) {
  let h = (Math.imul(c, 73856093) ^ Math.imul(r, 19349663) ^ Math.imul(salt, 83492791) ^ (0x9e3779b9 | 0)) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177) | 0; h = h ^ (h >>> 16); return (h & 0x7fffffff);
}
function rockNoise(px, py, seed) { return (hash2(px, py, seed) & 0xffff) / 65535.0; }
function lerpC(a, b, t) { return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t]; }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }
const ROCK_BASE = [120, 96, 78], ROCK_DARK = [72, 56, 44], ROCK_LIGHT = [150, 122, 102], ROCK_SHADOW = [46, 36, 30];
const GRASS_LIP = [86, 128, 60], GRASS_LIP_DK = [58, 92, 42];
function rockCol(s) {
  s = clamp(s, 0, 1.4);
  if (s < 0.7) return lerpC(ROCK_SHADOW, ROCK_DARK, Math.min(1, s / 0.7));
  if (s < 1.0) return lerpC(ROCK_DARK, ROCK_BASE, Math.min(1, (s - 0.7) / 0.3));
  return lerpC(ROCK_BASE, ROCK_LIGHT, Math.min(1, (s - 1.0) / 0.4));
}
// sample the real rock texture (portal.gd _rock_sample mirror): clean band x∈[8,120] y∈[12,150].
function rockSample(u, v, lit) {
  if (!ROCK_TEX) return rockCol(0.9 * lit);
  const bx = 8, by = 12, bw = 112, bh = 138;
  const sx = bx + (((u % bw) + bw) % bw), sy = by + (((v % bh) + bh) % bh);
  const i = (ROCK_TEX.width * sy + sx) << 2;
  lit = clamp(lit, 0.30, 1.55);
  return [clamp(ROCK_TEX.data[i] * lit, 0, 255), clamp(ROCK_TEX.data[i + 1] * lit, 0, 255), clamp(ROCK_TEX.data[i + 2] * lit, 0, 255)];
}
function darken(c, t) { return [c[0] * (1 - t), c[1] * (1 - t), c[2] * (1 - t)]; }
function lighten(c, t) { return [c[0] + (255 - c[0]) * t, c[1] + (255 - c[1]) * t, c[2] + (255 - c[2]) * t]; }

// ---------------- CliffGen.make_apron mirror --------------------------------
function makeApron(drop, exposeSE, exposeSW, salt) {
  const wall = LIFT * drop, imgH = wall + TH;
  const img = new PNG({ width: TW, height: imgH }); img.data.fill(0);
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
      if (y < wallTop + lipH - jag) { const g = ((x + y) % 3 !== 0) ? GRASS_LIP : GRASS_LIP_DK; put(img, x, y, g[0], g[1], g[2], 255); }
    }
  }
  return { img, h: imgH };
}

// ---------------- CliffGen.make_underside mirror (#257 v1.10.1) --------------
// Irregular bedrock underside: top edge follows the island's jagged bottom (topProfile,
// closing L/R gaps), stepped strata-banded silhouette, faint violet whisper-glow at the tip,
// plus asymmetric hanging chunks + stalactites. Mirrors CliffGen.make_underside exactly.
const WHISPER_VIOLET = [150, 118, 214];
const UNDER_SHADOW = [40, 38, 56], UNDER_SHADOW_DEEP = [26, 22, 40];
const UNDER_MOSS = [74, 110, 54], UNDER_MOSS_DK = [48, 78, 40];
function alphaAt(img, x, y) { return img.data[((img.width * y + x) << 2) + 3]; }
// smooth value-noise in [0,1] over a 1-D coordinate (linearly interpolated between integer
// samples) — used to wobble the silhouette CONTINUOUSLY down the body so the edge never jumps
// by whole steps row-to-row (that row jump was the left-side horizontal streak, 카나 #2).
function snoise1(t, salt) {
  const i = Math.floor(t), f = t - i;
  const a = rockNoise(i, salt, salt + 3), b = rockNoise(i + 1, salt, salt + 3);
  const u = f * f * (3 - 2 * f);
  return a + (b - a) * u;
}
// per-column jagged offset of the shelf boundary y (so band seams are organic 지그재그 노치,
// not a straight ruler line, 카나 #1). Smooth in x, deterministic per band index.
function shelfEdgeOffset(x, bandI, salt) {
  return (snoise1(x / 26.0, salt + bandI * 131) - 0.5) * 22.0
       + (snoise1(x / 7.0, salt + bandI * 57) - 0.5) * 7.0;
}
// (#257 v1.10.3, 멤쵸 판정) 3-lobe silhouette. Mirrors CliffGen._underside_lobes / _lobe_at.
function undersideLobes(span, depth, rimCx, rimHalf, salt) {
  const lobes = [];
  // 3개의 겹치는 암반 로브 — 좌·중(가장 넓고 깊음)·우. 정규화 [중심오프셋, 상대폭, 상대깊이].
  const specs = [[-0.66, 0.52, 0.60], [0.05, 0.86, 0.98], [0.62, 0.60, 0.72]];
  for (let i = 0; i < specs.length; i++) {
    const sp = specs[i], s = salt + 100 + i * 29;
    const jx = (rockNoise(s, 3, s + 2) - 0.5) * 0.22;
    const jw = 0.85 + rockNoise(s, 4, s + 3) * 0.30;
    const jd = 0.85 + rockNoise(s, 5, s + 4) * 0.28;
    const lcx = rimCx + (sp[0] + jx) * rimHalf;
    const lhalf = rimHalf * sp[1] * jw;
    const lbot = depth * sp[2] * jd;
    lobes.push({ cx: lcx, half: lhalf, bot: lbot, salt: s, main: i === 1 });
  }
  return lobes;
}
function lobeAt(lobes, x) {
  let bestBot = -1, domHx = 1.0, secondBot = -1;
  for (const lb of lobes) {
    const dx = (x - lb.cx) / Math.max(1, lb.half);
    if (Math.abs(dx) >= 1.0) continue;
    const dome = Math.pow(Math.max(0, 1 - dx * dx), 0.72);
    const wob = (snoise1(x / 55.0, lb.salt) - 0.5) * 0.07;   // 저주파만 (톱니 커튼 제거, 멤쵸)
    const bot = lb.bot * (dome * (0.93 + wob) + 0.10);
    if (bot > bestBot) { secondBot = bestBot; bestBot = bot; domHx = Math.abs(dx); }
    else if (bot > secondBot) { secondBot = bot; }
  }
  let gully = 0.0;
  if (secondBot > 0 && bestBot > 0) gully = clamp(1 - Math.abs(bestBot - secondBot) / (bestBot * 0.5 + 1), 0, 1);
  return [bestBot, domHx, gully];
}
function makeUnderside(span, depth, salt, topProfile) {
  const img = new PNG({ width: span, height: depth }); img.data.fill(0);
  const haveProfile = topProfile && topProfile.length === span;
  let rimL = 0, rimR = span;
  if (haveProfile) {
    rimL = span; rimR = 0;
    for (let x = 0; x < span; x++) if (topProfile[x] >= 0) { rimL = Math.min(rimL, x); rimR = Math.max(rimR, x + 1); }
    if (rimR <= rimL) { rimL = 0; rimR = span; }
  }
  const rimCx = (rimL + rimR) * 0.5, rimHalf = Math.max(2, (rimR - rimL) * 0.5);
  const NB = 5;   // sediment bands
  const lobes = undersideLobes(span, depth, rimCx, rimHalf, salt);
  const colBot = new Float32Array(span), colHx = new Float32Array(span), colGully = new Float32Array(span);
  for (let x = 0; x < span; x++) { const la = lobeAt(lobes, x); colBot[x] = la[0]; colHx[x] = la[1]; colGully[x] = la[2]; }
  for (let y = 0; y < depth; y++) {
    const ty = y / depth;
    for (let x = 0; x < span; x++) {
      let topY = 0;
      if (haveProfile) { topY = topProfile[x]; if (topY < 0) continue; if (y < topY) continue; }
      const bot = colBot[x];
      if (bot <= 0 || y > bot) continue;
      const hx = colHx[x], gully = colGully[x];
      const ly = clamp((y - topY) / Math.max(1, bot - topY), 0, 1);
      // STRATA BANDS — one step stronger contrast (멤쵸 #3). Jagged per-column seam.
      const bandF = ty * NB;
      const nearestSeam = Math.round(bandF);
      const seamY = nearestSeam / NB * depth + shelfEdgeOffset(x, nearestSeam, salt);
      const distToSeam = y - seamY;
      const bandI = clamp(Math.floor(ty * NB), 0, NB - 1);
      let band = 0.98 - 0.090 * bandI;                    // 강화 밴드 대비 (was 0.055)
      band += (bandI % 2 === 0) ? 0.055 : -0.045;         // 밴드 명암 강화
      // CLUSTERED faceted strata — 노이즈를 지층+로브 구조를 따라 뭉침 (안개 제거, 바위 질감).
      const cluster = Math.floor(rockNoise((x / 9) | 0, (y / 4) | 0, salt) * 4.0) / 4.0;
      const strata = Math.floor(rockNoise((x / 6) | 0, (y / 5) | 0, salt + 2) * 5.0) / 5.0;
      const facet = (cluster - 0.375) * 0.42 + (strata - 0.4) * 0.30;
      const crack = (rockNoise((x / 3) | 0, (y / 6) | 0, salt + 5) < 0.15) ? -0.34 : 0.0;
      let seam = 0.0;
      if (Math.abs(distToSeam) < 2.6) {
        const dith = ((x * 7 + y * 3 + (rockNoise(x, y, salt + 9) * 4 | 0)) & 3) !== 0;
        if (dith) seam = -0.30 * (1 - Math.abs(distToSeam) / 2.6);
      }
      const edge = -0.40 * hx * hx;
      const gsh = -0.55 * gully;                          // 로브 사이 깊은 그림자 골
      const n = rockNoise(x, y, salt) * 0.12 - 0.06;
      let col = rockCol(band + facet + crack + seam + edge + gsh + n);
      // cool LESS toward shadow so the underside isn't washed/foggy vs the surface (멤쵸 샤프니스).
      col = lerpC(col, UNDER_SHADOW, 0.08 + 0.14 * ty);
      col = lerpC(col, UNDER_SHADOW_DEEP, clamp((ly - 0.60) / 0.40, 0, 1) * 0.34);
      if (ty > 0.42) { const glow = clamp((ty - 0.42) / 0.58, 0, 1) * (0.10 + 0.42 * hx * hx) * 0.50; col = lerpC(col, WHISPER_VIOLET, glow); }
      if (haveProfile && (y - topY) < 4 && hx < 0.92) col = ((x + y) % 3 !== 0) ? UNDER_MOSS : UNDER_MOSS_DK;
      // 1px dithered eroded rim (no soft alpha feather that read as haze — 멤쵸 "안개 덩어리").
      let a = 1.0;
      if (hx > 0.90) a = ((x + y) & 1) === 0 ? 1.0 : 0.35;
      if (y > bot - 2) a = ((x + y) & 1) === 0 ? 1.0 : 0.35;
      put(img, x, y, col[0], col[1], col[2], Math.round(a * 255));
    }
  }
  // (#257 v1.10.3 카나 재검수) 바디 실루엣까지의 거리 페이드용 — per-row 좌우 / per-column 하단
  // 드로운 범위. 릴리프가 실루엣 가장자리에 매끈면으로 닿아 "반투명 회색 컵"으로 읽히는 것 방지.
  const rowMinX = new Int32Array(depth).fill(span), rowMaxX = new Int32Array(depth).fill(-1);
  const colMaxY = new Int32Array(span).fill(-1);
  for (let y = 0; y < depth; y++) for (let x = 0; x < span; x++) {
    if (img.data[((img.width * y + x) << 2) + 3] === 0) continue;
    if (x < rowMinX[y]) rowMinX[y] = x;
    if (x > rowMaxX[y]) rowMaxX[y] = x;
    if (y > colMaxY[x]) colMaxY[x] = y;
  }
  undersideHangers(img, span, depth, rimCx, rimHalf, salt, rowMinX, rowMaxX, colMaxY);
  return img;
}
function undersideHangers(img, span, depth, rimCx, rimHalf, salt, rowMinX, rowMaxX, colMaxY) {
  const count = 2 + ((rockNoise(salt, 3, salt + 21) * 2.0) | 0);   // 2..3, chunkier (멤쵸)
  for (let i = 0; i < count; i++) {
    const s = salt + 40 + i * 17;
    const ax = rimCx + (rockNoise(s, 1, s + 2) - 0.5) * 2.0 * rimHalf * 0.85;
    const ay = depth * (0.34 + rockNoise(s, 2, s + 3) * 0.42);
    // (#257 v1.10.3 카나 재검수) isSpike 변형 제거 — 스파이크는 바디 밖(alpha==0)에도 픽셀을
    // 찍어(구 `isSpike && t>0.6` 분기) 보이드로 삐져나온 "가는 스파이크 잔상"을 만들었다.
    // 이제 hanger는 전부 chunky nub, 바디 내부(alpha>0)에만 조각한다.
    const chunkH = depth * (0.10 + rockNoise(s, 6, s + 7) * 0.16);
    const chunkW = (span * 0.05) + rockNoise(s, 8, s + 9) * span * 0.055;
    for (let dy = 0; dy < (chunkH | 0); dy++) {
      const t = dy / Math.max(1, chunkH);
      const w = chunkW * (1 - t * 0.55);
      const yy = (ay + dy) | 0;
      if (yy < 0 || yy >= depth) continue;
      for (let dx = (-w) | 0; dx <= (w | 0); dx++) {
        const xx = (ax | 0) + dx;
        if (xx < 0 || xx >= span) continue;
        const sdx = dx / Math.max(1, w), hx = Math.abs(sdx);
        // (#257 v1.10.3 카나 재검수) 바디 실루엣(좌/우 rim 대각선 + 하단 bot 등고선) 근처에서는
        // 릴리프를 기존 rock 텍스처로 페이드아웃 — 매끈한 릴리프 면이 실루엣 가장자리까지 닿아
        // 보이드 대비 "반투명 회색 컵"으로 읽히던 문제. 실루엣 14px 이내 0%, 48px 이상 내부 100%.
        const dEdge = Math.min(xx - rowMinX[yy], rowMaxX[yy] - xx, colMaxY[xx] - yy);
        const mix = clamp((dEdge - 14) / 34, 0, 1);
        if (mix <= 0) continue;
        // (#257 v1.10.4 카나 재검수) "반투명 회색-보라 스쿱" 제거 — hanger를 매끈한 rockCol
        // 그라디언트로 새로 칠하면 주변 chunky rock보다 밝고 평평(std↓)해져 보이드 대비 반투명 컵으로
        // 읽혔다. 이제 relief는 기존 텍스처 위에 곱연산 음영(darken)만 얹는다 → 지층/facet 노이즈 보존
        // (평평한 매끈면 소멸), 항상 주변보다 어두운 recessed relief. 지오메트리·폭·질감 불변.
        const ea = alphaAt(img, xx, yy);
        if (ea <= 0) continue;
        const ei = (img.width * yy + xx) << 2;
        const base = [img.data[ei], img.data[ei + 1], img.data[ei + 2]];
        // recessed volume: darken more toward the tip / shadow-right side, ease off toward the lit
        // spine. Kept subtly darker than surrounding rock (never brightens → no bright cup, 카나 #3).
        const spine = (1 - hx) * 0.08;                   // gentle lit spine (still a darken, less deep)
        const dark = clamp(0.08 + 0.16 * t + 0.10 * (0.5 + 0.5 * sdx) - spine, 0, 0.34);
        let col = darken(base, dark);
        col = lerpC(col, UNDER_SHADOW_DEEP, clamp((t - 0.4) / 0.6, 0, 1) * 0.18);
        if (t > 0.6) col = lerpC(col, WHISPER_VIOLET, (t - 0.6) / 0.4 * 0.16);   // faint violet only at deep tip
        col = lerpC(base, col, mix);                     // edge → 기존 rock 텍스처로 페이드
        const a = Math.min(ea / 255, t < 0.85 ? 1.0 : clamp((1 - t) / 0.15, 0, 1));
        put(img, xx, yy, col[0], col[1], col[2], Math.round(a * 255));
      }
    }
  }
}
function makeDebris(w, salt) {
  const topH = (w * 0.42) | 0, underH = (w * 0.7) | 0, h = topH + underH;
  const img = new PNG({ width: w, height: h }); img.data.fill(0);
  const cx = w * 0.5;
  for (let y = 0; y < topH; y++) {
    const ty = y / topH, half = (w * 0.5) * (0.55 + 0.45 * ty);
    for (let x = (cx - half) | 0; x < (cx + half) | 0; x++) {
      if (x < 0 || x >= w) continue;
      const strata = Math.floor(rockNoise((x / 4) | 0, (y / 4) | 0, salt) * 4.0) / 4.0;
      const facet = (strata - 0.4) * 0.4, n = rockNoise(x, y, salt) * 0.10 - 0.05;
      let col = rockCol(0.9 + facet + n);
      if (y < 4) col = ((x + y) % 3 !== 0) ? GRASS_LIP : GRASS_LIP_DK;
      put(img, x, y, col[0], col[1], col[2], 255);
    }
  }
  for (let y = 0; y < underH; y++) {
    const ty2 = y / underH, half = (w * 0.5) * Math.pow(1 - ty2, 1.3);
    for (let x = (cx - half) | 0; x < (cx + half) | 0; x++) {
      if (x < 0 || x >= w) continue;
      const vshade = 0.6 - 0.4 * ty2, n = rockNoise(x, topH + y, salt) * 0.10 - 0.05;
      let col = lerpC(rockCol(vshade + n), [40, 38, 56], 0.35);
      const a = ty2 < 0.85 ? 1.0 : clamp((1 - ty2) / 0.15, 0, 1);
      put(img, x, topH + y, col[0], col[1], col[2], Math.round(a * 255));
    }
  }
  return img;
}

// ---------------- portal.gd (monumental gate) mirror ------------------------
const GATE_W = 206, GATE_H = 316, PILLAR_W = 50, OPENING_W = GATE_W - PILLAR_W * 2;
const LINTEL_H = 52, LINTEL_OVERHANG = 14, SIGIL_CY = 40, SIGIL_R = 34;
const LINTEL_TOP = 92, PILLAR_TOP = LINTEL_TOP + LINTEL_H, BASE_H = 40, PILLAR_BOTTOM = GATE_H - BASE_H;
const VEIL_W = OPENING_W + 6;
const MOSS = [78, 104, 58], VIOLET = [158, 122, 217], VIOLET_BRIGHT = [200, 168, 242], VIOLET_DEEP = [91, 63, 134];
const RUNE_STONE = [64, 50, 84];
const LAYER_GLYPH = { nature: "leaf", science: "star", machine: "gear", magic: "rune", divinity: "halo" };

function buildGate(state) {
  const img = new PNG({ width: GATE_W, height: GATE_H }); img.data.fill(0);
  const cx = GATE_W >> 1, innerHalf = OPENING_W >> 1;
  const leftOut = cx - innerHalf - PILLAR_W, leftIn = cx - innerHalf, rightIn = cx + innerHalf, rightOut = cx + innerHalf + PILLAR_W;
  const lintelLeft = leftOut - LINTEL_OVERHANG, lintelRight = rightOut + LINTEL_OVERHANG;
  const mod = state === "flickering" ? [0.92, 0.90, 0.96] : [0.74, 0.72, 0.80];
  const slabs = [
    [PILLAR_BOTTOM, PILLAR_BOTTOM + 14, lintelLeft - 10, lintelRight + 10],
    [PILLAR_BOTTOM + 14, PILLAR_BOTTOM + 27, lintelLeft - 2, lintelRight + 2],
    [PILLAR_BOTTOM + 27, GATE_H, leftOut - 6, rightOut + 6],
  ];
  for (let y = 0; y < GATE_H; y++) for (let x = 0; x < GATE_W; x++) {
    let region = "", slabI = -1;
    if (y >= PILLAR_TOP && y < PILLAR_BOTTOM) {
      if (x >= leftOut && x < leftIn) region = "lp";
      else if (x >= rightIn && x < rightOut) region = "rp";
    }
    if (y >= LINTEL_TOP && y < PILLAR_TOP && x >= lintelLeft && x < lintelRight) region = "li";
    for (let i = 0; i < slabs.length; i++) { const s = slabs[i]; if (y >= s[0] && y < s[1] && x >= s[2] && x < s[3]) { region = "base"; slabI = i; break; } }
    if (region === "") continue;
    let lit = 1.0;
    if (region === "lp") lit = 0.70 + ((x - leftOut) / PILLAR_W) * 0.46;
    else if (region === "rp") lit = 0.80 + ((x - rightIn) / PILLAR_W) * 0.44;
    else if (region === "li") lit = 1.10 - ((y - LINTEL_TOP) / LINTEL_H) * 0.40;
    else lit = 0.92 - ((y - slabs[slabI][0]) / 14) * 0.30;
    let uoff = 0, voff = 0;
    if (region === "lp") { uoff = 3; voff = 11; }
    else if (region === "rp") { uoff = 61; voff = 7; }
    else if (region === "li") { uoff = 20; voff = 90; }
    else { uoff = 40 + slabI * 17; voff = 150; }
    let col = rockSample(x + uoff, y + voff, lit);
    if ((region === "lp" || region === "rp") && (y % 40) < 2) col = darken(col, 0.42);
    if (region === "li" && Math.abs(x - cx) < 2) col = darken(col, 0.34);
    if (region === "base" && slabI >= 0 && Math.abs(y - slabs[slabI][0]) < 2) col = lighten(col, 0.18);
    if ((region === "lp" || region === "rp") && y > PILLAR_BOTTOM - 70) {
      const mv = rockNoise((x / 3) | 0, (y / 3) | 0, 133), low = (y - (PILLAR_BOTTOM - 70)) / 70.0;
      if (mv < 0.16 * low) col = lerpC(col, MOSS, 0.5);
    }
    col = [col[0] * mod[0], col[1] * mod[1], col[2] * mod[2]];
    put(img, x, y, col[0], col[1], col[2], 255);
  }
  // carved cracked runes down the inner face of each pillar.
  carveRunes(img, leftIn - 16, leftOut + PILLAR_W);
  carveRunes(img, rightIn + 2, rightOut);
  return img;
}
function carveRunes(img, x0, x1) {
  const cxr = (x0 + x1) >> 1;
  let gi = 0;
  for (let y = PILLAR_TOP + 22; y < PILLAR_BOTTOM - 18; y += 46, gi++) {
    const flip = (gi % 2 === 0) ? 1 : -1;
    for (let dy = -13; dy <= 13; dy++) {
      const yy = y + dy; if (yy < 0 || yy >= GATE_H) continue;
      for (let dx = -1; dx <= 1; dx++) { const xx = cxr + dx; if (xx >= x0 && xx < x1) { const b = getPx(img, xx, yy); put(img, xx, yy, ...lerpC(darken(b, 0.5), VIOLET_DEEP, 0.36), 255); } }
    }
    for (let t = 0; t < 7; t++) { const xx = cxr + flip * t, yy = y - 8 + t; if (xx >= x0 && xx < x1 && yy >= 0 && yy < GATE_H) { const b = getPx(img, xx, yy); put(img, xx, yy, ...lerpC(darken(b, 0.46), VIOLET_DEEP, 0.32), 255); } }
    for (let t = 0; t < 6; t++) { const xx = cxr - flip * t, yy = y + 3 + t; if (xx >= x0 && xx < x1 && yy >= 0 && yy < GATE_H) { const b = getPx(img, xx, yy); put(img, xx, yy, ...lerpC(darken(b, 0.44), VIOLET_DEEP, 0.3), 255); } }
    for (let dd = 1; dd < 5; dd++) { const xx = cxr + flip * dd, yy = y + 12 + dd; if (xx >= x0 && xx < x1 && yy < GATE_H) { const b = getPx(img, xx, yy); put(img, xx, yy, ...darken(b, 0.4), 255); } }
  }
}
function getPx(img, x, y) { const i = (img.width * y + x) << 2; return [img.data[i], img.data[i + 1], img.data[i + 2]]; }

// additive glow over the pillar rune channels (state-lit).
function buildRuneGlow(alphaScale) {
  const img = new PNG({ width: GATE_W, height: GATE_H }); img.data.fill(0);
  const cx = GATE_W >> 1, innerHalf = OPENING_W >> 1;
  const bands = [[cx - innerHalf - 16, cx - innerHalf - 6], [cx + innerHalf + 6, cx + innerHalf + 16]];
  for (const band of bands) {
    const bcx = (band[0] + band[1]) >> 1;
    let gi = 0;
    for (let yy = PILLAR_TOP + 22; yy < PILLAR_BOTTOM - 18; yy += 46, gi++) {
      const flip = (gi % 2 === 0) ? 1 : -1;
      for (let dy = -14; dy <= 14; dy++) {
        const y = yy + dy; if (y < 0 || y >= GATE_H) continue;
        for (let dx = -6; dx <= 6; dx++) {
          const x = bcx + dx; if (x < 0 || x >= GATE_W) continue;
          const vbar = (1 - clamp(Math.abs(dx) / 6, 0, 1)) * (Math.abs(dx) < 2 ? 1 : 0.30);
          let tick = 0;
          const uy = dy + 8; if (uy >= 0 && uy <= 6) tick = Math.max(tick, 1 - clamp(Math.abs(dx - flip * uy) / 3, 0, 1));
          const ly = dy - 3; if (ly >= 0 && ly <= 5) tick = Math.max(tick, 1 - clamp(Math.abs(dx + flip * ly) / 3, 0, 1));
          const a = Math.max(vbar, tick * 0.85) * 0.9 * alphaScale;
          if (a <= 0.02) continue;
          const i = (GATE_W * y + x) << 2; if (a * 255 > img.data[i + 3]) { img.data[i] = VIOLET_BRIGHT[0]; img.data[i + 1] = VIOLET_BRIGHT[1]; img.data[i + 2] = VIOLET_BRIGHT[2]; img.data[i + 3] = Math.round(a * 255); }
        }
      }
    }
  }
  return img;
}

// the floating carved sigil stone (bobs). state → sigil tint. Optional glyph glow.
function buildSigil(state, layer) {
  const s = SIGIL_R * 2 + 10, img = new PNG({ width: s, height: s }); img.data.fill(0);
  const c = s / 2.0;
  const mod = state === "flickering" ? [1.12, 1.04, 1.22] : [0.62, 0.58, 0.70];
  for (let y = 0; y < s; y++) for (let x = 0; x < s; x++) {
    const dx = Math.abs(x - c) / SIGIL_R, dy = Math.abs(y - c) / (SIGIL_R * 0.9), d = dx * 1.02 + dy;
    if (d > 1.0) continue;
    const lit = 0.66 + (1 - dx) * 0.32 + (1 - dy) * 0.30;
    let col = lerpC(RUNE_STONE, [96, 84, 118], clamp(lit - 0.6, 0, 0.6));
    if (d > 0.82) col = darken(col, 0.34);
    col = [col[0] * mod[0], col[1] * mod[1], col[2] * mod[2]];
    put(img, x, y, col[0], col[1], col[2], 255);
  }
  drawGlyph(img, c, LAYER_GLYPH[layer] || "rune", false);
  return img;
}
function buildSigilGlow(layer, alphaScale) {
  const s = SIGIL_R * 2 + 10, img = new PNG({ width: s, height: s }); img.data.fill(0);
  drawGlyph(img, s / 2.0, LAYER_GLYPH[layer] || "rune", true, alphaScale);
  return img;
}
function drawGlyph(img, c, kind, glow, alphaScale = 1) {
  const col = glow ? VIOLET : VIOLET_BRIGHT;
  const R = SIGIL_R * 0.56;
  const dotR = glow ? 5 : 3, aa = (glow ? 0.5 : 1.0) * alphaScale;
  const stamp = (px, py, rad) => {
    for (let yy = (py - rad) | 0; yy <= py + rad; yy++) for (let xx = (px - rad) | 0; xx <= px + rad; xx++) {
      if (xx < 0 || yy < 0 || xx >= img.width || yy >= img.height) continue;
      const dd = Math.hypot(xx - px, yy - py) / rad; if (dd > 1) continue;
      const a = (1 - dd) * aa; const i = (img.width * yy + xx) << 2;
      if (a * 255 > img.data[i + 3]) { img.data[i] = col[0]; img.data[i + 1] = col[1]; img.data[i + 2] = col[2]; img.data[i + 3] = Math.round(a * 255); }
    }
  };
  if (kind === "leaf") {
    for (let i = 0; i < 24; i++) { const t = i / 23, ang = -1.4 + 2.8 * t, rr = R * (1 - Math.abs(ang) / 1.6);
      stamp(c + Math.sin(ang) * rr, c - Math.cos(ang) * R * 0.4 - R * 0.1, dotR);
      stamp(c + Math.sin(ang) * rr, c + Math.cos(ang) * R * 0.4 - R * 0.1, dotR); }
    for (let i = 0; i < 12; i++) stamp(c, c - R * 0.5 + i / 11 * R, dotR * 0.8);
  } else if (kind === "star") {
    for (let k = 0; k < 5; k++) { const a0 = -Math.PI / 2 + k * Math.PI * 2 / 5;
      for (let i = 0; i < 12; i++) { const t = i / 11; stamp(c + Math.cos(a0) * R * t, c + Math.sin(a0) * R * t, dotR * (1.1 - 0.4 * t)); } }
  } else if (kind === "gear") {
    for (let i = 0; i < 28; i++) { const a1 = i / 28 * Math.PI * 2; stamp(c + Math.cos(a1) * R * 0.7, c + Math.sin(a1) * R * 0.7, dotR); }
    for (let k = 0; k < 8; k++) { const a2 = k * Math.PI * 2 / 8; stamp(c + Math.cos(a2) * R, c + Math.sin(a2) * R, dotR * 1.1); }
    stamp(c, c, dotR * 1.4);
  } else if (kind === "rune") {
    for (let i = 0; i < 12; i++) { const t = i / 11; stamp(c, c - R + t * R * 0.9, dotR); stamp(c - t * R * 0.7, c - R * 0.1 + t * R * 0.7, dotR); stamp(c + t * R * 0.7, c - R * 0.1 + t * R * 0.7, dotR); }
  } else {
    for (let i = 0; i < 30; i++) { const a3 = i / 30 * Math.PI * 2; stamp(c + Math.cos(a3) * R, c + Math.sin(a3) * R, dotR); stamp(c + Math.cos(a3) * R * 0.45, c + Math.sin(a3) * R * 0.45, dotR * 0.8); }
  }
}
// additive swirl veil (flickering/open).
function buildVeil(alphaScale) {
  const w = VEIL_W, h = PILLAR_BOTTOM - PILLAR_TOP, img = new PNG({ width: w, height: h }); img.data.fill(0);
  const cx = w / 2.0, cy = h / 2.0;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const dx = (x - cx) / (w * 0.5), dy = (y - cy) / (h * 0.5), r = Math.hypot(dx, dy);
    if (r > 1.0) continue;
    const ang = Math.atan2(dy, dx), swirl = 0.5 + 0.5 * Math.sin(ang * 3.0 + r * 7.0);
    const a = (1 - r) * (0.40 + 0.60 * swirl) * 0.95 * alphaScale;
    put(img, x, y, VIOLET_BRIGHT[0], VIOLET_BRIGHT[1], VIOLET_BRIGHT[2], Math.round(a * 255));
  }
  return img;
}

function put(png, x, y, r, g, b, a) {
  x = x | 0; y = y | 0;
  if (x < 0 || y < 0 || x >= png.width || y >= png.height) return;
  const i = (png.width * y + x) << 2;
  png.data[i] = r; png.data[i + 1] = g; png.data[i + 2] = b; png.data[i + 3] = a;
}

// ---------------- canvas -----------------------------------------------------
let minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  const [x, y] = cellLocal(c, r);
  minX = Math.min(minX, x - HW); maxX = Math.max(maxX, x + HW);
  minY = Math.min(minY, y - HH - GATE_H - 60); maxY = Math.max(maxY, y + HH + 60);
}
minX -= 1120; maxX += 1120; minY -= 620; maxY += 900;
const PAD = 40;
const CW = Math.ceil(maxX - minX) + PAD * 2, CH = Math.ceil(maxY - minY) + PAD * 2;
const OX = -minX + PAD, OY = -minY + PAD;
const canvas = new PNG({ width: CW, height: CH });

// ---- void sky: deep violet-black gradient ----------------------------------
for (let y = 0; y < CH; y++) {
  const t = y / CH;
  const br = 14 + t * 10, bg = 11 + t * 8, bb = 26 + t * 20;
  for (let x = 0; x < CW; x++) { const i = (CW * y + x) << 2; canvas.data[i] = br; canvas.data[i + 1] = bg; canvas.data[i + 2] = bb; canvas.data[i + 3] = 255; }
}
// two soft violet-blue nebula washes so the sky isn't uniform.
function nebula(cxf, cyf, radf, tintCol, strength) {
  const nc = [CW * cxf, CH * cyf], nmax = Math.max(CW, CH) * radf;
  for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) {
    const d = Math.hypot(x - nc[0], y - nc[1]) / nmax; if (d >= 1.0) continue;
    const a = (1 - d) * (1 - d) * strength; const i = (CW * y + x) << 2;
    canvas.data[i] = Math.min(255, canvas.data[i] + tintCol[0] * a);
    canvas.data[i + 1] = Math.min(255, canvas.data[i + 1] + tintCol[1] * a);
    canvas.data[i + 2] = Math.min(255, canvas.data[i + 2] + tintCol[2] * a);
  }
}
nebula(0.44, 0.46, 0.44, [90, 60, 140], 0.28);
nebula(0.72, 0.28, 0.30, [56, 66, 130], 0.22);
nebula(0.24, 0.66, 0.26, [80, 52, 120], 0.18);
// dense starfield.
for (let s = 0; s < 2200; s++) {
  const sx = hash2(s, 3, 7) % CW, sy = hash2(s, 11, 19) % CH;
  const b = 90 + (hash2(s, 5, 23) % 140);
  const violet = (hash2(s, 9, 31) % 4) === 0;
  put(canvas, sx, sy, b, violet ? Math.round(b * 0.7) : b, violet ? Math.round(b * 1.15) : Math.round(b * 0.95), 255);
  if ((hash2(s, 2, 41) % 9) === 0) put(canvas, sx + 1, sy, b >> 1, b >> 1, b >> 1, 255);
}
// a few larger twinkling stars (cross-glint).
const bigStars = [[0.20, 0.22], [0.78, 0.16], [0.62, 0.72], [0.30, 0.78], [0.88, 0.52]];
for (const [fx, fy] of bigStars) {
  const sx = (CW * fx) | 0, sy = (CH * fy) | 0;
  for (let rr = 0; rr <= 6; rr++) { const a = (1 - rr / 6); put(canvas, sx + rr, sy, 255, 250, 255, 255 * a); put(canvas, sx - rr, sy, 255, 250, 255, 255 * a); put(canvas, sx, sy + rr, 255, 250, 255, 255 * a); put(canvas, sx, sy - rr, 255, 250, 255, 255 * a); }
  for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) if (Math.hypot(dx, dy) <= 2) put(canvas, sx + dx, sy + dy, 255, 252, 255, 255);
}

// ---- blit helpers -----------------------------------------------------------
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
// nearest-neighbour scale of a PNG to (w,h) — for the scaled violet glow decal.
function scalePng(src, w, h) {
  w = Math.max(1, Math.round(w)); h = Math.max(1, Math.round(h));
  const out = new PNG({ width: w, height: h }); out.data.fill(0);
  for (let y = 0; y < h; y++) { const sy = Math.min(src.height - 1, Math.floor(y * src.height / h));
    for (let x = 0; x < w; x++) { const sx = Math.min(src.width - 1, Math.floor(x * src.width / w));
      const si = (src.width * sy + sx) << 2, di = (w * y + x) << 2;
      out.data[di] = src.data[si]; out.data[di + 1] = src.data[si + 1]; out.data[di + 2] = src.data[si + 2]; out.data[di + 3] = src.data[si + 3]; } }
  return out;
}
function blitAdd(src, dx, dy, aScale) {
  if (!src) return;
  for (let y = 0; y < src.height; y++) { const cy = Math.round(dy) + y; if (cy < 0 || cy >= CH) continue;
    for (let x = 0; x < src.width; x++) { const cx = Math.round(dx) + x; if (cx < 0 || cx >= CW) continue;
      const si = (src.width * y + x) << 2; let a = src.data[si + 3]; if (a === 0) continue;
      if (aScale != null) a = a * aScale;
      const di = (CW * cy + cx) << 2, af = a / 255;
      canvas.data[di] = Math.min(255, canvas.data[di] + src.data[si] * af);
      canvas.data[di + 1] = Math.min(255, canvas.data[di + 1] + src.data[si + 1] * af);
      canvas.data[di + 2] = Math.min(255, canvas.data[di + 2] + src.data[si + 2] * af);
    } }
}
function line(x0, y0, x1, y1, col, wdt, alpha) {
  const dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy), steps = Math.max(1, Math.ceil(len));
  const hw = wdt / 2;
  for (let i = 0; i <= steps; i++) {
    const t = i / steps, px = x0 + dx * t, py = y0 + dy * t;
    for (let oy = -hw; oy <= hw; oy++) for (let ox = -hw; ox <= hw; ox++) {
      const xx = Math.round(px + ox), yy = Math.round(py + oy);
      if (xx < 0 || yy < 0 || xx >= CW || yy >= CH) continue;
      const di = (CW * yy + xx) << 2, af = alpha;
      canvas.data[di] = col[0] * af + canvas.data[di] * (1 - af);
      canvas.data[di + 1] = col[1] * af + canvas.data[di + 1] * (1 - af);
      canvas.data[di + 2] = col[2] * af + canvas.data[di + 2] * (1 - af);
    }
  }
}
function filledCircle(cx0, cy0, rad, col, alpha, squashY) {
  for (let oy = -rad; oy <= rad; oy++) for (let ox = -rad; ox <= rad; ox++) {
    if (Math.hypot(ox, oy / (squashY || 1)) > rad) continue;
    const xx = Math.round(cx0 + ox), yy = Math.round(cy0 + oy);
    if (xx < 0 || yy < 0 || xx >= CW || yy >= CH) continue;
    const di = (CW * yy + xx) << 2, af = alpha;
    canvas.data[di] = col[0] * af + canvas.data[di] * (1 - af);
    canvas.data[di + 1] = col[1] * af + canvas.data[di + 1] * (1 - af);
    canvas.data[di + 2] = col[2] * af + canvas.data[di + 2] * (1 - af);
  }
}

// ---------------- draw order -------------------------------------------------
const order = [];
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) order.push([c, r]);
order.sort((a, b) => (a[0] + a[1]) - (b[0] + b[1]));
function findSym(s) { for (let r = 0; r < H; r++) { const c = layout[r].indexOf(s); if (c >= 0) return [c, r]; } return null; }
function allSym(s) { const out = []; for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) if (layout[r][c] === s) out.push([c, r]); return out; }

// island screen extents.
let ismnx = 1e9, ismxx = -1e9, botY = -1e9;
for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) {
  if (!isIsland(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  ismnx = Math.min(ismnx, OX + lx - HW); ismxx = Math.max(ismxx, OX + lx + HW);
  if (OY + ly + HH > botY) botY = OY + ly + HH;
}

// Pass -2: debris islets.
const [_clx, _cly] = cellLocal(Math.floor(W / 2), Math.floor(H / 2));
const centerLX = OX + _clx, centerLY = OY + _cly;
const debris = [[-980, 120, 78, 0], [1020, 40, 64, 1], [-620, 560, 52, 2], [760, 600, 70, 3], [120, -560, 46, 4]];
for (const [ox, oy, w, k] of debris) { const d = makeDebris(w, 900 + k); blit(d, centerLX + ox - w / 2, centerLY + oy - d.height / 2); }

// Pass -1: irregular bedrock underside (#257) — top edge hugs the island's jagged bottom,
// mass spans the widest lower silhouette then descends in bedrock layers to a hanging tail.
{
  const span = Math.round(ismxx - ismnx);
  let topRimY = 1e9;
  for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
    if (!isIsland(c, r)) continue;
    if (isIsland(c, r + 1) && isIsland(c + 1, r)) continue;
    const [, ly] = cellLocal(c, r);
    topRimY = Math.min(topRimY, OY + ly + HH);
  }
  const imgTopY = topRimY - HH;
  const hang = Math.round(span * 0.20);   // (#257 v1.10.3) 넓고 짧은 중앙 돌출 (멤쵸 #2)
  const depth = Math.round((botY - imgTopY) + hang);
  const topProfile = new Float32Array(span).fill(-1);
  // Trace EVERY island tile's lower-diamond edges (not just the lower-rim tiles). Restricting to
  // rim tiles left interior notch columns (a tile foot sits above them, but the rim tile one row
  // down doesn't cover that x) with no rock → the "blue triangle" voids in the staggered edge
  // (카나 #4). Covering every column that has ANY island foot above it, up to that foot's bottom
  // rim, closes the notches; the aprons/tiles (drawn in front) overpaint the non-notch part.
  for (let r = 0; r < H; r++) for (let c = 0; c < layout[r].length; c++) {
    if (!isIsland(c, r)) continue;
    const [lx, ly] = cellLocal(c, r);
    const cxImg = OX + lx - ismnx;                 // tile centre x in image space
    const vtxY = (OY + ly + HH) - imgTopY;         // bottom vertex y in image space
    // Follow the tile's two LOWER edges (bottom vertex up to the side vertices, 0.5 px/px). Keep
    // the HIGHEST rim per column (smallest y) so rock tucks right under the topmost tile foot.
    const tileL = Math.round(cxImg - HW), tileR = Math.round(cxImg + HW);
    for (let x = Math.max(0, tileL); x <= Math.min(span - 1, tileR); x++) {
      const edgeY = vtxY - 0.5 * Math.abs(x - cxImg);
      if (topProfile[x] < 0 || edgeY < topProfile[x]) topProfile[x] = edgeY;
    }
  }
  const u = makeUnderside(span, depth, 0x9e3779b9 & 0x7fffffff, topProfile);
  blit(u, (ismnx + ismxx) / 2 - span / 2, imgTopY);
}

// Pass A: full-perimeter cliff aprons.
for (const [c, r] of order) {
  if (!isIsland(c, r)) continue;
  let perim = false;
  for (const [dc, dr] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) if (!isIsland(c + dc, r + dr)) perim = true;
  if (!perim) continue;
  const southOpen = !isIsland(c, r + 1), eastOpen = !isIsland(c + 1, r);
  if (!southOpen && !eastOpen) continue;
  const { img } = makeApron(1, eastOpen, southOpen, hash2(c, r, 733));
  const [lx, ly] = cellLocal(c, r);
  blit(img, OX + lx - HW, OY + ly - HH);
}

// Pass B: island ground slab (dirt), TONE-lifted.
for (const [c, r] of order) {
  if (!isIsland(c, r)) continue;
  const [lx, ly] = cellLocal(c, r);
  blit(SRC[1], OX + lx - HW, OY + ly - HH, TONE);
}

// Pass B2: dead/worn grass patches on `g` cells (olive-tan dry mats, NOT green squares).
const DEAD_MAT = [96, 92, 58], DEAD_MAT_DK = [70, 66, 40], DEAD_BLADE = [122, 116, 72], DEAD_BLADE_DK = [84, 78, 46];
for (const [c, r] of allSym("g")) {
  const [lx, ly] = cellLocal(c, r), px = OX + lx, py = OY + ly;
  const seed = (Math.abs(px) * 3 + Math.abs(py) * 7) | 0;
  for (let i = 0; i < 70; i++) {
    const h = (seed * 1103515245 + i * 12345 + 7) & 0x7fffffff;
    const a = (h % 628) / 100.0, rr = 0.30 + ((h >> 8) % 100) / 100.0 * 0.70;
    const dx = Math.cos(a) * rr * (HW * 0.78), dy = Math.sin(a) * rr * (HH * 0.78);
    const col = ((h >> 3) % 3 !== 0) ? DEAD_MAT : DEAD_MAT_DK;
    filledCircle(px + dx, py + dy, 3, col, 0.42, 1);
  }
  for (let j = 0; j < 14; j++) {
    const h2 = (seed * 22695477 + j * 6971 + 13) & 0x7fffffff;
    const a2 = (h2 % 628) / 100.0, rr2 = ((h2 >> 6) % 100) / 100.0 * 0.72;
    const bx = px + Math.cos(a2) * rr2 * (HW * 0.66), by = py + Math.sin(a2) * rr2 * (HH * 0.66);
    const blade = (j % 2 === 0) ? DEAD_BLADE : DEAD_BLADE_DK, lean = (h2 & 1) ? -2 : 2, hgt = 5 + ((h2 >> 4) % 5);
    line(bx, by, bx + lean, by - hgt, blade, 1.5, 0.85);
  }
}

// Pass C: ground traces (worn stone-slab path decals dais→gates + spiral sigil + cracks).
const spawn = findSym("S");
if (spawn) {
  const [sx, sy] = cellLocal(spawn[0], spawn[1]); const dais = [OX + sx, OY + sy];
  for (const sym of ["1", "2", "3", "4", "5"]) {
    const g = findSym(sym); if (!g) continue;
    const [gx, gy] = cellLocal(g[0], g[1]); const gp = [OX + gx, OY + gy];
    const vx = gp[0] - dais[0], vy = gp[1] - dais[1], n = Math.hypot(vx, vy);
    if (n < 1) continue;
    const startf = 150 / n, endf = (n - 70) / n;
    // worn path underlay (darker dirt).
    line(dais[0] + vx * startf, dais[1] + vy * startf, dais[0] + vx * endf, dais[1] + vy * endf, [66, 54, 44], 20, 0.30);
    // stone-slab decals stepping along the path.
    const slabs = Math.max(2, Math.floor((endf - startf) * n / 44));
    for (let s = 0; s <= slabs; s++) {
      const t = startf + (endf - startf) * (s / slabs);
      const cxs = dais[0] + vx * t, cys = dais[1] + vy * t;
      // small iso stone slab.
      for (let oy = -9; oy <= 9; oy++) for (let ox = -18; ox <= 18; ox++) {
        if (Math.abs(ox) / 18 + Math.abs(oy) / 9 > 1) continue;
        const shade = 0.9 + 0.14 * (1 - (Math.abs(ox) / 18 + Math.abs(oy) / 9));
        const edge = Math.abs((Math.abs(ox) / 18 + Math.abs(oy) / 9) - 0.9) < 0.08;
        let col = edge ? [70, 66, 62] : [118 * shade, 112 * shade, 106 * shade];
        col = [col[0] * TONE[0], col[1] * TONE[1], col[2] * TONE[2]];
        const xx = Math.round(cxs + ox), yy = Math.round(cys + oy);
        if (xx < 0 || yy < 0 || xx >= CW || yy >= CH) continue;
        const di = (CW * yy + xx) << 2, af = 0.9;
        canvas.data[di] = col[0] * af + canvas.data[di] * (1 - af);
        canvas.data[di + 1] = col[1] * af + canvas.data[di + 1] * (1 - af);
        canvas.data[di + 2] = col[2] * af + canvas.data[di + 2] * (1 - af);
      }
    }
  }
  // spiral whisper-sigil.
  let prev = null;
  for (let i = 0; i <= 90; i++) { const t = i / 90, ang = t * 2.4 * Math.PI * 2, rad = 70 + t * 100; const p = [dais[0] + Math.cos(ang) * rad, dais[1] + Math.sin(ang) * rad * 0.5]; if (prev) line(prev[0], prev[1], p[0], p[1], [96, 78, 122], 2, 0.5); prev = p; }
  // cracked earth patches.
  for (const [dcx, dcy] of [[3, 2], [-4, 1], [2, -3], [-2, 4], [5, -1], [-5, -2], [1, 5], [4, 3]]) {
    const cc = spawn[0] + dcx, cr = spawn[1] + dcy; if (!isIsland(cc, cr)) continue;
    const [px2, py2] = cellLocal(cc, cr), c0 = [OX + px2, OY + py2];
    for (let k = 0; k < 5; k++) { const a = k / 5 * Math.PI * 2 + (c0[0] + c0[1]) * 0.01, len = 10 + ((c0[0] * 7 + c0[1] * 3 + k * 13) % 12); line(c0[0], c0[1], c0[0] + Math.cos(a) * len, c0[1] + Math.sin(a) * len * 0.5, [51, 38, 31], 1.5, 0.5); }
  }
}

// Pass D: raised ROUND stone dais (3 concentric weathered slabs + sigil ring + violet glow).
if (spawn) drawDais(spawn[0], spawn[1]);
function drawDais(c, r) {
  const [lx, ly] = cellLocal(c, r), px = OX + lx, py = OY + ly;
  const rise = 16, halfW = HW * 2.0, halfH = HH * 2.0;
  const rings = [[1.00, 0.80, 0.0], [0.74, 0.92, 3.0], [0.46, 1.04, 6.0]];
  // front wall (stepped bands).
  for (let x = -halfW; x <= halfW; x++) {
    const dxn = Math.abs(x) / halfW; if (dxn > 1) continue;
    const rim = (1 - dxn) * halfH;
    for (let yy = rim; yy < rim + rise; yy++) {
      const t = (yy - rim) / rise, lit = x < 0 ? 0.66 : 0.84, band = 1 - 0.12 * ((t * 3) | 0);
      let col = lerpC([78, 74, 72], [122, 116, 112], lit * band);
      col = [col[0] * TONE[0], col[1] * TONE[1], col[2] * TONE[2]];
      put(canvas, px + x, py + yy, col[0], col[1], col[2], 255);
    }
  }
  // top surface (paint outer→inner via ring lookup).
  for (let y = -halfH; y <= halfH; y++) for (let x = -halfW; x <= halfW; x++) {
    const dx = Math.abs(x) / halfW, dy = Math.abs(y) / halfH, d = dx + dy; if (d > 1) continue;
    let tone = 0.80, lift = 0, edge = false;
    for (const [rr, tn, lf] of rings) { if (d <= rr) { tone = tn; lift = lf; } if (Math.abs(d - rr) < 0.03) edge = true; }
    let col = [140 * (tone * (0.94 + 0.10 * (1 - d))), 134 * (tone * (0.94 + 0.10 * (1 - d))), 130 * (tone * (0.94 + 0.10 * (1 - d)))];
    if (edge) col = [78, 74, 72];
    if (Math.abs(d - 0.60) < 0.02 && !edge) col = lerpC(col, [92, 72, 118], 0.5);
    col = [col[0] * TONE[0], col[1] * TONE[1], col[2] * TONE[2]];
    put(canvas, px + x, py + Math.round(y - lift), col[0], col[1], col[2], 255);
  }
  // violet centre glow (additive pool).
  for (let oy = -22; oy <= 22; oy++) for (let ox = -40; ox <= 40; ox++) {
    const d = Math.hypot(ox / 40, oy / 22); if (d > 1) continue;
    const a = (1 - d) * (1 - d) * 0.5; const xx = px + ox, yy = py + oy - 4;
    if (xx < 0 || yy < 0 || xx >= CW || yy >= CH) continue;
    const di = (CW * yy + xx) << 2;
    canvas.data[di] = Math.min(255, canvas.data[di] + 150 * a);
    canvas.data[di + 1] = Math.min(255, canvas.data[di + 1] + 110 * a);
    canvas.data[di + 2] = Math.min(255, canvas.data[di + 2] + 200 * a);
  }
}

// Pass E: cauldron stone pad.
const caulCell = findSym("C");
if (caulCell) {
  const [lx, ly] = cellLocal(caulCell[0], caulCell[1]), px = OX + lx, py = OY + ly;
  const halfW = HW * 0.78, halfH = HH * 0.78;
  for (let y = -halfH; y <= halfH; y++) for (let x = -halfW; x <= halfW; x++) {
    const dx = Math.abs(x) / halfW, dy = Math.abs(y) / halfH; if (dx + dy > 1) continue;
    let col = Math.abs((dx + dy) - 0.86) < 0.05 ? [78, 74, 72] : [122 * (0.82 + 0.16 * (1 - (dx + dy))), 116 * (0.82 + 0.16 * (1 - (dx + dy))), 112 * (0.82 + 0.16 * (1 - (dx + dy)))];
    col = [col[0] * TONE[0], col[1] * TONE[1], col[2] * TONE[2]];
    put(canvas, px + x, py + y, col[0], col[1], col[2], 255);
  }
}

// Pass F: objects (cauldron, observation stone, gates) back-to-front.
for (const [c, r] of order) {
  const sym = layout[r][c];
  const [lx, ly] = cellLocal(c, r), px = OX + lx, py = OY + ly;
  if (sym === "C" && CAULDRON) blit(CAULDRON, px - CAULDRON.width / 2, py - CAULDRON.height + 16, TONE);
  else if (sym === "Y" && STONE) blit(STONE, px - STONE.width / 2, py - STONE.height + 12, TONE);
  else if (legend.objects[sym] && legend.objects[sym].kind === "homedeco") {
    // (v1.10.0) homedeco 소품 미러. map_loader _spawn_l2_object 배치를 그대로 재현:
    // Sprite2D(texture centered) at cell centre + offset. art_variants 는 hash2 로 결정 픽.
    const spec = legend.objects[sym];
    let artName = spec.art;
    const variants = spec.art_variants || [];
    if (variants.length) { const pool = [spec.art, ...variants]; artName = pool[hash2(c, r, 11) % pool.length]; }
    const art = DECO_ART[artName];
    if (art) {
      const ox = (spec.offset && spec.offset[0]) || 0, oy = (spec.offset && spec.offset[1]) || 0;
      // 접지 그림자: 스프라이트 시각 중심 아래 지면 셀 중앙에 눌린 타원 (허브 소품 접지감).
      filledCircle(px, py, 16, [0, 0, 0], 0.30, 2.4);
      // Sprite2D: texture는 중앙 정렬 + offset → 시각 중심 = (px+ox, py+oy).
      blit(art, px + ox - art.width / 2, py + oy - art.height / 2, TONE);
      // violet glow (map_loader: glow=="violet" → light_pool_violet, off.y*0.4, glow_scale).
      if (spec.glow === "violet" && GLOW_VIOLET) {
        const gs = spec.glow_scale != null ? spec.glow_scale : 0.8;
        const gw = GLOW_VIOLET.width * gs, gh = GLOW_VIOLET.height * gs;
        const scaled = scalePng(GLOW_VIOLET, gw, gh);
        blitAdd(scaled, px - gw / 2, py + oy * 0.4 - gh / 2, 0.85);
      }
    }
  }
  else if ("12345".includes(sym)) {
    const spec = legend.objects[sym];
    const isNature = spec && spec.layer === "nature";
    const state = isNature ? "flickering" : "dormant";
    const layer = spec.layer;
    // glow pool at base — open only (nature is flickering → none).
    const gate = buildGate(state);
    blit(gate, px - GATE_W / 2, py - GATE_H, TONE);
    if (isNature) {
      // lit pillar runes (flickering).
      const rg = buildRuneGlow(0.7);
      blitAdd(rg, px - GATE_W / 2, py - GATE_H);
      // flickering violet swirl veil, centred in the opening.
      const veil = buildVeil(0.5);
      const openingMid = (PILLAR_BOTTOM + PILLAR_TOP) / 2;   // centre y (from gate top)
      blitAdd(veil, px - veil.width / 2, py - GATE_H + openingMid - veil.height / 2);
    }
    // floating sigil stone above the lintel.
    const sig = buildSigil(state, layer);
    const sy = py - GATE_H + SIGIL_CY;
    blit(sig, px - sig.width / 2, sy - sig.height / 2, TONE);
    if (isNature) { const sg = buildSigilGlow(layer, 0.5); blitAdd(sg, px - sg.width / 2, sy - sg.height / 2); }
  }
}

// ---- soft vignette frame ----------------------------------------------------
for (let y = 0; y < CH; y++) for (let x = 0; x < CW; x++) {
  const dxu = x / CW - 0.5, dyu = y / CH - 0.5, dist = Math.hypot(dxu, dyu) / 0.7071;
  let a = 0;
  if (dist > 0.46) { const t = Math.min(1, (dist - 0.46) / (1 - 0.46)); a = t * t * (3 - 2 * t) * 0.30; }
  if (a <= 0) continue;
  const di = (CW * y + x) << 2;
  canvas.data[di] *= (1 - a); canvas.data[di + 1] *= (1 - a); canvas.data[di + 2] *= (1 - a);
}

// ---------------- write ------------------------------------------------------
if (CLOSEUP) {
  // Tight crop on the flickering nature gate (symbol "1").
  const g = findSym("1");
  const [gx, gy] = cellLocal(g[0], g[1]); const px = OX + gx, py = OY + gy;
  const cw = 620, ch = 720;
  const x0 = Math.max(0, Math.round(px - cw / 2)), y0 = Math.max(0, Math.round(py - GATE_H - 90));
  const crop = new PNG({ width: cw, height: ch });
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const si = (CW * Math.min(CH - 1, y0 + y) + Math.min(CW - 1, x0 + x)) << 2, di = (cw * y + x) << 2;
    crop.data[di] = canvas.data[si]; crop.data[di + 1] = canvas.data[si + 1]; crop.data[di + 2] = canvas.data[si + 2]; crop.data[di + 3] = 255;
  }
  writeScaled(crop, cw, ch, OUT, 900);
} else if (HERO) {
  // 아치(P1..P5)+다이스(스폰) 줌인. 프레임 중심 = 아치 정점 P3와 다이스의 중점 (hero_render.gd 미러).
  const p3 = findSym("3"), sp = findSym("S");
  const [p3x, p3y] = cellLocal(p3[0], p3[1]);
  const [spx, spy] = cellLocal(sp[0], sp[1]);
  // 아치 폭: P1(sym"1")↔P5(sym"5") 스크린 X 스팬 + 여백.
  const g1 = findSym("1"), g5 = findSym("5");
  const x1 = OX + cellLocal(g1[0], g1[1])[0], x5 = OX + cellLocal(g5[0], g5[1])[0];
  const cx = OX + (p3x + spx) / 2, cyc = OY + (p3y + spy) / 2;
  const cw = Math.round((x5 - x1) + GATE_W + 240);          // 아치 폭 + 게이트 여유
  const ch = Math.round(GATE_H + (spy - p3y) + 430);        // 게이트 높이 + 정점→다이스 + 여백(부유 시길 헤드룸)
  const x0 = Math.max(0, Math.round(cx - cw / 2)), y0 = Math.max(0, Math.round(cyc - ch / 2 - GATE_H / 2 - 20));
  const crop = new PNG({ width: cw, height: ch });
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const si = (CW * Math.min(CH - 1, y0 + y) + Math.min(CW - 1, x0 + x)) << 2, di = (cw * y + x) << 2;
    crop.data[di] = canvas.data[si]; crop.data[di + 1] = canvas.data[si + 1]; crop.data[di + 2] = canvas.data[si + 2]; crop.data[di + 3] = 255;
  }
  writeScaled(crop, cw, ch, OUT, 1400);
} else if (CAPSULE) {
  // (#257 v1.10.1 rev) 캡슐: **섬 전체 + 언더사이드가 프레임인** 되는 1920×1080 히어로.
  // 이전 버그: ZOOM=1.8 고정 크롭이 1067×600만 잘라 타일 클로즈업이 됐다(카나 검수 #5).
  // 대신 실 실루엣(위: 아치 top rim / 아래: 매달린 암반 tail / 좌우: slab rim)을 모두 감싸는
  // 최소 크롭 박스를 구해 16:9 로 맞춘 뒤 1920×1080 으로 업스케일한다. (v1.10.0 정상 캡슐의
  // "섬 전체 크롭 → 업스케일" 방식으로 복귀, 단 언더사이드 tail 까지 포함.)
  const OUTW = 1920, OUTH = 1080, ASPECT = OUTW / OUTH;
  const islandCX = (ismnx + ismxx) / 2;
  // Vertical silhouette bounds: from the top of the tallest gate arch (top rim − GATE_H − sigil
  // headroom) down to the bottom of the hanging rock tail (botY + hang).
  let topRim = 1e9;
  for (let r = 0; r < H; r++) for (let c = 0; c < W; c++) { if (!isIsland(c, r)) continue; const [, ly] = cellLocal(c, r); topRim = Math.min(topRim, OY + ly - HH); }
  const archTop = topRim - GATE_H - 70;                            // gate stands GATE_H above its cell + floating sigil headroom
  const massBottom = botY + Math.round((ismxx - ismnx) * 0.20);    // botY + hang (mirror of the underside tail, v1.10.3)
  const marginX = 90, marginY = 70;
  let boxL = ismnx - marginX, boxR = ismxx + marginX;
  let boxT = archTop - marginY, boxB = massBottom + marginY;
  let boxW = boxR - boxL, boxH = boxB - boxT;
  // Grow the shorter axis so the crop is exactly 16:9 (letterbox the content, never crop it out).
  if (boxW / boxH > ASPECT) { const need = boxW / ASPECT; const add = need - boxH; boxT -= add / 2; boxB += add / 2; boxH = need; }
  else { const need = boxH * ASPECT; const add = need - boxW; boxL -= add / 2; boxR += add / 2; boxW = need; }
  let cw = Math.round(boxW), ch = Math.round(boxH);
  let x0 = Math.round((boxL + boxR) / 2 - cw / 2), y0 = Math.round((boxT + boxB) / 2 - ch / 2);
  // Clamp inside the canvas.
  cw = Math.min(cw, CW); ch = Math.min(ch, CH);
  x0 = Math.max(0, Math.min(CW - cw, x0)); y0 = Math.max(0, Math.min(CH - ch, y0));
  const crop = new PNG({ width: cw, height: ch });
  for (let y = 0; y < ch; y++) for (let x = 0; x < cw; x++) {
    const si = (CW * (y0 + y) + (x0 + x)) << 2, di = (cw * y + x) << 2;
    crop.data[di] = canvas.data[si]; crop.data[di + 1] = canvas.data[si + 1]; crop.data[di + 2] = canvas.data[si + 2]; crop.data[di + 3] = 255;
  }
  writeScaled(crop, cw, ch, OUT, OUTW, true);
} else {
  writeScaled(canvas, CW, CH, OUT, 1600);
}
function writeScaled(src, sw, sh, out, targetW, allowUpscale) {
  const scale = allowUpscale ? (targetW / sw) : Math.min(1, targetW / sw);
  const oW = Math.max(1, Math.round(sw * scale)), oH = Math.max(1, Math.round(sh * scale));
  const o = new PNG({ width: oW, height: oH });
  for (let y = 0; y < oH; y++) { const syv = Math.min(sh - 1, Math.floor(y / scale));
    for (let x = 0; x < oW; x++) { const sxv = Math.min(sw - 1, Math.floor(x / scale));
      const si = (sw * syv + sxv) << 2, di = (oW * y + x) << 2;
      o.data[di] = src.data[si]; o.data[di + 1] = src.data[si + 1]; o.data[di + 2] = src.data[si + 2]; o.data[di + 3] = 255; } }
  fs.writeFileSync(out, PNG.sync.write(o));
  console.log(`wrote ${out}  (${oW}×${oH})`);
}
