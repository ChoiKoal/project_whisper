'use strict';
// tools_gen_home_deco.js — v1.10.0 L0 허브 확장 데코 아트.
// 세계층 방향성 소품(각 포탈 앞 층별 상징) + 프로시저럴 밀도 스캐터(빛 웅덩이·비석/잔해).
// 문법 정본: tools_iso_lib.js(3/4 아이소, 광원 NE, selout, 접지 그림자) + 홈 팔레트.
// 홈 팔레트 = 바렌 돌/보라 트와일라잇(신규 색 없음, 기존 램프 재사용). 전부 128×128,
// bottom-center 접지 → 컴포지터/씬 코드 무변경. 비-블로킹·비-채집 순수 장식.
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_home_deco.js
const path = require('path');
const L = require('./tools_iso_lib.js');
const { C, hex, px, rect, mix, darker, lighter, glow, ao, isoBox, topDiamond,
        diamondOutline, isoEllipseTop, deterministic } = L;
const save = L.saver(path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects'));

// 홈 램프 — 바렌 돌(회갈), 보라 룬/글로우, 죽은 이끼(올리브탄). 전부 저채도(§㉛ 목표물 대비:
// 게이트/제단 실루엣을 흐리지 않도록 데코는 낮고 어둡게).
const ROCK = hex('#6f6a63'), ROCK_L = hex('#8a857c'), ROCK_D = hex('#4a453f'), ROCK_DK = hex('#332f2b');
const RUNE = hex('#9e7ad9'), RUNE_B = hex('#c8a8ec'), RUNE_D = hex('#6b4a9e');
const MOSS = hex('#5c6b3a'), MOSS_L = hex('#7d8a4e'), SPROUT = hex('#8fae5a');
const BRASS = hex('#8a6a3a'), BRASS_L = hex('#b08a4a'), BRASS_D = hex('#5a4526');
const cx = 64, baseY = 112;  // bottom-center 접지 기준선

function newcv(){ return C(128,128); }

// 작은 돌 받침(비석/소품 공통 기단) — 낮은 아이소 돌덩이.
function pedestal(cv, y, rx, h){
  isoBox(cv, cx, y, rx, h, ROCK, ROCK, ROCK_D);
}

// ── p: 자연(잎) — 이끼 낀 돌 + 새싹 ─────────────────────────────────────────
function leaf(){
  const cv=newcv(); ao(cv,cx,baseY+4,30,9,60);
  // 낮은 이끼 바위
  const y=baseY-14;
  for(let s=0;s<14;s++){ const t=s/14; const rr=26*(1-0.5*t);
    for(let x=-rr;x<=rr;x++){ const xr=x/rr; const lit=Math.max(0,Math.min(1,0.5+xr*0.5));
      let c=mix(ROCK_D,ROCK_L,lit); c=mix(c,ROCK,0.2); c=mix(c,darker(c,0.3),t*0.4);
      px(cv,cx+x,y+s,c,255);} }
  // 이끼 캡(윗면)
  isoEllipseTop(cv,cx,y-1,24,MOSS,255,darker(MOSS,0.5));
  const r=deterministic(7);
  for(let n=0;n<40;n++){ const a=r()*Math.PI*2, rr=r()*22; const x=cx+Math.cos(a)*rr, yy=y-1+Math.sin(a)*rr*0.5;
    px(cv,x,yy,r()<0.5?MOSS_L:MOSS,200);}
  // 새싹 3가닥
  for(const [dx,hh] of [[-8,20],[2,26],[11,16]]){
    for(let i=0;i<hh;i++){ const t=i/hh; const x=cx+dx+Math.round(Math.sin(t*3)*2);
      px(cv,x,y-2-i,mix(SPROUT,MOSS_L,t),255);}
    // 잎 두 장
    px(cv,cx+dx-2,y-2-hh+3,SPROUT,255); px(cv,cx+dx+2,y-2-hh+5,SPROUT,255);
    px(cv,cx+dx-3,y-2-hh+4,darker(SPROUT,0.2),255); px(cv,cx+dx+3,y-2-hh+6,lighter(SPROUT,0.1),255);
  }
  save(cv,'home_deco_leaf.png');
}

// ── q: 과학(데이터) — 발광 룬 결정 ─────────────────────────────────────────
function data(){
  const cv=newcv(); ao(cv,cx,baseY+2,22,7,60);
  pedestal(cv, baseY-10, 18, 8);
  // 수직 결정(각진 크리스탈) — 룬 발광
  const topY=baseY-58, w=11;
  for(let y=0;y<48;y++){ const t=y/48; const rr=Math.round(w*(0.35+0.65*t));
    for(let x=-rr;x<=rr;x++){ const xr=x/rr; const lit=Math.max(0,Math.min(1,0.5+xr*0.6));
      let c=mix(RUNE_D,RUNE_B,lit); c=mix(c,RUNE,0.25);
      px(cv,cx+x,topY+y,c,235);}
    px(cv,cx-rr,topY+y,darker(RUNE_D,0.4)); px(cv,cx+rr,topY+y,darker(RUNE_D,0.4)); }
  // 룬 글리프(데이터 눈금)
  for(let i=0;i<5;i++){ const yy=topY+8+i*8; rect(cv,cx-3,yy,cx+4,yy+1,RUNE_B,220);
    px(cv,cx-1,yy-2,RUNE_B,180); px(cv,cx+2,yy+2,RUNE_B,180);}
  glow(cv,cx,topY+24,16,RUNE,60);
  px(cv,cx,topY-1,RUNE_B,240);
  save(cv,'home_deco_data.png');
}

// ── k: 기계(태엽) — 멈춘 톱니 비석 ─────────────────────────────────────────
function gear(){
  const cv=newcv(); ao(cv,cx,baseY+2,24,7,60);
  pedestal(cv, baseY-9, 20, 9);
  // 비스듬히 박힌 멈춘 톱니(정면 원판 + 이빨)
  const gy=baseY-34, R=20;
  for(let y=-R;y<=R;y++)for(let x=-R;x<=R;x++){ const d=Math.hypot(x,y)/R; if(d>1)continue;
    const lit=Math.max(0,Math.min(1,0.5+(x/R)*0.5));
    let c=mix(BRASS_D,BRASS_L,lit); c=mix(c,BRASS,0.2);
    px(cv,cx+x,gy+y,c,255);}
  // 톱니(이빨)
  for(let a=0;a<360;a+=30){ const rad=a*Math.PI/180; const x=cx+Math.cos(rad)*(R+3), y=gy+Math.sin(rad)*(R+3);
    rect(cv,x-2,y-2,x+2,y+2,BRASS,255); px(cv,x+1,y-1,BRASS_L,220);}
  // 중심 축 + 그림자(멈춤 = 어둡게)
  glow(cv,cx,gy,7,BRASS_D,90);
  for(let y=-4;y<=4;y++)for(let x=-4;x<=4;x++){ if(Math.hypot(x,y)<=4)px(cv,cx+x,gy+y,BRASS_D,255);}
  // 정지 룬(보라 한 점 — 태엽이 멈춘 세계)
  px(cv,cx,gy,RUNE_B,200);
  save(cv,'home_deco_gear.png');
}

// ── b: 마법(서고) — 부유하는 룬 서판 ───────────────────────────────────────
function tome(){
  const cv=newcv(); ao(cv,cx,baseY+4,20,6,50);
  // 낮은 받침 돌
  pedestal(cv, baseY-7, 14, 7);
  // 부유하는 석판(살짝 기울어 떠 있음) — 룬 각인
  const py=baseY-46, w=18, h=24;
  for(let y=0;y<h;y++)for(let x=-w;x<=w;x++){ const skew=Math.round((y-h/2)*0.15);
    const lit=Math.max(0,Math.min(1,0.5+(x/w)*0.4));
    let c=mix(ROCK_D,ROCK_L,lit); c=mix(c,ROCK,0.2);
    px(cv,cx+x+skew,py+y,c,240);}
  // 테두리 selout
  for(let y=0;y<h;y++){ const skew=Math.round((y-h/2)*0.15); px(cv,cx-w+skew,py+y,ROCK_DK); px(cv,cx+w+skew,py+y,ROCK_DK);}
  // 룬 글리프(보라 각인)
  const r=deterministic(13);
  for(let i=0;i<7;i++){ const gx=cx-10+ (i%3)*10, gy=py+4+Math.floor(i/3)*8;
    rect(cv,gx,gy,gx+6,gy+1,RUNE_B,220); px(cv,gx+2,gy-2,RUNE,200);}
  glow(cv,cx,py+h/2,18,RUNE,45);
  // 부유 파편 몇 점
  for(let n=0;n<4;n++){ const x=cx-14+r()*28, y=py-4-r()*8; px(cv,x,y,RUNE_B,180);}
  save(cv,'home_deco_tome.png');
}

// ── n: 신성(종) — 작은 석종 / 향로 ─────────────────────────────────────────
function bell(){
  const cv=newcv(); ao(cv,cx,baseY+3,22,7,60);
  pedestal(cv, baseY-9, 18, 8);
  // 종(사다리꼴 몸통 + 둥근 어깨)
  const topY=baseY-46, botY=baseY-16;
  for(let y=topY;y<=botY;y++){ const t=(y-topY)/(botY-topY); const rr=Math.round(6+12*t);
    for(let x=-rr;x<=rr;x++){ const xr=x/rr; const lit=Math.max(0,Math.min(1,0.5+xr*0.55));
      let c=mix(BRASS_D,BRASS_L,lit); c=mix(c,BRASS,0.2);
      px(cv,cx+x,y,c,255);}
    px(cv,cx-rr,y,darker(BRASS_D,0.4)); px(cv,cx+rr,y,darker(BRASS_D,0.4)); }
  // 종 어깨(둥근 캡)
  isoEllipseTop(cv,cx,topY,7,BRASS_L,255,darker(BRASS_D,0.4));
  // 걸이(작은 링)
  for(let a=0;a<360;a+=20){ const x=cx+Math.cos(a*Math.PI/180)*3, y=topY-4+Math.sin(a*Math.PI/180)*3; px(cv,x,y,BRASS_L,220);}
  // 종 입(어두운 개구부) + 추
  isoEllipseTop(cv,cx,botY,18,ROCK_DK,255);
  px(cv,cx,botY-2,BRASS_D,255); px(cv,cx,botY,BRASS_D,255);
  // 신성 룬 글로우(은은한 보라)
  glow(cv,cx,botY-10,16,RUNE,40);
  save(cv,'home_deco_bell.png');
}

// ── o: 빛 웅덩이(저대비) — 바닥 룬 사인 웅덩이 ─────────────────────────────
function pool(){
  const cv=newcv();
  // 바닥에 눕는 저대비 보라 웅덩이(아이소 타원). §㉚ 목적 있는 바닥 휴지 — 시선 유도.
  const py=baseY-2;
  for(let y=-14;y<=14;y++)for(let x=-42;x<=42;x++){ const d=(x/42)**2+(y/14)**2; if(d>1)continue;
    const a=Math.round((1-d)*(1-d)*70); px(cv,cx+x,py+y,mix(RUNE_D,RUNE,0.4),a);}
  // 얇은 룬 링
  for(let a=0;a<360;a+=3){ const x=cx+Math.cos(a*Math.PI/180)*30, y=py+Math.sin(a*Math.PI/180)*10; px(cv,x,y,RUNE_B,90);}
  glow(cv,cx,py,20,RUNE,45);
  save(cv,'home_deco_pool.png');
}

// ── x: 비석/잔해(변주 3종) — 낮은 돌무더기 (§㉙ 실루엣 변주) ────────────────
function rubble(name, seed){
  const cv=newcv(); ao(cv,cx,baseY+3,26,8,60);
  const r=deterministic(seed);
  // 3~5개 불규칙 낮은 돌덩이
  const nrocks=3+Math.floor(r()*3);
  for(let i=0;i<nrocks;i++){ const bx=cx-16+r()*32, by=baseY-4-r()*10, rw=6+r()*8, rh=5+r()*6;
    for(let y=-rh;y<=rh;y++)for(let x=-rw;x<=rw;x++){ const d=(x/rw)**2+(y/rh)**2; if(d>1)continue;
      const lit=Math.max(0,Math.min(1,0.5+(x/rw)*0.5)); let c=mix(ROCK_D,ROCK_L,lit); c=mix(c,ROCK,0.2);
      px(cv,bx+x,by+y,c,255);}
    // selout 밑동
    for(let x=-rw;x<=rw;x++)px(cv,bx+x,by+rh,ROCK_DK,200);
  }
  // 기울어진 비석(한 개) — 낮게
  if(seed%2===0){ const sx=cx+6, sy=baseY-6;
    for(let y=0;y<22;y++){ const skew=Math.round(y*0.2); rect(cv,sx-4+skew,sy-y,sx+4+skew,sy-y+1,mix(ROCK_D,ROCK,0.3),255);}
    px(cv,sx+4,sy-20,RUNE,180);
  }
  save(cv,name);
}

leaf(); data(); gear(); tome(); bell(); pool();
rubble('home_deco_rubble.png', 100);
rubble('home_deco_rubble_b.png', 101);
rubble('home_deco_rubble_c.png', 102);
console.log('home deco done.');
