#!/usr/bin/env node
// tools_gen_height.js — generate data/map_height.txt (v0.5 phase B real elevation).
//
// Parallel height map for the 시작의 숲 (starting grove), same 40×40 grid as
// data/map_layout.txt. One character per cell:
//   '0'  ground level (height 0)
//   '1'  plateau (+1 level, lifted HILL_LIFT px, cliff face on downhill transitions)
//   '2'  high plateau (+2 levels)
//   '/'  RAMP cell — the only place the player may cross a height transition. Rendered
//        at the mid-height of its high/low neighbours; walkable up/down.
//
// Design (per v0.5 level plan "풀 언덕"): the central grass meadow band (authored rows
// 17..23, the 'g' field) is the +1 hill. A small interior cluster (rows 19..21, centre
// columns) rises to +2 for silhouette. Ramps sit on the meadow's SOUTH edge (the stream
// exit the player climbs from G1) and where the meadow meets the G2 bush corridor to the
// NORTH — so the whole G1→G4 route stays traversable, and every hill cell is reachable.
//
// Crucially the base map_layout.txt is UNCHANGED — heights live in this parallel file —
// so the M4 exact tile-count asserts still hold. VOID/water/gate cells stay height 0.
//
// Run:  node tools_gen_height.js   (writes data/map_height.txt)

const fs = require("fs");
const path = require("path");

const GAME_DIR = __dirname;
const layoutPath = path.join(GAME_DIR, "data/map_layout.txt");
const outPath = path.join(GAME_DIR, "data/map_height.txt");

const layout = fs.readFileSync(layoutPath, "utf8").split("\n").filter((l) => l.length > 0);
const H = layout.length;
const W = layout[0].length;

// A cell is island (can carry height) iff its authored symbol is not VOID and not water
// and not a night-gate cell (gates stay at ground level so the day/night route is flat).
function isFlatBase(sym) {
  return sym === "V" || sym === "W" || sym === "w" || sym === "m" || sym === "N" || sym === "K";
}

// Hill band: authored meadow rows (inclusive). These are the 'g' grass field north of
// the G1 stream and south of the G2 corridor wall — the "풀 언덕".
const HILL_ROW_MIN = 17;
const HILL_ROW_MAX = 23;
// +2 core: a compact rise in the meadow centre for silhouette.
const HI_ROW_MIN = 19,
  HI_ROW_MAX = 21,
  HI_COL_MIN = 10,
  HI_COL_MAX = 22;

// Authored ramp cells (col,row): the walk-up / walk-down crossings on the route.
//  - south edge (row 23) near the stream exit column (the player climbs here after G1);
//  - north edge (row 17) at the bush-corridor column 18 (descends toward the G2 gap).
const RAMPS = [
  [14, 23],
  [15, 23],
  [16, 23],
  [18, 17],
];
const rampSet = new Set(RAMPS.map(([c, r]) => `${c},${r}`));

const rows = [];
for (let r = 0; r < H; r++) {
  let line = "";
  for (let c = 0; c < W; c++) {
    const sym = layout[r][c];
    let ch = "0";
    if (r >= HILL_ROW_MIN && r <= HILL_ROW_MAX && !isFlatBase(sym)) {
      ch = "1";
      if (r >= HI_ROW_MIN && r <= HI_ROW_MAX && c >= HI_COL_MIN && c <= HI_COL_MAX) {
        ch = "2";
      }
    }
    if (rampSet.has(`${c},${r}`)) {
      // Only mark a ramp where the base cell is actually island ground.
      ch = isFlatBase(sym) ? ch : "/";
    }
    line += ch;
  }
  rows.push(line);
}

fs.writeFileSync(outPath, rows.join("\n") + "\n");

// Report
let counts = { "0": 0, "1": 0, "2": 0, "/": 0 };
for (const line of rows) for (const ch of line) counts[ch] = (counts[ch] || 0) + 1;
console.log(`wrote ${outPath}  (${H}×${W})`);
console.log(`  height0=${counts["0"]} height1=${counts["1"]} height2=${counts["2"]} ramps=${counts["/"]}`);
