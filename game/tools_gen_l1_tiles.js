'use strict';
// L1A-1 — 시작의 숲 (Layer 1 nature) TILE generator. Procedural 128×64 iso diamonds,
// same fidelity/discipline as the L2~L5 generators (tools_gen_l2_tiles.js et al.) so
// the starting grove reads with the SAME procedural iso grammar as the rest of the game.
//   REPLACES the CC0 realistic photo tiles (green/brown cliffs with black voids, purple
//   backdrop bleed-through) that clashed with the flat procedural ground.
// Palette = docs/project-whisper-art-style-guide.md §3 (Layer-1 Nature 22색). No new colours.
//   초록 #1b3a2a #2e5d3b #4d8b4f #7ab567 #a8d982
//   갈색 #3a2a20 #5c4433 #8a6a4a #b59268
//   파랑 #1e3a5c #2e6b8a #4aa3b8 #8fd4d9
//   보라 #3a2a5c #6b4a9e #9e7ad9 #d9b8ff
//   중성 #2a2a33 #6e6e7a #b8b4a8 #e8dfc8 #faf5e6
// Lighting: 우상단(NE) 고정 (art-guide §2, iso-object-grammar §4). Deterministic (fixed
// seeds → identical output → save reproducibility).
// Produces into assets/tiles/. Run: node tools_gen_l1_tiles.js  (no external deps)
const zlib = require('zlib');
const fs = require('fs');
const path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'tiles');
fs.mkdirSync(OUT, { recursive: true });

// ---- PNG encoder (shared idiom with the L2~L5 generators) ----
function crc32(buf){let c=~0;for(let i=0;i<buf.length;i++){c^=buf[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(type,data){const len=Buffer.alloc(4);len.writeUInt32BE(data.length,0);const t=Buffer.from(type,'ascii');const body=Buffer.concat([t,data]);const crc=Buffer.alloc(4);crc.writeUInt32BE(crc32(body),0);return Buffer.concat([len,body,crc]);}
function encodePNG(w,h,pixels){const sig=Buffer.from([0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A]);const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(w,0);ihdr.writeUInt32BE(h,4);ihdr[8]=8;ihdr[9]=6;ihdr[10]=0;ihdr[11]=0;ihdr[12]=0;const stride=w*4;const raw=Buffer.alloc((stride+1)*h);for(let y=0;y<h;y++){raw[y*(stride+1)]=0;pixels.copy(raw,y*(stride+1)+1,y*stride,y*stride+stride);}const idat=zlib.deflateSync(raw,{level:9});return Buffer.concat([sig,chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]);}
function makeCanvas(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hexToRGB(hex){const s=hex.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function setPx(cv,x,y,rgb,a=255){if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;}
function blendPx(cv,x,y,rgb,a){if(a>=255)return setPx(cv,x,y,rgb,255);if(a<=0)return;if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;const af=a/255,ia=1-af;if(cv.data[i+3]===0){setPx(cv,x,y,rgb,a);return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function save(cv,name){const png=encodePNG(cv.w,cv.h,cv.data);fs.writeFileSync(path.join(OUT,name),png);console.log('wrote',name,cv.w+'x'+cv.h,png.length,'bytes');}
function inDiamond(x,y,w,h){const cx=(w-1)/2,cy=(h-1)/2;return Math.abs(x-cx)/(w/2)+Math.abs(y-cy)/(h/2)<=1.0+1e-6;}
function onDiamondEdge(x,y,w,h){const cx=(w-1)/2,cy=(h-1)/2;const d=Math.abs(x-cx)/(w/2)+Math.abs(y-cy)/(h/2);return d>0.9&&d<=1.0+1e-6;}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function clamp(v,lo,hi){return v<lo?lo:(v>hi?hi:v);}
// deterministic value-noise (bilinear smoothstep of a coarse hash grid) — organic patches
function hcell(ix,iy,salt){let h=(ix*374761393)^(iy*668265263)^(salt*2246822519);h=(h^(h>>>13))>>>0;h=(h*1274126177)>>>0;return((h^(h>>>16))>>>0)/4294967295;}
function smoothCell(x,y,cell,salt){const gx=x/cell,gy=y/cell;const x0=Math.floor(gx),y0=Math.floor(gy);let fx=gx-x0,fy=gy-y0;fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);const n00=hcell(x0,y0,salt),n10=hcell(x0+1,y0,salt),n01=hcell(x0,y0+1,salt),n11=hcell(x0+1,y0+1,salt);const nx0=n00*(1-fx)+n10*fx,nx1=n01*(1-fx)+n11*fx;return nx0*(1-fy)+nx1*fy;}
function det(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// ---- palette (art-guide §3, Layer-1 Nature) ----
const G0='#1b3a2a', G1='#2e5d3b', G2='#4d8b4f', G3='#7ab567', G4='#a8d982';  // 초록
const B0='#3a2a20', B1='#5c4433', B2='#8a6a4a', B3='#b59268';                // 갈색
const W0='#1e3a5c', W1='#2e6b8a', W2='#4aa3b8', W3='#8fd4d9';                // 파랑
const V0='#3a2a5c', V1='#6b4a9e', V2='#9e7ad9', V3='#d9b8ff';                // 보라
const N0='#2a2a33', N1='#6e6e7a', N2='#b8b4a8', N3='#e8dfc8', N4='#faf5e6';  // 중성

// Generic iso diamond tile with a procedural surface. `paint(x,y,c)->c` receives the
// interior base colour and returns a shaded colour. NE (upper-right) sheen baked in.
function makeTile(name, baseHex, edgeHex, paint) {
  const W = 128, H = 64;
  const cv = makeCanvas(W, H);
  const base = hexToRGB(baseHex), edge = hexToRGB(edgeHex);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    if (!inDiamond(x, y, W, H)) continue;
    let c = base;
    if (!onDiamondEdge(x, y, W, H)) {
      c = paint ? paint(x, y, base) : base;
      // NE (upper-right) soft sheen — the whole game is lit from the upper-right.
      if ((x + (H - y)) > 112) c = mix(c, [255,255,255], 0.08);
      if ((x + (H - y)) < 44) c = mix(c, [0,0,0], 0.06);
    } else {
      c = edge;
    }
    setPx(cv, x, y, c, 255);
  }
  save(cv, name);
}

// ── GRASS (T2A base + 3 decorated variants) ───────────────────────────────
// Bold moss-green field, soft tonal patches (not per-pixel noise), thin selout rim.
function grassPaint(x, y, base) {
  let c = base;
  const n = smoothCell(x, y, 13, 0x2e5d);      // large soft blade-patch tone
  if (n > 0.66) c = mix(c, hexToRGB(G3), 0.28);
  else if (n < 0.34) c = mix(c, hexToRGB(G1), 0.30);
  const m = smoothCell(x, y, 4, 0x4d8b);       // finer break-up
  if (m > 0.72) c = mix(c, hexToRGB(G4), 0.12);
  return c;
}
makeTile('t2a_grass.png', G2, G0, grassPaint);

// scatter a few deterministic accent specks (flowers/clover) onto a grass field
function accentTile(name, accents) {
  const W=128,H=64,cv=makeCanvas(W,H);
  const base=hexToRGB(G2), edge=hexToRGB(G0);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    if(!inDiamond(x,y,W,H))continue;
    let c = onDiamondEdge(x,y,W,H)?edge:grassPaint(x,y,base);
    if(!onDiamondEdge(x,y,W,H)){ if((x+(H-y))>112)c=mix(c,[255,255,255],0.08); if((x+(H-y))<44)c=mix(c,[0,0,0],0.06); }
    setPx(cv,x,y,c,255);
  }
  const r=det(0x515 + name.length*7);
  for(let n=0;n<accents.count;n++){
    const px=18+Math.floor(r()*(W-36)), py=10+Math.floor(r()*(H-20));
    if(!inDiamond(px,py,W,H)||onDiamondEdge(px,py,W,H))continue;
    const col=hexToRGB(accents.cols[Math.floor(r()*accents.cols.length)]);
    // a 2-3px bloom dot with a tiny lit top pixel
    blendPx(cv,px,py,col,235); blendPx(cv,px+1,py,col,200); blendPx(cv,px,py+1,mix(col,[0,0,0],0.3),200);
    blendPx(cv,px,py-1,mix(col,[255,255,255],0.4),210);
    if(accents.stem){blendPx(cv,px,py+2,hexToRGB(G1),160);}
  }
  save(cv,name);
}
// T2C clover patch: extra bright-green flecks
accentTile('t2c_grass_clover.png', {count:14, cols:[G4,G3], stem:false});
// T2B flowered patch: small white/violet/pink blossoms
accentTile('t2b_grass_flowers.png', {count:11, cols:[N4,V2,'#c96a7a'], stem:true});
// T2D bright flower-grass (rare highlight): denser mixed blossoms
accentTile('t2d_flower_grass.png', {count:18, cols:[N4,V3,'#f0a8b8',G4], stem:true});

// ── DIRT PATH (T1) — packed earth, small pebbles ──────────────────────────
makeTile('t1_dirt.png', B2, B0, (x,y,base)=>{
  let c=base;
  const n=smoothCell(x,y,10,0x8a6a);
  if(n>0.64)c=mix(c,hexToRGB(B3),0.24);
  else if(n<0.36)c=mix(c,hexToRGB(B1),0.28);
  // occasional pebble speck
  const p=smoothCell(x*2,y*2,3,0x5c44);
  if(p>0.86)c=mix(c,hexToRGB(N2),0.35);
  return c;
});

// ── MUD (T4) — dark wet brown, sheen puddles ──────────────────────────────
makeTile('t4_mud.png', B1, B0, (x,y,base)=>{
  let c=base;
  const n=smoothCell(x,y,9,0x3a2a);
  if(n<0.36)c=mix(c,hexToRGB(B0),0.40);          // dark wet pools
  else if(n>0.70)c=mix(c,hexToRGB(B2),0.18);
  // wet sheen fleck (blue-grey highlight where water pools reflect the sky)
  if(n<0.20)c=mix(c,hexToRGB(W1),0.20);
  return c;
});

// ── SANDBAR / worn dirt patch (worn_dirt_patch, trail decal, 128×64) ───────
(function wornPatch(){
  const W=128,H=64,cv=makeCanvas(W,H);
  const base=hexToRGB(B2), r=det(0x77);
  // a soft irregular blob of packed earth (transparent outside), not a full diamond
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const cx=(W-1)/2,cy=(H-1)/2;
    const dd=Math.abs(x-cx)/48+Math.abs(y-cy)/22;
    const wobble=0.78+smoothCell(x,y,7,0x88)*0.34;
    if(dd>wobble)continue;
    let c=mix(base,hexToRGB(B1),(dd/wobble)*0.4);
    const n=smoothCell(x,y,6,0x8a);
    if(n>0.7)c=mix(c,hexToRGB(B3),0.2);
    const a=Math.round(clamp(230*(1-(dd/wobble)*0.5),90,235));
    blendPx(cv,x,y,c,a);
  }
  save(cv,'worn_dirt_patch.png');
})();

// ── WATER (T5A / T5B) — lake blue, 2-frame shimmer (256×64 sheet) ──────────
function waterTile(name, baseHex, hiHex, seed) {
  const W=128,H=64,FR=2,cv=makeCanvas(W*FR,H);
  const base=hexToRGB(baseHex), dk=hexToRGB(W0), hi=hexToRGB(hiHex), edge=hexToRGB(W0);
  for(let f=0;f<FR;f++){const ox=f*W;
    for(let y=0;y<H;y++)for(let x=0;x<W;x++){
      if(!inDiamond(x,y,W,H))continue;
      let c=base;
      // iso ripple bands shifting per frame (dithering allowed on water per §2)
      const band=((y+f*2)%6);
      if(band===1)c=mix(c,hi,0.30);
      else if(band===4)c=mix(c,dk,0.26);
      const n=smoothCell(x,y+f*9,7,seed);
      if(n>0.74)c=mix(c,hi,0.22);
      else if(n<0.28)c=mix(c,dk,0.28);
      if(onDiamondEdge(x,y,W,H))c=edge;
      setPx(cv,ox+x,y,c,255);
    }
    // drifting sparkle glints (NE-lit crests)
    const r=det(seed+f*101);
    for(let n=0;n<10;n++){const px=18+Math.floor(r()*(W-36)),py=8+Math.floor(r()*(H-16));
      if(inDiamond(px,py,W,H)&&!onDiamondEdge(px,py,W,H)){blendPx(cv,ox+px,py,hexToRGB(W3),210);blendPx(cv,ox+px+1,py,hexToRGB(W3),140);}}
  }
  save(cv,name);
}
waterTile('t5a_water_anim.png', W2, W3, 0x5a11);
waterTile('t5b_water2_anim.png', W1, W2, 0x5b22);
// static 1-frame fallbacks (kept for any legacy reference)
makeTile('t5a_water.png', W2, W0, (x,y,base)=>{let c=base;const n=smoothCell(x,y,7,0x5a11);if(n>0.72)c=mix(c,hexToRGB(W3),0.2);else if(n<0.3)c=mix(c,hexToRGB(W0),0.25);return c;});
makeTile('t5b_water2.png', W1, W0, (x,y,base)=>{let c=base;const n=smoothCell(x,y,7,0x5b22);if(n>0.72)c=mix(c,hexToRGB(W2),0.2);else if(n<0.3)c=mix(c,hexToRGB(W0),0.25);return c;});

// ── MYSTIC WATER (T5M) — violet pond + glow overlay ───────────────────────
makeTile('t5m_mystic.png', V1, V0, (x,y,base)=>{
  let c=base;
  const band=(y%6);
  if(band===1)c=mix(c,hexToRGB(V2),0.28);
  else if(band===4)c=mix(c,hexToRGB(V0),0.24);
  const n=smoothCell(x,y,6,0x9e7a);
  if(n>0.74)c=mix(c,hexToRGB(V3),0.26);
  else if(n<0.28)c=mix(c,hexToRGB(V0),0.30);
  return c;
});
// mystic glow overlay: soft additive violet bloom on transparent bg (reused as bush cue too)
(function mysticGlow(){
  const W=128,H=64,cv=makeCanvas(W,H);
  const cx=(W-1)/2,cy=(H-1)/2, col=hexToRGB(V3);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const dx=(x-cx)/40,dy=(y-cy)/20;const d=Math.hypot(dx,dy);
    if(d<=1){const a=Math.round((1-d)*(1-d)*150);blendPx(cv,x,y,col,a);}
  }
  save(cv,'t5m_mystic_glow.png');
})();

// ── VOID (T0) — deep night-void diamond. NO purple zigzag: a clean dark diamond
//    with a subtle violet rim that reads as the floating-island silhouette edge, matching
//    the backdrop gradient so the top edge no longer "뚫린다". ──────────────
(function voidTile(){
  const W=128,H=64,cv=makeCanvas(W,H);
  const base=hexToRGB('#141422'), rim=hexToRGB(V0), deep=hexToRGB('#0d0d17');
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    if(!inDiamond(x,y,W,H))continue;
    let c=base;
    const cx=(W-1)/2,cy=(H-1)/2;const d=Math.abs(x-cx)/(W/2)+Math.abs(y-cy)/(H/2);
    c=mix(deep,base,clamp(1-d,0,1));            // darker toward centre → soft depth
    // faint violet inner rim (soft, not a hard zigzag)
    if(d>0.82&&d<=1.0)c=mix(c,rim,(d-0.82)/0.18*0.5);
    setPx(cv,x,y,c,255);
  }
  save(cv,'t0_void.png');
})();
// HOLLOW (T0h) — a gathered-out hole: like void but with a torn earthy rim so a hole
// dug in the ground reads as excavated (distinct from the border void).
(function hollowTile(){
  const W=128,H=64,cv=makeCanvas(W,H);
  const base=hexToRGB('#181420'), soil=hexToRGB(B0), r=det(0xC0);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    if(!inDiamond(x,y,W,H))continue;
    let c=base;
    const cx=(W-1)/2,cy=(H-1)/2;const d=Math.abs(x-cx)/(W/2)+Math.abs(y-cy)/(H/2);
    c=mix(hexToRGB('#0f0c16'),base,clamp(1-d,0,1));
    if(d>0.72&&d<=1.0)c=mix(c,soil,(d-0.72)/0.28*0.55);  // torn soil rim
    setPx(cv,x,y,c,255);
  }
  // a few crumbled dirt clods on the rim
  for(let n=0;n<10;n++){const a=r()*Math.PI*2;const px=Math.round(64+Math.cos(a)*54),py=Math.round(32+Math.sin(a)*26);blendPx(cv,px,py,hexToRGB(B1),200);}
  save(cv,'t0_hollow.png');
})();

console.log('L1 tiles done.');
