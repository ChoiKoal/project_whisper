'use strict';
// tools_gen_home_objects.js — AP-2 홈/공용 오브젝트 아이소 재작업 (v1.2.0 아트 정합).
// 문법 정본: docs/project-whisper-iso-object-grammar.md + assets/samples_iso/cauldron.png.
// 공용 헬퍼: tools_iso_lib.js. 팔레트는 기존 램프 그대로(art-guide §7 cauldron 색) — 신규 색 없음.
//
// 대상: cauldron.png / cauldron_bubble.png — 게임 아이덴티티 조합 솥.
//   구(舊): 정면뷰 둥근 항아리(열린 입 타원+평면 앞면) → 2:1 바닥과 원근 충돌.
//   신(新): 3/4 아이소 실린더 배불뚝 몸통 + 축소된 개구부 타원 + 다리 3개 + 접지 그림자.
//   검수 피드백 반영: "샘플이 양동이처럼 보임" → botTaper 낮춰 배 나온 실루엣,
//   개구부 타원 비율 축소(rx 대비), 다리 3개(앞-좌/앞-우/뒤) 복원.
// 동일 파일명 교체 · 128×128 · bottom-center 접지 → 씬/컴포지터 코드 무변경.
//   NODE_PATH=/workspace/group/tools/nodejs/node_modules node tools_gen_home_objects.js
const path = require('path');
const L = require('./tools_iso_lib.js');
const { C, hex, px, rect, mix, darker, glow, ao, isoCylinder, deterministic } = L;
const save = L.saver(path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects'));

// art-guide §7 cauldron 램프 (샘플과 동일)
const bodyD = hex('#2a2a33'), bodyL = hex('#3d3d4a'), bodyDk = hex('#20202a');
const rimD = hex('#4a4a5a'), rimL = hex('#5c5c70');
const brew = hex('#6b4a9e'), glowV = hex('#9e7ad9'), glowB = hex('#c8a8ec'), cream = hex('#faf5e6');

function cauldron(name, bubble){
  const W=128,H=128,cv=C(W,H);
  const cx=64;
  ao(cv,cx,118,42,12,60);
  // 배불뚝 솥: 어깨(입)에서 좁게 시작 → 중배에서 최대로 불룩 → 바닥에서 다시 좁아지는
  // 볼록 프로파일. isoCylinder 의 단조 테이퍼로는 배가 안 나와 "양동이"로 보였으므로
  // 몸통을 직접 그린다. 각 높이 t 의 반경 = 어깨rx * bellyProfile(t).
  const topY=54, rx=30, h=52;   // topY 개구부(어깨) 중심, rx=어깨 반경, h=몸통 높이
  const ry=rx/2;
  const shoulderY = topY;       // 어깨(개구부 테두리) y
  // 볼록 배 프로파일: 어깨 1.0(립과 동일 폭) → 중배(t≈0.42) 1.30 → 바닥 0.56. 사인 부풀림.
  // v1.4.1 bug2: 어깨 반경을 립(rx)과 동일하게 맞춰 개구부가 몸통 위에 얹히도록(둥둥 뜨는 halo 제거).
  function bellyR(t){ // t: 0(어깨)~1(바닥)
    const bulge = Math.sin(Math.min(1,t*1.15)*Math.PI); // 0→1→0 형태
    const base = 1.00 + 0.02*t;            // 어깨=립폭에서 시작 → 바닥 덜 뾰족
    return rx*(base + 0.34*bulge - 0.30*t*t); // 배 부풀림 - 완만한 바닥 수렴
  }
  // 몸통 채우기: 각 높이 라인마다 좌우 반경만큼 3톤 곡면 셰이딩(광원 우상단).
  // v1.4.1 bug2: 몸통 시작을 개구부(topY)에 붙여(구: shoulderY+ry) 립↔몸통 사이 목 간극을 없앤다.
  for(let s=0;s<=h;s++){
    const t=s/h;
    const rr=bellyR(t);
    const yline=shoulderY+ s; // 개구부 중심부터 아래로 (립 밑면과 연속)
    for(let x=-rr;x<=rr;x++){
      const xr=x/rr;
      // 원통 곡면 램버트: 광원 우상단 → 우측/윗쪽 밝고 좌하단 어둡게. 연속 그라데이션.
      const litFrac = Math.max(0, Math.min(1, 0.5 + xr*0.55)); // 좌0 우1
      let c = mix(bodyDk, bodyL, litFrac);     // 곡면 기본 톤
      c = mix(c, bodyD, 0.15);                 // 중간톤으로 살짝 눌러 통일감
      c = mix(c, darker(c,0.30), t*0.5);       // 아래로 갈수록 암
      px(cv,cx+x,yline,c,255);
    }
    // 좌우 최외곽 selout + 우측 rim 하이라이트
    const ol=darker(bodyD,0.5);
    px(cv,cx-rr,yline,ol);px(cv,cx+rr,yline,ol);
    if(s%5===0)px(cv,cx+rr-2,yline,mix(bodyL,[255,255,255],0.14),170);
  }
  // 테두리 립(rim lip): 어깨 상단 밝은 이중 링 (두께감)
  for(let a=0;a<360;a+=1.2){const x=Math.cos(a*Math.PI/180),y=Math.sin(a*Math.PI/180);
    const lit = x>0? rimL: rimD;
    px(cv,cx+x*rx,topY+y*ry,lit,255);
    px(cv,cx+x*(rx-2),topY+y*(ry-1),lit,235);
    px(cv,cx+x*(rx-1),topY+y*(ry-0.5),darker(lit,0.2),220);
    if(y<0)px(cv,cx+x*rx,topY+y*ry-1,mix(lit,[255,255,255],0.2),200);}
  // 개구부 안쪽 어두운 목(솥 내부) — 립보다 확실히 작은 타원, 브루 아래 깊이감.
  const mrx=rx-8, mry=mrx/2;
  for(let y=-mry;y<=mry;y++)for(let x=-mrx;x<=mrx;x++){const d=(x/mrx)**2+(y/mry)**2;if(d<=1)px(cv,cx+x,topY+y,bodyDk,255);}
  const phase = bubble?1:0;
  const brx=mrx-3, bry=brx/2;   // 브루 표면 — 어두운 목 안쪽
  for(let y=-bry;y<=bry;y++)for(let x=-brx;x<=brx;x++){const d=(x/brx)**2+(y/bry)**2;if(d<=1){
    const c=((((x>>2)+(y>>1)+phase)%2===0))?brew:mix(brew,glowV,0.5);px(cv,cx+x,topY+y,c,255);}}
  // 브루 발광 링 + 코어 글로우
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*(brx-1),y=Math.sin(a*Math.PI/180)*(bry-1);px(cv,cx+x,topY+y,glowB,220);}
  glow(cv,cx,topY,brx-2,glowV,70);
  // 다리 3개 복원 (아이소 배치: 앞-좌, 앞-우, 뒤 중앙 살짝 위/가림).
  // 배불뚝 바닥(t=1 반경 ≈ bellyR(1))에서 짧게 뻗음.
  const botY = shoulderY+h;  // 몸통 바닥 y (v1.4.1: 몸통 시작을 topY로 올린 것과 정합)
  for(const [fx,fy,fw] of [[cx-16,botY-4,8],[cx+16,botY-4,8],[cx,botY-1,7]]){
    rect(cv,fx-fw/2,fy,fx+fw/2,fy+9,bodyDk);
    rect(cv,fx-fw/2,fy,fx+fw/2-2,fy+3,bodyD);            // 다리 윗면 광원 하이라이트
    px(cv,fx+fw/2-1,fy,darker(bodyDk,0.4),200);          // 우측 selout
  }
  // 김(steam) — 위로 오르는 보라빛 김 (bubble 프레임은 위상 shift + 한 가닥 더 높이)
  const r=deterministic(bubble?23:11);const steamN=bubble?24:20;
  for(let n=0;n<steamN;n++){const t=n/steamN;const x=cx+Math.round(Math.sin(t*6+r())*8)+(r()<0.5?-5:5);const y=topY-6-Math.floor(t*40);px(cv,x,y,mix(cream,glowV,0.4),Math.round(90*(1-t)));}
  // 위스퍼 반짝임 (bubble 프레임 한 점 추가)
  px(cv,cx-4,topY-4,cream,220);px(cv,cx+8,topY-8,cream,180);px(cv,cx-10,topY-2,cream,150);
  if(bubble){px(cv,cx+2,topY-11,cream,200);}
  save(cv,name);
}
cauldron('cauldron.png', false);
cauldron('cauldron_bubble.png', true);
console.log('home objects done.');
