const fs = require('fs');
const { PNG } = require('pngjs');
// 36x48 native grid, x4 upscale. Palette (art guide + blacks)
const P = {
  k1:[23,23,28], k2:[35,35,41], k3:[46,46,56],      // cloak ramp dark->light
  v1:[107,74,158], v2:[158,122,217], v3:[217,184,255], // violet ramp
  rim:[232,223,200],                                  // cream rim light
  wood:[138,106,74], wood2:[92,68,51],
  boot:[92,68,51], boot2:[58,43,32],
  belt:[110,110,122], silver:[184,180,168],
};
const W=36,H=48;
function grid(){ return Array.from({length:H},()=>Array(W).fill(null)); }
function px(g,x,y,c){ if(x>=0&&x<W&&y>=0&&y<H) g[y][x]=c; }
function ell(g,cx,cy,rx,ry,c){ for(let y=0;y<H;y++)for(let x=0;x<W;x++) if(((x-cx)/rx)**2+((y-cy)/ry)**2<=1) px(g,x,y,c); }
function rect(g,x0,y0,w,h,c){ for(let y=y0;y<y0+h;y++)for(let x=x0;x<x0+w;x++) px(g,x,y,c); }
function vline(g,x,y0,y1,c){ for(let y=y0;y<=y1;y++) px(g,x,y,c); }
function hline(g,y,x0,x1,c){ for(let x=x0;x<=x1;x++) px(g,x,y,c); }
// shade: relight cloak by 3-tone based on x (top-right light) + selout outline
function finish(g){
  // rim light: any cloak pixel whose upper-right neighbor is empty -> rim hint (sparse)
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const c=g[y][x]; if(!c) continue;
    const isCloak = (c===P.k1||c===P.k2||c===P.k3);
    if(isCloak && (y===0||x===W-1||!g[y-1][x+1]) && ((x*7+y*13)%3===0)) g[y][x]=P.k3;
  }
  return g;
}
function upscale(g,s){
  const img=new PNG({width:W*s,height:H*s});
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const c=g[y][x]; if(!c) continue;
    for(let dy=0;dy<s;dy++)for(let dx=0;dx<s;dx++){
      const i=((y*s+dy)*img.width+(x*s+dx))*4;
      img.data[i]=c[0];img.data[i+1]=c[1];img.data[i+2]=c[2];img.data[i+3]=255;
    }
  } return img;
}

// ---------- Candidate A: 방랑자 (full hooded cloak, floating orb) ----------
function candA(){
  const g=grid();
  // flowing floor-length cloak: A-line silhouette
  for(let y=14;y<44;y++){ const half=3+((y-14)*4.2/30); for(let x=Math.round(18-half);x<=Math.round(18+half);x++) px(g,x,y,P.k2); }
  // cloak bottom ragged hem
  for(let x=13;x<=23;x++) if((x*5)%3!==0) px(g,x,44,P.k1);
  // left side shadow fold + right lit fold
  for(let y=16;y<44;y++){ px(g,Math.round(18-(3+((y-16)*4.0/28))),y,P.k1); px(g,Math.round(18+(3+((y-16)*4.0/28))),y,P.k3); }
  vline(g,16,20,42,P.k1); vline(g,20,20,42,P.k3); // inner folds
  // hood: big, pointed back
  ell(g,18,11,6,6,P.k2); ell(g,18,9,5,4,P.k3);
  px(g,12,7,P.k2); px(g,13,6,P.k2); px(g,13,5,P.k2); // hood point tilts left-back
  // face void + eyes
  ell(g,19,12,3.4,3.0,P.k1);
  px(g,18,12,P.v2); px(g,21,12,P.v2); px(g,18,11,P.v3); // glowing eyes, one shine
  // inner hood violet glow rim
  px(g,16,14,P.v1); px(g,17,15,P.v1); px(g,21,15,P.v1); px(g,22,14,P.v1);
  // silver clasp + violet sigil on chest
  px(g,18,17,P.silver); px(g,19,17,P.silver);
  px(g,18,20,P.v2); px(g,19,21,P.v1); px(g,18,22,P.v1);
  // staff (right hand side): tall, orb floats above tip
  vline(g,27,12,40,P.wood); vline(g,28,13,40,P.wood2);
  px(g,27,11,P.wood2);
  ell(g,27.5,8,1.8,1.8,P.v2); px(g,27,7,P.v3); px(g,28,8,P.v1); // orb
  px(g,25,9,P.v3); px(g,30,7,P.v3); // sparkles
  // sleeve reaching to staff
  for(let y=18;y<24;y++) for(let x=21;x<=26-(y>21?1:0);x++) px(g,x,y,P.k2);
  px(g,26,22,P.k1); px(g,26,23,P.k1); // hand shadow
  return finish(g);
}
// ---------- Candidate B: 모험가 (cape+tunic, boots, satchel, scarf) ----------
function candB(){
  const g=grid();
  // legs+boots
  rect(g,15,36,3,6,P.k2); rect(g,20,36,3,6,P.k2);
  rect(g,14,42,4,3,P.boot); rect(g,20,42,4,3,P.boot);
  hline(g,44,14,17,P.boot2); hline(g,44,20,23,P.boot2);
  // tunic
  for(let y=22;y<37;y++){ const half=4.5-((y-22)*0.06); for(let x=Math.round(19-half);x<=Math.round(19+half);x++) px(g,x,y,P.k3); }
  rect(g,15,29,9,2,P.belt); px(g,19,29,P.v2); // belt + violet buckle
  // satchel (left hip)
  rect(g,13,30,4,5,P.wood2); hline(g,30,13,16,P.wood); px(g,14,32,P.silver);
  // shoulder cape (short, flares right — wind)
  for(let y=16;y<28;y++){ const half=5+((y-16)*1.6/12); for(let x=Math.round(17-half);x<=Math.round(17+half*0.6);x++) px(g,x,y,P.k2); }
  for(let y=17;y<27;y++) px(g,Math.round(17-(5+((y-17)*1.5/11))),y,P.k1);
  // scarf tail flying left
  hline(g,18,9,13,P.v1); hline(g,17,7,11,P.v2); px(g,6,16,P.v2);
  // hood + face
  ell(g,18,11,5.4,5.2,P.k2); ell(g,18,9.5,4.4,3.6,P.k3);
  ell(g,19,12,3.2,2.8,P.k1);
  px(g,18,12,P.v2); px(g,21,12,P.v2); px(g,21,11,P.v3);
  // staff: shorter walking-stick, crystal shard tip
  vline(g,28,16,40,P.wood); px(g,28,15,P.wood2);
  px(g,28,13,P.v2); px(g,28,12,P.v3); px(g,27,14,P.v1); px(g,29,14,P.v1); // shard
  // arm to staff
  for(let y=22;y<26;y++) for(let x=23;x<=27;x++) if(x-y< 5) px(g,x,y,P.k3);
  return finish(g);
}
// ---------- Candidate C: 마도사 (wide-brim hat, robe, book) ----------
function candC(){
  const g=grid();
  // robe: straight elegant fall
  for(let y=18;y<44;y++){ const half=3.6+((y-18)*3.2/26); for(let x=Math.round(18-half);x<=Math.round(18+half);x++) px(g,x,y,P.k2); }
  for(let y=20;y<44;y++){ px(g,Math.round(18-(3.4+((y-20)*3.0/24))),y,P.k1); px(g,Math.round(18+(3.4+((y-20)*3.0/24))),y,P.k3); }
  hline(g,43,12,24,P.v1); // hem violet trim
  // hat: wide brim + tall bent cone
  hline(g,8,10,27,P.k2); hline(g,9,9,28,P.k1); // brim
  for(let y=2;y<8;y++){ const half=1+((y-2)*3.5/6); for(let x=Math.round(20-half);x<=Math.round(20+half);x++) px(g,x,y,P.k2); }
  px(g,21,1,P.k2); px(g,22,1,P.k2); // bent tip
  hline(g,7,16,25,P.k3); px(g,19,7,P.v2); px(g,20,7,P.v2); // hat band violet
  // face in hat shadow
  ell(g,18.5,12,3.4,2.8,P.k1);
  px(g,17,12,P.v2); px(g,20,12,P.v2); px(g,17,11,P.v3);
  // book on belt (left)
  rect(g,12,26,4,5,P.v1); vline(g,13,26,30,P.v3); px(g,14,28,P.rim);
  // staff: gnarled, orb nested in prongs
  vline(g,28,10,41,P.wood); vline(g,29,11,41,P.wood2);
  px(g,27,10,P.wood2); px(g,30,10,P.wood2); px(g,27,9,P.wood2); px(g,30,9,P.wood2); // prongs
  ell(g,28.5,8,1.6,1.6,P.v2); px(g,28,7,P.v3);
  // sleeve
  for(let y=20;y<25;y++) for(let x=22;x<=27;x++) if((x+y)%9!==0) px(g,x,y,P.k2);
  return finish(g);
}

const S=4, PAD=24;
const imgs=[candA(),candB(),candC()].map(g=>upscale(g,S));
const out=new PNG({width:imgs.length*(W*S+PAD)+PAD, height:H*S+PAD*2});
for(let i=0;i<out.data.length;i+=4){out.data[i]=26;out.data[i+1]=26;out.data[i+2]=32;out.data[i+3]=255;}
imgs.forEach((img,idx)=>{
  const ox=PAD+idx*(W*S+PAD), oy=PAD;
  for(let y=0;y<img.height;y++)for(let x=0;x<img.width;x++){
    const si=(y*img.width+x)*4; if(img.data[si+3]===0) continue;
    const di=((y+oy)*out.width+(x+ox))*4;
    for(let c=0;c<4;c++) out.data[di+c]=img.data[si+c];
  }
});
fs.writeFileSync('/workspace/group/char-candidates.png', PNG.sync.write(out));
console.log('written');
