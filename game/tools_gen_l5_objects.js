'use strict';
// L5-1 — Divinity-world (Layer 5) 「응답 없는 대성당」 OBJECT art generator. Deterministic PNGs with
// AO contact shadows, matching L2/L3/L4 object fidelity. Ground origin = bottom-center of canvas.
// Palette per design Part C §C-1: 창백한 상아·백은 base + 희미한 호박빛 잔불 발광 #e0a94a (the
// desaturated counterpart to L4's amethyst+gold — 채도를 뺀 세계). States off/on encoded as separate
// PNGs (the gate controller swaps to the _on variant). Also emits light_pool_amber.png (호박 발광 풀).
// Produces into assets/objects/  (l5_*.png). Run: NODE_PATH=... node tools_gen_l5_objects.js
const zlib = require('zlib'), fs = require('fs'), path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');

// AP-2 (v1.2.0 아트 정합): 정면뷰 제단/성물/문 → 3/4 아이소 박스/실린더. 공용 헬퍼.
const ISO = require('./tools_iso_lib.js');
const { isoBox, isoCylinder, topDiamond, isoEllipseTop, darker: dk } = ISO;
function crc32(b){let c=~0;for(let i=0;i<b.length;i++){c^=b[i];for(let k=0;k<8;k++)c=(c>>>1)^(0xEDB88320&-(c&1));}return(~c)>>>0;}
function chunk(t,d){const l=Buffer.alloc(4);l.writeUInt32BE(d.length,0);const tb=Buffer.from(t,'ascii');const body=Buffer.concat([tb,d]);const cr=Buffer.alloc(4);cr.writeUInt32BE(crc32(body),0);return Buffer.concat([l,body,cr]);}
function enc(w,h,px){const sig=Buffer.from([137,80,78,71,13,10,26,10]);const ih=Buffer.alloc(13);ih.writeUInt32BE(w,0);ih.writeUInt32BE(h,4);ih[8]=8;ih[9]=6;const st=w*4;const raw=Buffer.alloc((st+1)*h);for(let y=0;y<h;y++){raw[y*(st+1)]=0;px.copy(raw,y*(st+1)+1,y*st,y*st+st);}return Buffer.concat([sig,chunk('IHDR',ih),chunk('IDAT',zlib.deflateSync(raw,{level:9})),chunk('IEND',Buffer.alloc(0))]);}
function C(w,h){return{w,h,data:Buffer.alloc(w*h*4,0)};}
function hex(s){s=s.replace('#','');return[parseInt(s.slice(0,2),16),parseInt(s.slice(2,4),16),parseInt(s.slice(4,6),16)];}
function px(cv,x,y,rgb,a=255){x=Math.round(x);y=Math.round(y);if(x<0||y<0||x>=cv.w||y>=cv.h)return;const i=(y*cv.w+x)*4;if(a>=255){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=255;return;}if(a<=0)return;const af=a/255,ia=1-af;if(cv.data[i+3]===0){cv.data[i]=rgb[0];cv.data[i+1]=rgb[1];cv.data[i+2]=rgb[2];cv.data[i+3]=a;return;}cv.data[i]=Math.round(rgb[0]*af+cv.data[i]*ia);cv.data[i+1]=Math.round(rgb[1]*af+cv.data[i+1]*ia);cv.data[i+2]=Math.round(rgb[2]*af+cv.data[i+2]*ia);cv.data[i+3]=Math.min(255,cv.data[i+3]+a);}
function rect(cv,x0,y0,x1,y1,rgb,a=255){for(let y=Math.round(y0);y<Math.round(y1);y++)for(let x=Math.round(x0);x<Math.round(x1);x++)px(cv,x,y,rgb,a);}
function mix(a,b,t){return[Math.round(a[0]*(1-t)+b[0]*t),Math.round(a[1]*(1-t)+b[1]*t),Math.round(a[2]*(1-t)+b[2]*t)];}
function save(cv,name){fs.writeFileSync(path.join(OUT,name),enc(cv.w,cv.h,cv.data));console.log('wrote',name,cv.w+'x'+cv.h);}
function ao(cv,cx,gy,rx,ry,strength=64){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const dx=x/rx,dy=y/ry;const d=dx*dx+dy*dy;if(d<=1.0)px(cv,cx+x,gy+y,[0,0,0],Math.round((1-d)*strength));}}
function glow(cv,cx,cy,r,col,peak=120){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1.0)px(cv,cx+x,cy+y,col,Math.round((1-d)*(1-d)*peak));}}

// palette — 창백한 상아·백은 + 희미한 호박빛 잔불 (desaturated counterpart to L4 amethyst+gold)
const IV=hex('#e6e0d4'), I_HI=hex('#f2eee4'), I_MID=hex('#9a9385'), I_SH=hex('#6b6459'),
  SIL=hex('#cdd0d4'), SIL_HI=hex('#eef0f3'), ASH=hex('#4a463f'),
  AMBER=hex('#e0a94a'), AMBER_DK=hex('#b0852f'), AMBER_HI=hex('#f4d089'),
  STONE=hex('#b7b0a2'), DKPANEL=hex('#2a2620'), DEEP=hex('#141119'), VOID=hex('#0b0910');

function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// =========================================================================
// GATHER OBJECTS — the 7 S-elements (small, non-blocking, plant on cell centre)
// =========================================================================

// ---- S1 성수 샘 (holy water font, still pale water). 90×90, foot y84. ----
(function holyFont(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,24,7,60);
  // a small ivory stone basin holding still water
  rect(cv,28,60,62,80,mix(STONE,I_SH,0.3));rect(cv,28,60,62,64,mix(STONE,I_HI,0.3));rect(cv,58,60,62,80,I_SH);
  const wcx=45,wcy=62;
  for(let y=-5;y<=4;y++)for(let x=-15;x<=15;x++){const d=(x/15)**2+(y/6)**2;if(d<=1)px(cv,wcx+x,wcy+y,hex('#a8bcc4'),210);}
  // still surface glint (아무도 이마를 적시지 않아)
  for(let x=-11;x<11;x++)px(cv,wcx+x,wcy-2,SIL_HI,110);
  glow(cv,wcx,wcy,10,hex('#c8d4d8'),40);
  save(cv,'l5_holy_font.png');})();

// ---- S2 빛바랜 성물 (faded relic pile). 90×90, foot y84. ----
(function relicPile(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,24,7,60);const r=deterministic(502);
  // a heap of faded, indistinct relics — cloth, metal, bone, all bleached
  const bits=[[30,60,16,14],[46,64,14,12],[38,52,12,11],[52,58,13,12]];
  for(const [bx,by,w,h] of bits){for(let y=0;y<h;y++)for(let x=0;x<w;x++){const t=y/h;const c=(t<0.4)?mix(IV,I_HI,0.3):(x<w*0.35?I_MID:I_SH);px(cv,bx+x,by+y,c,230);}
    px(cv,bx,by,mix(IV,I_HI,0.5),190);}
  // one faded relic keeps a faint warmth (손에 쥐면, 조금 따뜻하다)
  glow(cv,44,58,7,AMBER,30);px(cv,44,58,mix(AMBER,IV,0.5),140);
  save(cv,'l5_relic_pile.png');})();

// ---- S3 대리석 조각 (marble chunk, broken statue fragment). 90×90, foot y84. ----
(function marbleChunk(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,23,7,58);
  // a broken marble fragment — a hand or a fold of robe
  const mar=hex('#e2ddd2'),marHi=hex('#f4f1ea'),marSh=hex('#a8a294'),marVein=hex('#b8b0a0');
  const rocks=[[30,54,22,24],[48,62,16,16]];
  for(const [bx,by,w,h] of rocks){for(let y=0;y<h;y++)for(let x=0;x<w;x++){const t=y/h;const c=(t<0.4)?marHi:(x<w*0.35?mar:marSh);px(cv,bx+x,by+y,c,235);}}
  // subtle marble vein
  for(let i=0;i<24;i++){const x=30+i,y=62+Math.round(Math.sin(i*0.4)*4);px(cv,x,y,marVein,150);}
  // a chiselled edge highlight (성인상의 한 조각)
  for(let y=54;y<78;y++)px(cv,30,y,marHi,180);
  save(cv,'l5_marble_chunk.png');})();

// ---- S4 기도 구슬 (prayer beads, string of beads). 90×90, foot y84. ----
(function beadString(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,22,7,56);
  const bead=hex('#8a7a5a'),beadHi=hex('#b8a880'),beadSh=hex('#5a4c34'),cord=hex('#6b5a3a');
  // a loop of prayer beads laid on the ground
  const cx=44,cy=64,rx=20,ry=10;
  for(let a=0;a<360;a+=22){const bx=cx+Math.cos(a*Math.PI/180)*rx,by=cy+Math.sin(a*Math.PI/180)*ry;
    for(let dy=-3;dy<=3;dy++)for(let dx=-3;dx<=3;dx++){if(dx*dx+dy*dy<=9){const c=(dy<0?beadHi:(dy>1?beadSh:bead));px(cv,bx+dx,by+dy,c,235);}}
    px(cv,bx-1,by-1,beadHi,200);}
  // cord between beads
  for(let a=0;a<360;a+=6){const bx=cx+Math.cos(a*Math.PI/180)*rx,by=cy+Math.sin(a*Math.PI/180)*ry;px(cv,bx,by,cord,160);}
  save(cv,'l5_bead_string.png');})();

// ---- S5 성가 악보 (hymn sheet, sheet music paper). 90×90, foot y84. ----
(function hymnSheet(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,22,7,54);
  const pap=hex('#e4dcc4'),papHi=hex('#f2ecd8'),papSh=hex('#b8ac88'),ink=hex('#4a463f');
  // a curled sheet of hymn music
  for(let y=48;y<78;y++){const t=(y-48)/30;const curl=Math.round(Math.sin(t*3)*3);rect(cv,26+curl,y,66+curl,y+1,y<52?papHi:pap,230);}
  rect(cv,26,48,66,50,papHi,220);rect(cv,26,76,66,78,papSh,220);
  // faint staff lines + a few notes (음을 기억한다)
  for(let ln=0;ln<4;ln++){const yy=54+ln*5;for(let x=30;x<62;x++)px(cv,x,yy,ink,90);}
  for(const [nx,ny] of [[34,55],[40,60],[48,54],[54,63],[58,58]])px(cv,nx,ny,ink,180);
  save(cv,'l5_hymn_sheet.png');})();

// ---- S6 재의 날개 (ash wing, ash fallen from a stone angel). 90×90, foot y84. ----
(function ashWing(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,22,7,54);const r=deterministic(606);
  const feath=hex('#9a9488'),feathHi=hex('#c4beb0'),feathSh=hex('#5a544a'),ashc=hex('#6b665c');
  // a single broken stone-feather + drift of ash
  const fcx=48,fcy=60;
  for(let i=0;i<26;i++){const t=i/26;const x=fcx-18+i,y=fcy-Math.round(Math.sin(t*Math.PI)*10);const c=t<0.5?feathHi:feath;px(cv,x,y,c,225);px(cv,x,y+1,feathSh,200);px(cv,x,y+2,feath,180);}
  // barbs
  for(let i=0;i<26;i+=3){const t=i/26;const x=fcx-18+i,y=fcy-Math.round(Math.sin(t*Math.PI)*10);for(let b=0;b<4;b++)px(cv,x,y+2+b,mix(feath,feathSh,b/4),160);}
  // drifting ash below (날려던 방향만, 남아 있다)
  for(let n=0;n<18;n++){const ax=30+Math.floor(r()*36),ay=66+Math.floor(r()*12);px(cv,ax,ay,ashc,120+Math.floor(r()*60));}
  save(cv,'l5_ash_wing.png');})();

// ---- S7 신성한 잔불 (divine ember, dying spark). 90×90, foot y84. ----
(function divineEmber(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,20,6,52);
  const coal=hex('#3a342c'),coalHi=hex('#5a5248');
  // a small heap of dark coal/ash with a single fading ember at the top
  for(let y=-8;y<=6;y++)for(let x=-16;x<=16;x++){const d=(x/16)**2+(y/9)**2;if(d<=1){const c=y<-2?coalHi:coal;px(cv,44+x,66+y,c,225);}}
  // the ember (꺼지기 직전의 불씨) — small amber glow
  glow(cv,44,60,14,AMBER,90);glow(cv,44,60,7,AMBER_HI,110);
  px(cv,44,60,hex('#fff0d0'),240);px(cv,43,61,AMBER,220);px(cv,46,61,AMBER,200);
  // a wisp of rising warmth
  const r=deterministic(707);for(let n=0;n<14;n++){const t=n/14;const x=44+Math.round(Math.sin(t*6+r())*5);const y=56-Math.floor(t*30);px(cv,x,y,mix(AMBER,hex('#e8d8b8'),0.4),Math.round(80*(1-t)));}
  save(cv,'l5_divine_ember.png');})();

// =========================================================================
// GATE STRUCTURES
// =========================================================================

// ---- G1. 꺼진 등불 길 (lantern path over the dark walkway) off/on. 128×72. ----
function lanternPath(name,lit){const W=128,H=72,cv=C(W,H);
  const cx=64,cy=32;
  // ivory pavement deck (dark until lit)
  for(let y=0;y<64;y++)for(let x=0;x<W;x++){const d=Math.abs(x-cx)/64+Math.abs(y-cy)/32;if(d<=1){let c=lit?mix(IV,I_MID,0.3):mix(DEEP,I_SH,0.2);if(d>0.9)c=I_SH;px(cv,x,y,c,lit?235:200);}}
  // a row of lantern posts along both iso edges
  const post=lit?I_MID:hex('#2a2620');
  for(let x=22;x<106;x+=18){const y1=32+(x-64)*0.25-9,y2=32+(x-64)*0.25+9;
    for(const yy of [y1,y2]){rect(cv,x-1,yy-8,x+1,yy,post,220);
      // lantern head
      if(lit){glow(cv,x,yy-10,8,AMBER,140);px(cv,x,yy-10,AMBER_HI,240);px(cv,x,yy-9,AMBER,220);}
      else {px(cv,x,yy-10,hex('#2a2620'),220);px(cv,x,yy-9,I_SH,180);}}}
  if(lit)glow(cv,cx,cy,44,AMBER,50);
  save(cv,name);}
lanternPath('l5_lantern_path_off.png',false);
lanternPath('l5_lantern_path_on.png',true);

// ---- G2. 생명의 샘 밸브문 (life-spring valve door) closed/open. 128×128. ----
function lifeDoor(name,open){const W=128,H=128,cv=C(W,H);const cx=W/2;ao(cv,cx,120,32,9,68);
  // AP-2: 아이소 문턱 플린스 — 벽형 밸브문 접지.
  topDiamond(cv,cx,116,30,I_SH);
  for(let t=0;t<=30;t++){const yy=15*(1-t/30);px(cv,cx-t,116-yy,dk(I_SH,0.5));px(cv,cx+t,116-yy,dk(I_SH,0.5));px(cv,cx-t,116+yy,dk(I_SH,0.5));px(cv,cx+t,116+yy,dk(I_SH,0.5));}
  if(!open){
    rect(cv,30,36,64,116,mix(STONE,I_MID,0.3));rect(cv,64,36,98,116,mix(STONE,I_SH,0.25));
    rect(cv,30,36,98,40,mix(STONE,I_HI,0.4));
    rect(cv,62,36,66,116,I_SH);
    // a central valve wheel
    const vx=64,vy=74;for(let a=0;a<360;a+=45){for(let i=0;i<14;i++)px(cv,vx+Math.cos(a*Math.PI/180)*i,vy+Math.sin(a*Math.PI/180)*i,I_SH,220);}
    for(let a=0;a<360;a+=6){px(cv,vx+Math.cos(a*Math.PI/180)*15,vy+Math.sin(a*Math.PI/180)*15,AMBER_DK,180);}
    px(cv,vx,vy,AMBER_DK,210);
    // sealed indicator (dry, cold)
    glow(cv,64,30,10,hex('#3a4650'),110);px(cv,64,30,hex('#5a6a74'),190);
    rect(cv,26,32,30,118,I_SH);rect(cv,98,32,102,118,I_SH);
  } else {
    rect(cv,26,36,40,116,mix(STONE,I_MID,0.3));rect(cv,88,36,102,116,mix(STONE,I_MID,0.3));
    rect(cv,40,36,88,116,hex('#a8bcc4'),190);
    // water rising up the open sluice + faint amber
    for(let y=40;y<114;y+=2)px(cv,64,y,SIL_HI,180);glow(cv,64,76,28,hex('#c8d4d8'),80);
    glow(cv,64,30,10,AMBER,110);
    const r=deterministic(202);for(let n=0;n<18;n++){const t=n/18;const x=64+Math.round(Math.sin(t*7+r())*8);const y=110-Math.floor(t*72);px(cv,x,y,mix(SIL_HI,hex('#c8e0c0'),0.4),Math.round(90*(1-t)));}
  }
  save(cv,name);}
lifeDoor('l5_life_door_closed.png',false);
lifeDoor('l5_life_door_open.png',true);

// ---- G2 landmark. 생명의 샘 (life spring, 2×3) off/on. 176×160. ----
function lifeSpring(name,on){const W=176,H=160,cv=C(W,H);const cx=W/2;ao(cv,cx,H-8,46,11,72);
  // AP-2: 3/4 아이소 3단 아이보리 석재 분수 — 아이소 실린더 적층 (윗면 타원 || 바닥).
  isoCylinder(cv,cx,H-46,52,26,mix(STONE,I_HI,0.2),mix(STONE,I_MID,0.3),mix(STONE,I_SH,0.3),0.96);
  isoCylinder(cv,cx,H-74,38,24,mix(STONE,I_HI,0.2),mix(STONE,I_MID,0.3),mix(STONE,I_SH,0.3),0.96);
  isoCylinder(cv,cx,H-100,24,22,mix(STONE,I_HI,0.2),mix(STONE,I_MID,0.3),mix(STONE,I_SH,0.3),0.96);
  isoCylinder(cv,cx,54,9,H-152,mix(STONE,I_HI,0.15),mix(STONE,I_MID,0.3),mix(STONE,I_SH,0.3),1.0);
  const wcx=cx,wcy=H-58;
  if(on){// clear silver water rising + green-ivory life particles
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1)px(cv,wcx+x,wcy+y,hex('#b8ccc4'),210);}
    glow(cv,wcx,wcy,30,SIL_HI,90);
    for(let a=0;a<360;a+=8){const x=cx+Math.cos(a*Math.PI/180)*20,y=64+Math.sin(a*Math.PI/180)*10;px(cv,x,y,SIL_HI,200);}
    glow(cv,cx,64,20,hex('#d8e4dc'),110);
    const r=deterministic(3011);for(let n=0;n<22;n++){const t=n/22;const mx=cx+Math.round(Math.sin(t*7+r())*14);const my=60-Math.floor(t*44);px(cv,mx,my,r()<0.5?hex('#a8d0a0'):SIL_HI,Math.round(150*(1-t)));}
  } else {// dry cracked basin, white mineral marks only
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1)px(cv,wcx+x,wcy+y,hex('#c8c2b4'),210);}
    // dry cracks + white water-line stain
    const r=deterministic(31);for(let n=0;n<12;n++){const mx=cx-28+Math.floor(r()*56),my=wcy-4+Math.floor(r()*8);for(let i=0;i<6;i++)px(cv,mx+i,my+Math.round(Math.sin(i)*2),I_MID,140);}
    for(let x=-30;x<30;x++)px(cv,cx+x,wcy-6,I_HI,120);// water-line stain (하얀 자국)
  }
  save(cv,name);}
lifeSpring('l5_life_spring.png',false);
lifeSpring('l5_life_spring_on.png',true);

// ---- G3. 침묵의 회랑 입구 (silence corridor mouth, 2×2) closed/passed. 128×160. ----
function silenceGate(name,passed){const W=128,H=160,cv=C(W,H);const cx=W/2;ao(cv,cx,H-8,32,9,60);
  // AP-2: 아이소 문턱 플린스 — 회랑 입구(벽형 콜로네이드) 접지.
  topDiamond(cv,cx,H-14,30,mix(STONE,I_SH,0.4));
  for(let t=0;t<=30;t++){const yy=15*(1-t/30);px(cv,cx-t,H-14-yy,dk(I_SH,0.5));px(cv,cx+t,H-14-yy,dk(I_SH,0.5));px(cv,cx-t,H-14+yy,dk(I_SH,0.5));px(cv,cx+t,H-14+yy,dk(I_SH,0.5));}
  // ivory colonnade arch framing a hushed dark passage
  rect(cv,18,20,34,150,mix(STONE,I_MID,0.3));rect(cv,94,20,110,150,mix(STONE,I_MID,0.3));
  rect(cv,18,20,110,32,mix(STONE,I_HI,0.35));
  // fluted columns
  for(let cxp of [26,102])for(let y=32;y<150;y+=6)px(cv,cxp,y,I_SH,140);
  // the hushed inner passage — soft grey fade (소리가 삼켜지는 회랑)
  for(let y=32;y<150;y++){const t=(y-32)/118;const w=30-Math.round(t*4);for(let x=-w;x<=w;x++){const d=Math.abs(x)/w;px(cv,cx+x,y,mix(hex('#3a3830'),hex('#88857c'),d*0.6),Math.round(220-t*40));}}
  if(passed){// hymn passing — faint amber note-motes fill the corridor
    glow(cv,cx,80,40,AMBER,60);
    const r=deterministic(303);for(let n=0;n<20;n++){const x=cx-20+Math.floor(r()*40),y=40+Math.floor(r()*100);px(cv,x,y,mix(AMBER,I_HI,0.4),150);}
    // a few floating note glyphs
    for(const [nx,ny] of [[cx-12,60],[cx+8,88],[cx-4,116],[cx+14,44]]){px(cv,nx,ny,AMBER_HI,220);px(cv,nx,ny+2,AMBER,180);px(cv,nx+3,ny-3,AMBER,180);}
  }
  save(cv,name);}
silenceGate('l5_silence_gate.png',false);
silenceGate('l5_silence_gate_on.png',true);

// ---- G1 mount. 성소 등불 제단 (lantern altar, place slot) off/on. 96×96. ----
function lanternAltar(name,on){const W=96,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,24,7,64);
  // AP-2: 3/4 아이소 석재 제단 + 등불 받침은 윗면 마름모 중앙.
  const rx=24,h=28,ry=rx/2,topY=88-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(STONE,I_HI,0.15),mix(STONE,I_MID,0.3),I_SH);
  const sx=cx,sy=topY;
  // the lantern cradle
  for(let a=0;a<360;a+=30){const x=sx+Math.cos(a*Math.PI/180)*13,y=sy+Math.sin(a*Math.PI/180)*8;px(cv,x,y,on?AMBER:AMBER_DK,on?230:160);px(cv,x,y+1,I_SH,180);}
  if(on){// lantern lit — warm amber radiating
    glow(cv,sx,sy,16,AMBER,120);glow(cv,sx,sy,8,AMBER_HI,140);
    for(let a=0;a<360;a+=6)px(cv,sx+Math.cos(a*Math.PI/180)*7,sy+Math.sin(a*Math.PI/180)*7,mix(AMBER,hex('#fff0c8'),0.4),235);
    px(cv,sx,sy,hex('#fff0d0'),255);
  } else {
    for(let y=-6;y<=6;y++)for(let x=-6;x<=6;x++){if(x*x+y*y<=36)px(cv,sx+x,sy+y,DEEP,235);}// empty dark cradle
  }
  save(cv,name);}
lanternAltar('l5_lantern_altar.png',false);
lanternAltar('l5_lantern_altar_on.png',true);

// ---- G3 mount. 성가대 제단 (choir stand / lectern) off/on. 80×96. ----
function choirStand(name,on){const W=80,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,20,6,58);
  // AP-2: 아이소 박스 받침 스템 + 그 위 경사 성가 데스크(윗면 마름모 각도).
  isoBox(cv,cx,66,10,16,mix(STONE,I_HI,0.15),mix(STONE,I_MID,0.3),I_SH);
  // 경사 성가 데스크 — 마름모 윗면처럼 2:1 각도로 기운 판
  for(let i=0;i<34;i++){const x=cx-17+i,y=42-Math.round((i-17)*0.5);rect(cv,x,y,x+1,y+16,mix(STONE,I_HI,0.2),230);}
  for(let i=0;i<34;i++){const x=cx-17+i,y=42-Math.round((i-17)*0.5);px(cv,x,y,I_HI,220);}
  const hx=cx,hy=40;
  if(on){// hymn glyphs rise from the open sheet
    glow(cv,hx,hy,16,AMBER,120);
    for(const [nx,ny] of [[hx-6,hy-6],[hx+4,hy-10],[hx-2,hy-14]]){px(cv,nx,ny,AMBER_HI,230);px(cv,nx,ny+2,AMBER,190);}
    px(cv,hx,hy,hex('#fff0d0'),240);
  } else {// blank open sheet
    rect(cv,28,36,52,44,hex('#e4dcc4'),200);
    for(let ln=0;ln<3;ln++)for(let x=30;x<50;x++)px(cv,x,38+ln*2,I_MID,80);
  }
  save(cv,name);}
choirStand('l5_choir_stand.png',false);
choirStand('l5_choir_stand_on.png',true);

// ---- G4 mount. 대제단 봉헌대 (offering altar, place slot) off/on. 80×96. ----
function offeringAltar(name,on){const W=80,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,20,6,58);
  // AP-2: 3/4 아이소 석재 봉헌대 + 봉헌 소켓은 우측 광원면.
  const rx=19,h=50,ry=rx/2,topY=88-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(STONE,I_HI,0.2),mix(STONE,I_MID,0.3),I_SH);
  const hx=cx+6,hy=topY+ry+22;
  for(let a=0;a<360;a+=30){const x=hx+Math.cos(a*Math.PI/180)*11,y=hy+Math.sin(a*Math.PI/180)*11;px(cv,x,y,on?AMBER:AMBER_DK,on?220:160);px(cv,x,y+1,I_SH,180);}
  if(on){glow(cv,hx,hy,20,AMBER,180);glow(cv,hx,hy,11,AMBER_HI,160);
    for(let a=0;a<360;a+=6)px(cv,hx+Math.cos(a*Math.PI/180)*6,hy+Math.sin(a*Math.PI/180)*6,mix(AMBER,hex('#fff0c8'),0.4),235);
    px(cv,hx,hy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=45)for(let i=7;i<13;i++)px(cv,hx+Math.cos(a*Math.PI/180)*i,hy+Math.sin(a*Math.PI/180)*i,AMBER,150);
    for(let x=0;x<12;x++)px(cv,hx-6+x,hy+16+(x)*0.4,AMBER,230);
  } else {
    for(let y=-7;y<=7;y++)for(let x=-7;x<=7;x++){if(x*x+y*y<=49)px(cv,hx+x,hy+y,DEEP,235);}
    for(let x=0;x<4;x++)px(cv,hx-6+x,hy+16+(x)*0.4,AMBER_DK,170);
  }
  save(cv,name);}
offeringAltar('l5_offering_altar.png',false);
offeringAltar('l5_offering_altar_on.png',true);

// ---- 순례자의 발전 제단 A (pilgrim dynamo, energy re-grant) off/on. 80×96. ----
function reliquaryBox(name,on,coreCol,coreDk,coreHi){const W=80,H=96,cv=C(W,H);const cx=W/2;ao(cv,cx,88,20,6,58);
  // AP-2: 3/4 아이소 석재 함체 + 발전/성물 다이얼은 우측 광원면.
  const rx=18,h=48,ry=rx/2,topY=88-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(STONE,I_HI,0.2),mix(STONE,I_MID,0.3),I_SH);
  const hx=cx+5,hy=topY+ry+20;
  const col=on?coreCol:coreDk;
  for(let a=0;a<360;a+=30){const x=hx+Math.cos(a*Math.PI/180)*10,y=hy+Math.sin(a*Math.PI/180)*10;px(cv,x,y,col,on?220:150);}
  if(on){glow(cv,hx,hy,16,coreCol,150);px(cv,hx,hy,coreHi,240);for(let x=0;x<12;x++)px(cv,hx-6+x,hy+15+(x)*0.4,coreCol,220);}
  else for(let y=-7;y<=7;y++)for(let x=-7;x<=7;x++){if(x*x+y*y<=49)px(cv,hx+x,hy+y,DEEP,230);}
  save(cv,name);}
// 순례자 발전 제단 (에너지 재화 색 계승 — L2 시안)
const pilgrimDynamo=(name,on)=>reliquaryBox(name,on,hex('#5ad0e0'),hex('#3a6a72'),hex('#d0f4ff'));
pilgrimDynamo('l5_pilgrim_dynamo.png',false);
pilgrimDynamo('l5_pilgrim_dynamo_on.png',true);

// ---- 마력 성물함 B (mana reliquary, mana re-grant) off/on. 80×96. (마력 재화 색 계승 — L4 보라)
const manaReliquary=(name,on)=>reliquaryBox(name,on,hex('#a878e0'),hex('#5a4670'),hex('#e0d0ff'));
manaReliquary('l5_mana_reliquary.png',false);
manaReliquary('l5_mana_reliquary_on.png',true);

// ---- G4 landmark. 대제단 (GREAT ALTAR, 3×3 tall) off/on. 256×320. ----
function greatAltar(name,lit){const W=256,H=320,cv=C(W,H);const cx=W/2;ao(cv,cx,306,66,14,78);
  // AP-2: 계단형 받침을 아이소 마름모 2단으로. 첨탑 샤프트는 유지(랜드마크).
  isoBox(cv,cx,286,70,20,mix(I_HI,I_MID,0.2),mix(I_SH,I_MID,0.5),dk(I_SH,0.2));
  isoBox(cv,cx,258,58,22,mix(IV,I_HI,0.2),mix(IV,I_MID,0.4),I_SH);
  // tapering shaft (a great pale altar/pillar)
  for(let y=110;y<252;y++){const t=(y-110)/142;const hw=Math.round(30+t*24);const c=mix(mix(IV,I_MID,0.3),I_SH,t*0.4);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+3,y+1,mix(c,I_HI,0.35));rect(cv,cx+hw-3,y,cx+hw,y+1,I_SH);}
  for(const by of [150,190,230]){rect(cv,cx-40,by,cx+40,by+4,I_SH,180);for(let rx=cx-36;rx<cx+36;rx+=12)px(cv,rx,by+2,lit?AMBER:AMBER_DK,180);}
  // altar head housing the divine ember
  rect(cv,cx-56,44,cx+56,116,mix(IV,I_MID,0.4));rect(cv,cx-56,44,cx+56,48,mix(I_MID,I_HI,0.5));
  rect(cv,cx-60,112,cx+60,120,I_SH);
  // the ember cavity
  const fcx=cx,fcy=80,fr=40;
  const cavity=lit?hex('#5a4620'):hex('#2a2620');
  for(let y=-fr;y<=fr;y++)for(let x=-fr;x<=fr;x++){if(x*x+y*y<=fr*fr)px(cv,fcx+x,fcy+y,cavity,245);}
  for(let a=0;a<360;a+=2)px(cv,fcx+Math.cos(a*Math.PI/180)*fr,fcy+Math.sin(a*Math.PI/180)*fr,lit?AMBER:I_MID,235);
  if(!lit){
    // dying ember — a single faint spark, almost out (신의 잔불, 꺼지기 직전)
    glow(cv,fcx,fcy,fr,hex('#2a2018'),50);
    glow(cv,fcx,fcy,10,AMBER_DK,60);px(cv,fcx,fcy,AMBER_DK,180);
  } else {
    // response heard — warm amber concentric rings, settled and steady
    for(let ring=8;ring<=fr-4;ring+=8)for(let a=0;a<360;a+=6)px(cv,fcx+Math.cos(a*Math.PI/180)*ring,fcy+Math.sin(a*Math.PI/180)*ring,AMBER,180);
    glow(cv,fcx,fcy,fr+6,AMBER,90);px(cv,fcx,fcy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=30)for(let i=fr-4;i<fr+8;i++)px(cv,fcx+Math.cos(a*Math.PI/180)*i,fcy+Math.sin(a*Math.PI/180)*i,AMBER,140);
  }
  // finial + beacon
  rect(cv,cx-4,20,cx+4,46,I_SH);rect(cv,cx-4,20,cx-1,46,mix(I_SH,I_HI,0.3));
  px(cv,cx,16,lit?hex('#fff0d0'):hex('#3a342c'),lit?255:200);
  if(lit)glow(cv,cx,18,12,AMBER,200);else glow(cv,cx,18,7,AMBER_DK,60);
  save(cv,name);}
greatAltar('l5_great_altar.png',false);
greatAltar('l5_great_altar_on.png',true);

// =========================================================================
// LANDMARK / DECO OBJECTS
// =========================================================================

// ---- 무너진 회랑 기둥 (collapsed colonnade pillars, blocks). 112×96. ----
(function ruinedColumns(){const W=112,H=96,cv=C(W,H);ao(cv,W/2,90,32,8,66);
  const runs=[[24,12],[42,14],[60,10],[78,15],[96,9]];
  for(const [px0,w] of runs){const brk=40+Math.floor(((px0*7)%30));// each column broken at a different height
    for(let y=brk;y<88;y++)for(let x=0;x<w;x++){const t=x/w;const c=t<0.3?I_HI:(t<0.7?I_MID:I_SH);px(cv,px0+x,y,c,240);}
    // jagged broken top
    rect(cv,px0-1,brk,px0+w+1,brk+3,I_SH);rect(cv,px0-1,brk,px0+w+1,brk+1,mix(I_SH,I_HI,0.4));
    // fluting
    for(let y=brk+4;y<88;y+=5)px(cv,px0+w/2,y,I_SH,120);}
  save(cv,'l5_ruined_columns.png');})();

// ---- 생명의 샘 랜드마크 (life spring silhouette landmark, dry). 176×160. ----
(function springLandmark(){const W=176,H=160,cv=C(W,H);const cx=W/2;ao(cv,cx,H-8,46,11,72);
  // AP-2: 마른 분수 랜드마크 — 아이소 3단 실린더(어두운 마른 톤).
  isoCylinder(cv,cx,H-46,54,26,mix(STONE,I_MID,0.2),mix(STONE,I_SH,0.35),dk(mix(STONE,I_SH,0.4),0.15),0.96);
  isoCylinder(cv,cx,H-76,40,26,mix(STONE,I_MID,0.2),mix(STONE,I_SH,0.35),dk(mix(STONE,I_SH,0.4),0.15),0.96);
  isoCylinder(cv,cx,H-104,26,24,mix(STONE,I_MID,0.2),mix(STONE,I_SH,0.35),dk(mix(STONE,I_SH,0.4),0.15),0.96);
  isoCylinder(cv,cx,50,9,H-154,mix(STONE,I_MID,0.15),mix(STONE,I_SH,0.3),dk(mix(STONE,I_SH,0.4),0.15),1.0);
  const wcy=H-58;
  for(let y=-8;y<=6;y++)for(let x=-36;x<=36;x++){const d=(x/36)**2+(y/9)**2;if(d<=1)px(cv,cx+x,wcy+y,hex('#c8c2b4'),210);}
  // white water-line stain (하얀 자국만 남았다)
  for(let x=-32;x<32;x++)px(cv,cx+x,wcy-6,I_HI,110);
  save(cv,'l5_spring_landmark.png');})();

// ---- 꺼진 등불 (extinguished lantern deco, blocks small). 90×110. ----
(function deadLantern(){const W=90,H=110,cv=C(W,H);const cx=W/2;ao(cv,cx,102,22,7,60);
  // AP-2: 아이소 받침 플린스 위 등불 기둥 — 접지 정합.
  topDiamond(cv,cx,100,16,I_SH);
  for(let t=0;t<=16;t++){const yy=8*(1-t/16);px(cv,cx-t,100-yy,dk(I_SH,0.5));px(cv,cx+t,100-yy,dk(I_SH,0.5));px(cv,cx-t,100+yy,dk(I_SH,0.5));px(cv,cx+t,100+yy,dk(I_SH,0.5));}
  // a tall lantern post, dark and cold
  rect(cv,42,40,48,98,mix(STONE,I_MID,0.3));rect(cv,42,40,44,98,mix(STONE,I_HI,0.2));
  // lantern housing (unlit)
  rect(cv,36,20,54,42,mix(STONE,I_SH,0.3));rect(cv,36,20,54,23,mix(STONE,I_HI,0.3));
  for(let y=23;y<40;y++)for(let x=38;x<52;x++)px(cv,x,y,DEEP,220);// dark glass
  px(cv,45,32,AMBER_DK,120);// the tiniest cold coal inside
  save(cv,'l5_dead_lantern.png');})();

// ---- 석화 피조물 (petrified creatures, 3 poses — investigate "마지막 기도"). 90×150 each. ----
// Stone-grey statue frozen mid-prayer; the "last prayer" gold flicker added at runtime.
function petrified(name,pose){const W=90,H=150,cv=C(W,H);const cx=44;ao(cv,W/2,144,24,8,60);
  const st=hex('#b0aa9c'),stHi=hex('#d4cec0'),stSh=hex('#78726a');
  // a small hunched figure turned to stone, hands gathered
  if(pose==='kneeling'){
    for(let y=88;y<140;y++){const t=(y-88)/52;const hw=Math.round(14+t*12);rect(cv,cx-hw,y,cx+hw,y+1,st);px(cv,cx-hw,y,stSh);px(cv,cx+hw-1,y,stHi);}
    for(let y=68;y<90;y++){const t=(y-68)/22;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw,y,cx+hw,y+1,st);}
    px(cv,cx-2,78,stSh);px(cv,cx+3,78,stSh);
    // hands gathered in prayer at chest
    for(let i=0;i<10;i++)px(cv,cx-4+i*0.8,96+i*0.3,stHi);for(let i=0;i<10;i++)px(cv,cx+4-i*0.8,96+i*0.3,stHi);
  } else if(pose==='reaching'){
    for(let y=70;y<140;y++){const t=(y-70)/70;const hw=Math.round(11+t*13);rect(cv,cx-hw,y,cx+hw,y+1,st);px(cv,cx-hw,y,stSh);}
    for(let y=50;y<72;y++){const t=(y-50)/22;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw,y,cx+hw,y+1,st);}
    px(cv,cx-2,60,stSh);px(cv,cx+3,60,stSh);
    // one arm reaching upward (toward a god who never answered)
    for(let i=0;i<28;i++)px(cv,cx+12+i*0.4,78-i*0.9,stHi);
  } else { // standing, head bowed
    for(let y=68;y<140;y++){const t=(y-68)/72;const hw=Math.round(10+t*14);rect(cv,cx-hw,y,cx+hw,y+1,st);px(cv,cx-hw,y,stSh);px(cv,cx+hw-1,y,stHi);}
    for(let y=48;y<70;y++){const t=(y-48)/22;const hw=Math.round(12-Math.abs(t-0.4)*7);rect(cv,cx-hw,y,cx+hw,y+1,st);}
    px(cv,cx-2,60,stSh);px(cv,cx+3,60,stSh);
    for(let i=0;i<9;i++)px(cv,cx-3+i*0.7,84+i*0.3,stHi);for(let i=0;i<9;i++)px(cv,cx+3-i*0.7,84+i*0.3,stHi);
  }
  // a faint amber ember mote at the chest (마지막 기도의 온기)
  glow(cv,cx,pose==='reaching'?94:98,7,AMBER,34);
  save(cv,name);}
petrified('l5_petrified_kneeling.png','kneeling');
petrified('l5_petrified_reaching.png','reaching');
petrified('l5_petrified_standing.png','standing');

// ---- 성가대석 데코 (choir seats deco). 128×96. ----
(function choirSeats(){const W=128,H=96,cv=C(W,H);ao(cv,W/2,88,36,9,64);
  // rows of empty ivory pews
  for(let row=0;row<3;row++){const y=48+row*14,x0=20+row*4,x1=108-row*4;
    rect(cv,x0,y,x1,y+8,mix(STONE,I_MID,0.3));rect(cv,x0,y,x1,y+2,mix(STONE,I_HI,0.3));rect(cv,x0,y+8,x1,y+10,I_SH);
    // back rest
    rect(cv,x0,y-10,x1,y,mix(STONE,I_SH,0.2));}
  // one open hymnal on the front pew
  rect(cv,56,44,72,50,hex('#e4dcc4'),200);
  save(cv,'l5_choir_seats.png');})();

// ---- L5 봉헌대/정비대 (workbench, ivory with AMBER fusion aperture). 128×112. ----
(function workbench(){const W=128,H=112,cv=C(W,H);const cx=W/2;ao(cv,cx,104,34,9,66);
  // AP-2: 3/4 아이소 박스 + 윗면 worktop에 앰버 융합 개구부.
  const rx=34,h=40,ry=rx/2,topY=104-h-ry;
  isoBox(cv,cx,topY,rx,h,mix(STONE,I_HI,0.15),mix(STONE,I_MID,0.3),I_SH);
  const ax=cx,ay=topY;
  glow(cv,ax,ay,24,AMBER_DK,100);glow(cv,ax,ay,15,AMBER,130);
  for(let a=0;a<360;a+=20)px(cv,ax+Math.cos(a*Math.PI/180)*10,ay+Math.sin(a*Math.PI/180)*5,mix(AMBER_DK,AMBER,0.6),210);
  px(cv,ax,ay,hex('#fff0d0'),240);
  for(let i=0;i<18;i++)px(cv,cx-14+i,topY-6-i*0.3,I_HI);px(cv,cx+4,topY-12,AMBER,200);
  const gx=cx+rx-14,gy=topY+ry+12;
  for(let y=0;y<18;y++)for(let x=0;x<8;x++)px(cv,gx+x,gy+y+(x)*0.5,DKPANEL,255);
  for(let x=0;x<6;x++)px(cv,gx+1+x,gy+3+(1+x)*0.5,AMBER,200);
  save(cv,'l5_workbench.png');})();

// =========================================================================
// SMALL SCATTER BITS + light pool
// =========================================================================

// ---- l5_debris_marble — tiny loose marble fleck. 48×48. ----
(function debrisMarble(){const W=48,H=48,cv=C(W,H);ao(cv,W/2,42,10,4,54);
  const bx=18,by=26;rect(cv,bx,by,bx+10,by+6,hex('#d4cec0'));rect(cv,bx,by,bx+10,by+1,hex('#f0ece2'));
  px(cv,bx+4,by+3,I_MID,160);px(cv,bx+2,by+1,I_HI,220);
  save(cv,'l5_debris_marble.png');})();

// ---- l5_debris_ash — pale ash wisp. 48×48. ----
(function debrisAsh(){const W=48,H=48,cv=C(W,H);const r=deterministic(4848);const ash=hex('#6b665c');
  for(let n=0;n<20;n++){const ax=14+Math.floor(r()*20),ay=26+Math.floor(r()*14);px(cv,ax,ay,ash,120);px(cv,ax+1,ay,mix(ash,AMBER,0.1),80);}
  for(let n=0;n<3;n++)px(cv,18+Math.floor(r()*14),28+Math.floor(r()*8),mix(AMBER_DK,ash,0.5),140);
  save(cv,'l5_debris_ash.png');})();

// ---- light_pool_amber.png — soft amber radial glow pool (used by the gate controller). 96×96. ----
(function lightPoolAmber(){const W=96,H=96,cv=C(W,H);
  glow(cv,W/2,H/2,46,AMBER,130);glow(cv,W/2,H/2,26,AMBER_HI,80);
  save(cv,'light_pool_amber.png');})();

console.log('L5 objects done.');
