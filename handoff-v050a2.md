# Handoff — v0.5 phase A2 (elevation VISUAL CONTINUITY fix)

Godot 4.5.stable. Base = uncommitted v0.5a tree. Version stays **0.4.0** (no bump).
Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
**No git commit, no export rebuild** (per instructions).

---

## Owner reject on v0.5a
> "풀 타일 숲타일 Z축이 다 똑같은데 대충 언덕 세운다고 되겠냐? 높이가 전혀 안 이어져 보임"

The raised plateau did not visually connect to the lower ground: cliff faces appeared on
only some transitions, with black gaps between levels; the hill read as floating patches.

## What was actually wrong in the first (v0.5a) implementation

The v0.5a `_build_cliff_faces` **region-clipped the CC0 `cliff_face_*.png` monolith**
(128×230 — a solid rock wall with NO grass cap, ~171px of wall + a baked diamond foot).
Two bugs made that fail:

1. **Wrong anchor + clip window.** It anchored the sprite top at the lifted diamond
   *centre* and region-clipped only the top `HILL_LIFT*drop + 40` px (72px for a +1 drop).
   The top ~64px of that monolith is the diamond BACK-rim, not wall — so a +1 face showed
   almost no rock and left the drop mostly open → the "높이가 안 이어져" gaps.
2. **Faces only where `_downhill_faces` fired, but nothing tied the wall base to the lower
   ground surface** — the clipped sliver floated, and +2 never stacked to a full 64px wall.

There was also **no AO seat, no grass fringe, and the ramp was a flat tinted dirt decal**
(no thickness → "floating flat tile"). And the **overview render** drew the interior ridge
V-band as raw 128×230 monoliths in painter order → black seams between every piece (the
"floating rock patches" the owner saw in preview-v050a.png).

## What changed

### NEW `scripts/world/cliff_gen.gd` (`CliffGen`) — parametric iso terrain art
Draws all elevation art procedurally so it is **gap-free by construction** and matches the
128×64 / 32px-per-level iso exactly (measured, not assumed). Pure integer math, mirrored
1:1 in the overview JS so the render == the game.
- `make_apron(drop, expose_se, expose_sw, salt)` → a `128 × (drop*32 + 64)` rock wall.
  For each screen column it finds the raised diamond's front rim and extrudes straight
  down exactly `drop*32` px, so the wall **starts at the raised diamond bottom edge and
  reaches the lower ground with ZERO gap**. Exposing both S+E gives an outer-corner V;
  +2 makes a 64px wall (stacks seamlessly). SE face lit / SW face shaded (light upper-R),
  faceted rock strata + cracks so it reads as fractured stone, and a **5px grass-lip
  fringe** baked on the top rim (kills the razor edge — satisfies the `_w_trans` fringe
  intent programmatically).
- `make_ao_diamond(strength)` → soft dark AO diamond (squared falloff) for the seat.
- `make_ramp(dir, salt)` → a worn-dirt slope diamond WITH a `LIFT`-tall front wall so the
  ramp has thickness and visibly climbs toward its high neighbour.

### `scripts/world/map_loader.gd`
- **`_build_cliff_faces` rewritten** to full-perimeter skirting via `CliffGen.make_apron`:
  every non-ramp raised cell whose screen-S (+row) or screen-E (+col) neighbour is lower
  gets ONE apron sprite covering the exposed edge(s), anchored at the lifted diamond
  top-left. 46 aprons on the grove plateau. `cliff_face_count` now counts aprons.
- **NEW `_build_ao_seats`** — an AO diamond on the lower ground at the foot of every
  exposed cliff (48 in grove). `ao_seat_count`. z below the aprons.
- **`_build_ramp_slopes` rewritten** to `CliffGen.make_ramp` (climb dir = toward highest
  neighbour). `ramp_slope_count`.
- **Raised `Elev%d` layers get a per-tier `modulate` tonal lift** (higher ground catches
  more sun) so the plateau reads as ABOVE the meadow even where the grass art is identical
  — the cliff wall carries the geometry, the value carries the separation.
- Untouched: height data/classification, per-level TileMapLayers, ledge collision (98),
  height-aware AStar, object lift, the **border cliff-skirt and interior ridge systems**
  (prior-agent work — left as-is in the game).

### `game/tools_overview_v050a2.js` (NEW) — corrected overview pipeline
Full pngjs pipeline mirroring `CliffGen` + `_build_elevation`: base ground → AO seats →
per-cell apron + tonally-lifted raised grass → ramps → ridge → objects, back-to-front.
Outputs **`/workspace/group/preview-v050a2.png`** (1600×986) and
**`/workspace/group/preview-v050a2-closeup.png`** (2× hill crop). `DBG=1` isolates the
plateau (skips ridge/objects) for inspection.
- **Interior ridge V-band**: to kill the painter-order black seams between the non-tiling
  monoliths, the overview now draws the ridge band as a continuous `RIDGE_LVL=3` rock
  apron + faceted rock cap (gap-free). This is a **schematic representation** of the
  continuous rock wall the Y-sorted game builds — the in-game ridge still uses the CC0
  `ridge_rock` monoliths (unchanged). Called out as a fidelity note below.

## My own visual verdict (I read the renders)
- **preview-v050a2-closeup.png / DBG plateau crop**: the raised meadow drops to the lower
  ground via ONE continuous brown rock cliff wall along both front edges, forming a clean
  outer corner at the bottom vertex; grass-lip fringe on the rim; AO seat at the base;
  the +2 core stacks with a taller wall and **no black gap between tiers**. The raised
  grass is tonally lifted so the tier separation reads. This is the connected hill the
  owner asked for.
- **preview-v050a2.png (full)**: the whole elevated region — plateau + ridge canyon rims —
  reads as one connected landmass; every raised edge is skirted; no black gaps at any
  transition; ramps read as slopes with thickness.
- Honest caveat: a single +1 (32px) step is a low retaining-wall look by nature; the +2
  core and the ridge (3-level) read as proper cliffs. +2 stacking IS seamless, so I kept
  +2 (did not fall back to +1-everywhere).

## Validation
- **Headless import: 0 errors.** Grove builds elevation clean (v050a harness exercises it:
  aprons=46, ao_seats=48, ramp_slopes=4, ledge=98, hill=186).
- Harnesses (`--headless res://scenes/dev/<name>.tscn`):
  | v021 v030 v031 v040 v040b m2 m3 m4 m5 m6a m7 m8 m2_integration | **PASS** |
  | e2e_playthrough (full G1–G4 clear) | **PASS** (elevation didn't break the route) |
  | **v050a (updated)** | **PASS (0 failures)** |
  | v040c `bgm_day loops forward` | **FAIL (1) — pre-existing audio regression, not mine** |
- **v050a asserts strengthened honestly** to the new skirting logic:
  - `EVERY exposed raised edge cell is skirted` — recomputes expected apron count from the
    height data and asserts `cliff_face_count == expected` (46==46) → no un-skirted edge.
  - apron sprites carry a generated full-height wall texture (≥ one level + foot).
  - `AO seating-shadow sprites drawn at cliff feet` (`ao_seat_count > 0`).
  - `ramp slopes drawn on every ramp cell` (`ramp_slope_count == ramp_cells.size()`).

## Files touched
NEW: `game/scripts/world/cliff_gen.gd`, `game/tools_overview_v050a2.js`,
`/workspace/group/preview-v050a2.png`, `/workspace/group/preview-v050a2-closeup.png`,
`project-whisper/handoff-v050a2.md`.
MODIFIED: `game/scripts/world/map_loader.gd` (apron rewrite + AO seats + ramp rewrite +
elevation-layer modulate + `ao_seat_count`/`ramp_slope_count`),
`game/scenes/dev/v050a_test_harness.gd` (skirting/AO/ramp asserts).
UNCHANGED game render of the interior ridge (still CC0 monoliths, Y-sorted).

## Deviations / notes (raw)
1. **Cliff faces are programmatic, not the CC0 `cliff_face_*` clip.** The measured CC0
   piece is a 171px monolith wall with no grass cap and a baked foot — it cannot represent
   a clean 32/64px iso drop without an ugly sliver. Generating the wall to the exact drop
   (brief explicitly allows/mandates programmatic art for AO and ramps) is what makes the
   skirting gap-free. The CC0 rock TONE is sampled into the palette so it still reads as
   the same stone.
2. **Overview ridge is schematic** (continuous parametric rock, not the monolith art) to
   remove painter-order seams; the game keeps the monoliths (Y-sort covers seams). If a
   future phase wants the ridge to look identical in-game, port the same apron treatment
   into `_build_ridges` (would need v040/v050a ridge asserts updated).
3. v040c bgm failure left unfixed — out of scope (audio deliverable), pre-existing.
4. No version bump / export / commit — per instructions.
