'use strict';
// L4-1 — Magic-world (Layer 4) 「봉인이 풀린 마탑」 OBJECT art generator. Deterministic PNGs with
// AO contact shadows, matching L2/L3 object fidelity. Ground origin = bottom-center of canvas.
// Palette per design Part C §C-1: 자수정 보라 base + 금색 룬 발광 #f2c14e (the arcane counterpart
// to L3's copper+orange). States off/on encoded as separate PNGs (the gate controller swaps to
// the _on variant). Also emits light_pool_gold.png (금색 발광 풀, orange 대응).
// Produces into assets/objects/  (l4_*.png). Run: NODE_PATH=... node tools_gen_l4_objects.js
const zlib = require('zlib'), fs = require('fs'), path = require('path');
const OUT = path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects');

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

// palette — 자수정 보라 + 금색 룬 발광 (arcane counterpart to L3 copper+orange)
const AME=hex('#2a1f3d'), P_HI=hex('#7a5cae'), P_MID=hex('#4a3670'), P_SH=hex('#221830'),
  GOLD=hex('#f2c14e'), GOLD_DK=hex('#c99a34'), STONE=hex('#5a4a6a'),
  DKPANEL=hex('#150e22'), DEEP=hex('#0e0a18'), VOID=hex('#060410');

function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// =========================================================================
// GATHER OBJECTS — the 7 P-elements (small, non-blocking, plant on cell centre)
// =========================================================================

// ---- P1 룬석 노두 (rune-stone outcrop, faint gold glyph). 90×90, foot y84. ----
(function runeNode(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,24,7,66);const r=deterministic(141);
  // a cluster of angular amethyst stones with a faint engraved rune
  const rocks=[[30,58,20,18],[46,64,18,14],[38,50,14,12],[54,56,16,13]];
  for(const [bx,by,w,h] of rocks){for(let y=0;y<h;y++)for(let x=0;x<w;x++){const t=y/h;const c=(t<0.4)?mix(AME,P_HI,0.4):(x<w*0.35?P_MID:P_SH);px(cv,bx+x,by+y,c,235);}
    px(cv,bx,by,mix(AME,P_HI,0.6),200);}// top glint
  // faint golden rune glyph on the biggest face
  for(let a=0;a<360;a+=72){const gx=40+Math.cos(a*Math.PI/180)*6,gy=62+Math.sin(a*Math.PI/180)*4;px(cv,gx,gy,GOLD,150);}
  px(cv,40,62,GOLD,180);glow(cv,40,62,6,GOLD,40);
  save(cv,'l4_rune_node.png');})();

// ---- P2 마력 결정 정동 (mana geode, glowing violet crystal cluster). 90×90, foot y84. ----
(function manaGeode(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,23,7,60);
  // geode shell + upstanding glowing crystals
  const gcx=44,gcy=64;
  for(let y=-10;y<=8;y++)for(let x=-22;x<=22;x++){const d=(x/22)**2+(y/12)**2;if(d<=1)px(cv,gcx+x,gcy+y,mix(AME,P_SH,0.4),220);}
  const crystals=[[38,60,4,20],[46,58,5,26],[52,62,4,18],[42,64,3,14],[56,64,3,12]];
  for(const [bx,base,w,h] of crystals){for(let y=0;y<h;y++){const yy=base-y;const ww=Math.max(1,Math.round(w*(1-y/h*0.5)));for(let x=-ww;x<=ww;x++){const t=(x+ww)/(2*ww);const c=mix(P_MID,P_HI,0.4+t*0.4);px(cv,bx+x,yy,c,235);}}
    for(let y=0;y<h;y++)px(cv,bx-Math.round(w*(1-y/h*0.5)),base-y,mix(P_HI,hex('#c8a8ff'),0.5),200);}// rim light
  glow(cv,46,54,16,hex('#9a6ad0'),90);glow(cv,46,54,8,hex('#c8a8ff'),110);
  save(cv,'l4_mana_geode.png');})();

// ---- P3 은가루 광맥 (silver dust vein). 90×90, foot y84. ----
(function silverVein(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,23,7,60);const r=deterministic(303);
  // an amethyst rock shelf shot through with a bright silver seam
  const rocks=[[28,58,24,18],[48,62,18,15]];
  for(const [bx,by,w,h] of rocks){for(let y=0;y<h;y++)for(let x=0;x<w;x++){const c=(y<h*0.4)?mix(AME,P_HI,0.3):P_SH;px(cv,bx+x,by+y,c,235);}}
  // bright silver seam winding through
  const sil=hex('#d8d8e8'),silHi=hex('#f4f4ff'),silSh=hex('#9a9ab0');
  for(let i=0;i<40;i++){const x=28+i,y=64+Math.round(Math.sin(i*0.3)*5);px(cv,x,y,sil,235);px(cv,x,y-1,silHi,200);px(cv,x,y+1,silSh,190);}
  // silver dust sparkle flecks
  for(let n=0;n<8;n++)px(cv,30+Math.floor(r()*36),58+Math.floor(r()*16),silHi,220);
  save(cv,'l4_silver_vein.png');})();

// ---- P4 양피지 두루마리 (vellum scroll roll). 90×90, foot y84. ----
(function vellumRoll(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,22,7,58);
  const vel=hex('#d8c8a0'),velHi=hex('#f0e4c4'),velSh=hex('#a89468'),tie=hex('#7a5a34');
  // a rolled scroll lying down + one half-unfurled
  for(let y=-9;y<=9;y++)for(let x=-24;x<=24;x++){const d=(x/24)**2+(y/10)**2;if(d<=1){const c=y<0?velHi:(y>4?velSh:vel);px(cv,44+x,66+y,c,235);}}
  // roll end caps (spiral)
  for(let a=0;a<Math.PI*4;a+=0.3){const rad=1+a*0.8;px(cv,22+Math.cos(a)*rad,66+Math.sin(a)*rad*0.6,mix(vel,velSh,0.5),220);}
  // half-unfurled sheet with a faint gold rune line
  rect(cv,44,56,72,68,vel,225);rect(cv,44,56,72,58,velHi,220);
  for(let x=48;x<68;x+=4)px(cv,x,62,GOLD_DK,130);
  // binding tie
  rect(cv,42,58,46,74,tie,220);
  save(cv,'l4_vellum_roll.png');})();

// ---- P5 봉인 밀랍 덩이 (sealing wax lump, dark red-violet). 90×90, foot y84. ----
(function waxLump(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,22,7,60);const r=deterministic(505);
  const wax=hex('#7a2c44'),waxHi=hex('#b04a68'),waxSh=hex('#4a1828');
  // a molten-then-cooled wax blob with drips
  for(let y=-12;y<=10;y++)for(let x=-20;x<=20;x++){const d=(x/20)**2+(y/14)**2;if(d<=1){const c=y<-2?waxHi:(y>6?waxSh:wax);px(cv,44+x,62+y,c,235);}}
  // a couple of drips hanging below
  for(const dx of [34,52]){for(let i=0;i<10;i++)px(cv,dx,72+i,mix(wax,waxSh,i/10),225);px(cv,dx,82,waxSh,220);}
  // a pressed seal impression on top (golden rim)
  for(let a=0;a<360;a+=20)px(cv,44+Math.cos(a*Math.PI/180)*8,58+Math.sin(a*Math.PI/180)*4,GOLD_DK,180);
  glow(cv,44,58,6,waxHi,50);
  save(cv,'l4_wax_lump.png');})();

// ---- P6 별빛 이슬 웅덩이 (starlight dew pool, faint blue-gold shimmer). 96×72. ----
(function dewPool(){const W=96,H=72,cv=C(W,H);ao(cv,W/2,66,26,6,42);
  const pcx=48,pcy=56,rx=28,ry=9;const water=hex('#1a1e3a');
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const d=(x/rx)**2+(y/ry)**2;if(d<=1){const a=Math.round(210*(1-d*0.3));px(cv,pcx+x,pcy+y,water,a);}}
  // reflective star-shimmer band
  for(let x=-rx+6;x<rx-6;x++){const y=pcy-3;px(cv,pcx+x,y,mix(water,hex('#cfd4ff'),0.3),120);px(cv,pcx+x,y-1,mix(water,GOLD,0.2),80);}
  glow(cv,pcx,pcy,16,hex('#6a7ad0'),30);
  // tiny star points floating on the surface
  const r=deterministic(606);for(let n=0;n<10;n++){const sx=pcx-20+Math.floor(r()*40),sy=pcy-5+Math.floor(r()*10);px(cv,sx,sy,r()<0.5?hex('#e8ecff'):GOLD,200);}
  // faint rising shimmer wisp
  for(let n=0;n<20;n++){const t=n/20;const x=pcx+Math.round(Math.sin(t*6+r())*7);const y=52-Math.floor(t*38);px(cv,x,y,mix(hex('#c8d0ff'),GOLD,0.3),Math.round(60*(1-t)));}
  save(cv,'l4_dew_pool.png');})();

// ---- P7 공허 파편 (void shard, cold black glass with cracked-space rim). 90×90, foot y84. ----
(function voidShard(){const W=90,H=90,cv=C(W,H);ao(cv,W/2,84,20,6,50);
  const vd=hex('#0a0818'),vdRim=hex('#3a2c5a'),star=hex('#aeb4ff');
  // jagged upstanding void shards (near-black, weightless)
  const shards=[[38,80,10,28],[48,82,8,32],[44,84,6,22],[56,80,7,24]];
  for(const [bx,base,w,h] of shards){for(let y=0;y<h;y++){const yy=base-y;const ww=Math.max(1,Math.round(w*(1-y/h)));for(let x=-ww/2;x<=ww/2;x++){px(cv,bx+x,yy,vd,220);}}
    for(let y=0;y<h;y++){const yy=base-y;const ww=Math.max(1,Math.round(w*(1-y/h)));px(cv,bx-ww/2,yy,vdRim,180);}}// cold rim
  // a couple of star points glimmering from inside the void
  const r=deterministic(707);for(let n=0;n<5;n++){const gx=40+Math.floor(r()*18),gy=58+Math.floor(r()*22);px(cv,gx,gy,star,160);}
  save(cv,'l4_void_shard.png');})();

// =========================================================================
// GATE STRUCTURES
// =========================================================================

// ---- G1. 룬 다리 (light rune bridge over the void) off/on. 128×72. ----
function runeBridge(name,lit){const W=128,H=72,cv=C(W,H);
  const cx=64,cy=32;
  // deck diamond over the void gap
  for(let y=0;y<64;y++)for(let x=0;x<W;x++){const d=Math.abs(x-cx)/64+Math.abs(y-cy)/32;if(d<=1){let c=lit?mix(AME,P_MID,0.5):mix(VOID,P_SH,0.25);if(d>0.9)c=P_SH;px(cv,x,y,c,lit?235:200);}}
  // golden rune rails running along both iso edges
  const rail=lit?GOLD:hex('#2a2038');
  for(let x=20;x<108;x++){const y1=32+(x-64)*0.25-8,y2=32+(x-64)*0.25+8;
    px(cv,x,y1,rail,lit?230:150);px(cv,x,y2,rail,lit?230:150);
    if(x%6===0){px(cv,x,y1-2,rail,lit?220:140);px(cv,x,y2+2,rail,lit?220:140);}// rune studs
    if(lit){px(cv,x,y1+1,rail,90);px(cv,x,y2-1,rail,90);}}
  // rune glyph seam down the deck centre
  for(let x=40;x<88;x+=4)px(cv,x,32+(x-64)*0.25,lit?GOLD:hex('#1a1428'),lit?200:60);
  if(lit)glow(cv,cx,cy,42,GOLD,66);
  save(cv,name);}
runeBridge('l4_rune_bridge_off.png',false);
runeBridge('l4_rune_bridge_on.png',true);

// ---- G2. 결계 밸브문 (ward blast-door) closed/open. 128×128. ----
function wardDoor(name,open){const W=128,H=128,cv=C(W,H);ao(cv,W/2,120,30,8,70);
  if(!open){
    rect(cv,30,36,64,116,P_MID);rect(cv,64,36,98,116,mix(P_MID,P_SH,0.25));
    rect(cv,30,36,98,40,mix(P_MID,P_HI,0.45));
    rect(cv,62,36,66,116,P_SH);
    // a big central ward sigil wheel
    const vx=64,vy=74;for(let a=0;a<360;a+=45){for(let i=0;i<14;i++)px(cv,vx+Math.cos(a*Math.PI/180)*i,vy+Math.sin(a*Math.PI/180)*i,P_SH,220);}
    for(let a=0;a<360;a+=6){px(cv,vx+Math.cos(a*Math.PI/180)*15,vy+Math.sin(a*Math.PI/180)*15,GOLD_DK,200);}
    glow(cv,vx,vy,6,P_MID,60);px(cv,vx,vy,GOLD_DK,220);
    // ward glyph chevrons
    for(let i=0;i<3;i++){const yy=46+i*22;for(let k=0;k<8;k++){px(cv,40+k,yy+k,hex('#8a6ac8'),120);px(cv,88-k,yy+k,hex('#8a6ac8'),120);}}
    // dark sealed indicator
    glow(cv,64,30,10,hex('#5a2c6a'),120);px(cv,64,30,hex('#9a4aca'),200);
    rect(cv,26,32,30,118,P_SH);rect(cv,98,32,102,118,P_SH);
  } else {
    rect(cv,26,36,40,116,P_MID);rect(cv,88,36,102,116,P_MID);
    rect(cv,40,36,88,116,DEEP,180);
    for(let y=40;y<114;y+=2)px(cv,64,y,GOLD,180);glow(cv,64,76,28,GOLD,90);
    glow(cv,64,30,10,GOLD,140);
    // golden ward mote curling up the open corridor
    const r=deterministic(202);for(let n=0;n<20;n++){const t=n/20;const x=64+Math.round(Math.sin(t*7+r())*8);const y=110-Math.floor(t*72);px(cv,x,y,mix(hex('#e8d8b0'),GOLD,0.4),Math.round(90*(1-t)));}
  }
  save(cv,name);}
wardDoor('l4_ward_door_closed.png',false);
wardDoor('l4_ward_door_open.png',true);

// ---- G2 landmark. 마력샘/결계 분수 (mana spring / ward fountain, 2×3) off/on. 176×160. ----
function manaSpring(name,on){const W=176,H=160,cv=C(W,H);ao(cv,W/2,H-8,46,11,74);
  const cx=W/2;
  // stone basin (three tiers)
  rect(cv,cx-52,H-40,cx+52,H-14,mix(STONE,P_SH,0.4));rect(cv,cx-52,H-40,cx+52,H-36,mix(STONE,P_HI,0.3));
  rect(cv,cx-38,H-70,cx+38,H-40,mix(STONE,P_SH,0.3));
  rect(cv,cx-24,H-96,cx+24,H-70,mix(STONE,P_SH,0.3));
  // central pillar
  rect(cv,cx-8,54,cx+8,H-96,mix(STONE,P_MID,0.3));
  const wcx=cx,wcy=H-58;
  if(on){// clear water + rotating golden ward + violet-gold mana particles
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1)px(cv,wcx+x,wcy+y,hex('#3a4a8a'),210);}
    glow(cv,wcx,wcy,30,hex('#6a7ad0'),90);
    // rotating golden ward ring around the pillar top
    for(let a=0;a<360;a+=8){const x=cx+Math.cos(a*Math.PI/180)*20,y=64+Math.sin(a*Math.PI/180)*10;px(cv,x,y,GOLD,220);}
    glow(cv,cx,64,20,GOLD,120);
    const r=deterministic(3011);for(let n=0;n<22;n++){const t=n/22;const mx=cx+Math.round(Math.sin(t*7+r())*14);const my=60-Math.floor(t*44);px(cv,mx,my,r()<0.5?GOLD:hex('#c8a8ff'),Math.round(150*(1-t)));}
  } else {// murky black-tinged water, no ward
    for(let y=-8;y<=6;y++)for(let x=-34;x<=34;x++){const d=(x/34)**2+(y/9)**2;if(d<=1)px(cv,wcx+x,wcy+y,hex('#181428'),215);}
    glow(cv,wcx,wcy,18,hex('#2a1a3a'),80);
    // faint dark tendrils of the escaped thing
    const r=deterministic(31);for(let n=0;n<10;n++){const mx=cx-18+Math.floor(r()*36),my=wcy-4-Math.floor(r()*10);px(cv,mx,my,hex('#3a2a4a'),140);}
  }
  save(cv,name);}
manaSpring('l4_mana_spring.png',false);
manaSpring('l4_mana_spring_on.png',true);

// ---- G3. 거대 균열 / 봉인 균열문 (great crack / sealed rift, 2×2) closed/warded. 128×160. ----
function crackGate(name,warded){const W=128,H=160,cv=C(W,H);ao(cv,W/2,H-8,30,8,60);
  const cx=W/2;
  // torn amethyst frame around a jagged vertical rift
  rect(cv,18,20,34,150,mix(AME,P_MID,0.4));rect(cv,94,20,110,150,mix(AME,P_MID,0.4));
  rect(cv,18,20,110,30,mix(AME,P_HI,0.3));
  // the rift itself — jagged black gap with star points beyond
  const black=hex('#050308'),star=hex('#aeb4ff');
  for(let y=30;y<148;y++){const w=14+Math.round(Math.sin(y*0.3)*6);for(let x=-w;x<=w;x++)px(cv,cx+x,y,black,235);
    // rim
    px(cv,cx-w,y,mix(P_SH,hex('#3a2c5a'),0.6),200);px(cv,cx+w,y,mix(P_SH,hex('#3a2c5a'),0.6),200);}
  const r=deterministic(303);for(let n=0;n<24;n++){const sx=cx-10+Math.floor(r()*20),sy=34+Math.floor(r()*110);px(cv,sx,sy,r()<0.5?star:GOLD,180);}
  if(warded){// a translucent golden ward membrane + faint stepping planks drawn across
    glow(cv,cx,80,40,GOLD,70);
    for(let y=40;y<146;y+=10){const w=12;for(let x=-w;x<=w;x++)px(cv,cx+x,y,GOLD,90);}
    for(let a=0;a<360;a+=30){const x=cx+Math.cos(a*Math.PI/180)*22,y=80+Math.sin(a*Math.PI/180)*40;px(cv,x,y,GOLD,150);}
  }
  save(cv,name);}
crackGate('l4_crack_gate.png',false);
crackGate('l4_crack_gate_on.png',true);

// ---- G1 mount. 룬 제단 (rune altar, place slot) off/on. 96×96. ----
function runeAltar(name,on){const W=96,H=96,cv=C(W,H);ao(cv,W/2,88,24,7,66);
  // a stone altar pedestal with a rune slot on top
  rect(cv,30,60,66,86,mix(STONE,P_SH,0.4));rect(cv,30,60,66,64,mix(STONE,P_HI,0.3));rect(cv,62,60,66,86,P_SH);
  rect(cv,26,84,70,90,P_SH);// footing
  const sx=48,sy=52;
  // rune slot ring
  for(let a=0;a<360;a+=30){const x=sx+Math.cos(a*Math.PI/180)*13,y=sy+Math.sin(a*Math.PI/180)*8;px(cv,x,y,on?GOLD:GOLD_DK,on?230:170);px(cv,x,y+1,P_SH,180);}
  if(on){// bridge-stone installed — golden runes radiate + a light-bridge fan
    glow(cv,sx,sy,16,GOLD,120);glow(cv,sx,sy,8,hex('#fff0c8'),140);
    for(let a=0;a<360;a+=6)px(cv,sx+Math.cos(a*Math.PI/180)*7,sy+Math.sin(a*Math.PI/180)*7,mix(GOLD,hex('#fff0c8'),0.4),235);
    px(cv,sx,sy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=45)for(let i=8;i<16;i++)px(cv,sx+Math.cos(a*Math.PI/180)*i,sy+Math.sin(a*Math.PI/180)*i,GOLD,150);
  } else {
    for(let y=-6;y<=6;y++)for(let x=-6;x<=6;x++){if(x*x+y*y<=36)px(cv,sx+x,sy+y,DEEP,235);}
  }
  save(cv,name);}
runeAltar('l4_rune_altar.png',false);
runeAltar('l4_rune_altar_on.png',true);

// ---- G3 mount. 결계석 / 부적 제단 (ward pillar / charm altar) off/on. 80×96. ----
function wardPillar(name,on){const W=80,H=96,cv=C(W,H);ao(cv,W/2,88,20,6,60);
  const bx=24,by=30,bw=32,bh=54;
  rect(cv,bx,by,bx+bw,by+bh,mix(STONE,P_MID,0.3));rect(cv,bx,by,bx+bw,by+3,mix(STONE,P_HI,0.4));rect(cv,bx+bw-3,by,bx+bw,by+bh,P_SH);
  rect(cv,bx+4,by+5,bx+bw-4,by+bh-6,DKPANEL);
  const hx=bx+bw/2,hy=by+24;
  // ward inset ring
  for(let a=0;a<360;a+=30){const x=hx+Math.cos(a*Math.PI/180)*11,y=hy+Math.sin(a*Math.PI/180)*11;px(cv,x,y,on?GOLD:GOLD_DK,on?220:160);}
  if(on){glow(cv,hx,hy,20,GOLD,160);glow(cv,hx,hy,10,hex('#fff0c8'),150);
    for(let a=0;a<360;a+=6)px(cv,hx+Math.cos(a*Math.PI/180)*6,hy+Math.sin(a*Math.PI/180)*6,mix(GOLD,hex('#fff0c8'),0.4),235);
    px(cv,hx,hy,hex('#fff0d0'),255);
    rect(cv,bx+6,by+bh-12,bx+bw-8,by+bh-9,GOLD,230);
  } else {
    for(let y=-8;y<=8;y++)for(let x=-8;x<=8;x++){if(x*x+y*y<=64)px(cv,hx+x,hy+y,DEEP,235);}
    rect(cv,bx+6,by+bh-12,bx+10,by+bh-9,GOLD_DK,180);
  }
  save(cv,name);}
wardPillar('l4_ward_pillar.png',false);
wardPillar('l4_ward_pillar_on.png',true);

// ---- G4 mount. 봉인 코어 배전반 (seal-core mount, place slot) off/on. 80×96. ----
function sealMount(name,on){const W=80,H=96,cv=C(W,H);ao(cv,W/2,88,20,6,60);
  const bx=22,by=30,bw=36,bh=54;
  rect(cv,bx,by,bx+bw,by+bh,mix(STONE,P_MID,0.3));rect(cv,bx,by,bx+bw,by+3,mix(STONE,P_HI,0.4));rect(cv,bx+bw-3,by,bx+bw,by+bh,P_SH);
  rect(cv,bx+4,by+5,bx+bw-4,by+bh-6,DKPANEL);
  const hx=bx+bw/2,hy=by+26;
  // seal socket — a ring of rune petals framing the core cavity
  for(let a=0;a<360;a+=30){const x=hx+Math.cos(a*Math.PI/180)*13,y=hy+Math.sin(a*Math.PI/180)*13;px(cv,x,y,on?GOLD:GOLD_DK,on?220:170);px(cv,x,y+1,P_SH,180);}
  if(on){// seal orb installed — golden rune rings radiating
    glow(cv,hx,hy,22,GOLD,180);glow(cv,hx,hy,12,hex('#fff0c8'),160);
    for(let a=0;a<360;a+=6)px(cv,hx+Math.cos(a*Math.PI/180)*7,hy+Math.sin(a*Math.PI/180)*7,mix(GOLD,hex('#fff0c8'),0.4),235);
    px(cv,hx,hy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=45)for(let i=8;i<16;i++)px(cv,hx+Math.cos(a*Math.PI/180)*i,hy+Math.sin(a*Math.PI/180)*i,GOLD,150);
    rect(cv,bx+6,by+bh-12,bx+bw-8,by+bh-9,GOLD,230);
  } else {
    for(let y=-8;y<=8;y++)for(let x=-8;x<=8;x++){if(x*x+y*y<=64)px(cv,hx+x,hy+y,DEEP,235);}
    rect(cv,bx+6,by+bh-12,bx+10,by+bh-9,GOLD_DK,180);
  }
  save(cv,name);}
sealMount('l4_seal_mount.png',false);
sealMount('l4_seal_mount_on.png',true);

// ---- G4 landmark. 봉인 코어 (SEAL CORE, 3×3 tall) off/on. 256×320. ----
function sealCore(name,lit){const W=256,H=320,cv=C(W,H);ao(cv,W/2,306,66,14,80);
  const cx=W/2;
  // stepped amethyst base
  rect(cv,cx-70,278,cx+70,306,P_SH);rect(cv,cx-70,278,cx+70,282,mix(P_SH,P_HI,0.3));
  rect(cv,cx-58,250,cx+58,280,mix(AME,P_MID,0.4));rect(cv,cx-58,250,cx+58,254,mix(P_MID,P_HI,0.4));
  // tapering shaft
  for(let y=110;y<252;y++){const t=(y-110)/142;const hw=Math.round(30+t*24);const c=mix(mix(AME,P_MID,0.4),P_SH,t*0.4);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+3,y+1,mix(c,P_HI,0.35));rect(cv,cx+hw-3,y,cx+hw,y+1,P_SH);}
  for(const by of [150,190,230]){rect(cv,cx-40,by,cx+40,by+4,P_SH,200);for(let rx=cx-36;rx<cx+36;rx+=12)px(cv,rx,by+2,lit?GOLD:GOLD_DK,190);}
  // core housing head
  rect(cv,cx-56,44,cx+56,116,mix(AME,P_MID,0.4));rect(cv,cx-56,44,cx+56,48,mix(P_MID,P_HI,0.5));
  rect(cv,cx-60,112,cx+60,120,P_SH);
  // the seal cavity / orb
  const fcx=cx,fcy=80,fr=40;
  const cavity=lit?hex('#4a3410'):hex('#160f26');
  for(let y=-fr;y<=fr;y++)for(let x=-fr;x<=fr;x++){if(x*x+y*y<=fr*fr)px(cv,fcx+x,fcy+y,cavity,245);}
  for(let a=0;a<360;a+=2)px(cv,fcx+Math.cos(a*Math.PI/180)*fr,fcy+Math.sin(a*Math.PI/180)*fr,lit?GOLD:P_HI,235);
  if(!lit){
    // cracked seal, black tendrils seeping out (풀려난 것)
    const r=deterministic(909);for(let n=0;n<8;n++){const a=r()*Math.PI*2;for(let i=0;i<fr;i++){const x=fcx+Math.cos(a)*i,y=fcy+Math.sin(a)*i;px(cv,x,y,hex('#1a0a24'),Math.round(180*(1-i/fr)));}}
    glow(cv,fcx,fcy,fr,hex('#3a1a4a'),60);
    px(cv,fcx,fcy,hex('#5a2c6a'),220);
  } else {
    // re-sealed — concentric golden rune rings
    for(let ring=8;ring<=fr-4;ring+=8)for(let a=0;a<360;a+=6)px(cv,fcx+Math.cos(a*Math.PI/180)*ring,fcy+Math.sin(a*Math.PI/180)*ring,GOLD,180);
    glow(cv,fcx,fcy,fr+6,GOLD,90);px(cv,fcx,fcy,hex('#fff0d0'),255);
    for(let a=0;a<360;a+=30)for(let i=fr-4;i<fr+8;i++)px(cv,fcx+Math.cos(a*Math.PI/180)*i,fcy+Math.sin(a*Math.PI/180)*i,GOLD,140);
  }
  // finial spire + beacon
  rect(cv,cx-4,20,cx+4,46,P_SH);rect(cv,cx-4,20,cx-1,46,mix(P_SH,P_HI,0.3));
  px(cv,cx,16,lit?hex('#fff0d0'):hex('#3a2c4a'),lit?255:210);
  if(lit)glow(cv,cx,18,12,GOLD,200);else glow(cv,cx,18,8,hex('#5a2c6a'),80);
  save(cv,name);}
sealCore('l4_seal_core.png',false);
sealCore('l4_seal_core_on.png',true);

// =========================================================================
// LANDMARK / DECO OBJECTS
// =========================================================================

// ---- 룬 기둥 (rune pillar cluster, blocks). 112×96. ----
(function runePillars(){const W=112,H=96,cv=C(W,H);ao(cv,W/2,90,32,8,68);
  const runs=[[24,10],[40,14],[58,10],[74,16],[92,8]];
  for(const [px0,w] of runs){for(let y=24;y<88;y++)for(let x=0;x<w;x++){const t=x/w;const c=t<0.3?P_HI:(t<0.7?P_MID:P_SH);px(cv,px0+x,y,c,240);}
    rect(cv,px0-1,22,px0+w+1,26,P_SH);rect(cv,px0-1,22,px0+w+1,23,mix(P_SH,P_HI,0.4));
    // a golden rune band around each pillar
    for(let x=0;x<w;x++)px(cv,px0+x,48,GOLD,160);}
  glow(cv,W/2,50,18,GOLD,40);
  save(cv,'l4_rune_pillars.png');})();

// ---- 마력샘 랜드마크 (mana spring silhouette landmark, dormant murky). 176×160. ----
(function springLandmark(){const W=176,H=160,cv=C(W,H);ao(cv,W/2,H-8,46,11,74);
  const cx=W/2;
  rect(cv,cx-54,H-40,cx+54,H-14,mix(STONE,P_SH,0.5));
  rect(cv,cx-40,H-72,cx+40,H-40,mix(STONE,P_SH,0.4));
  rect(cv,cx-26,H-100,cx+26,H-72,mix(STONE,P_SH,0.4));
  rect(cv,cx-8,50,cx+8,H-100,mix(STONE,P_MID,0.25));
  const wcy=H-58;
  for(let y=-8;y<=6;y++)for(let x=-36;x<=36;x++){const d=(x/36)**2+(y/9)**2;if(d<=1)px(cv,cx+x,wcy+y,hex('#141020'),215);}
  glow(cv,cx,wcy,14,hex('#2a1a3a'),70);
  const r=deterministic(1101);for(let n=0;n<8;n++){const mx=cx-16+Math.floor(r()*32),my=wcy-6-Math.floor(r()*8);px(cv,mx,my,hex('#3a2a4a'),130);}
  save(cv,'l4_spring_landmark.png');})();

// ---- 부유 파편 (floating debris chunk, deco, blocks). 140×150. ----
(function floatShard(){const W=140,H=150,cv=C(W,H);
  const cx=W/2;
  // a chunk of amethyst ground torn free, floating (shadow cast far below)
  ao(cv,W/2,H-6,30,7,50);
  for(let y=50;y<110;y++){const t=(y-50)/60;const hw=Math.round(50-t*38);const c=mix(AME,P_SH,t*0.5);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+4,y+1,mix(c,P_HI,0.25));rect(cv,cx+hw-4,y,cx+hw,y+1,P_SH);}
  // top surface (amethyst pavement with a rune)
  for(let y=44;y<52;y++)for(let x=-50;x<=50;x++){const d=Math.abs(x)/50;if(d<=1)px(cv,cx+x,y,mix(AME,P_HI,0.4-d*0.3),235);}
  for(let a=0;a<360;a+=60)px(cv,cx+Math.cos(a*Math.PI/180)*10,48+Math.sin(a*Math.PI/180)*4,GOLD,150);
  // jagged torn bottom + a few star specks in the void below
  const r=deterministic(1202);for(let n=0;n<10;n++)px(cv,cx-40+Math.floor(r()*80),112+Math.floor(r()*20),hex('#aeb4ff'),120);
  save(cv,'l4_float_shard.png');})();

// ---- 룬 파편 더미 (rune fragment heap, gather-look deco). 96×96. ----
(function runeHeap(){const W=96,H=96,cv=C(W,H);ao(cv,W/2,90,27,8,70);const r=deterministic(1302);
  for(let n=0;n<28;n++){const kind=Math.floor(r()*3);const bx=24+Math.floor(r()*48),by=54+Math.floor(r()*30);
    const tone=[P_MID,P_HI,P_SH][Math.floor(r()*3)];
    if(kind===0){const w=5+Math.floor(r()*7),h=3+Math.floor(r()*4);rect(cv,bx,by,bx+w,by+h,tone);rect(cv,bx,by,bx+w,by+1,mix(tone,P_HI,0.4));if(r()<0.4)px(cv,bx+1,by+1,GOLD,150);}
    else if(kind===1){const rad=3+Math.floor(r()*4);for(let a=0;a<360;a+=45)px(cv,bx+Math.cos(a*Math.PI/180)*rad,by+Math.sin(a*Math.PI/180)*rad*0.7,tone,225);px(cv,bx,by,mix(tone,P_HI,0.4),220);}
    else {const len=6+Math.floor(r()*8);for(let i=0;i<len;i++)px(cv,bx+i,by-Math.round(i*0.3),tone,225);}}
  for(let n=0;n<4;n++)px(cv,30+Math.floor(r()*40),56+Math.floor(r()*24),GOLD,200);
  save(cv,'l4_rune_heap.png');})();

// ---- 마법사들의 잔영 (mage afterimages, 3 poses — translucent, investigate). 90×150 each. ----
// Ghostly translucent violet silhouette; the "truth-fragment" gold flicker added at runtime.
function mageGhost(name,pose){const W=90,H=150,cv=C(W,H);const cx=44;
  const ghost=hex('#4a3a6a'),ghostHi=hex('#7a5cae'),ghostSh=hex('#2a1f3d');
  const A=110; // base translucency
  // robe body (tapering, hooded figure)
  if(pose==='standing'){
    for(let y=52;y<138;y++){const t=(y-52)/86;const hw=Math.round(10+t*18);rect(cv,cx-hw,y,cx+hw,y+1,ghost,A);px(cv,cx-hw,y,ghostSh,A);px(cv,cx+hw-1,y,ghostHi,A-30);}
    // hood + bowed head
    for(let y=34;y<56;y++){const t=(y-34)/22;const hw=Math.round(12-Math.abs(t-0.4)*7);rect(cv,cx-hw,y,cx+hw,y+1,ghost,A);}
    // faint face void
    px(cv,cx-2,46,ghostSh,A+40);px(cv,cx+3,46,ghostSh,A+40);
  } else if(pose==='reaching'){
    for(let y=54;y<138;y++){const t=(y-54)/84;const hw=Math.round(10+t*16);const lean=Math.round((1-t)*5);rect(cv,cx-hw+lean,y,cx+hw+lean,y+1,ghost,A);}
    for(let y=36;y<58;y++){const t=(y-36)/22;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw+8,y,cx+hw+8,y+1,ghost,A);}
    // one arm reaching up toward the tower
    for(let i=0;i<30;i++)px(cv,cx+14+i*0.4,64-i*0.9,ghostHi,A);
    px(cv,cx+2,46,ghostSh,A+40);px(cv,cx+9,46,ghostSh,A+40);
  } else { // kneeling
    for(let y=70;y<130;y++){const t=(y-70)/60;const hw=Math.round(14+t*14);rect(cv,cx-hw,y,cx+hw,y+1,ghost,A);}
    for(let y=52;y<74;y++){const t=(y-52)/22;const hw=Math.round(11-Math.abs(t-0.4)*6);rect(cv,cx-hw,y,cx+hw,y+1,ghost,A);}
    px(cv,cx-2,62,ghostSh,A+40);px(cv,cx+3,62,ghostSh,A+40);
    // arms braced on the ground
    for(let i=0;i<20;i++)px(cv,cx-14-i*0.2,80+i,ghost,A);for(let i=0;i<20;i++)px(cv,cx+14+i*0.2,80+i,ghost,A);
  }
  // a faint golden rune mote hovering at the chest (the truth waiting to be read)
  glow(cv,cx,pose==='kneeling'?92:84,8,GOLD,40);
  save(cv,name);}
mageGhost('l4_mage_ghost_standing.png','standing');
mageGhost('l4_mage_ghost_reaching.png','reaching');
mageGhost('l4_mage_ghost_kneeling.png','kneeling');

// ---- 봉인 제단 데코 (broken seal altar, deco). 128×112. ----
(function brokenAltar(){const W=128,H=112,cv=C(W,H);ao(cv,W/2,104,34,9,70);
  const bx=30,by=54,bw=68,bh=46;
  rect(cv,bx,by,bx+bw,by+bh,mix(STONE,P_MID,0.3));rect(cv,bx,by,bx+bw,by+4,mix(STONE,P_HI,0.4));rect(cv,bx+bw-3,by,bx+bw,by+bh,P_SH);
  // a cracked seal disc on top, dark leak
  const ax=bx+bw/2,ay=by-4;
  for(let a=0;a<360;a+=8)px(cv,ax+Math.cos(a*Math.PI/180)*16,ay+Math.sin(a*Math.PI/180)*8,GOLD_DK,180);
  // crack across it + dark seep
  for(let i=-14;i<14;i++)px(cv,ax+i,ay+Math.round(Math.sin(i*0.5)*2),hex('#1a0a24'),200);
  glow(cv,ax,ay,10,hex('#3a1a4a'),70);
  rect(cv,bx+4,by+bh,bx+9,by+bh+8,P_SH);rect(cv,bx+bw-9,by+bh,bx+bw-4,by+bh+8,P_SH);
  save(cv,'l4_broken_altar.png');})();

// ---- L4 정비대 (workbench, amethyst with GOLD fusion aperture). 128×112. ----
(function workbench(){const W=128,H=112,cv=C(W,H);ao(cv,W/2,104,34,9,70);
  const bx=28,by=54,bw=72,bh=46;
  rect(cv,bx,by,bx+bw,by+bh,P_MID);rect(cv,bx,by,bx+bw,by+4,mix(P_MID,P_HI,0.5));rect(cv,bx+bw-3,by,bx+bw,by+bh,P_SH);
  for(let rx=bx+6;rx<bx+bw-4;rx+=12)px(cv,rx,by+20,P_HI,190);rect(cv,bx,by+18,bx+bw,by+21,P_SH,160);
  rect(cv,bx+2,by-8,bx+bw-2,by+2,P_SH);
  const ax=bx+bw/2,ay=by-4;
  glow(cv,ax,ay,26,GOLD_DK,110);glow(cv,ax,ay,16,GOLD,140);
  for(let a=0;a<360;a+=24)px(cv,ax+Math.cos(a*Math.PI/180)*9,ay+Math.sin(a*Math.PI/180)*4.5,mix(GOLD_DK,GOLD,0.6),220);
  px(cv,ax,ay,hex('#fff0d0'),245);
  for(let i=0;i<18;i++)px(cv,bx+14+i,by-6-i*0.4,P_HI);px(cv,bx+32,by-13,GOLD,210);
  rect(cv,bx+bw-16,by+10,bx+bw-6,by+30,DKPANEL);rect(cv,bx+bw-14,by+12,bx+bw-8,by+16,GOLD,210);
  rect(cv,bx+4,by+bh,bx+9,by+bh+8,P_SH);rect(cv,bx+bw-9,by+bh,bx+bw-4,by+bh+8,P_SH);
  save(cv,'l4_workbench.png');})();

// =========================================================================
// SMALL SCATTER BITS + light pool
// =========================================================================

// ---- l4_debris_rune — tiny loose rune shard fleck. 48×48. ----
(function debrisRune(){const W=48,H=48,cv=C(W,H);ao(cv,W/2,42,10,4,58);
  const bx=18,by=26;rect(cv,bx,by,bx+10,by+6,P_MID);rect(cv,bx,by,bx+10,by+1,mix(P_MID,P_HI,0.4));
  px(cv,bx+4,by+3,GOLD,180);px(cv,bx+2,by+1,P_HI,220);
  save(cv,'l4_debris_rune.png');})();

// ---- l4_debris_ash — arcane ash wisp (violet-tinted). 48×48. ----
(function debrisAsh(){const W=48,H=48,cv=C(W,H);const r=deterministic(2424);const ash=hex('#241c34');
  for(let n=0;n<20;n++){const ax=14+Math.floor(r()*20),ay=26+Math.floor(r()*14);px(cv,ax,ay,ash,120);px(cv,ax+1,ay,mix(ash,GOLD,0.12),90);}
  for(let n=0;n<3;n++)px(cv,18+Math.floor(r()*14),28+Math.floor(r()*8),mix(GOLD,ash,0.5),150);
  save(cv,'l4_debris_ash.png');})();

// ---- light_pool_gold.png — soft golden radial glow pool (used by the gate controller). 96×96. ----
(function lightPoolGold(){const W=96,H=96,cv=C(W,H);
  glow(cv,W/2,H/2,46,GOLD,150);glow(cv,W/2,H/2,26,hex('#fff0c8'),90);
  save(cv,'light_pool_gold.png');})();

console.log('L4 objects done.');
