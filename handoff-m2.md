# Project Whisper — M2 Handoff (Gathering + Inventory + Placement/Use)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on M0+M1 (see `handoff-m0m1.md`). M0+M1 movement/collision/Y-sort unchanged.

## What was built

### 1. ItemDB autoload — `scripts/core/item_db.gd`
Loads `data/items.json` at startup into a canonical registry. 31 JSON records =
**30 canonical + 1 alias** (D06 "나무" has `alias_of: I4`, so it is not a separate
stack — it resolves to I4).

Public API (all take an item id; alias ids resolve automatically):
- `resolve_id(id) -> String` — alias → canonical (e.g. `"D06"` → `"I4"`).
- `has_item(id) -> bool`
- `get_item(id) -> Dictionary` — raw record (resolved).
- `item_name(id)` / `item_category(id)` / `item_flavor(id) -> String`
  (named `item_*`, **not** `get_name`, to avoid clobbering `Node.get_name`).
- `get_placeable_on(id) -> Array` / `get_usable_on(id) -> Array`
- `is_unique(id) -> bool` / `is_key_item(id) -> bool`
- `can_place_on_tile(id, tile_id) -> bool` — `tile_id in placeable_on`.
- `can_use_on_object(id, object_id) -> bool` — `object_id in usable_on`.
- `all_ids() -> Array` — 30 canonical ids.

### 2. Inventory autoload — `scripts/core/inventory.gd`
Stack-based, keyed by canonical id → int count (no per-slot cap). Aliased ids fold
into the canonical stack. Unique items (I9) cap at 1.

Public API:
- `add(id, amount=1) -> int` — returns amount actually added (0 if unique at cap).
- `remove(id, amount=1) -> int` — returns amount actually removed.
- `count(id) -> int`, `has(id, amount=1) -> bool`
- `ids() -> Array` (held ids, insertion order), `is_empty()`, `clear()`
- Signals: **`changed`** (any mutation), `item_added(id, amount)`,
  `item_removed(id, amount)`. UI/HUD refresh off these — no polling.

### 3. Gathering interaction
- **`scripts/world/gatherable.gd`** (`class_name Gatherable`, extends Sprite2D):
  world object that self-registers into the **`gatherable`** group. Exports
  `item_id`, `amount`, `unique`, `object_id`. `can_gather()`, `gather()` (grants
  item, emits `GameState.item_gathered`, `queue_free()`s unless `unique`),
  `target_point()`. **World-tree exception**: `unique=true` objects set an internal
  `_spent` flag after first gather and stay in the world, non-re-gatherable.
- **`scripts/world/interaction_controller.gd`** (`class_name InteractionController`,
  Node2D): the hub. Each `_process` frame resolves a target — nearest `Gatherable`
  within `OBJECT_REACH` (140px), else the **facing-adjacent tile** (from
  `Player.facing_cell_step()`) — and drives the highlight. On the `interact` action
  (`_unhandled_input`) it does, in order:
  1. If a held item is set: try use-on-object, then place-on-tile.
  2. Else gather the targeted object.
  3. Else gather the targeted tile (custom-data `gatherable` → grant `item_id`,
     replace cell with **T0 VOID** source 0).
  Spawns a floating "+1 <이름>" label on each gather.
- **`scripts/world/tile_highlight.gd`** (`class_name TileHighlight`, Node2D):
  pulsing violet **#9e7ad9** diamond outline (128×64 footprint), `show_cell(world)`
  / `hide_highlight()`.
- **`scripts/world/floating_label.gd`** (`class_name FloatingLabel`, Label):
  `FloatingLabel.spawn(parent, world_pos, msg)` — rises 48px and fades over 0.9s via
  Tween, frees itself. Cream text with dark outline.

### 4. Item placement / use framework
Driven by `ItemDB.placeable_on` / `usable_on` (data), with a small **named-effect
registry** for the executable effect (an effect is code, not data):
- **Placement** (`_try_place_on_tile`): target tile's logical id (via
  `SOURCE_TO_TILE_ID`, source ids == tile ids) must be in the item's `placeable_on`.
  Effects in `_apply_placement_effect`:
  - **D14 디딤돌** on T5A/T5B water → swaps cell to source 1 (T1 dirt art reused,
    `walkable=true`, no collision) so the water becomes crossable; emits
    `GameState.stepping_stone_placed(cell)`. TODO: dedicated on-water stone art.
  - **D22 어린 세계수** on T0 VOID → emits `GameState.world_tree_planted(cell)`
    (MVP clear condition; cutscene hooks here in M4).
  Item consumed only if the effect applied. Held item auto-clears when its count
  hits 0.
- **Use** (`_try_use_on_object`): held item's `usable_on` must contain the target
  object's `object_id` → consume item, emit
  `GameState.item_used_on_object(item_id, object)`. Works today against any
  `Gatherable` carrying an `object_id` (the real `bush_dry` bush arrives in M4; a
  test bush is on the map now — see below).

### 5. Inventory UI — `scripts/ui/inventory_ui.gd` (`class_name InventoryUI`, CanvasLayer)
Toggle grid panel with `inventory` action (I/Tab); ESC or I closes. Panel bg
**#2a2a33**, text cream **#faf5e6**. Each row = colored category-square icon
(gather=green, craft=violet) + name + `xN` count. Click a row, or arrow-select
(ui_up/down) + Enter, to set the **held** item → shown in a bottom-left HUD with a
violet-bordered swatch + name + count. Rebuilds on `Inventory.changed`. The held
item is pushed to the `InteractionController` via `set_held_item`.

### 6. Test-map objects — `scenes/world/test_map.tscn`
Added to `YSortLayer` (all Y-sorted, gatherable group):
- TreeA/B/C → **I4**, RockA → **I6**, StoneA → **I8**, FlowerA → **I5**,
  GrassTuftA → **I2**, plus **BushDry** (`object_id=bush_dry`, use-only, for the I7
  water-use framework test).
- New nodes: `TileHighlight`, `Interaction` (InteractionController wired to Player /
  Ground / TileHighlight / YSortLayer), `InventoryUI` (CanvasLayer).
- Tile-sourced items confirmed reachable on the map: **I1** (T1 dirt path), **I2**
  (grass), **I3** (T4 mud patch), **I7** (pond water). So all of **I1–I8** are
  obtainable on the test map (I2 via both tile and tuft).

New placeholder art (added to `tools_gen_art.js`, regenerated):
`assets/objects/rock.png`, `stone.png`, `flower.png`, `grass_tuft.png` (64×64,
bottom-center origin).

### GameState additions — `scripts/core/game_state.gd`
New signals: `world_tree_planted(cell)`, `item_used_on_object(item_id, object)`,
`stepping_stone_placed(cell)`. `item_gathered(item_id)` (declared in M1) is now live.

### Player additions — `scripts/player/player.gd` (movement identical)
`get_facing() -> String` and `facing_cell_step() -> Vector2i` (SE=+x, NW=-x, SW=+y,
NE=-y). No change to `_physics_process` movement/collision/animation behavior.

## How M3 / M4 hook in
- **M3 (Fusion + 도감)**: read items via `ItemDB`; mutate stacks via `Inventory`
  (`remove` ingredients, `add` result — aliases fold automatically, e.g. crafting
  D06 lands in the I4 stack). Discovery UI can reuse the category-color +
  name/count row pattern in `inventory_ui.gd`. Fire `GameState.recipe_discovered`.
- **M4 (map + day/night + gates)**:
  - G1 stream: place **D14** on the water tiles — framework is done; just author the
    real water gap. Swap in real on-water stone art at
    `InteractionController.STEPPING_STONE_SOURCE` (or add a tileset source and change
    the const).
  - G2 dry bush: give the real bush a `Gatherable` with `object_id="bush_dry"`;
    listen to `GameState.item_used_on_object` to trigger bloom + open the path.
  - G4 clear: listen to `GameState.world_tree_planted` for the cutscene.
  - World-tree O0/I9: put a `Gatherable` with `unique=true`, `item_id="I9"` — it
    stays after the one gather.
- **M5 (save)**: serialize `Inventory.ids()`+counts, and gathered/VOID tile state +
  removed objects. `Inventory.clear()` + re-`add` on load.

## Deviations / notes
- **`ItemDB.item_name/item_category/item_flavor`** (not `get_name/...`): renamed to
  avoid overriding `Node.get_name()` (Godot treats the override as a
  warning-as-error).
- Stepping-stone visual **reuses T1 dirt** (source 1) as an interim — flagged TODO
  in code for a dedicated on-water stone sprite/overlay.
- Icons are **colored category squares** (placeholder), per spec ("icon
  placeholder"). Pixel font not applied to floating labels yet (spec: not required).
- 31 items.json records → 30 canonical + 1 alias; `all_ids()` returns 30.
- Headless env has no display server, so no visual screenshot; behavior verified by
  the two harnesses below (isolated logic + real-scene integration).

## Validation output tails

### Import (zero script/parse errors)
```
cd game && Godot_v4.5-stable_linux.arm64 --headless --import .
→ autoloads created; global classes Gatherable, InteractionController, TileHighlight,
  FloatingLabel, InventoryUI, Player, MapBuilder registered; no error/parse/warning lines.
```

### Main scene runtime (zero runtime errors)
```
... --headless res://scenes/world/test_map.tscn --quit-after 180
→ exit=0, error_lines=0
```

### Acceptance harness — `scenes/dev/m2_test_harness.tscn` (exit=0, 22/22 PASS)
```
=== M2 TEST HARNESS ===
[PASS] ItemDB loaded 30 canonical items
[PASS] ItemDB resolves the 1 alias (D06)
[PASS] ItemDB I2 name = 풀
[PASS] ItemDB D14 placeable_on T5A/T5B
[PASS] ItemDB I7 usable_on bush_dry
[PASS] ItemDB I9 unique
[PASS] grass tile is gatherable
[PASS] inventory gained I2
[PASS] gathered tile became T0 VOID (source 0)
[PASS] VOID tile is walkable
[PASS] water tile starts non-walkable
[PASS] D14 may be placed on this water tile
[PASS] water tile is now walkable after D14 placement
[PASS] first unique add returns 1
[PASS] second unique add returns 0
[PASS] unique item count capped at 1
[PASS] D06 resolves to I4
[PASS] alias folds into same stack (I4 == 5)
[PASS] querying by alias returns folded count
[PASS] I7 valid on bush_dry
[PASS] item_used_on_object fired with I7
[PASS] water consumed on use
=== RESULT: PASS (0 failures) ===
```

### Integration harness — `scenes/dev/m2_integration.tscn` (loads real scene, 16/16 PASS)
Drives the actual InteractionController / Gatherable group / held-item flow:
```
=== M2 INTEGRATION ===
[PASS] InteractionController present
[PASS] gatherable group populated (>=8)
[PASS] objects yield I2 / I4 / I5 / I6 / I8
[PASS] rock.gather() granted I6
[PASS] non-unique rock freed after gather
[PASS] controller holds D14
[PASS] found a water cell on map
[PASS] map water cell non-walkable pre-place
[PASS] controller placed D14 on water
[PASS] map water cell walkable post-place
[PASS] D14 consumed from inventory
[PASS] controller planted D22 on VOID
=== RESULT: PASS (0 failures) ===
```

## File map (new/changed in M2)
```
game/
  project.godot                              # + ItemDB, Inventory autoloads
  tools_gen_art.js                           # + rock/stone/flower/grass_tuft gen
  data/items.json                            # (unchanged; consumed by ItemDB)
  scripts/
    core/game_state.gd                       # + M2 signals
    core/item_db.gd            (new)         # autoload
    core/inventory.gd          (new)         # autoload
    player/player.gd                         # + get_facing / facing_cell_step
    world/gatherable.gd        (new)
    world/interaction_controller.gd (new)
    world/tile_highlight.gd    (new)
    world/floating_label.gd    (new)
    ui/inventory_ui.gd         (new)
  scenes/world/test_map.tscn                 # + objects, highlight, interaction, UI
  scenes/dev/m2_test_harness.{gd,tscn} (new) # acceptance harness (leave in place)
  scenes/dev/m2_integration.{gd,tscn}  (new) # real-scene integration harness
  assets/objects/{rock,stone,flower,grass_tuft}.png (new)
```
```
```
