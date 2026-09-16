'use strict';
// L1 representative first-harvest marker. A quiet organic trail, not the Home machine circuit:
// worn footsteps lead from arrival toward one open flower pocket; a leaf ring frames the target.
const path = require('path');
const L = require('./tools_iso_lib.js');
const { C, hex, px, rect, mix, darker, topDiamond, diamondOutline, isoEllipseTop } = L;
const save = L.saver(path.join(process.env.ART_OUT_DIR || __dirname, 'assets', 'objects'));

const earth = hex('#8a6a4a'), earthD = hex('#5c4433');
const green = hex('#4d8b4f'), greenL = hex('#a8d982'), greenD = hex('#1b3a2a');
const cream = hex('#e8dfc8'), violet = hex('#9e7ad9');

function drawLine(cv,x0,y0,x1,y1,colour,alpha=255,width=1){
  const steps=Math.max(Math.abs(x1-x0),Math.abs(y1-y0));
  for(let i=0;i<=steps;i++){
    const t=steps===0?0:i/steps,x=Math.round(x0+(x1-x0)*t),y=Math.round(y0+(y1-y0)*t);
    rect(cv,x-Math.floor(width/2),y-Math.floor(width/2),x+Math.ceil(width/2),y+Math.ceil(width/2),colour,alpha);
  }
}

function firstHarvest(){
  const W=512,H=192,cv=C(W,H);
  // Soft earth-coloured footfalls curve from the arrival side into the target pocket.
  const steps=[[58,35],[103,48],[148,56],[198,66],[248,76],[296,84],[336,90]];
  for(let i=0;i<steps.length;i++){
    const [x,y]=steps[i];
    const stepCol=i%2===0?earth:mix(earth,cream,0.18);
    isoEllipseTop(cv,x,y,9,stepCol,205,darker(earthD,0.25));
    // Three toe pixels and alternating height make these read as footfalls, not path nodes.
    for(let toe=0;toe<3;toe++)px(cv,x+8+toe*3,y-5+toe+(i%2?2:0),cream,180);
  }
  // The first I5 flower remains the real Y-sorted gatherable at image coordinate (384,96).
  // This decal only gives it an authored reading pocket below the actor/object layer.
  for(const radius of [78,66])diamondOutline(cv,384,96,radius,
    radius===78?greenD:mix(greenL,cream,0.18));
  topDiamond(cv,384,96,46,mix(earth,cream,0.22),70);
  // Three broad leaves with visible veins make the target read as harvest/life, not a gate.
  for(const [x,y,c] of [[318,96,green],[450,96,greenL],[384,57,mix(greenL,cream,0.15)]]){
    isoEllipseTop(cv,x,y,22,c,225,darker(greenD,0.15));
    drawLine(cv,x-12,y,x+12,y,darker(green,0.28),210,2);
  }
  // A small warm focus under the flower; no baked glow, just palette-safe pixels.
  for(let r=12;r<=28;r+=8)diamondOutline(cv,384,96,r,mix(cream,violet,0.10));
  save(cv,'l1_first_harvest.png');
}

firstHarvest();
console.log('l1 first-harvest marker done.');
