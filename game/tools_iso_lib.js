'use strict';
// tools_iso_lib.js — AP-2 공용 아이소 오브젝트 헬퍼 (v1.2.0 아트 정합 패스).
// 문법 정본: docs/project-whisper-iso-object-grammar.md + assets/samples_iso/ 5종.
// 샘플 제너레이터(tools_gen_iso_samples.js, commit 051d360)의 박스/실린더/셰이딩
// 헬퍼를 모듈로 추출 — 전 레이어 오브젝트 제너레이터가 공유한다.
//   3/4 아이소 뷰(윗면 마름모/타원 || 바닥 2:1 다이아), 광원 NE(우상단) 고정,
//   3톤 셰이딩(윗면 최명/우측 광원면 중간/좌측 그늘면 최암), 타원 접지 그림자,
//   selout 아웃라인(순수 검정 금지 — 동일 계열 2단계 암).
// 팔레트는 각 레이어 램프 그대로 — 이 모듈은 형태(뷰)만 만든다. 신규 색 없음.
const zlib = require('zlib'), fs = require('fs'), path = require('path');

// ---- PNG encode + canvas primitives (전 제너레이터 공통 API) ----
function crc32(b){let c=~0;for(let i=0;i<b.length;i++){c^=b[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t,'ascii');const body=Buffer.concat([tb,d]);const cr=Buffer.alloc(4);cr.writeUInt32BE(crc32(body),0);return Buffer.concat([l,body,cr]);}
function enc(w,h,px){const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;const st=w*4;const raw=Buffer.alloc((st+1)*h);for(let y=0;y<h;y++){raw[y*(st+1)]=0;px.copy(raw,y*(st+1)+1,y*st,y*st+st);}return Buffer.concat([sig,chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
function C(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hex(s){s=s.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function px(cv,x,y,rgb,a=255){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;if(a>=255){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=255;return;}if(a<=0)return;const af=a/255,ia=1-af;if(cv.data[i+3]===0){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function rect(cv,x0,y0,x1,y1,rgb,a=255){for(let y=Math.round(y0);y<Math.round(y1);y++)for(let x=Math.round(x0);x<Math.round(x1);x++)px(cv,x,y,rgb,a);}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function darker(c,t){return mix(c,[0,0,0],t);}
function lighter(c,t){return mix(c,[255,255,255],t);}
function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// 접지 그림자 — 바닥 라인의 소프트 아이소 타원 (검정 블롭). rx:ry ~ 3.5:1
function ao(cv,cx,gy,rx,ry,strength=64){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const dx=x/rx,dy=y/ry;const d=dx*dx+dy*dy;if(d<=1.0)px(cv,cx+x,gy+y,[0,0,0],Math.round((1-d)*strength));}}
function glow(cv,cx,cy,r,col,peak=120){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1.0)px(cv,cx+x,cy+y,col,Math.round((1-d)*(1-d)*peak));}}

// ── 아이소 문법 헬퍼 (광원 우상단 NE) ─────────────────────────────────────────
// 아이소 윗면 마름모 채우기 — 중심(cx,cy), 반경 rx, ry=rx/2 (바닥 2:1 다이아 평행).
function topDiamond(cv,cx,cy,rx,col,a=255){const ry=rx/2;for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=Math.abs(x)/rx+Math.abs(y)/ry;if(d<=1.0){const shade=mix(col,darker(col,0.12),(y+ry)/(2*ry)*0.5);px(cv,cx+x,cy+y,shade,a);}}}
function diamondOutline(cv,cx,cy,rx,ol){const ry=rx/2;for(let t=0;t<=rx;t++){const yy=ry*(1-t/rx);px(cv,cx-t,cy-yy,ol);px(cv,cx+t,cy-yy,ol);px(cv,cx-t,cy+yy,ol);px(cv,cx+t,cy+yy,ol);}}

// 아이소 박스: 윗면 마름모(cx,topY,rx) + 좌/우 측벽 높이 h.
// cTop=윗면(최명), cR=우측 광원면(중간~밝음), cL=좌측 그늘면(최암).
function isoBox(cv,cx,topY,rx,h,cTop,cR,cL){
  const ry=rx/2;
  const ol=darker(cR,0.55);
  for(let x=-rx;x<=rx;x++){
    const edgeY = topY + (ry - Math.abs(x)*ry/rx);
    const face = x<=0 ? cL : cR;
    for(let y=0;y<h;y++){
      const t=y/h;
      const c=mix(face,darker(face,0.30),t*0.5);
      px(cv,cx+x,edgeY+y,c,255);
    }
    if(x>0) px(cv,cx+x,edgeY,mix(cR,[255,255,255],0.18),200);
  }
  for(let y=0;y<h;y++)px(cv,cx,topY+ry+y,darker(cR,0.4),200);
  for(let x=-rx;x<=rx;x++){const edgeY=topY+(ry-Math.abs(x)*ry/rx)+h;px(cv,cx+x,edgeY,ol);}
  topDiamond(cv,cx,topY,rx,cTop);
  diamondOutline(cv,cx,topY,rx,darker(cTop,0.5));
  for(let y=0;y<h;y++){px(cv,cx-rx,topY+y,ol);px(cv,cx+rx,topY+y,ol);}
}

// 아이소 실린더: 윗면 타원(rx:ry=2:1) + 수직 벽. 좌/오 톤 분리.
// botTaper<1 이면 아래로 갈수록 좁아짐(솥 배).
function isoCylinder(cv,cx,topY,rx,h,cTop,cR,cL,botTaper=1.0){
  const ry=rx/2;const ol=darker(cR,0.55);
  for(let x=-rx;x<=rx;x++){
    const xr=x/rx; if(xr*xr>1)continue;
    const edgeY=topY+ry*Math.sqrt(1-xr*xr);
    const face = x<=0 ? cL : cR;
    const rim = mix(face,[255,255,255],0.15);
    for(let y=0;y<h;y++){
      const t=y/h;
      const c=mix(face,darker(face,0.34),t*0.55);
      const inset = Math.round((1-botTaper)*rx*(t)*(Math.abs(xr)));
      const xx = cx + x + (x<0?inset:-inset);
      px(cv,xx,edgeY+y,c,255);
      if(y===0 && x>0)px(cv,xx,edgeY+y,rim,200);
    }
  }
  for(let x=-rx;x<=rx;x++){const xr=x/rx;if(xr*xr>1)continue;const inset=Math.round((1-botTaper)*rx*Math.abs(xr));const edgeY=topY+ry*Math.sqrt(1-xr*xr)+h;const xx=cx+x+(x<0?inset:-inset);px(cv,xx,edgeY,ol);}
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=(x/rx)**2+(y/ry)**2;if(d<=1){const shade=mix(cTop,darker(cTop,0.14),(y+ry)/(2*ry)*0.5);px(cv,cx+x,topY+y,shade,255);}}
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*rx,y=Math.sin(a*Math.PI/180)*ry;px(cv,cx+x,topY+y,darker(cTop,0.5));}
}

// 아이소 타원 윗면만 (뚜껑/수면/받침 표면 등) — 채움+아웃라인.
function isoEllipseTop(cv,cx,cy,rx,col,a=255,outline=null){
  const ry=rx/2;
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=(x/rx)**2+(y/ry)**2;if(d<=1){const shade=mix(col,darker(col,0.14),(y+ry)/(2*ry)*0.5);px(cv,cx+x,cy+y,shade,a);}}
  if(outline)for(let ang=0;ang<360;ang+=2){const x=Math.cos(ang*Math.PI/180)*rx,y=Math.sin(ang*Math.PI/180)*ry;px(cv,cx+x,cy+y,outline);}
}

// selout 아웃라인 컬러 (동일 계열 2단계 암, 순수 검정 금지)
function selout(c){return darker(c,0.55);}

// PNG 저장 (OUT 디렉토리 지정)
function saver(OUT){fs.mkdirSync(OUT,{recursive:true});return function save(cv,name){fs.writeFileSync(path.join(OUT,name),enc(cv.w,cv.h,cv.data));console.log('wrote',name,cv.w+'x'+cv.h);};}

module.exports = {
  crc32, chunk, enc, C, hex, px, rect, mix, darker, lighter, deterministic,
  ao, glow, topDiamond, diamondOutline, isoBox, isoCylinder, isoEllipseTop, selout, saver,
};
