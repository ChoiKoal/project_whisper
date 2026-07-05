'use strict';
// L2-1 — Science-world (Layer 2) OBJECT art generator. Deterministic PNGs with AO
// contact shadows, matching Layer-1 object fidelity. Ground origin = bottom-center of a
// 128-wide iso base (so the loader plants them on the cell centre like the L1 objects).
// Palette per project-whisper-layer2-design-v1.md Part C §2: 남색 base, 금속 회색 램프,
// 시안 발광 #4ad9c8. States off/on encoded as separate PNGs (gate LOGIC = stage L2-3;
// here only the static/off art + the lit variants the L2-3 agent will swap to).
// Produces into assets/objects/  (l2_*.png). Run: node tools_gen_l2_objects.js
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
// AO contact shadow: soft iso ellipse at ground line (y = H - foot)
function ao(cv,cx,gy,rx,ry,strength=64){for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const dx=x/rx,dy=y/ry;const d=dx*dx+dy*dy;if(d<=1.0)px(cv,cx+x,gy+y,[0,0,0],Math.round((1-d)*strength));}}
// glow blob (additive-ish): soft cyan disc for baked bloom on the object itself
function glow(cv,cx,cy,r,col,peak=120){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y)/r;if(d<=1.0)px(cv,cx+x,cy+y,col,Math.round((1-d)*(1-d)*peak));}}

// palette
const NAVY=hex('#1a2438'), MHI=hex('#5a6472'), MMID=hex('#3a4452'), MSH=hex('#222a38'),
  CYAN=hex('#4ad9c8'), DKPANEL=hex('#141a26'), RUST=hex('#7a4a3a'), VIOLET=hex('#9e7ad9'),
  DEEP=hex('#0d1018');

function deterministic(seed){let s=seed;return()=>{s=(s*1103515245+12345)&0x7fffffff;return s/0x7fffffff;};}

// ---- R 잔해 더미 (scrap heap, gatherable J1). 96×96, foot at y88. ----
(function scrap(){const W=96,H=96,cv=C(W,H);ao(cv,W/2,90,26,8,70);const r=deterministic(11);
  // a mound of broken metal chunks
  for(let n=0;n<26;n++){const bx=24+Math.floor(r()*48),by=52+Math.floor(r()*30),w=6+Math.floor(r()*10),h=4+Math.floor(r()*7);
    const tone=r()<0.5?MMID:MSH;rect(cv,bx,by,bx+w,by+h,tone);rect(cv,bx,by,bx+w,by+2,mix(tone,MHI,0.4));// lit top
    if(r()<0.3)px(cv,bx+1,by+1,RUST,180);}
  // a bent girder poking out
  for(let i=0;i<22;i++)px(cv,40+i,60-i*0.5,MHI,220);
  for(let i=0;i<22;i++)px(cv,40+i,61-i*0.5,MSH);
  save(cv,'l2_scrap.png');})();

// ---- s 부품 상자 (parts crate, gatherable). 80×80, lid slightly open. ----
(function crate(){const W=80,H=80,cv=C(W,H);ao(cv,W/2,74,22,7,70);
  const bx=22,by=40,bw=36,bh=30;
  rect(cv,bx,by,bx+bw,by+bh,MMID);// body
  rect(cv,bx,by,bx+bw,by+3,mix(MMID,MHI,0.5));// top rim lit
  rect(cv,bx,by,bx+2,by+bh,mix(MMID,MHI,0.3));rect(cv,bx+bw-2,by,bx+bw,by+bh,MSH);
  // corner brackets
  for(const cxk of [bx+2,bx+bw-4])for(const cyk of [by+2,by+bh-6])rect(cv,cxk,cyk,cxk+2,cyk+4,mix(MSH,CYAN,0.15));
  // slightly open lid revealing dark interior + a wire glint
  rect(cv,bx-1,by-6,bx+bw+1,by+2,MSH);rect(cv,bx+2,by-4,bx+bw-2,by-1,DEEP);
  px(cv,bx+10,by-3,CYAN,200);px(cv,bx+22,by-2,RUST,200);
  save(cv,'l2_crate.png');})();

// ---- F 깨진 유리 돔 파편 (broken glass dome fragment, gatherable J3). 96×96. ----
(function dome(){const W=96,H=96,cv=C(W,H);ao(cv,W/2,88,24,7,60);
  const glass=hex('#3a5560'), glassLt=hex('#7fb8c0');
  // a curved shard base + jagged upstanding pieces (translucent teal glass)
  for(let x=26;x<70;x++){const t=(x-26)/44;const top=78-Math.round(Math.sin(t*Math.PI)*22);for(let y=top;y<86;y++){const a=170-Math.round((86-y)*1.5);px(cv,x,y,glass,Math.max(60,a));}}
  // rim light on the arc + cyan glint edges
  for(let x=26;x<70;x++){const t=(x-26)/44;const top=78-Math.round(Math.sin(t*Math.PI)*22);px(cv,x,top,glassLt,180);}
  const r=deterministic(303);for(let n=0;n<8;n++){const gx=30+Math.floor(r()*38),gy=60+Math.floor(r()*16);px(cv,gx,gy,CYAN,150);}
  // a couple standing broken splinters
  for(let i=0;i<14;i++)px(cv,44,74-i,glassLt,140);for(let i=0;i<10;i++)px(cv,58,76-i,glass,160);
  save(cv,'l2_dome.png');})();

// ---- N 네온 결정 군락 (neon crystal cluster, glows cyan, gatherable J6). 96×96. ----
(function neon(){const W=96,H=112,cv=C(W,H);ao(cv,W/2,104,22,7,60);
  glow(cv,W/2,74,30,CYAN,90);// base bloom
  const dark=hex('#125a52'),lit=hex('#7ff0e2');
  // several angular crystals rising
  const crystals=[[40,52,10,44],[52,44,9,54],[46,36,7,62],[60,58,8,40],[34,60,7,38]];
  for(const [cx,ty,w,h] of crystals){
    for(let y=0;y<h;y++){const yy=104-y;const ww=Math.round(w*(1-y/h*0.6));for(let x=-ww;x<=ww;x++){const face=x> -1?lit:dark;const t=y/h;px(cv,cx+x,yy,mix(face,CYAN,t*0.5),245);}}
    // bright core line
    for(let y=0;y<h;y++)px(cv,cx,104-y,hex('#e6fffb'),200*(y/h));
  }
  glow(cv,52,50,16,hex('#bffff5'),150);
  save(cv,'l2_neon.png');})();

// ---- T 꺼진 가로등 (unlit lamp post, 1×3). 64×160, head dark. ----
function lamp(off){const W=64,H=160,cv=C(W,H);ao(cv,W/2,152,16,6,70);
  // pole
  rect(cv,29,40,35,150,MMID);rect(cv,29,40,31,150,mix(MMID,MHI,0.4));rect(cv,34,40,35,150,MSH);
  // base flare
  rect(cv,24,146,40,152,MSH);rect(cv,24,146,40,148,mix(MSH,MHI,0.3));
  // arm + head
  rect(cv,32,40,52,44,MMID);
  const head=off?hex('#2a3038'):CYAN;
  // lamp head housing
  rect(cv,44,38,58,50,MSH);rect(cv,46,40,56,48,head);
  if(!off){glow(cv,51,44,20,CYAN,150);
    // light pool on ground
    for(let y=-4;y<=4;y++)for(let x=-20;x<=20;x++){const d=(x/20)**2+(y/4)**2;if(d<=1)px(cv,W/2+x,150+y,CYAN,Math.round((1-d)*50));}}
  save(cv,off?'l2_lamp.png':'l2_lamp_lit.png');}
lamp(true);lamp(false);

// ---- 위성 안테나 (satellite antenna, 2×2 landmark, tilted). 160×176. ----
(function antenna(){const W=160,H=176,cv=C(W,H);ao(cv,W/2,168,40,10,70);
  // tripod mast
  rect(cv,72,80,86,164,MMID);rect(cv,72,80,75,164,mix(MMID,MHI,0.4));
  rect(cv,60,150,100,166,MSH);// footing
  for(const lx of [64,94])for(let i=0;i<40;i++)px(cv,lx+ (lx<80?i*0.3:-i*0.3),126+i,MSH);
  // tilted dish (ellipse) facing up-right
  const dcx=98,dcy=58,rx=44,ry=30;const dish=MMID,dishLt=MHI;
  for(let y=-ry;y<=ry;y++)for(let x=-rx;x<=rx;x++){const nx=(x*0.92-y*0.38)/rx,ny=(x*0.38+y*0.92)/ry;if(nx*nx+ny*ny<=1){const c=(nx-ny)>0.1?dishLt:dish;px(cv,dcx+x,dcy+y,c);}}
  // dish inner ring shading
  for(let y=-ry+6;y<=ry-6;y++)for(let x=-rx+8;x<=rx-8;x++){const nx=(x*0.92-y*0.38)/(rx-8),ny=(x*0.38+y*0.92)/(ry-6);if(nx*nx+ny*ny<=1&&nx*nx+ny*ny>0.5)px(cv,dcx+x,dcy+y,MSH,120);}
  // feed arm + blinking tip (cyan)
  for(let i=0;i<24;i++)px(cv,dcx-i*0.6,dcy+i*0.7,MHI);
  glow(cv,dcx-14,dcy+18,10,CYAN,150);px(cv,dcx-14,dcy+18,hex('#e6fffb'),230);
  save(cv,'l2_antenna.png');})();

// ---- 대형 스크린 (big screen, landmark 1, 2-frame flicker). 176×160 ×2 states. ----
function screen(on){const W=176,H=160,cv=C(W,H);ao(cv,W/2,152,44,10,70);
  // frame housing on a stand
  rect(cv,72,120,104,150,MSH);// stand
  rect(cv,20,20,156,124,MMID);// bezel
  rect(cv,20,20,156,24,mix(MMID,MHI,0.4));rect(cv,20,20,24,124,mix(MMID,MHI,0.3));rect(cv,152,20,156,124,MSH);
  // screen surface
  const scr=on?hex('#123a44'):hex('#0a0d12');
  rect(cv,30,30,146,114,scr);
  if(on){// glitchy dead text rows in dark cyan
    const r=deterministic(7);for(let ry=36;ry<108;ry+=8){const rw=Math.floor(r()*90);rect(cv,36,ry,36+rw,ry+3,mix(scr,CYAN,0.5),200);}
    glow(cv,88,72,60,CYAN,60);
    rect(cv,30,30,146,32,CYAN,120);// scanline
  } else {
    // near-black with one faint ghost line
    rect(cv,36,68,120,70,mix(scr,CYAN,0.25),120);
  }
  save(cv,on?'l2_screen_on.png':'l2_screen_off.png');}
screen(false);screen(true);

// ---- 발전기 메인 E (2×2) + 보조 e (1×2), off/on. ----
function generator(name,W,H,big,on){const cv=C(W,H);ao(cv,W/2,H-8,big?40:22,big?10:7,70);
  const bw=big?96:52,bh=big?70:56,bx=(W-bw)/2,by=H-14-bh;
  rect(cv,bx,by,bx+bw,by+bh,MMID);// body
  rect(cv,bx,by,bx+bw,by+4,mix(MMID,MHI,0.5));rect(cv,bx,by,bx+3,by+bh,mix(MMID,MHI,0.3));rect(cv,bx+bw-3,by,bx+bw,by+bh,MSH);
  // vent slats
  for(let i=0;i<5;i++)rect(cv,bx+6,by+10+i*7,bx+bw-6,by+12+i*7,MSH,180);
  // gauge panel
  const gx=bx+bw-(big?32:22),gy=by+bh-(big?30:24);
  rect(cv,gx,gy,gx+(big?24:16),gy+(big?18:14),DKPANEL);
  const gauge=on?CYAN:hex('#2a3038');
  // gauge needle / readout
  glow(cv,gx+(big?12:8),gy+(big?9:7),big?12:8,on?CYAN:hex('#1a2028'),on?150:0);
  rect(cv,gx+2,gy+2,gx+(big?22:14),gy+4,gauge,on?220:140);
  if(on){// rotating core glow on top
    glow(cv,bx+bw*0.4,by+bh*0.4,big?22:14,CYAN,140);
    // hum particles
    const r=deterministic(name.length*13);for(let n=0;n<6;n++)px(cv,bx+10+Math.floor(r()*(bw-20)),by-2-Math.floor(r()*10),CYAN,150);
  }
  // exhaust stack (main only)
  if(big){rect(cv,bx+8,by-22,bx+20,by,MSH);rect(cv,bx+8,by-22,bx+12,by,mix(MSH,MHI,0.3));}
  save(cv,name);}
generator('l2_gen_main.png',176,140,true,false);
generator('l2_gen_main_on.png',176,140,true,true);
generator('l2_gen_sub.png',96,120,false,false);
generator('l2_gen_sub_on.png',96,120,false,true);

// ---- K 배전반 (breaker/socket panel, empty/energized). 80×96. ----
function breaker(name,on){const W=80,H=96,cv=C(W,H);ao(cv,W/2,88,20,6,60);
  const bx=24,by=34,bw=32,bh=48;
  rect(cv,bx,by,bx+bw,by+bh,MMID);rect(cv,bx,by,bx+bw,by+3,mix(MMID,MHI,0.5));rect(cv,bx+bw-3,by,bx+bw,by+bh,MSH);
  // panel face + socket
  rect(cv,bx+5,by+6,bx+bw-5,by+bh-8,DKPANEL);
  const sock=on?CYAN:hex('#26303a');
  // socket ring
  glow(cv,bx+bw/2,by+22,on?12:0,CYAN,on?160:0);
  for(let a=0;a<360;a+=30){const rad=6;px(cv,bx+bw/2+Math.cos(a*Math.PI/180)*rad,by+22+Math.sin(a*Math.PI/180)*rad,sock,220);}
  rect(cv,bx+bw/2-2,by+20,bx+bw/2+2,by+24,sock);
  // gauge bar fills when energized
  rect(cv,bx+7,by+bh-14,bx+bw-7,by+bh-11,hex('#26303a'));
  if(on)rect(cv,bx+7,by+bh-14,bx+bw-9,by+bh-11,CYAN,230);
  save(cv,name);}
breaker('l2_breaker.png',false);
breaker('l2_breaker_on.png',true);

// ---- 관제탑 O (control tower, 3×3 tall landmark, dark → lit). 256×320. ----
function tower(name,lit){const W=256,H=320,cv=C(W,H);ao(cv,W/2,306,66,14,80);
  const cx=W/2;
  // stepped base
  rect(cv,cx-70,278,cx+70,306,MSH);rect(cv,cx-70,278,cx+70,282,mix(MSH,MHI,0.3));
  rect(cv,cx-56,250,cx+56,280,MMID);rect(cv,cx-56,250,cx+56,254,mix(MMID,MHI,0.4));
  // tapering shaft
  for(let y=80;y<252;y++){const t=(y-80)/172;const hw=Math.round(28+t*24);const c=mix(MMID,MSH,t*0.4);
    rect(cv,cx-hw,y,cx+hw,y+1,c);rect(cv,cx-hw,y,cx-hw+3,y+1,mix(c,MHI,0.35));rect(cv,cx+hw-3,y,cx+hw,y+1,MSH);}
  // vertical seam lights on shaft
  const strip=lit?CYAN:hex('#1e2a30');
  for(let y=90;y<246;y+=2)px(cv,cx,y,strip,lit?210:150);
  if(lit)for(let y=90;y<246;y+=2){px(cv,cx-1,y,strip,90);px(cv,cx+1,y,strip,90);}
  // control cap (wide head with windows)
  rect(cv,cx-50,44,cx+50,84,MMID);rect(cv,cx-50,44,cx+50,48,mix(MMID,MHI,0.5));
  rect(cv,cx-54,80,cx+54,88,MSH);// lip
  // window band
  const win=lit?hex('#123a44'):hex('#0a0d12');
  rect(cv,cx-44,54,cx+44,74,win);
  if(lit){const r=deterministic(99);for(let wx=cx-40;wx<cx+40;wx+=10){const on=r()<0.7;rect(cv,wx,58,wx+6,70,on?mix(win,CYAN,0.6):win,on?220:255);}
    glow(cv,cx,64,60,CYAN,80);
    // antenna beacon
    glow(cx!==undefined?cv:cv,cx,30,14,CYAN,180);}
  // spire
  rect(cv,cx-3,20,cx+3,46,MSH);px(cv,cx,18,lit?hex('#e6fffb'):hex('#3a3038'),lit?255:200);
  if(lit)glow(cv,cx,20,10,CYAN,200);
  save(cv,name);}
tower('l2_tower.png',false);
tower('l2_tower_lit.png',true);

// ---- 정비대 (tech workbench = L2 crafting station, violet-cyan glow). 128×112. ----
(function workbench(){const W=128,H=112,cv=C(W,H);ao(cv,W/2,104,34,9,70);
  // bench body
  const bx=28,by=54,bw=72,bh=46;
  rect(cv,bx,by,bx+bw,by+bh,MMID);rect(cv,bx,by,bx+bw,by+4,mix(MMID,MHI,0.5));rect(cv,bx+bw-3,by,bx+bw,by+bh,MSH);
  // worktop with a glowing fusion aperture (violet→cyan)
  rect(cv,bx+2,by-8,bx+bw-2,by+2,MSH);
  const ax=bx+bw/2,ay=by-4;
  glow(cv,ax,ay,26,VIOLET,110);glow(cv,ax,ay,16,CYAN,130);
  for(let a=0;a<360;a+=24)px(cv,ax+Math.cos(a*Math.PI/180)*9,ay+Math.sin(a*Math.PI/180)*4.5,mix(VIOLET,CYAN,0.5),220);
  px(cv,ax,ay,hex('#e6fffb'),240);
  // tool arm over the aperture
  for(let i=0;i<18;i++)px(cv,bx+14+i,by-6-i*0.4,MHI);px(cv,bx+32,by-13,CYAN,200);
  // side gauges
  rect(cv,bx+bw-16,by+10,bx+bw-6,by+30,DKPANEL);rect(cv,bx+bw-14,by+12,bx+bw-8,by+16,CYAN,200);
  // legs
  rect(cv,bx+4,by+bh,bx+9,by+bh+8,MSH);rect(cv,bx+bw-9,by+bh,bx+bw-4,by+bh+8,MSH);
  save(cv,'l2_workbench.png');})();

// ---- B 에너지 브리지(꺼짐) — unwalkable dark gap with dormant light strips. 128×64 diamond overlay. ----
function bridge(name,lit){const W=128,H=72,cv=C(W,H);
  // dark bridge deck diamond (sits over the canyon gap)
  const cx=64,cy=32;
  for(let y=0;y<64;y++)for(let x=0;x<W;x++){const d=Math.abs(x-cx)/64+Math.abs(y-cy)/32;if(d<=1){let c=mix(DEEP,MSH,0.4);if(d>0.9)c=MSH;px(cv,x,y,c,235);}}
  // dormant light strips running along the deck (two iso rails)
  const strip=lit?CYAN:hex('#1c343a');
  for(let x=20;x<108;x++){const y1=32+(x-64)*0.25-8,y2=32+(x-64)*0.25+8;px(cv,x,y1,strip,lit?220:150);px(cv,x,y2,strip,lit?220:150);if(lit){px(cv,x,y1+1,strip,80);px(cv,x,y2-1,strip,80);}}
  // conduit under-glow leaking (very faint even when off, per flavor)
  for(let x=40;x<88;x+=6)px(cv,x,44,CYAN,lit?160:50);
  if(lit)glow(cv,cx,cy,40,CYAN,70);
  save(cv,name);}
bridge('l2_bridge_off.png',false);
bridge('l2_bridge_on.png',true);

// ---- D 차폐문 (shield door, closed → open). 128×128, stands on the corridor cell. ----
function door(name,open){const W=128,H=128,cv=C(W,H);ao(cv,W/2,120,30,8,70);
  if(!open){
    // two heavy blast-door leaves meeting in the middle, closed
    rect(cv,30,36,64,116,MMID);rect(cv,64,36,98,116,mix(MMID,MSH,0.2));
    rect(cv,30,36,98,40,mix(MMID,MHI,0.4));// top lit
    rect(cv,62,36,66,116,MSH);// seam
    // hazard chevrons (dim)
    for(let i=0;i<4;i++){const yy=48+i*16;for(let k=0;k<8;k++){px(cv,40+k,yy+k,hex('#c8a83a'),120);px(cv,88-k,yy+k,hex('#c8a83a'),120);}}
    // locked indicator
    glow(cv,64,30,10,hex('#c83a3a'),120);px(cv,64,30,hex('#ff6a6a'),200);
    // frame posts
    rect(cv,26,32,30,118,MSH);rect(cv,98,32,102,118,MSH);
  } else {
    // leaves retracted to the sides, open corridor cyan-lit
    rect(cv,26,36,40,116,MMID);rect(cv,88,36,102,116,MMID);
    rect(cv,40,36,88,116,DEEP,180);
    for(let y=40;y<114;y+=2)px(cv,64,y,CYAN,180);glow(cv,64,76,28,CYAN,90);
    glow(cv,64,30,10,CYAN,140);
  }
  save(cv,name);}
door('l2_door_closed.png',false);
door('l2_door_open.png',true);

// ---- N blackout bottleneck dark overlay (G3 gate, static-closed). 128×80. ----
(function blackout(){const W=128,H=80,cv=C(W,H);
  // a heavy dark vignette diamond signalling "정전 병목" — nearly black, faint cyan crystal hint
  const cx=64,cy=40;
  for(let y=0;y<80;y++)for(let x=0;x<W;x++){const d=Math.abs(x-cx)/64+Math.abs(y-cy)/40;if(d<=1){const a=Math.round(200*(1-d*0.3));px(cv,x,y,DEEP,a);}}
  // faint dormant neon glints in the dark (the crystals you can't see without a lantern)
  const r=deterministic(444);for(let n=0;n<5;n++){const gx=30+Math.floor(r()*68),gy=20+Math.floor(r()*36);px(cv,gx,gy,mix(DEEP,CYAN,0.4),120);}
  save(cv,'l2_blackout.png');})();

// ---- small debris scatter bits (ash wisp + scrap fleck) for the map scatter ----
(function debrisBits(){
  // scrap fleck
  {const W=48,H=48,cv=C(W,H);ao(cv,W/2,42,10,4,60);const r=deterministic(21);
    for(let n=0;n<6;n++){const bx=16+Math.floor(r()*16),by=28+Math.floor(r()*10),w=4+Math.floor(r()*6),h=3+Math.floor(r()*4);const t=r()<0.5?MMID:MSH;rect(cv,bx,by,bx+w,by+h,t);rect(cv,bx,by,bx+w,by+1,mix(t,MHI,0.4));}
    save(cv,'l2_debris_scrap.png');}
  // ash wisp
  {const W=48,H=48,cv=C(W,H);const r=deterministic(84);const soot=hex('#20222a');
    for(let n=0;n<20;n++){const ax=14+Math.floor(r()*20),ay=26+Math.floor(r()*14);px(cv,ax,ay,soot,120);px(cv,ax+1,ay,soot,90);}
    save(cv,'l2_debris_ash.png');}
})();

console.log('L2 objects done.');
