'use strict';
// tools_gen_home_maker.js — recovery representative-art slice for the Home maker yard.
// Generates only new assets; it deliberately does not rewrite legacy cauldron sprites.
// Grammar: 2:1 top faces, bottom-centre origin, NE light, selout, AO, existing Home/L1 palette.
const path = require('path');
const L = require('./tools_iso_lib.js');
const {
  C, hex, px, rect, mix, darker, lighter, ao, isoCylinder, isoBox,
  isoEllipseTop, topDiamond, diamondOutline,
} = L;
const save = L.saver(path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects'));

const bodyD = hex('#2a2a33'), glowV = hex('#9e7ad9'), glowB = hex('#d9b8ff'), cream = hex('#faf5e6');
const earthD = hex('#3a2a20'), earth = hex('#5c4433'), earthL = hex('#8a6a4a');
const woodD = hex('#3a2a20'), wood = hex('#5c4433'), woodL = hex('#b59268');
const stoneD = hex('#2a2a33'), stone = hex('#6e6e7a'), stoneL = hex('#b8b4a8');
const greenD = hex('#1b3a2a'), green = hex('#4d8b4f'), greenL = hex('#a8d982');
const blueD = hex('#1e3a5c'), blue = hex('#4aa3b8'), blueL = hex('#8fd4d9');

function drawLine(cv,x0,y0,x1,y1,colour,alpha=255,width=1){
  const steps=Math.max(Math.abs(x1-x0),Math.abs(y1-y0));
  for(let i=0;i<=steps;i++){
    const t=steps===0?0:i/steps,x=Math.round(x0+(x1-x0)*t),y=Math.round(y0+(y1-y0)*t);
    rect(cv,x-Math.floor(width/2),y-Math.floor(width/2),x+Math.ceil(width/2),y+Math.ceil(width/2),colour,alpha);
  }
}

function drawChevron(cv,a,b,t,colour){
  const dx=b[0]-a[0],dy=b[1]-a[1],len=Math.hypot(dx,dy)||1;
  const ux=dx/len,uy=dy/len,pxv=-uy,pyv=ux;
  const tip=[a[0]+dx*t,a[1]+dy*t];
  const back=[tip[0]-ux*17,tip[1]-uy*17];
  drawLine(cv,back[0]+pxv*10,back[1]+pyv*10,tip[0],tip[1],colour,245,4);
  drawLine(cv,tip[0],tip[1],back[0]-pxv*10,back[1]-pyv*10,colour,245,4);
}

function makerYard(){
  const W=896,H=320,cv=C(W,H);
  // Image coordinates are aligned to the actual authored cells relative to anchor m(8,12):
  // inputs(128,192), cauldron(320,160), Build(576,224), Whisper(768,256).
  const stations=[[128,192],[320,160],[576,224],[768,256]];
  // A wide dark edge and a lighter inner road make one continuous maker circuit while the
  // underlying authoritative dirt tiles remain unchanged for movement and saves.
  for(let i=0;i<stations.length-1;i++){
    const a=stations[i],b=stations[i+1];
    drawLine(cv,a[0],a[1],b[0],b[1],darker(earth,0.58),255,70);
    drawLine(cv,a[0],a[1]-3,b[0],b[1]-3,mix(stone,earthL,0.28),255,58);
    drawLine(cv,a[0],a[1]-6,b[0],b[1]-6,mix(glowV,cream,0.15),225,5);
    drawChevron(cv,a,b,0.62,mix(glowV,cream,0.30));
  }
  const padCols=[mix(woodL,stoneL,0.28),mix(earthL,stoneL,0.38),stone, mix(stone,glowV,0.22)];
  for(let i=0;i<stations.length;i++){
    const [x,y]=stations[i],tone=padCols[i];
    topDiamond(cv,x,y-4,86,tone,255);
    diamondOutline(cv,x,y-4,86,darker(tone,0.52));
    diamondOutline(cv,x,y-4,70,mix(glowV,cream,0.08));
  }
  // Four simple, aligned station marks. The physical props carry meaning; the floor stays calm.
  for(const x of [108,128,148])isoEllipseTop(cv,x,188,9,blueD,235,darker(blueD,0.45));
  for(let r=18;r<=30;r+=12)diamondOutline(cv,320,156,r,mix(bodyD,glowV,0.24));
  topDiamond(cv,556,220,22,stoneD,230); topDiamond(cv,596,220,22,stoneL,230);
  diamondOutline(cv,768,252,34,mix(glowV,cream,0.05));
  save(cv,'home_maker_yard.png');
}

function makerInputs(){
  const W=160,H=160,cv=C(W,H),cx=80;
  ao(cv,cx,136,58,9,78);
  isoBox(cv,cx,96,58,20,woodL,wood,woodD);
  const jars=[
    [46,78,earthL,earth,earthD],
    [80,68,greenL,green,greenD],
    [114,78,blueL,blue,blueD],
  ];
  for(const [x,y,top,right,left] of jars){
    isoCylinder(cv,x,y,14,28,top,right,left,0.82);
    isoEllipseTop(cv,x,y,8,mix(top,cream,0.22),255,darker(top,0.5));
  }
  // Contents are shape-coded as well as colour-coded: soil grains, sprout, water shine.
  for(const [x,y] of [[42,76],[48,80],[52,75]])px(cv,x,y,cream,210);
  rect(cv,78,58,82,72,greenD); rect(cv,70,60,79,64,greenL); rect(cv,82,57,91,61,greenL);
  rect(cv,106,76,122,78,blueL); rect(cv,110,72,118,74,cream,190);
  rect(cv,28,95,34,132,woodD); rect(cv,126,95,132,132,wood);
  save(cv,'home_maker_inputs.png');
}

function makerBuild(){
  const W=192,H=160,cv=C(W,H),cx=96;
  ao(cv,cx,143,72,10,82);
  isoBox(cv,cx,94,70,22,woodL,wood,woodD);
  isoBox(cv,58,116,12,20,wood,woodD,darker(woodD,0.28));
  isoBox(cv,134,116,12,20,woodL,wood,woodD);
  isoBox(cv,82,70,24,26,stoneL,stone,stoneD);
  isoBox(cv,119,78,20,18,mix(stoneL,glowV,0.18),stone,stoneD);
  // One visible mallet makes the station read as Build rather than a table with boxes.
  rect(cv,143,62,148,100,woodD); rect(cv,147,62,150,100,woodL);
  isoBox(cv,146,54,18,9,stoneL,stone,stoneD);
  topDiamond(cv,137,99,13,glowV,220); diamondOutline(cv,137,99,13,stoneD);
  save(cv,'home_maker_build.png');
}

function makerWhisper(){
  const W=160,H=192,cv=C(W,H),cx=80;
  ao(cv,cx,177,54,9,82);
  isoBox(cv,cx,139,50,18,stoneL,stone,stoneD);
  isoCylinder(cv,cx,122,14,24,stoneL,stone,stoneD,0.92);
  rect(cv,74,72,86,132,stoneD); rect(cv,80,72,86,132,stoneL);
  const petals=[[80,58],[53,81],[107,81]];
  for(let i=0;i<petals.length;i++){
    const [x,y]=petals[i];
    const c=i===0?lighter(glowV,0.18):(i===1?mix(glowV,blueL,0.24):mix(glowV,greenL,0.16));
    isoBox(cv,x,y,20,7,c,mix(c,stone,0.22),darker(c,0.42));
    topDiamond(cv,x,y,7,cream);
    // One, two, three short voice marks distinguish the three resonators.
    for(let mark=0;mark<=i;mark++)rect(cv,x-5+mark*5,y-2,x-3+mark*5,y+1,darker(glowV,0.32),230);
  }
  isoEllipseTop(cv,cx,91,22,cream,255,darker(glowV,0.42));
  isoEllipseTop(cv,cx,91,13,glowB,255,darker(glowV,0.30));
  // Reflected violet light ties the active core back into its physical stand.
  rect(cv,80,102,86,124,glowV,170);
  topDiamond(cv,cx,139,18,mix(stoneL,glowV,0.25),230);
  save(cv,'home_maker_whisper.png');
}

makerYard();
makerInputs();
makerBuild();
makerWhisper();
console.log('home maker assets done.');
