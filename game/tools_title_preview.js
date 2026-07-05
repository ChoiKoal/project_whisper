// tools_title_preview.js — a static SCHEMATIC preview of scenes/ui/title.tscn's 감성
// composition (v0.4.0-B B4). The real title is drawn at runtime by title_menu.gd with
// GPU compositing (additive glow, parallax); this headless environment has no GPU, so
// this pngjs render is a layout reference for the owner (palette + arrangement faithful,
// glow approximated by alpha blends). Deterministic — re-running reproduces byte-identical.
//
//   node tools_title_preview.js  → writes preview-title-v040b.png (1280×720)
const fs = require('fs');
const { PNG } = require('pngjs');

const W = 1280, H = 720;
const img = new PNG({ width: W, height: H });

function hex(h){ return [parseInt(h.slice(1,3),16), parseInt(h.slice(3,5),16), parseInt(h.slice(5,7),16)]; }
function set(x, y, c, a = 1) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || x >= W || y < 0 || y >= H) return;
  const i = (y * W + x) * 4;
  img.data[i]   = Math.round(img.data[i]   * (1 - a) + c[0] * a);
  img.data[i+1] = Math.round(img.data[i+1] * (1 - a) + c[1] * a);
  img.data[i+2] = Math.round(img.data[i+2] * (1 - a) + c[2] * a);
  img.data[i+3] = 255;
}
function fillRect(x0, y0, x1, y1, c, a = 1) {
  for (let y = y0; y < y1; y++) for (let x = x0; x < x1; x++) set(x, y, c, a);
}
function disc(cx, cy, r, c, a = 1) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++)
    if (x*x + y*y <= r*r) set(cx + x, cy + y, c, a);
}
// soft radial (additive-ish) glow: alpha falls off with distance
function glow(cx, cy, r, c, peak = 0.6) {
  for (let y = -r; y <= r; y++) for (let x = -r; x <= r; x++) {
    const d = Math.sqrt(x*x + y*y);
    if (d > r) continue;
    const a = peak * (1 - d / r) * (1 - d / r);
    set(cx + x, cy + y, c, a);
  }
}

// palette (art guide + title_menu.gd)
const NAVY = hex('#14131f'), NAVY2 = hex('#241f38');
const VIOLET = hex('#9e7ad9'), VIOLET_SOFT = hex('#c8b0ec'), CREAM = hex('#faf5e6');
const BAND_FAR = hex('#1c1a2c'), BAND_MID = hex('#171525'), BAND_NEAR = hex('#100e1c');

// 1) flat navy base + vertical gradient (navy top → violet-navy bottom)
for (let y = 0; y < H; y++) {
  const t = y / H;
  const c = [Math.round(NAVY[0]*(1-t)+NAVY2[0]*t), Math.round(NAVY[1]*(1-t)+NAVY2[1]*t), Math.round(NAVY[2]*(1-t)+NAVY2[2]*t)];
  for (let x = 0; x < W; x++) set(x, y, c, 1);
}
// 2) moon: soft halo + crisp disc + violet rim (upper-left)
const mx = 300, my = 180;
glow(mx, my, 220, VIOLET_SOFT, 0.28);
glow(mx, my, 120, CREAM, 0.22);
disc(mx, my, 46, hex('#f2ead6'), 1);
for (let a = 0; a < 360; a += 2) disc(mx + Math.cos(a)*52, my + Math.sin(a)*52, 1, VIOLET, 0.25);
// 3) three low-contrast cloud/hill bands
function bandRidge(crestY, amp, bumps, col) {
  for (let x = -50; x < W + 50; x++) {
    const t = (x + 50) / (W + 100);
    const y = crestY - Math.sin(t * Math.PI * bumps) * amp;
    fillRect(x, Math.round(y), x + 1, H, col, 0.9);
  }
}
bandRidge(H * 0.60, 40, 7, BAND_FAR);       // far
// mid jagged conifer line
for (let i = 0; i < 11; i++) {
  const cx = (W + 100) * (i + 0.5) / 11 - 50;
  const w = (W + 100) / 11 * 0.5;
  const h = 120 * (0.6 + 0.5 * Math.abs(Math.sin(i * 1.7)));
  for (let x = -w; x <= w; x++) {
    const yy = H * 0.66 - (h * (1 - Math.abs(x) / w));
    fillRect(cx + x, Math.round(yy), cx + x + 1, H, BAND_MID, 0.9);
  }
}
// 4) near hill + world tree + violet dawn glow behind tree
const crestY = H * 0.74, peakX = W * 0.72;
for (let x = -50; x < W + 50; x++) {
  const d = (x - peakX) / (W * 0.55);
  const y = crestY + 130 - Math.exp(-d*d) * 150;
  fillRect(x, Math.round(y), x + 1, H, BAND_NEAR, 1);
}
const treeX = peakX, treeTopY = crestY - 20;
glow(treeX, treeTopY - 180, 150, VIOLET, 0.35);          // large soft violet dawn glow
fillRect(treeX - 10, treeTopY - 150, treeX + 10, treeTopY, BAND_NEAR, 1);  // trunk
disc(treeX, treeTopY - 168, 62, BAND_NEAR, 1);           // crown
// 5) the constructor: tiny hooded back-view figure w/ staff, left of the tree
const fx = peakX - 132, fy = crestY + 6;
const bodyCol = [Math.round(BAND_NEAR[0]*0.25+NAVY2[0]*0.75), Math.round(BAND_NEAR[1]*0.25+NAVY2[1]*0.75), Math.round(BAND_NEAR[2]*0.25+NAVY2[2]*0.75)];
// cloak (trapezoid)
for (let y = 0; y <= 22; y++) {
  const half = 4 + (y / 22) * 4;
  fillRect(fx - half, fy - 22 + y, fx + half, fy - 22 + y + 1, bodyCol, 1);
}
disc(fx, fy - 24, 6, bodyCol, 1);                        // hood
fillRect(fx + 9, fy - 26, fx + 11, fy + 2, bodyCol, 1);  // staff
glow(fx + 10, fy - 32, 10, VIOLET, 0.85);                // floating orb glint
// 6) sparse fireflies
let seed = 12345;
function rnd(){ seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; }
for (let i = 0; i < 26; i++) glow(rnd()*W, crestY - rnd()*160, 3, hex('#ffe6a8'), 0.7);
for (let i = 0; i < 16; i++) glow(rnd()*W, rnd()*crestY*0.8, 2, VIOLET_SOFT, 0.5);
// 7) vignette (darken top+bottom edges)
for (let y = 0; y < H; y++) {
  const edge = Math.max(0, 1 - y / (H*0.28)) * 0.55 + Math.max(0, (y - H*0.72) / (H*0.28)) * 0.8;
  if (edge > 0) for (let x = 0; x < W; x++) set(x, y, [4,4,7], Math.min(0.85, edge));
}
// 8) logotype placeholder block (centered upper-third) + subtitle bar + glow copy
function textBar(cx, cy, w, h, c, a) { fillRect(cx - w/2, cy - h/2, cx + w/2, cy + h/2, c, a); }
glow(W/2, H*0.34, 260, VIOLET, 0.18);                    // title glow copy underneath
textBar(W/2, H*0.32, 520, 44, VIOLET, 0.92);             // "Project Whisper"
textBar(W/2, H*0.40, 300, 16, CREAM, 0.5);               // subtitle "속삭임이 세계를 만든다"
// 9) minimal menu markers (bottom-center column, thin underlines)
for (let i = 0; i < 4; i++) textBar(W/2, H*0.62 + i*44, 150, 4, CREAM, 0.55 - i*0.05);

fs.writeFileSync('preview-title-v040b.png', PNG.sync.write(img));
console.log('written preview-title-v040b.png', W + 'x' + H);
