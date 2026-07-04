# Project Whisper — M4 Handoff (Real Map + Day/Night + Puzzle Gates)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on M0+M1+M2+M3 (see `handoff-m2.md`, `handoff-m3.md`). Those systems unchanged
> except: `interaction_controller.SOURCE_TO_TILE_ID` gained `10: "T5M"`; `m2_test_harness`
> asserts the grown catalog (57 canonical items, was 30). Main scene is now the real map.

## What was built

### 0. Main scene switch
`project.godot` `run/main_scene` → `res://scenes/world/starting_grove.tscn`.
`test_map.tscn` stays for the M2/M3 harnesses (they load it explicitly).

### 1. Data-driven map — `data/map_layout.txt` + `data/map_legend.json`
- **map_layout.txt**: the Part A §A-1 40×40 ASCII map, byte-exact (40 lines × 40 chars,
  no ruler/colon prefix). Verified char-for-char against level-design-v1 Part A.
  Coordinate convention `(col,row)`, `(0,0)` = top-left = north/world-tree; row 39 = south/spawn.
- **map_legend.json**: symbol → `(tileset source, tile_id, flags)` for tiles, and
  symbol → `(scene, object_id, gatherable, gate)` for objects, plus landmark names.
  Source ids match the **actual tileset** (`whisper_tileset.tres`), not the illustrative
  C-1 JSON: `G/g=2`, `D=1`, `M(mud)=7`, `W=8`, `w=9`, `m(mystic)=10`, `V=0`.
  (C-1's example used 4/5/5/5; the real tileset assigns distinct sources — legend follows
  the tileset. `SOURCE_TO_TILE_ID` == source-id-as-tile-id convention is preserved.)

### 2. Map loader — `scripts/world/map_loader.gd` (`class_name MapLoader`, extends TileMapLayer)
Replaces the hand-coded MapBuilder for the real map (test_map keeps MapBuilder). On
`_ready()`: `_load_data` → `_build_tiles` (set_cell per legend; `g` picks T2A~T2D by cell
hash, deterministic) → `_build_objects` (instances object scenes into `YSortLayer`) →
`_place_player` (moves Player onto spawn cell) → `_wire_stump_fade`.
- Exposes for wiring/tests: `spawn_cell`, `cauldron_cell`, `stump_cell`, `bush_cell`,
  `world_tree_cells[]`, `night_gate_cells[]`, `stepping_slot_cells[]`, `tile_counts{}`,
  `object_spawns[]` (respawn source of truth), `rest_stump`.
- Helpers: `cell_center_world(cell)`, `world_to_cell(world)`.
- Trees/flowers/rocks/stones become `Gatherable` (M2) with the legend's `item_id`;
  cauldron/stump/bush/night-gate/world-tree/mystic-water use their dedicated scripts.

### 3. Gate wiring (all listen to M2/M4 GameState signals — no new frameworks)
- **G1 stream (배치형)** — `K` cells are T5A water (non-walkable) in the layout. Placing
  **D14** on them uses the M2 placement framework unchanged: swaps to source 1 (walkable),
  emits `stepping_stone_placed`. Stone-on-water art still reuses T1 dirt (M2 TODO).
- **G2 dry bush (사용형)** — `scripts/world/bush_dry.gd` (`BushDry`, extends Gatherable,
  `object_id="bush_dry"`, use-only). A child StaticBody2D physically blocks cell (18,16).
  On `GameState.item_used_on_object("I7", self)` → `bloom()`: swap to bush_bloom art, free
  the collider, corridor opens. `is_bloomed()` for tests.
- **G3 night path (시간형)** — `scripts/world/night_gate.gd` (`NightGate`) at N cells
  (19,7)/(20,7). Listens to `GameState.day_phase_changed`; `_apply(is_night_window())`
  toggles closed-bud sprite + StaticBody2D wall (day) vs open-bud + additive glow +
  no collision (evening~dawn). Day-time approach flavor
  "꽃봉오리가 닫혀 있다… 밤을 기다리는 걸까" driven by `scripts/world/night_gate_guard.gd`
  (`NightGateGuard`, polls player distance to the `night_gate` group, 2.5s per-gate cooldown).
- **G4 clear (체인형)** — `scripts/world/world_tree.gd` (`WorldTree`, extends Gatherable,
  `unique=true`, `item_id="I9"`) at the O cluster; stays after one gather (M2 unique/_spent).
  Chain I9(catalyst)+I7 → D19 → D20 → D22, then place D22 on a T0 VOID cell →
  `world_tree_planted` → `scripts/world/clear_sequence.gd` (`ClearSequence`, CanvasLayer
  layer 10): fade to dark, "…들려? 방금, 세계가 대답했어.", "Project Whisper — 계속됩니다"
  + 발견률 stats (from Codex/ItemDB/RecipeDB), ESC/interact returns to free play
  (`GameState.time_running` restored). `mystic_water.gd` (`MysticWater`) yields I7 at the
  `m` tiles behind the tree with a violet glow.

### 4. Day/night cycle — `GameState` (extended) + `day_night.gd` + `time_hud.gd`
- **GameState** (`scripts/core/game_state.gd`): `game_time` accumulates in `_process`.
  `DAY_LENGTH=900s` (day 540 / evening 120 / night 180 / dawn 60). API:
  `day_fraction()`, `day_index()`, `phase()` ∈ {day,evening,night,dawn},
  `is_night_window()` (true evening~dawn), `set_game_time(t)` (harness/M5-load, re-emits
  phase), `skip_to_next_evening()` (Rest Stump), signals `game_time_changed`,
  `day_phase_changed(phase)`.
- **DayNight** (`day_night.gd`, CanvasModulate): color curve keyed off `day_fraction()`
  per C-3 keyframes (cream→warm→violet→deep blue-violet→dawn).
- **GlowSprite** (`glow_sprite.gd`): additive overlay (world tree / mystic water / night
  bloom); alpha ramps faint-by-day → strong-at-night off `day_phase_changed`, plus a
  breathing pulse. NOTE: it is an additive child in the same canvas as the CanvasModulate,
  so the modulate still tints it slightly — acceptable for placeholder; a dedicated CanvasLayer
  is the follow-up if the night "pop" needs to be exact.
- **TimeHUD** (`time_hud.gd`, CanvasLayer): top-right sun/moon glyph + "낮/저녁/밤/새벽 · N일차".

### 5. Rest Stump — `scripts/world/rest_stump.gd` (`RestStump`)
At (12,33). Duck-types the InteractionController contract (like Cauldron): `can_gather()`
false → routes to `on_interact()` → `rest()`: fade the scene ColorRect to black,
`GameState.skip_to_next_evening()`, fade back. `fade_rect` injected by the map loader;
if null (harness) the skip is instant.

### 6. Object respawn / VOID persistence — `scripts/world/object_respawn.gd` (`ObjectRespawn`)
Watches the loader's `object_spawns` (T/F/R/s). When a tracked node frees on gather it
schedules a respawn at `game_time + DAY_LENGTH` and rebuilds the same object at the same
cell then — UNLESS the tile beneath became T0 VOID (player gathered the tile too), in which
case it never respawns. Tile gathers → VOID are permanent (테마). The unique World Tree
never frees, so never respawns. `force_tick()` test helper.

## Two locked QA tweaks (applied)
1. **Player +25%**: `starting_grove.tscn` Player/AnimatedSprite2D `scale = Vector2(1.25, 1.25)`.
   Sheet NOT regenerated.
2. **Top-right lighting**: all NEW M4 placeholder art (bush_dry/bloom, rest_stump, world_tree
   (+glow), young_tree, night buds, mystic glow) shades lit-from-top-right
   (`(x - y) > t ? lit : dark` in `tools_gen_art.js`). Existing trees (tree_a/b) still shade
   top-left; left as-is per the tweak (flagged for the final art pass, not regenerated).

## Scene structure — `scenes/world/starting_grove.tscn`
```
StartingGrove (Node2D)
├── DayNight (CanvasModulate, day_night.gd)
├── Ground (TileMapLayer, map_loader.gd)   # ysort/feedback/player/fade paths exported
├── TileHighlight (Node2D, tile_highlight.gd)
├── YSortLayer (Node2D, y_sort)
│   └── Player (CharacterBody2D) → AnimatedSprite2D(scale 1.25) / Collision / Camera2D
│   └── (map objects instanced here at runtime)
├── Interaction (InteractionController)     # M2, unchanged logic
├── ObjectRespawn (ObjectRespawn)
├── NightGateGuard (NightGateGuard)
├── InventoryUI / FusionUI / CodexUI (CanvasLayers, M2/M3)
├── TimeHUD (CanvasLayer)
├── ClearSequence (CanvasLayer, layer 10)
└── FadeLayer (CanvasLayer, layer 8) → Fade (ColorRect)  # rest-stump fade
```

## Deviations / notes
- Legend source ids follow the real tileset (mud 7, water 8/9, mystic 10, void 0), not the
  illustrative C-1 example (which used 4/5/5/5). Internally consistent + matches
  `SOURCE_TO_TILE_ID`.
- Stepping-stone-on-water still visually reuses T1 dirt (M2 carry-over TODO).
- GlowSprite additive layer shares the CanvasModulate canvas (minor tint bleed; placeholder-OK).
- Gates enforce progression both physically (StaticBody2D walls on B/N + water polygons on
  W/w/m/K) and logically; matches the Part A §A-5 flood-fill geometry (G1→G2→G3→G4 only).

## M5 (save) hook guidance
Serialize alongside `Inventory` + `Codex.to_dict()`:
- `GameState.game_time` (float) — restore via `GameState.set_game_time(t)` (re-emits phase).
- **Tile deltas**: which cells became T0 VOID (tile gathers) and which K water cells became
  walkable (D14 placed). The layout is deterministic; store only the diff from
  `map_layout.txt`. `g`/tree variants are cell-hash deterministic — no need to save.
- **Removed/respawning objects**: for each `object_spawns` cell, store gathered state +
  `respawn_at` (or "present"). World Tree `_spent` (I9 taken) is a single bool.
- **Gate state**: BushDry `is_bloomed()`; G3 derives from `game_time` (no separate save).
  `world_tree_planted` / cleared is a single bool.
`MapLoader` rebuilds the base map on load; the save layer then applies the tile/object diff.

## Validation output tails

### Import (zero script/parse errors)
```
cd game && Godot_v4.5-stable_linux.arm64 --headless --import .
→ exit 0; no SCRIPT ERROR / Parse Error / ERROR lines.
```

### Main scene runtime (zero runtime errors)
```
... --headless res://scenes/world/starting_grove.tscn --quit-after 300
→ exit 0; zero error lines.
```

### Acceptance — `scenes/dev/m4_test_harness.tscn` (exit 0, 30/30 PASS)
```
=== M4 TEST HARNESS ===
[PASS] map is 40 rows / 40 cols / all 1600 cells populated
[PASS] tile counts match legend exactly
[PASS] spawn (12,32) / cauldron (13,32) / stump (12,33) / bush (18,16)
[PASS] 3 stepping-stone slots / 2 night-gate cells / 4 world-tree cells
[PASS] WorldTree spawned, unique I9
[PASS] G1 stone slot starts non-walkable → D14 placed → walkable
[PASS] G2 bush blocks (not bloomed) → bloomed after I7 use
[PASS] G3 blocked at noon (day) → open at night
[PASS] rest stump jumps to evening start / phase is evening
[PASS] world_tree_planted fired / clear sequence active after plant
[PASS] object respawned after a full game day
[PASS] VOID tile persists (never respawns to ground)
=== RESULT: PASS (0 failures) ===
```

### Regression — M2/M3 harnesses still pass
```
m2_test_harness.tscn  → RESULT: PASS (0 failures)   (catalog assert updated to 57 canonical)
m2_integration.tscn   → RESULT: PASS (0 failures)
m3_test_harness.tscn  → RESULT: PASS (0 failures)   (recipes now 50, assert >=23)
```

## File map (new/changed in M4)
```
game/
  project.godot                              # main_scene → starting_grove
  data/map_layout.txt          (new)         # 40×40, byte-exact to Part A
  data/map_legend.json         (new)
  data/whisper_tileset.tres                  # + t5m mystic source (10)
  tools_gen_art.js                           # + M4 art (top-right lit)
  scenes/world/starting_grove.tscn (new)     # MAIN SCENE (player scale 1.25)
  scenes/dev/m2_test_harness.gd              # catalog-growth-tolerant assert
  scenes/dev/m4_test_harness.{gd,tscn} (new)
  scripts/core/game_state.gd                 # + day/night cycle + skip_to_next_evening
  scripts/world/interaction_controller.gd    # + T5M in SOURCE_TO_TILE_ID
  scripts/world/map_loader.gd  (new)
  scripts/world/{bush_dry,night_gate,night_gate_guard,world_tree,mystic_water,
                 rest_stump,day_night,glow_sprite,object_respawn}.gd (new)
  scripts/world/clear_sequence.gd (new)
  scripts/ui/time_hud.gd       (new)
  assets/objects/{bush_dry,bush_bloom,rest_stump,world_tree,world_tree_glow,
                  young_tree,night_bud_closed,night_bud_open}.png (new)
  assets/tiles/{t5m_mystic,t5m_mystic_glow}.png (new)
```
