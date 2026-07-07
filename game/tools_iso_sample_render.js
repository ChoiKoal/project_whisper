#!/usr/bin/env node
// tools_iso_sample_render.js — v1.2.0 게이트1 검수 렌더 2장.
//  (a) before_after.png — 5종 각각 [기존|신규] 나란히 스트립 (원근 교정 대비)
//  (b) in_context.png   — 신규 5종을 실제 아이소 바닥 타일(2:1) 위에 배치한 목업 (접지·원근 정합)
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_iso_sample_render.js
const fs = require('fs');
const path = require('path');
const { PNG } = require('pngjs');

const GAME = __dirname;
const OBJ = `${GAME}/assets/objects`;
const NEW = `${GAME}/assets/samples_iso`;
const TILES = `${GAME}/assets/tiles`;
const OUT_BA = '/workspace/group/project-whisper/render_before_after.png';
const OUT_IC = '/workspace/group/project-whisper/render_in_context.png';

function load(p){ try { return PNG.sync.read(fs.readFileSync(p)); } catch(e){ return null; } }
function newPng(w,h){ const p = new PNG({width:w,height:h}); p.data.fill(0); return p; }
function setpx(p,x,y,r,g,b,a){ x=Math.round(x);y=Math.round(y); if(x<0||y<0||x>=p.width||y>=p.height)return;
  const i=(y*p.width+x)<<2; const af=a/255, ia=1-af*(p.data[i+3]/255);
  const sa=p.data[i+3]/255; const oa=af+sa*(1-af); if(oa<=0)return;
  p.data[i]  =Math.round((r*af + p.data[i]  *sa*(1-af))/oa);
  p.data[i+1]=Math.round((g*af + p.data[i+1]*sa*(1-af))/oa);
  p.data[i+2]=Math.round((b*af + p.data[i+2]*sa*(1-af))/oa);
  p.data[i+3]=Math.round(oa*255);
}
function blit(dst, src, dx, dy){ if(!src)return; for(let y=0;y<src.height;y++)for(let x=0;x<src.width;x++){
  const i=(y*src.width+x)<<2; const a=src.data[i+3]; if(a===0)continue;
  setpx(dst,dx+x,dy+y,src.data[i],src.data[i+1],src.data[i+2],a); }}
function fillBg(p,r,g,b){ for(let y=0;y<p.height;y++)for(let x=0;x<p.width;x++){const i=(y*p.width+x)<<2;p.data[i]=r;p.data[i+1]=g;p.data[i+2]=b;p.data[i+3]=255;} }
// 5x7 미니 텍스트(라벨용) — 최소 글리프
const FONT={ 'B':[0x1E,0x12,0x1E,0x12,0x1E],'E':[0x1F,0x10,0x1E,0x10,0x1F],'F':[0x1F,0x10,0x1E,0x10,0x10],
 'O':[0x0E,0x11,0x11,0x11,0x0E],'R':[0x1E,0x11,0x1E,0x14,0x12],'A':[0x0E,0x11,0x1F,0x11,0x11],
 'T':[0x1F,0x04,0x04,0x04,0x04],'N':[0x11,0x19,0x15,0x13,0x11],'W':[0x11,0x11,0x15,0x1B,0x11],
 'C':[0x0E,0x11,0x10,0x11,0x0E],'G':[0x0E,0x10,0x17,0x11,0x0E],'S':[0x0F,0x10,0x0E,0x01,0x1E],
 'U':[0x11,0x11,0x11,0x11,0x0E],'L':[0x10,0x10,0x10,0x10,0x1F],'P':[0x1E,0x11,0x1E,0x10,0x10],
 'D':[0x1E,0x11,0x11,0x11,0x1E],'I':[0x1F,0x04,0x04,0x04,0x1F],'M':[0x11,0x1B,0x15,0x11,0x11],
 'H':[0x11,0x11,0x1F,0x11,0x11],'V':[0x11,0x11,0x11,0x0A,0x04],'Y':[0x11,0x0A,0x04,0x04,0x04],
 ' ':[0,0,0,0,0],'|':[0x04,0x04,0x04,0x04,0x04],'>':[0x08,0x04,0x02,0x04,0x08] };
function text(p,s,x,y,r,g,b){ let cx=x; for(const ch of s.toUpperCase()){const gl=FONT[ch]||FONT[' '];
  for(let ry=0;ry<5;ry++)for(let rx=0;rx<5;rx++)if(gl[ry]&(1<<(4-rx)))setpx(p,cx+rx,y+ry,r,g,b,255); cx+=6; }}

// ── 샘플 정의: [기존 오브젝트, 신규 샘플, 라벨, 바닥타일] ──
const SAMPLES = [
  { old:`${OBJ}/cauldron.png`,          neo:`${NEW}/cauldron.png`,        label:'CAULDRON', tile:`${TILES}/t2a_grass.png` },
  { old:`${OBJ}/l2_gen_sub.png`,        neo:`${NEW}/l2_gen_sub.png`,      label:'GEN SUB',  tile:`${TILES}/l2_metal.png` },
  { old:`${OBJ}/l3_gear_assembly.png`,  neo:`${NEW}/l3_gear_assembly.png`,label:'GEAR',     tile:`${TILES}/l3_brass.png` },
  { old:`${OBJ}/l4_rune_pillars.png`,   neo:`${NEW}/l4_rune_pillar.png`,  label:'RUNE',     tile:`${TILES}/l4_amethyst.png` },
  { old:`${OBJ}/l5_petrified_standing.png`, neo:`${NEW}/l5_statue.png`,   label:'STATUE',   tile:`${TILES}/l5_ivory.png` },
];

// =========================================================================
// (a) BEFORE / AFTER 스트립
// =========================================================================
(function beforeAfter(){
  const CELL_W=140, CELL_H=150, PAD=14, LABEL_H=20;
  const cols=SAMPLES.length;
  const W = cols*CELL_W + PAD*(cols+1);
  const H = LABEL_H + CELL_H*2 + PAD*3 + 14;
  const p = newPng(W,H);
  fillBg(p, 0x1a,0x1a,0x22); // 다크 검수 배경
  // 헤더 행 라벨
  for(let c=0;c<cols;c++){
    const cx = PAD + c*(CELL_W+PAD);
    text(p, SAMPLES[c].label, cx + (CELL_W - SAMPLES[c].label.length*6)/2, 6, 0xe8,0xdf,0xc8);
  }
  // 좌측 행 라벨(세로 대신 상단 라벨 옆)
  text(p,'BEFORE', 4, LABEL_H+6, 0x9a,0x6a,0x6a);
  text(p,'AFTER',  4, LABEL_H+PAD+CELL_H+6, 0x7a,0xb5,0x67);
  for(let c=0;c<cols;c++){
    const s=SAMPLES[c];
    const cx = PAD + c*(CELL_W+PAD);
    const oldImg=load(s.old), neoImg=load(s.neo);
    // BEFORE 셀
    const by0 = LABEL_H;
    // 셀 배경(살짝 밝은 패널)
    for(let y=by0;y<by0+CELL_H;y++)for(let x=cx;x<cx+CELL_W;x++){const i=(y*W+x)<<2;p.data[i]=0x24;p.data[i+1]=0x24;p.data[i+2]=0x2e;p.data[i+3]=255;}
    if(oldImg) blit(p, oldImg, cx+(CELL_W-oldImg.width)/2, by0+(CELL_H-oldImg.height)/2);
    // AFTER 셀
    const ay0 = LABEL_H + CELL_H + PAD;
    for(let y=ay0;y<ay0+CELL_H;y++)for(let x=cx;x<cx+CELL_W;x++){const i=(y*W+x)<<2;p.data[i]=0x22;p.data[i+1]=0x2a;p.data[i+2]=0x24;p.data[i+3]=255;}
    if(neoImg) blit(p, neoImg, cx+(CELL_W-neoImg.width)/2, ay0+(CELL_H-neoImg.height)/2);
  }
  fs.writeFileSync(OUT_BA, PNG.sync.write(p));
  console.log('wrote', OUT_BA, W+'x'+H);
})();

// =========================================================================
// (b) IN CONTEXT — 실제 아이소 바닥 타일 위 배치 목업
//   각 샘플을 해당 레이어 바닥 타일 3x3 패치 위에, origin=바닥 셀 중심에 접지.
// =========================================================================
(function inContext(){
  const TW=128, TH=64, HW=64, HH=32; // 2:1 다이아
  const N = SAMPLES.length;
  const PATCH = 3; // 3x3 타일 패치
  // 패치 하나의 화면 크기: iso 3x3 → 가로 3*HW*2 대략, 세로 3*HH*2
  const patchW = (PATCH+PATCH)*HW;        // ~ 384
  const patchH = (PATCH+PATCH)*HH + 96;   // 오브젝트 세로 여유
  const GAP=24;
  const W = N*(patchW+GAP) - GAP + 40;
  const H = patchH + 60;
  const p = newPng(W,H);
  fillBg(p, 0x12,0x12,0x18);
  for(let s=0;s<N;s++){
    const smp=SAMPLES[s];
    const tile=load(smp.tile);
    const neo=load(smp.neo);
    const ox = 20 + s*(patchW+GAP) + patchW/2; // 이 패치의 화면 중심 x
    const oyBase = 70; // 패치 상단
    // 3x3 아이소 타일 블릿 (뒤→앞 순서: row+col 큰 게 앞)
    // 셀(r,c) 다이아 중심 screen 좌표
    function cellCenter(r,c){ return { x: ox + (c-r)*HW, y: oyBase + (c+r)*HH + HH }; }
    for(let r=0;r<PATCH;r++)for(let c=0;c<PATCH;c++){
      const cc=cellCenter(r,c);
      if(tile) blit(p, tile, cc.x - TW/2, cc.y - TH/2 - (tile.height-TH)); // 타일 하단정렬
      else { // 타일 없으면 다이아 컬러 채움
        for(let y=-HH;y<HH;y++)for(let x=-HW;x<HW;x++){const d=Math.abs(x)/HW+Math.abs(y)/HH;if(d<=1)setpx(p,cc.x+x,cc.y+y,0x3a,0x3a,0x44,255);}
      }
    }
    // 오브젝트를 중앙 셀(1,1) 중심에 접지 — 스프라이트 origin=하단중앙
    const center=cellCenter(1,1);
    if(neo){ blit(p, neo, center.x - neo.width/2, center.y - neo.height + 8); }
    // 라벨
    text(p, smp.label, ox - smp.label.length*3, 40, 0xe8,0xdf,0xc8);
  }
  fs.writeFileSync(OUT_IC, PNG.sync.write(p));
  console.log('wrote', OUT_IC, W+'x'+H);
})();
