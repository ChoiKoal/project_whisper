# Handoff — M5 (save/load + New Game Plus + title/pause menus)

Status: DONE. Import clean, title + starting_grove run headless with zero errors,
all five harnesses (m2, m2_integration, m3, m4, m5) green. Uncommitted (per project
rule: do not git commit).

## Scene paths / wiring
- Main scene is now `res://scenes/ui/title.tscn` (project.godot `run/main_scene`).
  Title launches `res://scenes/world/starting_grove.tscn`.
- `SaveManager` is an autoload (`res://scripts/core/save_manager.gd`), registered
  after Fusion in project.godot `[autoload]`.
- `title.tscn` — Control + `title_menu.gd` (TitleMenu). Buttons built in code:
  새로 시작 (always) / 이어하기 (if `SaveManager.has_save()`) / NG+ 시작 (if the save
  file's `ngplus.cleared` is true) / 종료.
- `starting_grove.tscn` gained two nodes:
  - `PauseMenu` (CanvasLayer, layer 9, `pause_menu.gd`) — ESC toggles. 계속 / 저장 /
    타이틀로. Pauses `GameState.time_running` while open (not SceneTree pause).
  - `GroveSession` (Node, `grove_session.gd`) with exported NodePaths to
    `../Ground`, `../YSortLayer/Player`, `../ObjectRespawn`, `../ClearSequence`.
    On ready (deferred one frame so MapLoader built the map): registers the live
    world with SaveManager; if `SaveManager.pending_load`, calls `load_game()`
    (the 이어하기 path); wires `ClearSequence.cleared` → mark_cleared + autosave.

## Save file — user://save1.json (SAVE_VERSION = 1)
Written with `JSON.stringify(data, "\t")`. Top-level fields:

| field | type | contents |
|---|---|---|
| `version` | int | SAVE_VERSION (1). Bump on breaking schema change; `_migrate()` hook. |
| `inventory` | {id: count} | every stack from `Inventory.ids()`. |
| `held_item` | String | InteractionController held item id ("" if none). Found via class DFS. |
| `codex` | dict | `Codex.to_dict()`: items[], recipes[], hint_gauge, hints{}, attempted_pairs[]. |
| `time.game_time` | float | `GameState.game_time`. Restored via `set_game_time` (re-derives G3 night gate + phase). |
| `time.day_index` | int | `GameState.day_index()` (informational; game_time is source of truth). |
| `ngplus.run_number` | int | 1-based run counter. |
| `ngplus.carried_recipes` | [String] | recipe ids carried into current run (속삭임 marker). |
| `ngplus.lifetime_recipes` | [String] | lifetime honor union of every recipe ever discovered. |
| `ngplus.cleared` | bool | current run reached clear (world tree planted). |
| `map` | dict | present only if a world is registered (see below). |
| `player.x`, `player.y` | float | player global_position. |

### map sub-dict (diff from deterministic base layout)
The map is rebuilt deterministically by MapLoader on load; only the DIFF is stored.
- `void_cells`: `[[c,r], ...]` cells that became T0 VOID (tile gathered). Base-VOID
  cells produce no diff.
- `stepping_stones`: `[[c,r], ...]` K water slots that became walkable (D14 placed;
  source id 1). Guarded by `_is_stepping_slot`.
- `objects`: per tracked ObjectRespawn spawn cell — `{cell:[c,r], symbol, present,
  respawn_at}`. On load, absent objects are freed and their `respawn_at` (absolute
  game_time) restored so mid-respawn state survives.
- `gates.bush_bloomed`: BushDry `is_bloomed()` → re-`bloom()` on load.
- `gates.world_tree_gathered`: WorldTree `_spent` → re-set on load.
  (g/tree tile variants are cell-hash deterministic — never saved. G3 night gate is
  derived from game_time, not saved.)

### Load path
`load_game()` → `_read_save()` (+`_migrate`) → `_apply_core_state` (inventory, codex,
time, NG+ meta) → if world registered, `apply_world_state` (map diff, objects, gates,
player pos, held item). The 이어하기 flow defers `apply_world_state` until GroveSession's
deferred `_setup` (after MapLoader builds), matching the harness's manual register→load.

## Autosave
- On quit: `_notification(NOTIFICATION_WM_CLOSE_REQUEST)` → save_game() (only if a world
  is registered) → quit. `set_auto_accept_quit(false)` in `_ready`.
- After clear: GroveSession `_on_cleared` → `mark_cleared()` + `save_game()`.
- Manual: PauseMenu 저장 button; PauseMenu 타이틀로 autosaves before leaving.

## NG+ flow (KOAL-confirmed)
`start_ng_plus(finished_run_recipes=[])`:
1. pool = finished run's discovered recipes (defaults to `Codex.to_dict().recipes`).
2. fold pool into `lifetime_recipes` (honor record superset).
3. `carry = _pick_random(pool, 3)` — up to 3 distinct random; if N<3, carries all N;
   N==0 carries none.
4. reset world: Inventory.clear, game_time=0, Codex.reset, cleared=false, run_number+1.
5. re-discover the carried recipes in the fresh codex (start discovered).
6. carried recipes flagged via `is_carried_recipe()` → codex renders "세계가 기억해 준
   속삭임" marker. `is_lifetime_recipe()` → subtle honor checkmark.
Title 새로 시작 uses `new_game()` (full reset incl. run_number→1 and lifetime cleared).
Title NG+ 시작: reads save → `_apply_core_state` (core only, no world) → `start_ng_plus`
→ fresh grove, no pending_load.

## Colors (locked)
bg #2a2a33, text #faf5e6, accent #9e7ad9, muted #b8b4a8. Used by both menus.

## Validation tails
- `Godot --headless --import .` → EXIT=0, zero errors.
- title.tscn / starting_grove.tscn headless → zero runtime errors (killed by timeout only).
- m2 22/22, m2_integration 16/16, m3 56/56, m4 30/30, m5 34/34 — all `RESULT: PASS (0 failures)`.

## Notes / deviations
- Audited the previous agent's partial work: code was NOT broken mid-edit. All script
  APIs it depends on (GameState.time_running/set_game_time/day_index, Codex to_dict/
  from_dict/reset, ObjectRespawn._tracked/force_tick, MapLoader stepping_slot_cells/
  cell_center_world, BushDry, WorldTree._spent, InteractionController held-item) exist
  and match. Scene wiring (PauseMenu + GroveSession) was already present and correct.
- The ONE gap completed this run: `project.godot run/main_scene` still pointed at
  starting_grove.tscn; changed to title.tscn per spec §4. (The SaveManager autoload
  line and the .tscn node wiring were already in place from the previous run.)
- This handoff (handoff-m5.md) was missing and is written here (spec §5).
- Harnesses load their own scenes explicitly (m5 instances starting_grove directly and
  drives register/load itself), so title.tscn becoming main scene does not affect them —
  verified: all still green.
