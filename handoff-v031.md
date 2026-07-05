# handoff — v0.3.1 (UX sprint, owner-feedback fixes)

Base = v0.3.0 (75790e1). This sprint finished the interrupted v0.3.1 work, completed the
remaining scope, and added three new owner-feedback items. **Not committed** (per brief).

Godot 4.5.stable. Verify: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`

---

## Audit of the interrupted agent's partial work

Ground-truth from `git status` + reading every modified file (not the task log):

- **Fix 4 (gathered-VOID → walkable HOLLOW): COMPLETE + consistent.** New tile source 11
  `t0_hollow` (walkable=true, no physics, logical id stays "T0"). All call sites agree —
  `whisper_tileset.tres` (src 11), `interaction_controller.HOLLOW_SOURCE`,
  `save_manager` (round-trips under the unchanged `void_cells` key; old real-VOID saves
  reload as HOLLOW), `object_respawn` (skips src 0 **and** 11), `game_state.tile_walkable_changed`
  signal → `touch_controller._rebuild_solids` (AStar re-solidifies). e2e/m2/m4/m5 harnesses
  already updated to assert src 11 + walkable. D22 plant-on-T0 chain intact.
- **Fix 3 (cursor rework): COMPLETE.** `player.is_moving()`, hover targeting, subtler
  `tile_highlight` idle/hover styles, prompt fade-in — all present and correct.
- **Fix 2 (black cloak regen): COMPLETE.** character_sheet/portrait PNGs + tools_gen_art.js.
- **Fix 1 (UI fits viewport): BROKEN — the comment lied.** `fusion_ui.gd` had the
  container restructure (fit → CenterContainer → PanelContainer → ScrollContainer) and a
  comment claiming "caps height at ~85% of viewport", **but no clamp code existed** — no
  resize handler, no height cap. The panel would still overflow a small window: exactly the
  owner's unreachable-ingredient-strip bug, unfixed. inventory/codex/character had no
  viewport-fit work at all.

No mid-edit corruption found; the gap was missing (not broken) clamp logic.

---

## Per-item status

### R1 — UI fits viewport  ✅ (this was the owner's top pain, and it was fake-done)
- **fusion_ui.gd**: added `_clamp_to_viewport()` — caps panel height at `min(700, vp*0.85)`,
  caps the scroll-body min-height so the ingredient strip is always reachable (scrolls
  inside the panel when clamped), caps width at `vp*0.9`. Wired to `get_viewport().size_changed`
  + on `open()`.
- **inventory_ui.gd**: same cap; the item grid (`_grid_scroll`) shrinks so the detail pane +
  들기 button stay on-screen; re-centers on resize.
- **character_window.gd**: same cap + re-center (content ~460px already fits, clamp is
  defensive for small retina point sizes).
- **codex_ui.gd**: already viewport-relative (PRESET_FULL_RECT with margins + internal
  scrolls) — fits by construction, left as-is.
- Each `_clamp_to_viewport(override_size)` takes an optional size so the v031 harness can
  drive 1280×720 / 1920×1080 headless (the dummy display can't actually resize the window).

### R2 — tone pass  ✅
- **Vignette**: new `scripts/world/vignette.gd` (CanvasLayer, layer 1, shader radial
  falloff, STRENGTH 0.15) added to `starting_grove.tscn` above world / below UI windows.
- **Prompt pill**: already reworked (smaller, softer, fade-in, offset above target). Verified
  it anchors above the *target* point, never the player sprite.
- **Gather label** (`floating_label.gd`): CUBIC ease-out rise, hold-then-fade opacity, slight
  random ±10px x-drift so repeated gathers don't stack a rigid column.
- **Command bar** (`ui_hub.gd`): glyph beside each label (◈ ▤ ✦ ≡) + a tweened hover lift.

### R3 — gather reach + non-blocking gatherables  ✅
- **Reach**: `OBJECT_REACH` 140 → 180 so adjacent objects in ALL directions (incl. NE/NW
  "above" the player) are targetable. `_do_interact()` now **prefers the mouse-hover target**
  over the nearest/facing one (`_hover_object`/`_hover_cell` win).
- **Non-blocking**: added `blocks_movement` to `Gatherable` — false = no collision (player
  walks over it). `map_loader._gatherable()` sets it true only for trees (`tex_path.contains("tree")`).
  Trees get a small circular trunk StaticBody (layer 1, matches border/bush/world-tree
  collision convention); rock/stone/flower/tuft/bush_green have none. (Pre-existing state:
  *no* scatter object had collision; this adds it to trees so "trees block, small stuff
  doesn't" is real.)
  - Note: tap-to-move AStar is tile-based, so paths can still route toward a tree tile;
    the small trunk radius (20px) lets move_and_slide slide around. Acceptable / minor.

### R4 — held-item affordance  ✅
- **held HUD** (`inventory_ui.gd`): persistent one-line affordance under the held box —
  placeable → "물가에 놓을 수 있다"; usable → "마른 덤불에 쓸 수 있다"; neither → dimmed
  "조합 재료 — 솥단지에서 쓰자" (keyed on `get_placeable_on`/`get_usable_on`).
- **first-hold hint**: first time per session a combo-only item is held, floats
  "이건 조합 재료야. 솥단지로 가져가자." near the player (new
  `interaction_controller.spawn_player_hint()`; session guard `_combat_hint_shown`).

### R5 — validation + release prep  ✅
1. Headless `--import`: **0 errors**. title / opening / starting_grove load clean (0 errors each).
2. **All harnesses green (12/12):** m2, m2_integration, m3, m4, m5, m6a, m8, e2e, v021,
   v030, **v031 (new)**, m7. v030 button-text asserts loosened to substring (glyph prefix).
   New **v031_test_harness** asserts: UI-fit height≤min(700,vp*0.85) + in-viewport at
   1280×720 and 1920×1080 (fusion/inventory/character); cursor hidden-while-moving; gathered
   HOLLOW walkable + distinct from unwalkable border VOID; small-gatherable no-collision +
   walkable tile (test_move crosses) + tree HAS collision; held-affordance text.
3. **Version 0.3.1** in `project.godot` + all three export presets.
4. **Export validation flow** ran: temp-included dev scenes in the Linux arm64 preset →
   exported → **m7 + v030 + v031 PASS on the exported binary** (data-intact, real PCK) →
   restored presets → built finals. Zip integrity + contents verified.
5. This handoff. **No git commit.**

---

## Release artifacts (`export/`)

| file | size |
|---|---|
| ProjectWhisper-win64-v0.3.1.zip | 34,190,430 B (embed_pck .exe) |
| ProjectWhisper-macos-v0.3.1.zip | 62,523,940 B (release .app) |
| ProjectWhisper-macos-DEBUG-v0.3.1.zip | 67,225,730 B (debug .app + .command) |

Export templates installed from `tools/export_templates.tpz` into
`~/.local/share/godot/export_templates/4.5.stable/` (version.txt = 4.5.stable).

---

## Files touched

New: `scripts/world/vignette.gd`, `scenes/dev/v031_test_harness.{gd,tscn}`,
`assets/tiles/t0_hollow.png` (from partial work).

Modified this sprint: `project.godot`, `export_presets.cfg`, `scripts/ui/fusion_ui.gd`,
`scripts/ui/inventory_ui.gd`, `scripts/ui/character_window.gd`, `scripts/ui/ui_hub.gd`,
`scripts/world/floating_label.gd`, `scripts/world/gatherable.gd`,
`scripts/world/interaction_controller.gd`, `scripts/world/map_loader.gd`,
`scenes/world/starting_grove.tscn`, `scenes/dev/v030_test_harness.gd`.

(Plus the interrupted agent's already-present changes to character assets, whisper_tileset.tres,
game_state, save_manager, player, object_respawn, tile_highlight, touch_controller,
e2e/m2/m4/m5 harnesses, tools_gen_art.js.)

**Untouched by request:** `data/recipes.json`, `data/items.json` (recipe-integration task
follows). Confirmed clean in git.
