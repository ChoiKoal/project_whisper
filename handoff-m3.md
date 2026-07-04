# Project Whisper — M3 Handoff (Fusion + Recipe Discovery + 도감)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on M0+M1+M2 (see `handoff-m2.md`). M2 gathering/inventory/placement unchanged.

## What was built

### 1. RecipeDB autoload — `scripts/core/recipe_db.gd`
Loads `data/recipes.json` (23 recipes) at startup. Every recipe is a 2-ingredient
fusion `{"id","inputs":[a,b],"output","hint"}`. Matching is **order-independent**:
inputs are canonicalized (`ItemDB.resolve_id`) and sorted into a `"a|b"` key, so
`[I5,I2]` and `[I2,I5]` both hit R04. Fully data-driven — new recipes need no code.

Public API:
- `find_recipe(ids: Array) -> Dictionary` — raw record for an unordered pair; `{}` if none (requires exactly 2 ids).
- `get_recipe(id) -> Dictionary`, `all_recipes() -> Array`, `all_ids() -> Array`.

### 2. Codex autoload — `scripts/core/codex.gd`
Discovery tracker (도감 state). All state in plain Dictionaries/Arrays for M5 save.
- **Item discovery**: first acquisition counts once, **regardless of source** —
  gather (via `GameState.item_gathered`) OR fusion output. Aliases fold to
  canonical, so 진흙 I3 (gatherable AND R01 output) counts once. Idempotent.
- **Recipe discovery**: **fusion success only** (gathering discovers no recipe).
  `discover_recipe` also discovers its output item and re-emits `GameState.recipe_discovered`.
- **Hint gauge** (recipes-v1 §4 + economy §B-3): a failed fusion increments the
  gauge **only for a not-previously-attempted pair**. An order-independent
  `_attempted_pairs` set stores every failed pair; repeating an already-failed
  pair is a no-op for the gauge (중복 실패 미적립, brute-force suppression). At
  `HINT_THRESHOLD` (5) it reveals ONE undiscovered recipe's one-ingredient
  silhouette hint and resets the gauge.
- Signals: `item_discovered(id)`, `recipe_discovered(id)`, `hint_gauge_changed(value)`,
  `hint_revealed(recipe_id, ingredient_id)`.
- API: `discover_item/discover_recipe`, `is_item_discovered/is_recipe_discovered`,
  `discovered_item_count/discovered_recipe_count`, `hint_gauge()`,
  `hint_for_recipe(rid) -> String`, `register_failed_fusion(a_id, b_id) -> bool`,
  `to_dict()/from_dict()`, `reset()`.

**Codex state dict shape** (from `to_dict()`, consumed by M5 save):
```gdscript
{
  "items": [<canonical item id>, ...],        # discovered items (set as list)
  "recipes": [<recipe id>, ...],              # discovered recipes
  "hint_gauge": int,                          # 0..5
  "hints": { <recipe_id>: <ingredient id> },  # active gauge-revealed hints
  "attempted_pairs": [ "a|b", ... ],          # sorted-canonical failed-pair keys
}
```
`from_dict()` restores all five fields (attempted-pair suppression survives a load).

### 3. Fusion autoload — `scripts/core/fusion.gd`
`fuse(a_id, b_id) -> Dictionary` — logic split from UI so it is headless-testable.
- Match → consume inputs, add output, record recipe + output item in Codex.
- No match → **no consumption**, `Codex.register_failed_fusion(a,b)` ticks the gauge.
- Result shape (always): `{matched:bool, recipe_id:String, output:String, hint_revealed:bool}`
  (`output` is the canonical output id).
- **UNIQUE-AS-CATALYST rule (M3 refinement)**: an input marked `"unique": true` in
  items.json (I9 세계수 정수) must be PRESENT but is **NOT consumed** — it is a
  catalyst. Other inputs consume normally. Prevents the G4 softlock (spending the
  one-and-only I9). Implemented in `_consume_inputs` via `ItemDB.is_unique`.

### 4. Cauldron — `scripts/world/cauldron.gd` (`class_name Cauldron`, Sprite2D)
솥단지 world object on test_map near spawn. Joins the **`gatherable`** group so the
existing InteractionController targets/highlights it, but duck-types as a
non-gatherable interactable: `can_gather()` → false, and `on_interact()` emits
`interacted`. The controller (M2, unchanged logic path) routes it: after no
gather/use applies, it calls `on_interact()` on a targeted object that has the method.
Placeholder art `assets/objects/cauldron.png` (128×128, added to `tools_gen_art.js`).

### 5. Fusion UI — `scripts/ui/fusion_ui.gd` (`class_name FusionUI`, CanvasLayer)
2 input slots + result slot + 조합 button, inventory strip to pick items, 비우기 to
clear. Success: consumes inputs, adds output, shows flavor text + "새로운 것을
만들었다!" + celebratory scale pulse (Tween). Fail: no consumption, "…반응이 없다",
and a 5-dot hint gauge that updates from `Codex.hint_gauge_changed`. Colors bg
`#2a2a33` / text `#faf5e6` / accent `#9e7ad9`. Opened by the Cauldron: `_ready()`
calls `call_deferred("_autobind_cauldrons")` which binds every `Cauldron` in the
`gatherable` group to `open` — no scene node-path wiring needed. Toggled closed by
`ui_cancel` or `interact`.

### 6. Codex UI — `scripts/ui/codex_ui.gd` (`class_name CodexUI`, CanvasLayer)
Toggle with the **`codex`** action (**C** key, added to the input map). Tabs 채집 /
창조. Discovered = category-colored square + name + flavor; undiscovered =
silhouette + "???". Gauge-revealed hints surface on the corresponding output-item
row as "힌트: <재료명> + ???". Header 발견률 combines **item + recipe denominators**
(discovered items + discovered recipes over total items + total recipes), plus a
per-category breakdown (채집 / 창조 / 레시피). Colors as above.

### Wiring — `scenes/world/test_map.tscn`
- `YSortLayer/Cauldron` (Cauldron) at (96,32), near the Player spawn (0,0).
- `FusionUI` and `CodexUI` CanvasLayers (layer 2) at the scene root.
- Autoloads (project.godot): **RecipeDB, Codex, Fusion** added after Inventory.
- Input map: **`codex`** = C.

## Deviations / notes
- **Codex 발견률 denominator**: spec §5 asked for "item + recipe combined
  denominators". The partial code counted items only; corrected to combine
  discovered items + recipes over total items + recipes, with a 레시피 x/23 breakdown.
- **Cauldron in `gatherable` group** surfaced a latent M2 issue: the M2 integration
  harness assumed every group member was a `Gatherable` and read `.item_id`,
  crashing on the Cauldron (Nil cast). Fixed the harness to filter `n is Gatherable`
  before iterating (the InteractionController itself was already defensive via
  `has_method("target_point")` / `as Gatherable`). No production-code change needed.
- FusionUI binds cauldrons by **group scan** (deferred), not an exported path, so
  adding more cauldrons requires no re-wiring.
- Same-ingredient recipes (R10 풀+풀, R19 꽃+꽃) require 2 of that stack; unique
  same-ingredient recipes would need only 1 present + consume 0 (none exist today).

## Validation output tails

### Import (zero script/parse errors)
```
cd game && Godot_v4.5-stable_linux.arm64 --headless --import .
→ exit 0; global classes Cauldron, FusionUI, CodexUI registered; no error/parse lines.
```

### Main scene runtime (zero runtime errors)
```
... --headless res://scenes/world/test_map.tscn --quit-after 180
→ exit 0, zero SCRIPT ERROR / ERROR lines.
```

### Acceptance harness — `scenes/dev/m3_test_harness.tscn` (exit 0, 56/56 PASS)
```
=== M3 TEST HARNESS ===
[PASS] RecipeDB loaded all 23 recipes
[PASS] RecipeDB find_recipe(I5,I2) = R04
[PASS] RecipeDB find_recipe is order-independent
[PASS] R04 fuse matched / output = D03 / consumed I5 / consumed I2 / added D03
[PASS] R04 recorded recipe + output item in codex
[PASS] wrong pair not matched / did NOT consume I1 / did NOT consume I2 / ticked gauge +1
[PASS] repeated same wrong pair does NOT increment gauge
[PASS] 5 distinct wrong pairs revealed a hint / gauge reset / a recipe carries a hint
[PASS] fuse(I2,I5) reversed still matches R04 (order-independence)
[PASS] find_recipe folds alias D06 -> I4 (matches R11) / alias fuse consumes I4 stack
[PASS] catalyst fuse matched R20 / produced D19 / I9 NOT consumed / I7 consumed
[PASS] I3 discovered by gathering / by fusing / counted once regardless of source
[PASS] recipe discovery is fusion-success only / to_dict+from_dict round-trip
[PASS] restored attempted pair stays suppressed
[PASS] Cauldron/FusionUI/CodexUI present on test_map
[PASS] cauldron.on_interact() opens FusionUI
[PASS] loop step 1: I5+I2 -> D03 / step 2: D03+I7 -> D04 / discovered R04 and R05
=== RESULT: PASS (0 failures) ===
```

### Regression — M2 harnesses still pass
```
m2_test_harness.tscn  → RESULT: PASS (0 failures)   (22/22)
m2_integration.tscn   → RESULT: PASS (0 failures)   (16/16, real scene incl. Cauldron)
```

## File map (new/changed in M3)
```
game/
  project.godot                              # + RecipeDB/Codex/Fusion autoloads, codex(C) input
  tools_gen_art.js                           # + cauldron.png generation
  data/recipes.json                          # (consumed by RecipeDB; unchanged this pass)
  scripts/
    core/recipe_db.gd          (new)         # autoload
    core/codex.gd              (new)         # autoload  (+attempted-pair dedup)
    core/fusion.gd             (new)         # autoload  (+catalyst rule)
    world/cauldron.gd          (new)
    ui/fusion_ui.gd            (new)         # (+cauldron group autobind)
    ui/codex_ui.gd             (new)         # (+combined 발견률 denominator)
    world/interaction_controller.gd          # M2; on_interact() route already present
  scenes/world/test_map.tscn                 # + Cauldron, FusionUI, CodexUI
  scenes/dev/m3_test_harness.{gd,tscn} (new) # acceptance harness (leave in place)
  scenes/dev/m2_integration.gd               # hardened: filter non-Gatherable group members
  assets/objects/cauldron.png (new)
```

## How M4 / M5 hook in
- **M4**: G4 clear chain is fully fusable — I9 (catalyst) + I7 → D19 → D20 → D22,
  then place D22 on VOID (`GameState.world_tree_planted`, M2 framework). The
  catalyst rule guarantees I9 is never stranded.
- **M5 (save)**: serialize `Codex.to_dict()` alongside inventory/tile state;
  `Codex.from_dict()` on load restores discovery, gauge, hints, and the
  attempted-pair suppression set.
