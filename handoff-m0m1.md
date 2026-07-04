# Project Whisper — M0 + M1 Handoff

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`

## What was built

### M0 — Project setup
- `project.godot`: name "Project Whisper", main scene `res://scenes/world/test_map.tscn`.
- Renderer `gl_compatibility` (desktop + mobile method), viewport 1920×1080, stretch
  mode `canvas_items` / aspect `keep`, `snap_2d_transforms_to_pixel=true` (+ vertices),
  `default_texture_filter=0` (nearest — pixel art).
- Folder structure: `scenes/world scripts/{core,player,world} data assets/{tiles,objects,character} ui`.
- Input map: `move_up/down/left/right` (WASD + arrow keys), `interact` (E + Space),
  `inventory` (I + Tab).
- Autoload: `GameState` singleton.

### M1 — Isometric core
1. **Placeholder art** — generated programmatically by `tools_gen_art.js` (pure Node,
   built-in `zlib`, no npm deps; a minimal RGBA PNG encoder). All are proper 2:1 iso
   diamonds (transparent corners) at 128×64:
   - `assets/tiles/`: t0_void, t1_dirt, t2a_grass, t2b_grass_flowers, t2c_grass_clover,
     t2d_flower_grass, t4_mud, t5a_water, t5b_water2 (9 tiles; palette per art guide §3).
   - `assets/character/character_sheet.png` — 288×384 sheet, 96×96 frames,
     3 cols (idle, walk0, walk1) × 4 rows (SE, SW, NE, NW). Cream #e8dfc8 cat silhouette,
     violet #9e7ad9 eyes. Back views (NE/NW) show a tail hint instead of eyes.
   - `assets/objects/tree_a.png`, `tree_b.png` — 128×256, trunk #5c4433 + canopy
     (#2e5d3b / #4d8b4f), transparent bg, soft top-right shading.
2. **TileSet** `data/whisper_tileset.tres` — isometric (`tile_shape=1`), diamond-down
   layout, 128×64. Custom data layers: `gatherable`(bool), `item_id`(String),
   `walkable`(bool), `speed_mod`(float). Physics layer 0 with diamond collision polygon
   on the two water tiles. Per-tile data:
   | tile | source id | gatherable | item_id | walkable | speed_mod |
   |---|---|---|---|---|---|
   | T0 VOID | 0 | false | "" | true | 1.0 |
   | T1 dirt | 1 | true | I1 | true | 1.0 |
   | T2A/B/C/D grass | 2,3,4,5 | true | I2 | true | 1.0 |
   | T4 mud | 7 | true | I3 | true | 0.5 |
   | T5A/B water | 8,9 | true | I7 | **false** | 1.0 (blocked by collision) |
   Source ids intentionally equal tile ids (skips 6, reserved for a future T3).
3. **test_map.tscn** — 20×20 iso map built in code (`scripts/world/map_builder.gd` on the
   `Ground` TileMapLayer — avoids hand-authoring the packed `tile_data` binary).
   Pond (water, deep T5B core + shallow T5A) center-left, dirt path to the east edge,
   mud patch on the south shore, grass variants scattered elsewhere. Uses **TileMapLayer**
   (not deprecated TileMap).
4. **Player** — `scripts/player/player.gd` on a `CharacterBody2D`. Cardinal input is
   transformed into iso screen space (vertical squashed ×0.5) so motion glides along the
   2:1 diamond. Facing (SE/SW/NE/NW) chosen from dominant screen axis; `AnimatedSprite2D`
   plays `idle_*`/`walk_*` from `data/player_frames.tres`. Speed 300px/s, scaled by the
   tile's `speed_mod` sampled from tile custom data (data-driven, no tile-id switch).
   Water blocks via TileSet physics collision. `Camera2D` child with position smoothing.
5. **Y-sort proof** — `YSortLayer` (Node2D, `y_sort_enabled`) holds Player + 3 tree
   Sprite2Ds (also y_sort_enabled, `offset=(0,-120)` so origin sits at the trunk base).
   Player sorts behind/in front by ground Y.
6. **GameState** — `scripts/core/game_state.gd` autoload. `game_time: float` advanced in
   `_process`; signals declared for later milestones (`game_time_changed`,
   `day_phase_changed`, `item_gathered`, `recipe_discovered`), `time_running` toggle.

## File map
```
game/
  project.godot
  tools_gen_art.js                 # reproducible art generator (Node, no deps)
  data/
    whisper_tileset.tres           # 9 tiles, 4 custom data layers, water physics
    player_frames.tres             # SpriteFrames: idle/walk × 4 dirs
  scenes/world/test_map.tscn       # main scene
  scripts/
    core/game_state.gd             # autoload singleton
    player/player.gd               # CharacterBody2D iso movement
    world/map_builder.gd           # populates 20×20 map
  assets/tiles/*.png               # 9 iso diamond tiles (128×64)
  assets/character/character_sheet.png  # 288×384
  assets/objects/tree_{a,b}.png    # 128×256
```

## Known limitations / deviations
- Spec said "8 tiles"; the enumerated list (T0–T5B) is **9**. Shipped all 9 (T0 VOID is
  needed for M2's gather→VOID replacement).
- Character sheet has 1 idle + 2 walk frames per direction (spec permitted "1 idle frame
  is fine"; walk is 2). Full Idle-4 / Walk-6 / Gather / Place anim counts from art guide §4
  are deferred to the art batches (this is placeholder).
- Placeholder art is blocky geometric shapes (diamonds, ellipses) — no selout outlines /
  soft top-right lighting from art guide §2. Intended to be resource-swapped later.
- No macOS/Windows export build performed (headless Linux env only; export presets are an
  M0 acceptance item in the dev plan but out of scope for this headless validation).
- Headless framebuffer screenshot could not be captured on this platform (no display
  server); visual layout verified indirectly via programmatic tile/collision checks.
- VOID tile currently `gatherable=false` (it is the empty result, not a source).

## Validation commands run + output tails

1. Import (zero script errors):
   `cd game && Godot_v4.5-stable_linux.arm64 --headless --import .`
   → global classes `Player`, `MapBuilder` registered; no error/parse/fail lines.

2. Main scene runtime (zero runtime errors):
   `... --headless res://scenes/world/test_map.tscn --quit-after 180`
   → clean start + exit 0, no error/push_error/SCRIPT ERROR output.

3. Data/collision harness (temp scripts, since removed):
   ```
   custom data layers: 4 | physics layers: 1 | tile_shape 1 | tile_size (128,64)
   used cells: 400
   water(5,9) walkable=false item_id=I7 speed_mod=1.0
   mud(6,12)  walkable=true  item_id=I3 speed_mod=0.5
   grass(15,2) gatherable=true item_id=I2 walkable=true
   player class: CharacterBody2D speed=300.0
   GameState game_time advancing (0.0167 after 1 frame)
   ```
   Movement test: player pushed velocity (-320,0) for 90 physics frames from x=948 →
   stopped at x≈931 (blocked by water collision polygon; did not enter pond). PASS.
```
```
