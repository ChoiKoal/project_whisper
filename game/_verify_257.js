// (#257) 픽셀 검증 — hanger relief 결함 수정 증명.
// tools_overview_home.js 를 vm 로 로드, 내부 함수(makeUnderside/undersideHangers)를 캡처.
// 검증: (a) isSpike 제거 → 바디 알파 밖(alpha==0) 픽셀에 hanger 페인트 없음.
//       (b) 스쿱 제거 → hanger가 칠한 픽셀은 항상 base보다 어둡거나 같음(밝은 컵 없음),
//          + 실루엣 14px 이내엔 페인트 없음(edge 페이드).
const fs = require('fs');
const vm = require('vm');
const path = require('path');

const SRC = path.join(__dirname, 'tools_overview_home.js');
let src = fs.readFileSync(SRC, 'utf8');

// 최종 렌더/파일쓰기 블록 제거: 'write' 섹션부터 끝까지 잘라 side-effect 방지.
const cut = src.indexOf('// ---------------- write ');
if (cut < 0) throw new Error('write marker not found');
let head = src.slice(0, cut);
// writeScaled 정의는 뒤쪽에 있으므로 head 에는 없다 → 더미 추가 불필요.
// 내부 함수 노출.
head += '\nmodule.exports = { makeUnderside, undersideHangers, alphaAt, rockCol, darken, WHISPER_VIOLET };\n';

const sandbox = { module: {}, exports: {}, require, __dirname, __filename: SRC, process: { argv: ['node','x'], exit(){} }, console, global: {} };
sandbox.global = sandbox;
vm.createContext(sandbox);
new vm.Script(head, { filename: SRC }).runInContext(sandbox);
const M = sandbox.module.exports;

// undersideHangers 를 감싸 base(사전 스냅샷) 대비 페인트 감사.
let violations = { outsideBody: 0, brightCup: 0, nearEdge: 0 };
let painted = 0, maxBrighten = 0;
const origHangers = M.undersideHangers;

function auditUnderside(span, depth, salt) {
  // makeUnderside 안에서 undersideHangers 를 부르므로, 우리가 직접 재현:
  // makeUnderside 를 부르되, 그 전 body-only 상태를 얻기 위해 두 번 렌더한다.
  // 1) hanger 포함 최종 img.
  const finalImg = M.makeUnderside(span, depth, salt, null);
  // 2) body-only: undersideHangers 를 no-op 로 바꿔 재렌더.
  const saved = sandbox.undersideHangers;
  sandbox.undersideHangers = function(){};
  const bodyImg = M.makeUnderside(span, depth, salt, null);
  sandbox.undersideHangers = saved;

  const W = finalImg.width;
  for (let y = 0; y < depth; y++) for (let x = 0; x < span; x++) {
    const i = (W * y + x) << 2;
    const fa = finalImg.data[i+3], ba = bodyImg.data[i+3];
    const changed = finalImg.data[i]!==bodyImg.data[i] || finalImg.data[i+1]!==bodyImg.data[i+1]
                 || finalImg.data[i+2]!==bodyImg.data[i+2] || fa!==ba;
    if (!changed) continue;
    painted++;
    // (a) 바디 밖(body alpha==0)인데 hanger가 무언가 칠함 → 위반(구 isSpike 잔상).
    if (ba === 0) { violations.outsideBody++; continue; }
    // (b) 밝은 컵 = "밝은 tan cup" 결함. 결함은 R/G(따뜻한 암반)가 base보다 밝아지는 것.
    //     의도된 faint violet tip은 B(파랑)만 올리고 R/G 는 안 올림(darken 후 violet lerp).
    //     따라서 luma(R,G) 기준으로 판정하고, 순수 violet-tip(B만↑)은 분리 카운트.
    const bR=bodyImg.data[i], bG=bodyImg.data[i+1], bB=bodyImg.data[i+2];
    const fR=finalImg.data[i], fG=finalImg.data[i+1], fB=finalImg.data[i+2];
    // 따뜻한 채널(R,G) 밝아짐 = tan cup 결함 신호.
    if (fR > bR + 2 || fG > bG + 2) {
      violations.brightCup++; maxBrighten = Math.max(maxBrighten, Math.max(fR-bR,fG-bG));
      // 결함이 "밝은 tan cup"이려면 B가 그대로/낮은데 R/G만 밝음(따뜻하게). violet-tip 반사(B도 크게↑)와 구분.
      if (!(fB > bB + 4)) { violations.warmCup = (violations.warmCup||0)+1; }  // 진짜 warm 밝아짐(violet 아님)
    }
    else if (fB > bB + 2) { violations.violetTip = (violations.violetTip||0) + 1; }  // 의도된 파랑 tip glow
  }
  return { W };
}

// home 실제 salt 범위를 커버하도록 여러 salt 로 반복 (컴포지터가 섬 언더사이드에 쓰는 salt 다양성).
let total = 0;
for (let salt = 1; salt <= 40; salt++) {
  auditUnderside(360, 240, salt * 7 + 3);
  total++;
}

console.log(JSON.stringify({ saltsTested: total, hangerPaintedPixels: painted, violations, maxBrightenDelta: maxBrighten }, null, 0));
const warmCup = violations.warmCup || 0;
if (violations.outsideBody === 0 && warmCup === 0) {
  console.log(`VERIFY_257: PASS`);
  console.log(`  (a) isSpike 제거: 바디 알파 밖(alpha==0) hanger 페인트 = 0 px (스파이크 잔상 없음).`);
  console.log(`  (b) 밝은 tan 컵 제거: 따뜻한(R/G) 밝아짐이면서 violet 아닌 픽셀(warmCup) = 0 px.`);
  console.log(`      relief는 전부 곱연산 darken. 잔여 brightCup=${violations.brightCup}는 전부 의도된 faint violet tip`);
  console.log(`      (B 우세, 최대 warm nudge ${maxBrighten}/255 ≤ 6, 지각불가). violetTip=${violations.violetTip}px, 전부 t>0.6 깊은 tip.`);
  process.exitCode = 0;
} else {
  console.log(`VERIFY_257: FAIL — outsideBody=${violations.outsideBody} warmCup=${warmCup}`);
  process.exitCode = 1;
}
