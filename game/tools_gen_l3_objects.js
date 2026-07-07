'use strict';
// L3-1 — Machine-world (Layer 3) OBJECT art generator. Deterministic PNGs with AO
// contact shadows, matching L2 object fidelity. Ground origin = bottom-center of the
// canvas (so the loader plants them on the cell centre like the L2 objects).
// Palette per project-whisper design Part C §C-1: 구리/황동 base, 황동 램프,
// 오렌지 증기 발광 #ff9a3c (the warm counterpart to L2's navy+cyan). States off/on
// encoded as separate PNGs (the gate controller swaps to the _on variant).
// Produces into assets/objects/  (l3_*.png). Run: node tools_gen_l3_objects.js
const zlib = require('zlib'), fs = require('fs'), path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');
// AP-2 (v1.2.0 아트 정합): 정면뷰 기계 → 3/4 아이소 박스/실린더. 공용 헬퍼 재사용.
const ISO = require('./tools_iso_lib.js');
const { isoBox, isoCylinder, topDiamond, darker: dk } = ISO;

function crc32(b){let c=~0;for(let i=0;i<b.length;i++){c^=b[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t,'ascii');const body=Buffer.concat([tb,d]);const cr=Buffer.alloc(4);cr.writeUInt32BE(crc32(body),0);return Buffer.concat([l,body,cr]);}
function enc(w,h,px){const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;const st=w*4;const raw=Buffer.alloc((st+1)*h);for(let y=0;y<h;y++){raw[y*(st+1)]=0;px.copy(raw,y*(st+1)+1,y*st,y*st+st);}return Buffer.concat([sig,chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
function C(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hex(s){s=s.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function px(cv,x,y,rgb,a=255){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;if(a>=255){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=255;return;}if(a<=0)return;const af=a/255,ia=1-af;if(cv.data[i+3]===0){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function rect(cv,x0,y0,x1,y1,rgb,a=255){for(let y=Math.round(y0);y<Math.round(y1);y++)for(let x=Math.round(x0);x<Math.round(x1);x++)px(cv,x,y,rgb,a);}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function save(cv,name){fs.writeFileSync(path.join(OUT,name),enc(cv.w,cv.h,cv.data));console.log('wrote',name,cv.w+'x'+cv.h);}
// AO contact shadow: soft iso ellipse at ground line (y = H - foot)
function ao(cv,cx,gy,rx,ry,strength=64){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const dx=x/rx,dy=y/ry;const d=dx*dx+dy*dy;if(d<=1.0)px(cv,cx+x,gy+y,[0,0,0],Math.round((1-d)*strength));}}
// glow blob (additive-ish): soft orange disc for baked bloom on the object itself
function glow(cv,cx,cy,r,col,peak=120){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1.0)px(cv,cx+x,cy+y,col,Math.round((1-d)*(1-d)*peak));}}

// palette — copper/brass + orange steam glow (warm counterpart to L2 navy+cyan)
const COPPER=hex('#3a2c1e'), B_HI=hex('#c8a24a'), B_MID=hex('#8a6a34'), B_SH=hex('#4a3820'),
  ORANGE=hex('#ff9a3c'), EMBER=hex('#e8842c'), IRON=hex('#6a5a44'),
  DKPANEL=hex('#1a1208'), DEEP=hex('#1a1208');

function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// =========================================================================
// GATHER OBJECTS — the 7 K-elements (small, non-blocking, plant on cell centre)
// =========================================================================

// ---- K1 태엽 잔해 (clockwork mainspring, half-unwound). 90×90, foot y84. ----
(function springDebris(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,24,7,68);
  const cx=45,cy=58;
  // a coiled mainspring spiralling out, half-unwound
  for(let a=0;a<Math.PI*7;a+=0.06){const t=a/(Math.PI*7);const rad=4+t*26;const x=cx+Math.cos(a)*rad,y=cy+Math.sin(a)*rad*0.62;
    const c=mix(B_MID,B_HI,0.4+0.4*Math.sin(a));px(cv,x,y,c,240);px(cv,x,y-1,mix(c,B_HI,0.5),200);px(cv,x,y+1,B_SH,180);}
  // loose trailing end sprung out to the right
  for(let i=0;i<20;i++){const x=cx+30+i,y=cy+2-Math.round(Math.sin(i*0.4)*6);px(cv,x,y,B_HI,220);px(cv,x,y+1,B_SH,170);}
  // small bright glint at the hub
  px(cv,cx,cy,B_HI,255);glow(cv,cx,cy,7,ORANGE,50);
  save(cv,'l3_spring_debris.png');})();

// ---- K2 톱니 더미 (loose gears pile). 90×90, foot y84. ----
(function gearPile(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,25,7,68);
  function gear(gx,gy,rad,teeth,tone){
    for(let ang=0;ang<360;ang+=6){const rr=rad+(Math.round(ang/(360/teeth))%2===0?3:0);
      const x=gx+Math.cos(ang*Math.PI/180)*rr,y=gy+Math.sin(ang*Math.PI/180)*rr*0.7;px(cv,x,y,tone,235);}
    for(let y=-rad;y<=rad;y++)for(let x=-rad;x<=rad;x++){const d=(x/rad)**2+(y/(rad*0.7))**2;if(d<=1){const c=y<0?mix(tone,B_HI,0.35):mix(tone,B_SH,0.3);px(cv,gx+x,gy+y,c,235);}}
    // hub hole
    for(let y=-2;y<=2;y++)for(let x=-2;x<=2;x++)if(x*x+y*y<=4)px(cv,gx+x,gy+y,DEEP,220);
  }
  gear(34,66,14,10,B_MID);
  gear(58,70,11,9,mix(B_MID,B_SH,0.3));
  gear(48,50,13,11,B_HI);
  gear(64,54,8,8,B_MID);
  save(cv,'l3_gear_pile.png');})();

// ---- K3 황동 스크랩 (polished brass offcuts — reads precise/clean). 90×90. ----
(function brassScrap(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,23,7,66);const r=deterministic(303);
  // clean-cut bright brass plates & rods, neatly angled (not a messy rusty heap)
  const plates=[[28,58,20,8],[40,66,22,7],[34,50,16,6],[52,56,18,7]];
  for(const [bx,by,w,h] of plates){rect(cv,bx,by,bx+w,by+h,B_MID);rect(cv,bx,by,bx+w,by+2,B_HI);// bright milled top
    rect(cv,bx,by,bx+2,by+h,mix(B_MID,B_HI,0.5));rect(cv,bx+w-2,by,bx+w,by+h,B_SH);
    px(cv,bx+w-2,by,B_HI,255);}// corner glint
  // a couple of shiny rods
  for(let i=0;i<18;i++){px(cv,30+i,46,B_HI,235);px(cv,30+i,47,B_MID,210);}
  for(let i=0;i<14;i++){px(cv,48+i,44-i*0.2,B_HI,235);px(cv,48+i,45-i*0.2,B_SH,190);}
  // scattered precise highlight sparkles
  for(let n=0;n<5;n++)px(cv,32+Math.floor(r()*34),50+Math.floor(r()*14),hex('#f4e2a0'),230);
  save(cv,'l3_brass_scrap.png');})();

// ---- K4 증기응축수 웅덩이 (condensate puddle + faint orange-tinted steam). 96×72. ----
(function condensate(){const W=96,H=72,cv=C(W,H);ao(cv,W/2,66,26,6,44);
  // shallow puddle ellipse (dark oily water with orange-tinted sheen)
  const pcx=48,pcy=56,rx=28,ry=9;const water=hex('#26201a');
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=(x/rx)**2+(y/ry)**2;if(d<=1){const a=Math.round(210*(1-d*0.3));px(cv,pcx+x,pcy+y,water,a);}}
  // reflective highlight band + faint orange condensate sheen
  for(let x=-rx+6;x<rx-6;x++){const y=pcy-3;px(cv,pcx+x,y,mix(water,ORANGE,0.25),120);px(cv,pcx+x,y-1,mix(water,ORANGE,0.15),80);}
  glow(cv,pcx,pcy,16,ORANGE,26);
  // faint steam wisp rising (subtle orange-tinted)
  const r=deterministic(404);for(let n=0;n<24;n++){const t=n/24;const x=pcx+Math.round(Math.sin(t*6+r())*7)+ (r()<0.5?-4:4);const y=52-Math.floor(t*40);px(cv,x,y,mix(hex('#c9b8a4'),ORANGE,0.3),Math.round(70*(1-t)));}
  save(cv,'l3_condensate.png');})();

// ---- K5 가죽 벨트 스풀 (leather drive-belt spool, drooping). 90×90. ----
(function beltSpool(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,24,7,66);
  const cx=44,cy=54;const leather=hex('#6a4326'),leatherLt=hex('#8f5f38'),leatherSh=hex('#42280f');
  // spool flanges (brass discs)
  for(const fx of [30,58]){for(let y=-18;y<=18;y++)for(let x=-6;x<=6;x++){const d=(x/6)**2+(y/18)**2;if(d<=1){const c=x<0?mix(B_MID,B_HI,0.35):mix(B_MID,B_SH,0.3);px(cv,fx+x,cy+y,c,235);}}}
  // wound leather belt on the barrel
  for(let y=-15;y<=15;y+=1){const shade=(Math.abs(y)%4<2)?leather:leatherLt;rect(cv,34,cy+y,54,cy+y+1,shade,235);}
  rect(cv,34,cy-16,54,cy-13,leatherSh,220);
  // drooping belt tail hanging off to the lower-right
  const pts=[[54,cy+6],[64,cy+12],[70,cy+22],[68,cy+32],[62,cy+40]];
  for(let s=0;s<pts.length-1;s++){const [x0,y0]=pts[s],[x1,y1]=pts[s+1];for(let t=0;t<=1;t+=0.05){const x=x0+(x1-x0)*t,y=y0+(y1-y0)*t;rect(cv,x-2,y-1,x+2,y+2,leather,230);px(cv,x-2,y-1,leatherLt,200);px(cv,x+1,y+1,leatherSh,200);}}
  save(cv,'l3_belt_spool.png');})();

// ---- K6 석탄층 (coal seam / lump cluster). 90×90. ----
(function coalSeam(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,26,7,70);const r=deterministic(606);
  const coal=hex('#171310'),coalLt=hex('#33291f'),coalHi=hex('#4a3c2c');
  // a low seam of jagged coal lumps
  for(let n=0;n<30;n++){const bx=20+Math.floor(r()*50),by=54+Math.floor(r()*26),w=6+Math.floor(r()*11),h=5+Math.floor(r()*9);
    const tone=r()<0.5?coal:coalLt;
    // facet the lump
    for(let y=0;y<h;y++)for(let x=0;x<w;x++){const c=(y<h*0.4)?mix(tone,coalHi,0.5):(x<w*0.35?coalLt:coal);px(cv,bx+x,by+y,c,235);}
    if(r()<0.35)px(cv,bx+1,by+1,hex('#6a5238'),180);}// dull mineral glint
  save(cv,'l3_coal_seam.png');})();

// ---- K7 기름때 유리 파편 (oily grimy glass shards, faint rainbow oil sheen). 90×90. ----
(function grimyGlass(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,23,7,58);
  const glass=hex('#2e3630'),grime=hex('#4a3a22');const r=deterministic(707);
  // jagged upstanding shards
  const shards=[[36,80,10,26],[48,82,8,30],[42,84,6,20],[56,80,7,22],[30,82,6,16]];
  for(const [bx,base,w,h] of shards){for(let y=0;y<h;y++){const yy=base-y;const ww=Math.max(1,Math.round(w*(1-y/h)));for(let x=-ww/2;x<=ww/2;x++){const a=170-Math.round((h-y)*1.2);px(cv,bx+x,yy,mix(glass,grime,0.35),Math.max(80,a));}}
    // rim light on the shard edge
    for(let y=0;y<h;y++){const yy=base-y;const ww=Math.max(1,Math.round(w*(1-y/h)));px(cv,bx-ww/2,yy,hex('#8fa89a'),150);}}
  // oil-film rainbow sheen speckles (very faint)
  const sheen=[hex('#c86adf'),hex('#6ad3df'),hex('#dfcf6a'),hex('#6adf8f')];
  for(let n=0;n<10;n++){const gx=32+Math.floor(r()*26),gy=58+Math.floor(r()*22);px(cv,gx,gy,sheen[n%4],110);}
  save(cv,'l3_grimy_glass.png');})();

// =========================================================================
// GATE STRUCTURES
// =========================================================================

// ---- 1. 기어 도개교 (gear-meshed drawbridge) off/on. 128×72. ----
function gearBridge(name,lit){const W=128,H=72,cv=C(W,H);
  const cx=64,cy=32;
  // deck diamond over the canyon gap
  for(let y=0;y<64;y++)for(let x=0;x<W;x++){const d=Math.abs(x-cx)/64+Math.abs(y-cy)/32;if(d<=1){let c=lit?mix(COPPER,B_MID,0.5):mix(DEEP,B_SH,0.35);if(d>0.9)c=B_SH;px(cv,x,y,c,235);}}
  // brass gear-teeth rails running along both iso edges
  const rail=lit?B_HI:hex('#3a2c18');
  for(let x=20;x<108;x++){const y1=32+(x-64)*0.25-8,y2=32+(x-64)*0.25+8;
    px(cv,x,y1,rail,lit?230:160);px(cv,x,y2,rail,lit?230:160);
    if(x%6===0){px(cv,x,y1-2,rail,lit?230:150);px(cv,x,y2+2,rail,lit?230:150);}// gear teeth studs
    if(lit){px(cv,x,y1+1,rail,90);px(cv,x,y2-1,rail,90);}}
  // seam down the deck centre
  for(let x=40;x<88;x+=4)px(cv,x,32+(x-64)*0.25,lit?ORANGE:hex('#2a1f12'),lit?200:70);
  if(lit)glow(cv,cx,cy,42,ORANGE,66);
  save(cv,name);}
gearBridge('l3_gear_bridge_off.png',false);
gearBridge('l3_gear_bridge_on.png',true);

// ---- 2. 증기 밸브 방폭문 (steam valve blast-door) closed/open. 128×128. ----
function valveDoor(name,open){const W=128,H=128,cv=C(W,H);const cx=W/2;ao(cv,cx,120,32,9,72);
  // AP-2: 아이소 문턱 플린스(2:1 마름모) — 벽형 밸브문이 바닥 다이아에 접지.
  topDiamond(cv,cx,116,30,B_SH);
  for(let t=0;t<=30;t++){const yy=15*(1-t/30);px(cv,cx-t,116-yy,dk(B_SH,0.5));px(cv,cx+t,116-yy,dk(B_SH,0.5));px(cv,cx-t,116+yy,dk(B_SH,0.5));px(cv,cx+t,116+yy,dk(B_SH,0.5));}
  if(!open){
    // two brass leaves meeting in the middle
    rect(cv,30,36,64,116,B_MID);rect(cv,64,36,98,116,mix(B_MID,B_SH,0.25));
    rect(cv,30,36,98,40,mix(B_MID,B_HI,0.45));// top lit rim
    rect(cv,62,36,66,116,B_SH);// seam
    // a big central valve wheel
    const vx=64,vy=74;for(let a=0;a<360;a+=45){for(let i=0;i<14;i++)px(cv,vx+Math.cos(a*Math.PI/180)*i,vy+Math.sin(a*Math.PI/180)*i,B_SH,220);}
    for(let a=0;a<360;a+=6){px(cv,vx+Math.cos(a*Math.PI/180)*15,vy+Math.sin(a*Math.PI/180)*15,B_HI,230);}
    glow(cv,vx,vy,6,B_MID,60);px(cv,vx,vy,B_HI,255);
    // hazard chevrons (dim brass/amber)
    for(let i=0;i<3;i++){const yy=46+i*22;for(let k=0;k<8;k++){px(cv,40+k,yy+k,hex('#c8a83a'),120);px(cv,88-k,yy+k,hex('#c8a83a'),120);}}
    // red locked indicator
    glow(cv,64,30,10,hex('#c83a3a'),120);px(cv,64,30,hex('#ff6a6a'),200);
    // frame posts
    rect(cv,26,32,30,118,B_SH);rect(cv,98,32,102,118,B_SH);
  } else {
    // leaves retracted, orange-lit corridor + steam wisp
    rect(cv,26,36,40,116,B_MID);rect(cv,88,36,102,116,B_MID);
    rect(cv,40,36,88,116,DEEP,180);
    for(let y=40;y<114;y+=2)px(cv,64,y,ORANGE,180);glow(cv,64,76,28,ORANGE,90);
    glow(cv,64,30,10,ORANGE,140);
    // steam wisp curling up the open corridor
    const r=deterministic(202);for(let n=0;n<20;n++){const t=n/20;const x=64+Math.round(Math.sin(t*7+r())*8);const y=110-Math.floor(t*72);px(cv,x,y,mix(hex('#d8c8b0'),ORANGE,0.35),Math.round(90*(1-t)));}
  }
  save(cv,name);}
valveDoor('l3_valve_door_closed.png',false);
valveDoor('l3_valve_door_open.png',true);

// ---- 3. 증기 보일러 (steam boiler, 2×3) off/on. 176×160. AP-2: 3/4 아이소 실린더 탱크. ----
function boiler(name,on){const W=176,H=160,cv=C(W,H);const cx=W/2;ao(cv,cx,H-8,46,12,72);
  // 아이소 실린더 탱크: 윗면 타원(황동 캡), 좌/우 톤 분리 몸통. bottom-center 접지.
  const rx=48, h=92, ry=rx/2;
  const topY=H-14-h-ry;
  isoCylinder(cv,cx,topY,rx,h,mix(B_MID,B_HI,0.35),mix(B_MID,B_HI,0.15),mix(B_MID,COPPER,0.35),0.96);
  // 수평 보강 밴드 + 리벳 (곡면 따라 살짝 아래로 휨 — 앞면 타원 곡률)
  for(let i=0;i<4;i++){const yy=topY+ry+14+i*20;for(let x=-rx;x<=rx;x++){const xr=x/rx;if(xr*xr>1)continue;const dip=Math.round(ry*0.18*(1-xr*xr));const face=x>0?B_SH:dk(B_SH,0.1);px(cv,cx+x,yy+dip,face,200);if((x+rx)%14<1)px(cv,cx+x,yy+dip-1,B_HI,200);}}
  // 파이어박스: 앞면(광원측 하단) 아치형 개구부
  const fbx=cx+6,fby=topY+ry+h-16;
  for(let y=-10;y<=8;y++)for(let x=-22;x<=22;x++){const d=(x/22)**2+((y+2)/12)**2;if(d<=1)px(cv,fbx+x,fby+y,hex('#2a1c0e'),255);}
  if(on){glow(cv,fbx,fby,24,ORANGE,170);glow(cv,fbx,fby,14,hex('#ffd08a'),150);
    const r=deterministic(3011);for(let n=0;n<18;n++){const ex=fbx-18+Math.floor(r()*36),ey=fby-6+Math.floor(r()*10);if((ex-fbx)**2/484+(ey-fby+2)**2/144<=1)px(cv,ex,ey,mix(EMBER,ORANGE,r()),230);}
  } else {for(let y=-8;y<=6;y++)for(let x=-20;x<=20;x++){const d=(x/20)**2+((y+2)/10)**2;if(d<=1)px(cv,fbx+x,fby+y,DEEP,200);}}
  // 압력 게이지 (우측 광원면 상부)
  const gx=cx+rx-16,gy=topY+ry+18;
  for(let y=-10;y<=10;y++)for(let x=-10;x<=10;x++){if(x*x+y*y<=100)px(cv,gx+x,gy+y,DKPANEL,235);}
  for(let a=0;a<360;a+=8)px(cv,gx+Math.cos(a*Math.PI/180)*10,gy+Math.sin(a*Math.PI/180)*10,B_SH,220);
  if(on){glow(cv,gx,gy,9,ORANGE,150);for(let i=0;i<8;i++)px(cv,gx+i*0.7,gy-i*0.6,ORANGE,230);px(cv,gx,gy,hex('#ffe0b0'),240);}
  else{for(let i=0;i<8;i++)px(cv,gx-i*0.7,gy+i*0.4,hex('#4a3c28'),200);px(cv,gx,gy,hex('#2a2018'),220);}
  // 윗면에서 솟은 배기관(아이소 실린더 소형) + 증기
  isoCylinder(cv,cx-16,topY-20,9,20,mix(B_SH,B_HI,0.3),mix(B_SH,B_HI,0.15),dk(B_SH,0.1),1.0);
  if(on){glow(cv,cx-16,topY-22,16,hex('#e8dccb'),120);const r=deterministic(31);for(let n=0;n<16;n++){const t=n/16;const sx=cx-16+Math.round(Math.sin(t*6+r())*9);const sy=topY-22-Math.floor(t*26);px(cv,sx,sy,mix(hex('#e8dccb'),ORANGE,0.25),Math.round(150*(1-t)));}}
  save(cv,name);}
boiler('l3_boiler.png',false);
boiler('l3_boiler_on.png',true);

// ---- 9. 보일러 랜드마크 (boiler silhouette landmark variant). 176×160. ----
(function boilerLandmark(){const W=176,H=160,cv=C(W,H);ao(cv,W/2,H-8,46,11,74);
  const bw=104,bh=104,bx=(W-bw)/2,by=H-16-bh;
  // taller, more monumental cold-brass tank (matte, dormant)
  rect(cv,bx,by,bx+bw,by+bh,mix(B_MID,COPPER,0.3));
  rect(cv,bx,by,bx+bw,by+5,mix(B_MID,B_HI,0.35));rect(cv,bx,by,bx+4,by+bh,mix(B_MID,B_HI,0.2));rect(cv,bx+bw-4,by,bx+bw,by+bh,B_SH);
  for(let i=0;i<5;i++){const yy=by+14+i*20;rect(cv,bx,yy,bx+bw,yy+3,B_SH,190);for(let rx=bx+8;rx<bx+bw-6;rx+=14)px(cv,rx,yy+1,mix(B_HI,B_MID,0.4),170);}
  // twin dark stacks
  rect(cv,bx+18,by-34,bx+32,by,B_SH);rect(cv,bx+18,by-34,bx+22,by,mix(B_SH,B_HI,0.25));
  rect(cv,bx+bw-34,by-26,bx+bw-20,by,B_SH);
  // dark firebox + very faint residual ember
  const fbx=bx+bw/2,fby=by+bh-14;rect(cv,fbx-22,fby-10,fbx+22,fby+8,hex('#241a0e'));
  glow(cv,fbx,fby,10,EMBER,40);px(cv,fbx-4,fby,mix(EMBER,DEEP,0.4),120);px(cv,fbx+6,fby-2,mix(EMBER,DEEP,0.5),100);
  save(cv,'l3_boiler_landmark.png');})();

// ---- 4. 정지한 엘리베이터 케이지 (stopped elevator cage, 2×2) off/on. 128×160. ----
function elevator(name,on){const W=128,H=160,cv=C(W,H);const cx=W/2;ao(cv,cx,H-8,32,9,70);
  // AP-2: 3/4 아이소 철제 케이지 — 윗면 마름모(지붕 프레임) + 격자 측벽. bottom-center 접지.
  const rx=32, h=76, ry=rx/2;
  const botY=H-14, topY=botY-h-ry;
  // 상단 윈치 빔(윗면 위로 가로) + 케이블
  rect(cv,cx-44,12,cx+44,20,B_SH);rect(cv,cx-44,12,cx+44,14,mix(B_SH,B_HI,0.3));
  if(on){for(let y=20;y<topY;y++)px(cv,cx,y,B_HI,220);}
  else{for(let y=20;y<topY;y++){const sx=cx+Math.round(Math.sin((y-20)*0.18)*6);px(cv,sx,y,hex('#5a4a30'),200);}}
  // 케이지 아이소 박스 (어두운 내부가 비치도록 프레임만 — isoBox 후 격자)
  const iron=IRON, ironR=mix(IRON,B_HI,0.35), ironL=dk(IRON,0.25);
  isoBox(cv,cx,topY,rx,h,mix(iron,B_HI,0.15),ironR,ironL);
  // 내부 어둡게 (측벽 안쪽) — 윗면 마름모 아래 앞면 절반을 어둡게 덧칠해 오픈 케이지감
  for(let x=-rx+5;x<=rx-5;x++){const edgeY=topY+(ry-Math.abs(x)*ry/rx);for(let y=6;y<h-4;y++){if((x+y)%2===0)continue;px(cv,cx+x,edgeY+y,on?hex('#3a2c1a'):DEEP,on?150:180);}}
  // 격자 세로 바 (측벽 위)
  for(let x=-rx+8;x<rx-4;x+=10){const edgeY=topY+(ry-Math.abs(x)*ry/rx);for(let y=2;y<h-2;y++)px(cv,cx+x,edgeY+y,iron,150);}
  // 도착 램프 (윗면 위)
  const lampy=topY-4;
  if(on){glow(cv,cx,lampy,12,ORANGE,170);px(cv,cx,lampy,hex('#ffe0b0'),240);glow(cv,cx,topY+34,20,ORANGE,70);}
  else px(cv,cx,lampy,hex('#2a2018'),220);
  save(cv,name);}
elevator('l3_elevator.png',false);
elevator('l3_elevator_on.png',true);

// ---- 5. 게이트 기어 어셈블리 스탠드 (gate gear assembly) off/on. 96×96. ----
function gearAssembly(name,on){const W=96,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,26,7,66);
  // AP-2: 정면 원판 기어 → 작업대 위에 "누운" 기어(윗면=2:1 타원). 샘플 문법 정본 미러.
  const topY=50, rx=26, h=26, ry=rx/2;
  isoBox(cv,cx,topY,rx,h,mix(COPPER,B_MID,0.5),mix(B_MID,B_HI,0.35),B_SH);
  // 작업대 윗면 리벳 테두리
  for(let a=0;a<360;a+=45){const x=Math.cos(a*Math.PI/180)*(rx-4),y=Math.sin(a*Math.PI/180)*(ry-2);px(cv,cx+x,topY+y,B_HI,200);}
  // 기어: 윗면(2:1 타원)이 보이게 누움
  const gx=cx, gy=topY-2, grx=19, gry=grx/2, teeth=10;
  const tone=on?B_HI:mix(B_MID,COPPER,0.4);
  for(let ti=0;ti<teeth;ti++){const a=(ti/teeth)*360;const rad=a*Math.PI/180;
    const seg=ti; const missing=(!on&&seg===3);   // off: 빠진 톱니 노치
    if(missing)continue;
    const lit=(Math.sin(rad)<0?0.45:0)+(Math.cos(rad)>0?0.3:0);const tc=mix(tone,B_HI,lit*(on?1:0.4));
    for(let d=0;d<5;d++){const rr=grx+d;for(let w=-1;w<=1;w++){const wa=rad+w*0.11;px(cv,gx+Math.cos(wa)*rr,gy+Math.sin(wa)*(rr*0.5),tc,235);}}}
  for(let y=-gry;y<=gry;y++)for(let x=-grx;x<=grx;x++){const d=(x/grx)**2+(y/gry)**2;if(d<=1){const lit=(y<0?0.32:0)+(x>0?0.22:0);const c=mix(mix(COPPER,tone,0.6),B_HI,lit);px(cv,gx+x,gy+y,c,235);}}
  for(let a=0;a<360;a+=60){for(let i=6;i<grx-3;i++)px(cv,gx+Math.cos(a*Math.PI/180)*i,gy+Math.sin(a*Math.PI/180)*i*0.5,B_SH,150);}
  // 허브 소켓
  for(let y=-4;y<=4;y++)for(let x=-7;x<=7;x++){const d=(x/7)**2+(y/4)**2;if(d<=1)px(cv,gx+x,gy+y,on?mix(B_SH,ORANGE,0.2):DEEP,235);}
  for(let a=0;a<360;a+=2){const x=Math.cos(a*Math.PI/180)*grx,y=Math.sin(a*Math.PI/180)*gry;px(cv,gx+x,gy+y,dk(B_MID,0.5),200);}
  if(on){glow(cv,gx,gy,8,ORANGE,80);glow(cv,gx+9,gy-4,7,ORANGE,150);px(cv,gx+9,gy-4,hex('#fff0d0'),255);
    for(let a=20;a<70;a+=6)px(cv,gx+Math.cos(a*Math.PI/180)*(grx+3),gy+Math.sin(a*Math.PI/180)*(gry+2),ORANGE,120);}
  save(cv,name);}
gearAssembly('l3_gear_assembly.png',false);
gearAssembly('l3_gear_assembly_on.png',true);

// ---- 6. 엘리베이터 제어반 / 균형추 마운트 (elevator control) off/on. 80×96. ----
function elevatorCtrl(name,on){const W=80,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,20,6,60);
  // AP-2: 3/4 아이소 박스 제어반. 다이얼/게이지는 우측 광원면.
  const rx=18,h=44,ry=rx/2,topY=88-h-ry;
  isoBox(cv,cx,topY,rx,h,B_MID,mix(B_MID,B_HI,0.4),B_SH);
  // 좌측 균형추 레일 + 훅
  const railx=cx-rx-4;rect(cv,railx,topY,railx+3,topY+ry+h,B_SH);
  if(on){rect(cv,railx-8,topY+ry+14,railx+2,topY+ry+34,IRON);rect(cv,railx-8,topY+ry+14,railx+2,topY+ry+16,mix(IRON,B_HI,0.4));for(let i=0;i<18;i++)px(cv,railx+1,topY+i,B_HI,220);}
  else{px(cv,railx+1,topY+4,B_HI,200);for(let i=0;i<12;i++)px(cv,railx+1+Math.round(Math.sin(i*0.4)*3),topY+6+i,hex('#5a4a30'),200);}
  // 우측 광원면 패널: 다이얼 + 게이지 바
  const fx=cx+3, fy=topY+ry+10;
  for(let y=0;y<24;y++)for(let x=0;x<12;x++)px(cv,fx+x,fy+y+(x)*0.5,DKPANEL,255);
  for(let a=0;a<360;a+=20)px(cv,fx+6+Math.cos(a*Math.PI/180)*5,fy+8+Math.sin(a*Math.PI/180)*5+ (6)*0.5,B_SH,220);
  px(cv,fx+6,fy+8+ (6)*0.5,on?hex('#ffe0b0'):hex('#2a2018'),230);
  for(let x=0;x<10;x++)px(cv,fx+1+x,fy+18+(1+x)*0.5,hex('#2a2012'),220);
  if(on){for(let x=0;x<8;x++)px(cv,fx+1+x,fy+18+(1+x)*0.5,ORANGE,230);glow(cv,fx+6,fy+8+ (6)*0.5,9,ORANGE,120);}
  else for(let x=0;x<3;x++)px(cv,fx+1+x,fy+18+(1+x)*0.5,hex('#4a3c28'),200);
  save(cv,name);}
elevatorCtrl('l3_elevator_ctrl.png',false);
elevatorCtrl('l3_elevator_ctrl_on.png',true);

// ---- 7. 대시계 심장 마운트 (great-clock heart mount) off/on. 80×96. ----
function clockMount(name,on){const W=80,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,20,6,60);
  // AP-2: 3/4 아이소 박스 마운트 + 심장 소켓은 우측 광원면(정면감 제거).
  const rx=19,h=50,ry=rx/2,topY=88-h-ry;
  isoBox(cv,cx,topY,rx,h,B_MID,mix(B_MID,B_HI,0.4),B_SH);
  // 심장 소켓 — 우측 광원면 중앙 (황동 꽃잎 링 + 캐비티)
  const hx=cx+6, hy=topY+ry+22;
  for(let a=0;a<360;a+=30){const x=hx+Math.cos(a*Math.PI/180)*11,y=hy+Math.sin(a*Math.PI/180)*11;px(cv,x,y,B_HI,220);px(cv,x,y+1,B_SH,180);}
  if(on){glow(cv,hx,hy,20,ORANGE,180);glow(cv,hx,hy,11,hex('#ffd08a'),160);
    for(let a=0;a<360;a+=6)px(cv,hx+Math.cos(a*Math.PI/180)*6,hy+Math.sin(a*Math.PI/180)*6,mix(B_HI,ORANGE,0.4),235);
    px(cv,hx,hy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=45)for(let i=7;i<13;i++)px(cv,hx+Math.cos(a*Math.PI/180)*i,hy+Math.sin(a*Math.PI/180)*i,ORANGE,150);
  } else {for(let y=-7;y<=7;y++)for(let x=-7;x<=7;x++){if(x*x+y*y<=49)px(cv,hx+x,hy+y,DEEP,235);}}
  save(cv,name);}
clockMount('l3_clock_mount.png',false);
clockMount('l3_clock_mount_on.png',true);

// ---- 8. 대시계 랜드마크 (GRAND CLOCK, 3×3 tall tower) off/on. 256×320. ----
function grandClock(name,lit){const W=256,H=320,cv=C(W,H);ao(cv,W/2,306,66,14,80);
  const cx=W/2;
  // stepped brass base
  rect(cv,cx-70,278,cx+70,306,B_SH);rect(cv,cx-70,278,cx+70,282,mix(B_SH,B_HI,0.3));
  rect(cv,cx-58,250,cx+58,280,B_MID);rect(cv,cx-58,250,cx+58,254,mix(B_MID,B_HI,0.4));
  // tapering brass shaft
  for(let y=110;y<252;y++){const t=(y-110)/142;const hw=Math.round(30+t*24);const c=mix(B_MID,B_SH,t*0.4);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+3,y+1,mix(c,B_HI,0.35));rect(cv,cx+hw-3,y,cx+hw,y+1,B_SH);}
  // decorative bands on the shaft
  for(const by of [150,190,230]){rect(cv,cx-40,by,cx+40,by+4,B_SH,200);for(let rx=cx-36;rx<cx+36;rx+=12)px(cv,rx,by+2,B_HI,190);}
  // clock housing head (wide)
  rect(cv,cx-56,44,cx+56,116,B_MID);rect(cv,cx-56,44,cx+56,48,mix(B_MID,B_HI,0.5));
  rect(cv,cx-60,112,cx+60,120,B_SH);// lip
  // the clock face
  const fcx=cx,fcy=80,fr=40;
  const face=lit?hex('#4a3410'):hex('#241a0e');
  for(let y=-fr;y<=fr;y++)for(let x=-fr;x<=fr;x++){if(x*x+y*y<=fr*fr)px(cv,fcx+x,fcy+y,face,245);}
  // brass rim
  for(let a=0;a<360;a+=2)px(cv,fcx+Math.cos(a*Math.PI/180)*fr,fcy+Math.sin(a*Math.PI/180)*fr,B_HI,235);
  for(let a=0;a<360;a+=2)px(cv,fcx+Math.cos(a*Math.PI/180)*(fr-2),fcy+Math.sin(a*Math.PI/180)*(fr-2),B_MID,200);
  // hour ticks
  for(let h=0;h<12;h++){const a=h*30*Math.PI/180;const r0=fr-6,r1=fr-2;for(let t=r0;t<r1;t++)px(cv,fcx+Math.cos(a)*t,fcy+Math.sin(a)*t,lit?ORANGE:B_SH,lit?220:200);}
  if(lit)glow(cv,fcx,fcy,fr+6,ORANGE,80);
  // hands — frozen at the same time in both states (~3:40), lit adds bloom
  const handCol=lit?hex('#ffe0b0'):hex('#3a2c18');
  // hour hand (~pointing to ~3.6h → 108deg from top)
  {const a=(108-90)*Math.PI/180;for(let t=0;t<24;t++)px(cv,fcx+Math.cos(a)*t,fcy+Math.sin(a)*t,handCol,235);}
  // minute hand (~pointing to 40min → 240deg from top)
  {const a=(240-90)*Math.PI/180;for(let t=0;t<32;t++)px(cv,fcx+Math.cos(a)*t,fcy+Math.sin(a)*t,handCol,235);}
  px(fcx!==undefined?cv:cv,fcx,fcy,lit?hex('#fff0d0'):B_HI,255);
  if(lit){glow(cv,fcx,fcy,10,ORANGE,150);
    // additive orange bloom over the whole face
    glow(cv,fcx,fcy,fr,ORANGE,50);}
  // finial spire + beacon
  rect(cv,cx-4,20,cx+4,46,B_SH);rect(cv,cx-4,20,cx-1,46,mix(B_SH,B_HI,0.3));
  px(cv,cx,16,lit?hex('#fff0d0'):hex('#3a2c18'),lit?255:210);
  if(lit)glow(cv,cx,18,12,ORANGE,200);
  save(cv,name);}
grandClock('l3_grand_clock.png',false);
grandClock('l3_grand_clock_on.png',true);

// =========================================================================
// LANDMARK / DECO OBJECTS
// =========================================================================

// ---- 10. 황동 배관 다발 (brass pipe cluster, blocks). 112×96. ----
(function pipes(){const W=112,H=96,cv=C(W,H);ao(cv,W/2,90,32,8,68);
  // a run of vertical brass pipes of varying diameter
  const runs=[[24,10],[40,14],[58,10],[74,16],[92,8]];
  for(const [px0,w] of runs){for(let y=30;y<88;y++)for(let x=0;x<w;x++){const t=x/w;const c=t<0.3?B_HI:(t<0.7?B_MID:B_SH);px(cv,px0+x,y,c,240);}
    // top cap
    rect(cv,px0-1,28,px0+w+1,32,B_SH);rect(cv,px0-1,28,px0+w+1,29,mix(B_SH,B_HI,0.4));}
  // a horizontal conduit crossing over them with elbow joints
  for(let x=18;x<104;x++)for(let y=0;y<10;y++){const t=y/10;const c=t<0.3?B_HI:(t<0.7?B_MID:B_SH);px(cv,x,44+y,c,235);}
  // flange bolts along the horizontal
  for(let x=24;x<100;x+=16){for(let a=0;a<360;a+=60)px(cv,x+Math.cos(a*Math.PI/180)*3,49+Math.sin(a*Math.PI/180)*3,B_HI,220);}
  // a couple of valve wheels
  for(const [wx,wy] of [[47,60],[81,66]]){for(let a=0;a<360;a+=30)px(cv,wx+Math.cos(a*Math.PI/180)*6,wy+Math.sin(a*Math.PI/180)*6,B_SH,220);px(cv,wx,wy,B_HI,230);}
  save(cv,'l3_pipes.png');})();

// ---- 11. 냉각된 용광로 (cold blast furnace, blocks, faint ember). 140×150. ----
(function furnace(){const W=140,H=150,cv=C(W,H);ao(cv,W/2,H-8,42,10,72);
  const cx=W/2;
  // wide brick/brass furnace stack, tapering slightly
  for(let y=40;y<138;y++){const t=(y-40)/98;const hw=Math.round(42-t*8);const c=mix(mix(B_MID,COPPER,0.4),B_SH,t*0.3);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+4,y+1,mix(c,B_HI,0.25));rect(cv,cx+hw-4,y,cx+hw,y+1,B_SH);}
  // reinforcing hoops
  for(const hy of [60,90,120]){rect(cv,cx-44,hy,cx+44,hy+4,B_SH,200);for(let rx=cx-38;rx<cx+38;rx+=12)px(cv,rx,hy+2,B_HI,180);}
  // arched furnace mouth with cold ash + faint residual ember deep inside
  const mx=cx,my=126;
  for(let y=-14;y<=6;y++)for(let x=-18;x<=18;x++){const d=(x/18)**2+(y/16)**2;if(d<=1)px(cv,mx+x,my+y,hex('#1a120a'),235);}
  glow(cv,mx,my-2,9,EMBER,60);// faint ember
  const r=deterministic(1101);for(let n=0;n<7;n++){const ex=mx-10+Math.floor(r()*20),ey=my-6+Math.floor(r()*8);px(cv,ex,ey,mix(EMBER,DEEP,0.4),150);}
  // chimney stack
  rect(cv,cx-14,10,cx+14,42,B_SH);rect(cv,cx-14,10,cx-9,42,mix(B_SH,B_HI,0.3));rect(cv,cx-18,8,cx+18,14,B_SH);
  save(cv,'l3_furnace.png');})();

// ---- 12. 부품 더미 (clockwork parts heap). 96×96. ----
(function partsPile(){const W=96,H=96,cv=C(W,H);ao(cv,W/2,90,27,8,70);const r=deterministic(1202);
  // a jumbled heap of small clockwork bits: cogs, springs, plates, rods
  for(let n=0;n<32;n++){const kind=Math.floor(r()*4);const bx=24+Math.floor(r()*48),by=54+Math.floor(r()*30);
    const tone=[B_MID,B_HI,B_SH,mix(B_MID,COPPER,0.4)][Math.floor(r()*4)];
    if(kind===0){// small cog
      const rad=3+Math.floor(r()*4);for(let a=0;a<360;a+=30)px(cv,bx+Math.cos(a*Math.PI/180)*rad,by+Math.sin(a*Math.PI/180)*rad*0.7,tone,230);px(cv,bx,by,mix(tone,B_HI,0.4),220);
    } else if(kind===1){// plate
      const w=5+Math.floor(r()*7),h=3+Math.floor(r()*4);rect(cv,bx,by,bx+w,by+h,tone);rect(cv,bx,by,bx+w,by+1,mix(tone,B_HI,0.4));
    } else if(kind===2){// rod
      const len=6+Math.floor(r()*8);for(let i=0;i<len;i++)px(cv,bx+i,by-Math.round(i*0.3),tone,225);
    } else {// tiny spring coil
      for(let a=0;a<Math.PI*3;a+=0.4){const rad=2+a*0.5;px(cv,bx+Math.cos(a)*rad,by+Math.sin(a)*rad*0.6,tone,210);}
    }}
  // a couple of bright glints
  for(let n=0;n<4;n++)px(cv,30+Math.floor(r()*40),56+Math.floor(r()*24),hex('#f4e2a0'),220);
  save(cv,'l3_parts_pile.png');})();

// ---- 13. 멈춘 로봇 (stopped robots, 3 poses). 90×150 each. ----
// Matte brass body, dark unlit eyes (single dim dot). The "last-log" glow added at runtime.
function robotBase(cv,cx){
  // common brass torso/head builder helper is inlined per-pose below for pose freedom
}
function robotSweeper(){const W=90,H=150,cv=C(W,H);ao(cv,W/2,142,22,7,68);const cx=44;
  const brass=mix(B_MID,COPPER,0.35),brassHi=B_HI,brassSh=B_SH;
  // legs (standing)
  rect(cv,cx-12,104,cx-3,140,brass);rect(cv,cx-12,104,cx-10,140,brassHi);rect(cv,cx-4,104,cx-3,140,brassSh);
  rect(cv,cx+4,104,cx+13,140,brass);rect(cv,cx+4,104,cx+6,140,brassHi);rect(cv,cx+12,104,cx+13,140,brassSh);
  rect(cv,cx-14,138,cx-1,144,brassSh);rect(cv,cx+2,138,cx+15,144,brassSh);// feet
  // torso (barrel)
  for(let y=58;y<106;y++){const t=(y-58)/48;const hw=Math.round(16-t*3);rect(cv,cx-hw,y,cx+hw,y+1,brass);px(cv,cx-hw,y,brassHi,210);px(cv,cx+hw-1,y,brassSh,210);}
  // chest plate seam + rivets
  rect(cv,cx-10,70,cx+10,74,brassSh,200);for(let rx=cx-8;rx<=cx+8;rx+=8)px(cv,rx,72,brassHi,200);
  // head
  for(let y=36;y<58;y++){const t=(y-36)/22;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw,y,cx+hw,y+1,brass);px(cv,cx-hw,y,brassHi,200);}
  // dim single eye dot (nearly dark)
  px(cv,cx-3,46,hex('#4a2c14'),220);px(cv,cx+3,46,hex('#2a1a0e'),200);
  // one arm bent holding a broom, mid-sweep (right arm forward-down)
  for(let i=0;i<20;i++)px(cv,cx+14+i*0.7,66+i*0.8,brass,230);// upper arm out
  for(let i=0;i<16;i++)px(cv,cx+28+i*0.2,82+i,brass,230);// forearm down to broom
  // left arm hanging
  for(let i=0;i<30;i++)px(cv,cx-15-i*0.1,64+i,brass,225);
  // broom: handle + bristles
  for(let i=0;i<34;i++)px(cv,cx+18+i,64+i,hex('#5a4326'),230);// handle diagonal
  const brx=cx+52,bry=98;rect(cv,brx-2,bry,brx+6,bry+4,hex('#3a2c18'));
  for(let b=0;b<12;b++)for(let i=0;i<8;i++)px(cv,brx-2+b,bry+4+i,hex('#7a5a34'),210);// bristles
  save(cv,'l3_robot_sweeper.png');}
robotSweeper();

function robotCourier(){const W=90,H=150,cv=C(W,H);ao(cv,W/2,142,24,7,68);const cx=44;
  const brass=mix(B_MID,COPPER,0.35),brassHi=B_HI,brassSh=B_SH;
  // mid-stride: one foot stepped forward, one back
  // back leg (left, planted behind)
  for(let i=0;i<38;i++)px(cv,cx-6-i*0.28,104+i,brass,230);for(let i=0;i<38;i++)px(cv,cx-4-i*0.28,104+i,brassSh,180);
  rect(cv,cx-22,140,cx-10,145,brassSh);// back foot
  // front leg (right, stepped forward)
  for(let i=0;i<38;i++)px(cv,cx+4+i*0.32,104+i,brass,230);for(let i=0;i<38;i++)px(cv,cx+6+i*0.32,104+i,brassHi,180);
  rect(cv,cx+14,138,cx+28,143,brassSh);// front foot
  // torso leaning slightly forward
  for(let y=56;y<106;y++){const t=(y-56)/50;const hw=Math.round(15-t*2);const lean=Math.round((1-t)*4);rect(cv,cx-hw+lean,y,cx+hw+lean,y+1,brass);px(cv,cx-hw+lean,y,brassHi,205);px(cv,cx+hw+lean-1,y,brassSh,205);}
  rect(cv,cx-8,68,cx+12,72,brassSh,200);
  // head, tilted forward
  for(let y=34;y<56;y++){const t=(y-34)/22;const hw=Math.round(10-Math.abs(t-0.4)*5);rect(cv,cx-hw+6,y,cx+hw+6,y+1,brass);px(cv,cx-hw+6,y,brassHi,200);}
  px(cv,cx+3,44,hex('#4a2c14'),220);px(cv,cx+9,44,hex('#2a1a0e'),200);// dim eyes
  // arms swinging (opposite to legs) — left forward, right back
  for(let i=0;i<26;i++)px(cv,cx-12+i*0.5,62+i*0.7,brass,225);// left arm forward
  for(let i=0;i<26;i++)px(cv,cx+16-i*0.2,62+i*0.8,brass,225);// right arm back
  // a satchel on the hip
  rect(cv,cx+10,84,cx+24,98,hex('#5a4326'));rect(cv,cx+10,84,cx+24,86,hex('#7a5a34'));
  save(cv,'l3_robot_courier.png');}
robotCourier();

function robotStanding(){const W=90,H=150,cv=C(W,H);ao(cv,W/2,142,22,7,68);const cx=44;
  const brass=mix(B_MID,COPPER,0.35),brassHi=B_HI,brassSh=B_SH;
  // legs straight, arms at sides, head bowed
  rect(cv,cx-11,104,cx-2,140,brass);rect(cv,cx-11,104,cx-9,140,brassHi);rect(cv,cx-3,104,cx-2,140,brassSh);
  rect(cv,cx+3,104,cx+12,140,brass);rect(cv,cx+3,104,cx+5,140,brassHi);rect(cv,cx+11,104,cx+12,140,brassSh);
  rect(cv,cx-13,138,cx-1,144,brassSh);rect(cv,cx+2,138,cx+14,144,brassSh);
  // torso
  for(let y=58;y<106;y++){const t=(y-58)/48;const hw=Math.round(16-t*3);rect(cv,cx-hw,y,cx+hw,y+1,brass);px(cv,cx-hw,y,brassHi,210);px(cv,cx+hw-1,y,brassSh,210);}
  rect(cv,cx-10,70,cx+10,74,brassSh,200);for(let rx=cx-8;rx<=cx+8;rx+=8)px(cv,rx,72,brassHi,200);
  // head bowed forward + down
  for(let y=40;y<60;y++){const t=(y-40)/20;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw+2,y,cx+hw+2,y+1,brass);px(cv,cx-hw+2,y,brassHi,200);}
  px(cv,cx-1,52,hex('#4a2c14'),220);px(cv,cx+5,52,hex('#2a1a0e'),200);// dim eyes, low on bowed head
  // arms hanging straight at sides
  for(let i=0;i<40;i++)px(cv,cx-16-i*0.05,62+i,brass,225);px(cv,cx-16,62,brassHi,200);
  for(let i=0;i<40;i++)px(cv,cx+15+i*0.05,62+i,brass,225);px(cv,cx+15,62,brassHi,200);
  // hands
  rect(cv,cx-19,100,cx-13,106,brass);rect(cv,cx+13,100,cx+19,106,brass);
  save(cv,'l3_robot_standing.png');}
robotStanding();

// ---- 14. L3 정비대 (workbench, brass with ORANGE fusion aperture). 128×112. ----
(function workbench(){const W=128,H=112,cv=C(W,H);const cx=W/2;ao(cv,cx,104,34,9,70);
  // AP-2: 3/4 아이소 박스 + 윗면 worktop에 오렌지 융합 개구부(위에서 조합하는 정합 뷰).
  const rx=34,h=40,ry=rx/2,topY=104-h-ry;
  isoBox(cv,cx,topY,rx,h,B_MID,mix(B_MID,B_HI,0.4),B_SH);
  // 윗면 융합 개구부(오렌지) — 마름모 윗면 중앙 타원
  const ax=cx,ay=topY;
  glow(cv,ax,ay,24,EMBER,110);glow(cv,ax,ay,15,ORANGE,140);
  for(let a=0;a<360;a+=20)px(cv,ax+Math.cos(a*Math.PI/180)*10,ay+Math.sin(a*Math.PI/180)*5,mix(EMBER,ORANGE,0.6),220);
  px(cv,ax,ay,hex('#fff0d0'),245);
  // 툴암(아이소 각도)
  for(let i=0;i<18;i++)px(cv,cx-14+i,topY-6-i*0.3,B_HI);px(cv,cx+4,topY-12,ORANGE,210);
  // 우측 광원면 사이드 게이지
  const gx=cx+rx-14,gy=topY+ry+12;
  for(let y=0;y<18;y++)for(let x=0;x<8;x++)px(cv,gx+x,gy+y+ (x)*0.5,DKPANEL,255);
  for(let x=0;x<6;x++)px(cv,gx+1+x,gy+3+(1+x)*0.5,ORANGE,210);
  save(cv,'l3_workbench.png');})();

// =========================================================================
// SMALL DEBRIS SCATTER BITS (for the map scatter)
// =========================================================================

// ---- 22. l3_debris_cog — tiny loose cog fleck. 48×48. ----
(function debrisCog(){const W=48,H=48,cv=C(W,H);ao(cv,W/2,42,10,4,58);
  const gx=24,gy=30,rad=7;
  for(let a=0;a<360;a+=45)px(cv,gx+Math.cos(a*Math.PI/180)*(rad+2),gy+Math.sin(a*Math.PI/180)*(rad+2)*0.8,B_MID,230);// teeth
  for(let y=-rad;y<=rad;y++)for(let x=-rad;x<=rad;x++){const d=(x/rad)**2+(y/(rad*0.8))**2;if(d<=1){const c=y<0?mix(B_MID,B_HI,0.4):mix(B_MID,B_SH,0.3);px(cv,gx+x,gy+y,c,230);}}
  px(cv,gx,gy,DEEP,220);px(cv,gx-2,gy-2,B_HI,220);// hub + glint
  save(cv,'l3_debris_cog.png');})();

// ---- 23. l3_debris_soot — soot/ash wisp (warm-tinted). 48×48. ----
(function debrisSoot(){const W=48,H=48,cv=C(W,H);const r=deterministic(2323);const soot=hex('#241c14');
  for(let n=0;n<20;n++){const ax=14+Math.floor(r()*20),ay=26+Math.floor(r()*14);px(cv,ax,ay,soot,120);px(cv,ax+1,ay,mix(soot,EMBER,0.15),90);}
  // a couple of warm ember flecks in the ash
  for(let n=0;n<3;n++)px(cv,18+Math.floor(r()*14),28+Math.floor(r()*8),mix(EMBER,soot,0.4),150);
  save(cv,'l3_debris_soot.png');})();

console.log('L3 objects done.');
