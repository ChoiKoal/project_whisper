'use strict';
// tools_gen_iso_samples.js — v1.2.0 아트 정합 게이트 1 · 아이소 오브젝트 문법 샘플 5종.
// 기존 오브젝트가 정면뷰("종이 팻말")라 2:1 아이소 바닥과 원근 충돌하는 문제를 교정.
// 문법: docs/project-whisper-iso-object-grammar.md — 3/4 아이소 박스/실린더(윗면 마름모||바닥 다이아),
// 우상단 광원 3톤 셰이딩(art-style-guide §2 STRICT), selout 아웃라인, 타원 접지 그림자.
// 팔레트는 각 레이어 기존 램프 그대로(신규 색 없음 — 뷰만 교정).
// 게임 미적용: assets/samples_iso/ 격리 폴더로만 출력 (오너 검수용).
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_iso_samples.js
const zlib = require('zlib'), fs = require('fs'), path = require('path');
const OUT = path.join(__dirname, 'assets', 'samples_iso');
fs.mkdirSync(OUT, { recursive: true });

// ---- PNG encode + canvas primitives (L3 오브젝트 제너레이터와 동일 API) ----
function crc32(b){let c=~0;for(let i=0;i<b.length;i++){c^=b[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t,'ascii');const body=Buffer.concat([tb,d]);const cr=Buffer.alloc(4);cr.writeUInt32BE(crc32(body),0);return Buffer.concat([l,body,cr]);}
function enc(w,h,px){const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;const st=w*4;const raw=Buffer.alloc((st+1)*h);for(let y=0;y<h;y++){raw[y*(st+1)]=0;px.copy(raw,y*(st+1)+1,y*st,y*st+st);}return Buffer.concat([sig,chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
function C(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hex(s){s=s.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function px(cv,x,y,rgb,a=255){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;if(a>=255){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=255;return;}if(a<=0)return;const af=a/255,ia=1-af;if(cv.data[i+3]===0){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function rect(cv,x0,y0,x1,y1,rgb,a=255){for(let y=Math.round(y0);y<Math.round(y1);y++)for(let x=Math.round(x0);x<Math.round(x1);x++)px(cv,x,y,rgb,a);}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function save(cv,name){fs.writeFileSync(path.join(OUT,name),enc(cv.w,cv.h,cv.data));console.log('wrote',name,cv.w+'x'+cv.h);}
function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}
// 접지 그림자 — 바닥 라인의 소프트 아이소 타원 (검정 블롭). rx:ry ~ 3.5:1
function ao(cv,cx,gy,rx,ry,strength=64){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const dx=x/rx,dy=y/ry;const d=dx*dx+dy*dy;if(d<=1.0)px(cv,cx+x,gy+y,[0,0,0],Math.round((1-d)*strength));}}
function glow(cv,cx,cy,r,col,peak=120){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1.0)px(cv,cx+x,cy+y,col,Math.round((1-d)*(1-d)*peak));}}

// ── 문법 헬퍼 ──────────────────────────────────────────────────────────────
// 광원 우상단(NE): 윗면 최명, 우측면(광원측) 중간~밝음, 좌측면(그늘측) 최암.
// darker(c,steps): selout 아웃라인용 — 2단계 어두운 동일 계열.
function darker(c,t){return mix(c,[0,0,0],t);}

// 아이소 윗면 마름모 채우기 — 중심(cx,cy), 반경(rx). 바닥과 평행하도록 ry=rx/2 (2:1).
// 마름모 위/아래로 조금 밝기 그라데이션(top face는 균일하게 최명이되 뒤쪽 살짝 어둡게).
function topDiamond(cv,cx,cy,rx,col,a=255){const ry=rx/2;for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=Math.abs(x)/rx+Math.abs(y)/ry;if(d<=1.0){const shade=mix(col,darker(col,0.12),(y+ry)/(2*ry)*0.5);px(cv,cx+x,cy+y,shade,a);}}}
// 마름모 윗면의 아웃라인(selout) 그리기
function diamondOutline(cv,cx,cy,rx,ol){const ry=rx/2;for(let t=0;t<=rx;t++){const yy=ry*(1-t/rx);px(cv,cx-t,cy-yy,ol);px(cv,cx+t,cy-yy,ol);px(cv,cx-t,cy+yy,ol);px(cv,cx+t,cy+yy,ol);}}

// 아이소 박스 그리기: 윗면 마름모(cx,topY,rx) + 좌/우 측벽 높이 h.
// faceTop/faceR(광원측·오른쪽)/faceL(그늘측·왼쪽) 색 지정.
function isoBox(cv,cx,topY,rx,h,cTop,cR,cL){
  const ry=rx/2;
  const ol=darker(cR,0.55);
  // 측벽: 마름모의 좌하변(→왼면)과 우하변(→오른면)에서 h만큼 아래로 extrude
  // 각 x열에서 윗면 하단 가장자리 y를 구해 그 아래로 수직 채움
  for(let x=-rx;x<=rx;x++){
    const edgeY = topY + (ry - Math.abs(x)*ry/rx); // 마름모 아래쪽 가장자리
    const face = x<=0 ? cL : cR;
    for(let y=0;y<h;y++){
      // 세로 그라데이션: 위쪽 살짝 밝게(윗면 접점), 아래로 어둡게
      const t=y/h;
      const c=mix(face,darker(face,0.30),t*0.5);
      px(cv,cx+x,edgeY+y,c,255);
    }
    // 측벽 상단 rim (윗면과 만나는 밝은 1px) — 오른면만 광원 rim
    if(x>0) px(cv,cx+x,edgeY,mix(cR,[255,255,255],0.18),200);
  }
  // 좌/우 면 경계 세로선(정면 모서리)
  for(let y=0;y<h;y++)px(cv,cx,topY+ry+y,darker(cR,0.4),200);
  // 밑변 아웃라인 (selout)
  for(let x=-rx;x<=rx;x++){const edgeY=topY+(ry-Math.abs(x)*ry/rx)+h;px(cv,cx+x,edgeY,ol);}
  // 윗면
  topDiamond(cv,cx,topY,rx,cTop);
  diamondOutline(cv,cx,topY,rx,darker(cTop,0.5));
  // 좌우 최외곽 세로 아웃라인
  for(let y=0;y<h;y++){px(cv,cx-rx,topY+y,ol);px(cv,cx+rx,topY+y,ol);}
}

// 아이소 실린더: 윗면 타원(rx:ry=2:1) + 수직 벽. 왼/오 톤 분리.
function isoCylinder(cv,cx,topY,rx,h,cTop,cR,cL,botTaper=1.0){
  const ry=rx/2;const ol=darker(cR,0.55);
  for(let x=-rx;x<=rx;x++){
    const xr=x/rx; if(xr*xr>1)continue;
    const edgeY=topY+ry*Math.sqrt(1-xr*xr); // 앞쪽 타원 가장자리
    // botTaper<1 이면 아래로 갈수록 좁아짐(솥 배)
    const face = x<=0 ? cL : cR;
    const rim = mix(face,[255,255,255],0.15);
    for(let y=0;y<h;y++){
      const t=y/h;
      const c=mix(face,darker(face,0.34),t*0.55);
      // 배불뚝 실루엣: 가장자리쪽 아래는 살짝 안으로 (테이퍼)
      const inset = Math.round((1-botTaper)*rx*(t)*(Math.abs(xr)));
      const xx = cx + x + (x<0?inset:-inset);
      px(cv,xx,edgeY+y,c,255);
      if(y===0 && x>0)px(cv,xx,edgeY+y,rim,200);
    }
  }
  // 밑변 아웃라인
  for(let x=-rx;x<=rx;x++){const xr=x/rx;if(xr*xr>1)continue;const inset=Math.round((1-botTaper)*rx*Math.abs(xr));const edgeY=topY+ry*Math.sqrt(1-xr*xr)+h;const xx=cx+x+(x<0?inset:-inset);px(cv,xx,edgeY,ol);}
  // 윗면 타원
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=(x/rx)**2+(y/ry)**2;if(d<=1){const shade=mix(cTop,darker(cTop,0.14),(y+ry)/(2*ry)*0.5);px(cv,cx+x,topY+y,shade,255);}}
  // 윗면 아웃라인
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*rx,y=Math.sin(a*Math.PI/180)*ry;px(cv,cx+x,topY+y,darker(cTop,0.5));}
}

// ===========================================================================
// SAMPLE 1 — 솥단지 (cauldron). 게임 아이덴티티. 실린더+테두리 립+김.
// 팔레트: art-guide §7 — dark #2a2a33 base, violet #9e7ad9 brew, cream #faf5e6.
// ===========================================================================
(function cauldron(){const W=128,H=128,cv=C(W,H);
  const cx=64;
  const bodyD=hex('#2a2a33'), bodyL=hex('#3d3d4a'), bodyDk=hex('#20202a');
  const rimD=hex('#4a4a5a'), rimL=hex('#5c5c70');
  const brew=hex('#6b4a9e'), brewL=hex('#8a5ac8'), glowV=hex('#9e7ad9'), glowB=hex('#c8a8ec'), cream=hex('#faf5e6');
  ao(cv,cx,116,40,11,58);
  // 배불뚝 실린더 몸통: 윗면(테두리 립 아래로 열린 입) topY=56, rx=40, 벽높이 46, 테이퍼
  const topY=54, rx=40, h=44;
  // 몸통 벽(윗면은 나중에 브루로 덮음): 우측 광원면 밝게, 좌측 그늘 어둡게
  isoCylinder(cv,cx,topY,rx,h,bodyD,bodyL,bodyDk,0.72);
  // 테두리 립(rim lip): 몸통 상단 테두리를 한 겹 밝은 링으로 (윗면 타원보다 살짝 큰 링)
  const ry=rx/2;
  for(let a=0;a<360;a+=1.5){const x=Math.cos(a*Math.PI/180),y=Math.sin(a*Math.PI/180);
    const lit = x>0? rimL: rimD; // 오른쪽(광원) 밝게
    px(cv,cx+x*rx,topY+y*ry,lit,255);
    px(cv,cx+x*(rx-2),topY+y*(ry-1),lit,235);
    if(y<0)px(cv,cx+x*rx,topY+y*ry-1,mix(lit,[255,255,255],0.2),200);}
  // 브루(보라 마름모 표면) — 립 안쪽 타원
  const mrx=rx-6, mry=mrx/2;
  for(let y=-mry;y<=mry;y++)for(let x=-mrx;x<=mrx;x++){const d=(x/mrx)**2+(y/mry)**2;if(d<=1){
    const c=(((x>>2)+(y>>1))%2===0)?brew:mix(brew,glowV,0.5);px(cv,cx+x,topY+y,c,255);}}
  // 브루 발광 링
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*(mrx-1),y=Math.sin(a*Math.PI/180)*(mry-1);px(cv,cx+x,topY+y,glowB,220);}
  glow(cv,cx,topY,mrx-4,glowV,70);
  // 발 3개 (아이소 배치: 앞-좌, 앞-우, 뒤 살짝)
  for(const [fx,fy,fw] of [[cx-22,110,7],[cx+22,110,7],[cx,116,6]]){rect(cv,fx-fw/2,fy,fx+fw/2,fy+8,bodyDk);rect(cv,fx-fw/2,fy,fx+fw/2-1,fy+2,bodyD);}
  // 김(steam) — 위로 오르는 보라빛 김
  const r=deterministic(11);for(let n=0;n<20;n++){const t=n/20;const x=cx+Math.round(Math.sin(t*6+r())*8)+(r()<0.5?-5:5);const y=topY-6-Math.floor(t*38);px(cv,x,y,mix(cream,glowV,0.4),Math.round(90*(1-t)));}
  // 위스퍼 반짝임
  px(cv,cx-4,topY-4,cream,220);px(cv,cx+8,topY-8,cream,180);
  save(cv,'cauldron.png');})();

// ===========================================================================
// SAMPLE 2 — 발전기 (L2 gen_sub). 박스 + 파이프 + 시안 패널.
// 팔레트 L2: navy #1a2438, steel MHI/MMID/MSH, cyan #4ad9c8, panel #141a26.
// ===========================================================================
(function genSub(){const W=96,H=120,cv=C(W,H);
  const cx=48;
  const NAVY=hex('#1a2438'), MHI=hex('#5a6472'), MMID=hex('#3a4452'), MSH=hex('#222a38'),
        CYAN=hex('#4ad9c8'), DKPANEL=hex('#141a26');
  ao(cv,cx,108,30,8,64);
  // 본체 아이소 박스: 윗면(cx, topY=44, rx=30), 벽높이 52
  const topY=42, rx=30, h=52;
  isoBox(cv,cx,topY,rx,h,MMID,mix(MMID,MHI,0.5),MSH);
  const ry=rx/2;
  // 윗면에 환기 그릴(냉각 슬릿) — 마름모 각도 평행선
  for(let i=-3;i<=3;i++){const off=i*5;for(let t=-rx+Math.abs(off)*2;t<=rx-Math.abs(off)*2;t+=1){const x=t;const y=off/2 - x*0.5; if(Math.abs(x)/rx+Math.abs(y+off? y:0)/ry<=1){}}}
  // 간단·확실하게: 윗면 마름모 위에 평행 슬릿 3줄 (기울기 -0.5)
  for(const off of [-8,0,8]){for(let x=-rx+12;x<=rx-12;x++){const y=off - x*0.5; if(Math.abs(x)/rx+Math.abs(y)/ry<=0.86)px(cv,cx+x,topY+y,darker(MMID,0.35),200);}}
  // 우측 광원면에 시안 패널(발전 상태 창)
  const px0=cx+8, py0=topY+ry+14;
  for(let y=0;y<18;y++)for(let x=0;x<16;x++){const ex=px0+x, ey=py0+y+ (x)*0.5; px(cv,ex,ey,DKPANEL,255);}
  // 패널 시안 라이트 바
  for(let i=0;i<3;i++){for(let x=0;x<12;x++){const ex=px0+2+x, ey=py0+3+i*5 + (2+x)*0.5; px(cv,ex,ey,CYAN,220);}}
  glow(cv,px0+8,py0+9,10,CYAN,70);
  // 좌측 그늘면 리벳 밴드
  for(let ry2=0;ry2<3;ry2++){for(let x=-rx+4;x<-2;x+=6){const ex=cx+x, ey=topY+ry+8+ry2*14 - x*0.5*0 + (-x)*0.5; px(cv,ex,ey,MHI,180);}}
  // 상단 파이프(윗면에서 솟은 배기관) — 아이소 실린더 소형
  isoCylinder(cv,cx-2,topY-14,7,14,mix(MHI,CYAN,0.1),mix(MMID,MHI,0.4),MSH,1.0);
  px(cv,cx-2,topY-14,mix(CYAN,[255,255,255],0.3),200);
  save(cv,'l2_gen_sub.png');})();

// ===========================================================================
// SAMPLE 3 — 톱니 조립대 (L3 gear_assembly). 스크린샷 최악. 기어 윗면이 보이는 작업대.
// 팔레트 L3: copper #3a2c1e, brass B_HI/B_MID/B_SH, orange #ff9a3c.
// 핵심 교정: 정면 원판 기어 → 작업대 박스 위에 "누워있는(윗면이 보이는)" 기어.
// ===========================================================================
(function gearAssembly(){const W=96,H=96,cv=C(W,H);
  const cx=48;
  const COPPER=hex('#3a2c1e'), B_HI=hex('#c8a24a'), B_MID=hex('#8a6a34'), B_SH=hex('#4a3820'),
        ORANGE=hex('#ff9a3c'), DEEP=hex('#1a1208');
  ao(cv,cx,86,26,7,66);
  // 작업대(스탠드) 아이소 박스: 윗면 topY=52, rx=26, 높이 26
  const topY=50, rx=26, h=26;
  isoBox(cv,cx,topY,rx,h,mix(COPPER,B_MID,0.5),mix(B_MID,B_HI,0.35),B_SH);
  const ry=rx/2;
  // 작업대 윗면에 리벳 테두리
  for(let a=0;a<360;a+=45){const x=Math.cos(a*Math.PI/180)*(rx-4),y=Math.sin(a*Math.PI/180)*(ry-2);px(cv,cx+x,topY+y,B_HI,200);}
  // === 기어: 작업대 위에 "누워서" 윗면(마름모 원근)이 보이게 → 2:1 타원 기어 ===
  const gx=cx, gy=topY-2, grx=19, gry=grx/2, teeth=10;
  // 톱니 (타원 궤도, 2:1) — 각 톱니를 사다리꼴 블록으로 확실히 돌출
  for(let ti=0;ti<teeth;ti++){const a=(ti/teeth)*360;const rad=a*Math.PI/180;
    const lit=(Math.sin(rad)<0?0.45:0)+(Math.cos(rad)>0?0.3:0);const tc=mix(B_MID,B_HI,lit);
    for(let d=0;d<5;d++){const rr=grx+d; // 바깥으로 뻗는 톱니
      for(let w=-1;w<=1;w++){const wa=rad+w*0.11;px(cv,gx+Math.cos(wa)*rr, gy+Math.sin(wa)*(rr*0.5),tc,235);}}}
  // 기어 디스크 윗면 (타원 채움 + 방사 셰이딩)
  for(let y=-gry;y<=gry;y++)for(let x=-grx;x<=grx;x++){const d=(x/grx)**2+(y/gry)**2;if(d<=1){
    const lit=(y<0?0.32:0)+(x>0?0.22:0);const c=mix(mix(COPPER,B_MID,0.6),B_HI,lit);px(cv,gx+x,gy+y,c,235);}}
  // 기어 살(spoke) — 두께감 위해 안쪽 어두운 링
  for(let a=0;a<360;a+=60){for(let i=6;i<grx-3;i++){px(cv,gx+Math.cos(a*Math.PI/180)*i, gy+Math.sin(a*Math.PI/180)*i*0.5, B_SH,150);}}
  // 허브 구멍(어두운 소켓) — 여기 축이 박힘
  for(let y=-4;y<=4;y++)for(let x=-7;x<=7;x++){const d=(x/7)**2+(y/4)**2;if(d<=1)px(cv,gx+x,gy+y,DEEP,235);}
  // 기어 윗면 아웃라인 selout
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*grx,y=Math.sin(a*Math.PI/180)*gry;px(cv,gx+x,gy+y,darker(B_MID,0.5),200);}
  // 회전 축 글린트(우상단)
  glow(cv,gx+8,gy-4,6,ORANGE,90);px(cv,gx+8,gy-4,hex('#fff0d0'),230);
  save(cv,'l3_gear_assembly.png');})();

// ===========================================================================
// SAMPLE 4 — 룬 기둥 (L4). 팔각/원기둥 + 금 룬.
// 팔레트 L4: amethyst AME/P_HI/P_MID/P_SH, gold #f2c14e, stone #5a4a6a.
// 교정: 곧게 선 정면 원기둥 → 윗면(타원 캡)이 보이는 아이소 실린더 + 좌우 톤 분리.
// ===========================================================================
(function runePillar(){const W=96,H=128,cv=C(W,H);
  const cx=48;
  const AME=hex('#2a1f3d'), P_HI=hex('#7a5cae'), P_MID=hex('#4a3670'), P_SH=hex('#221830'),
        GOLD=hex('#f2c14e'), GOLD_DK=hex('#c99a34'), STONE=hex('#5a4a6a');
  ao(cv,cx,116,22,6,64);
  // 받침 아이소 박스 (넓은 base)
  isoBox(cv,cx,92,24,14,mix(STONE,P_HI,0.2),mix(STONE,P_MID,0.4),P_SH);
  // 기둥 본체 아이소 실린더: 윗면 topY=30, rx=17, 높이 72
  const topY=30, rx=17, h=64;
  isoCylinder(cv,cx,topY,rx,h,mix(STONE,P_HI,0.3),mix(P_MID,P_HI,0.45),P_SH,0.94);
  const ry=rx/2;
  // 세로 금 룬 띠 (기둥 정면 광원측·중앙에 세로로) — 3톤 유지 위해 광원면만 밝은 금
  const runes=['#','X','=','o'];
  for(let i=0;i<4;i++){const ry0=topY+ry+8+i*15;
    // 룬은 실린더 곡률 따라 살짝 좌우로 — 중앙 밴드
    for(let dx=-6;dx<=6;dx++){const shade = dx>0? GOLD: GOLD_DK; // 우측 광원 밝게
      px(cv,cx+dx,ry0,shade,230);px(cv,cx+dx,ry0+1,GOLD_DK,200);}
    // 룬 글자 느낌의 노치
    px(cv,cx-3,ry0,mix(GOLD,[255,255,255],0.3),240);px(cv,cx+3,ry0,mix(GOLD,[255,255,255],0.3),240);
    glow(cv,cx,ry0,7,GOLD,45);}
  // 기둥 상단 금 캡 링 (윗면 테두리)
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180),y=Math.sin(a*Math.PI/180);const lit=x>0?GOLD:GOLD_DK;px(cv,cx+x*rx,topY+y*ry,lit,235);}
  // 윗면 룬 문양 (마름모/타원 각도 평행)
  for(let a=0;a<360;a+=90){px(cv,cx+Math.cos(a*Math.PI/180)*8, topY+Math.sin(a*Math.PI/180)*4, GOLD,220);}
  px(cv,cx,topY,mix(GOLD,[255,255,255],0.3),240);glow(cv,cx,topY,9,GOLD,60);
  save(cv,'l4_rune_pillar.png');})();

// ===========================================================================
// SAMPLE 5 — 석화 피조물 (L5 statue). 유기형이지만 접지·광원 통일 (문법 §7).
// 팔레트 L5: ivory IV/I_HI/I_MID/I_SH, silver SIL, amber #e0a94a, stone #b7b0a2.
// 유기형은 박스 불가 → 실루엣 유지 + 접지 마름모 풋프린트 + 우상단 3톤 + selout.
// ===========================================================================
(function statue(){const W=96,H=128,cv=C(W,H);
  const cx=48;
  const IV=hex('#e6e0d4'), I_HI=hex('#f2eee4'), I_MID=hex('#9a9385'), I_SH=hex('#6b6459'),
        STONE=hex('#b7b0a2'), AMBER=hex('#e0a94a'), DEEP=hex('#141119');
  ao(cv,cx,118,24,7,68);
  // 접지 받침 — 아이소 마름모 대좌 (원근 각도 부여)
  const topY=100, rx=24, ry=rx/2;
  isoBox(cv,cx,topY,rx,10,mix(STONE,I_HI,0.15),mix(STONE,I_MID,0.3),I_SH);
  // 석화된 피조물(고양이형 실루엣) — 정면감 빼고 약간 뒤로 기운 3/4 자세.
  // 몸통: 아래 넓고 위로 좁아지는 유기 실루엣, 광원 우상단 3톤
  function organ(x0,y0,x1,y1,wtop,wbot){ // 테이퍼진 유기 세로 덩어리
    for(let y=y0;y<y1;y++){const t=(y-y0)/(y1-y0);const w=wtop+(wbot-wtop)*t;const cxx=x0+(x1-x0)*t;
      for(let x=-w;x<=w;x++){const lit=(x>0?0.28:0)+ (0.1);const c = x < -w*0.4 ? I_SH : mix(STONE, x>w*0.2? I_HI:IV, lit);
        px(cv,cx+cxx+x,y,c,255);}
      // 우측 rim 하이라이트
      px(cv,cx+cxx+w,y,mix(I_HI,[255,255,255],0.2),200);
      // 좌측(그늘) 아웃라인 selout
      px(cv,cx+cxx-w,y,darker(I_MID,0.4),220);}}
  // 몸통(앉은 자세): 하부 넓게
  organ(0,58,-2,100,10,20);
  // 가슴/앞다리
  for(let y=78;y<100;y++){const w=6+(y-78)*0.3;for(let x=-w;x<=w;x++){const c=x>0?mix(STONE,I_HI,0.25):mix(STONE,I_SH,0.3);px(cv,cx+2+x,y,c,255);}}
  // 머리 (둥근 고양이 머리, 살짝 숙임+뒤로)
  const hx=cx-2, hy=48;
  for(let y=-14;y<=12;y++)for(let x=-13;x<=13;x++){const d=(x/13)**2+(y/14)**2;if(d<=1){
    const lit=(x>0?0.3:0)+(y<0?0.15:0);const c=mix(STONE,I_HI,lit);px(cv,hx+x,hy+y,x<-9?I_SH:c,255);}}
  // 귀 2개 (아이소 각도로 살짝 벌어짐)
  for(const [ex,dir] of [[-9,-1],[8,1]]){for(let i=0;i<10;i++){const w=5-i*0.5;for(let x=-w;x<=w;x++)px(cv,hx+ex+x+dir*i*0.2,hy-13-i,dir>0?mix(STONE,I_HI,0.25):mix(STONE,I_SH,0.2),255);}}
  // 눈 — 석화되어 흐릿한 호박빛 잔광 (아이덴티티: 원래 보라지만 L5 석화는 호박)
  glow(cv,hx-4,hy-1,4,AMBER,120);glow(cv,hx+5,hy-1,4,AMBER,120);
  px(cv,hx-4,hy-1,mix(AMBER,[255,255,255],0.4),220);px(cv,hx+5,hy-1,mix(AMBER,[255,255,255],0.4),220);
  // 석화 균열(crack) 몇 줄 — 몸통에 어두운 실선
  const r=deterministic(505);for(let n=0;n<5;n++){let sx=cx-6+Math.floor(r()*14),sy=64+Math.floor(r()*30);for(let k=0;k<8;k++){px(cv,sx,sy,I_SH,180);sx+=r()<0.5?1:-1;sy+=1;}}
  // 꼬리 (뒤로 감긴 유기 곡선)
  const pts=[[14,92],[22,86],[26,76],[22,68]];for(let s=0;s<pts.length-1;s++){const[x0,y0]=pts[s],[x1,y1]=pts[s+1];for(let t=0;t<=1;t+=0.05){const x=x0+(x1-x0)*t,y=y0+(y1-y0)*t;for(let w=-3;w<=3;w++)px(cv,cx+x+w,y,w>0?mix(STONE,I_HI,0.2):mix(STONE,I_SH,0.25),255);}}
  save(cv,'l5_statue.png');})();

console.log('iso samples done →', OUT);
