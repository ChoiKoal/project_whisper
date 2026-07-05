# handoff — v0.4.0 part A (interaction UX rework)

Base = v0.3.1 clean tree. Three owner complaints from live play, all addressed. Godot
4.5.stable. **Version → 0.4.0-dev** (project.godot only; export presets stay 0.3.1, final
bump + rebuild is part B). **No exports rebuilt. No git commit.** (per brief §4).

Verify: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`

---

## Per-item status

### A1 — Gather reach: adjacent-only for direct E  ✅
"먼곳에 있는 것도 채집되는게 말이 되냐" — the old 180px `OBJECT_REACH` radius pick for direct E is
**gone**. `interaction_controller.gd`:
- **New rule (`ADJ_RANGE = 1`)**: `_resolve_target()` picks a gatherable/cauldron only if
  its cell is on the player's own cell or the 8-neighbourhood (Chebyshev ≤ 1). Among
  adjacent candidates the nearest wins. A far object is no longer a direct-E target.
- **`_do_interact()`** now re-checks adjacency at press time: a hover object/cell wins over
  the facing one **only when it is itself adjacent**; a far object under the cursor is a
  preview, not an E-target.
- **Mouse click on a far gatherable → unchanged**: `touch_controller` still walks the player
  to a cell beside it, then calls `interact_with_object()` (the "already reached" entrypoint,
  which intentionally does NOT re-check reach). The e2e playthrough exercises this path and
  passes, so walk-then-gather is intact.
- **Hover PREVIEW may still light a far object** (`_resolve_hover`, cursor pick 72px), but
  pressing E on that preview does nothing.

### A2 — Cursor / highlight redesign  ✅
"커서 너무 마음에 안들어" — the floor diamond for **gather** targeting is deleted. New model, three
mutually-exclusive channels per frame in `_update_targeting()` (renamed from
`_update_highlight`):
- **Object brighten** — the target/hover gatherable OBJECT self-brightens. New
  `Gatherable.set_targeted(bool)`: a gentle `self_modulate` pulse lerping BASE 1.08 → PEAK
  1.25 brightness with a subtle violet rim mixed in (art-guide §3 `#9e7ad9`). Cleared →
  `self_modulate = WHITE` so day/night CanvasModulate still tints normally. Process is
  toggled on only while targeted (cheap). Duck-typed via `has_method("set_targeted")`, so the
  Cauldron (no such method) is simply skipped. Brighten only fires for a genuinely gatherable
  object (`can_gather()`), and hover-preview brightens even a far object.
- **Soft tile glow** — a gatherable ground tile with no object gets a soft radial violet
  bloom decal (new `scripts/world/tile_glow.gd` → `TileGlow` node), low-alpha (~0.16–0.26),
  2:1-squashed to hug the diamond. NOT the hard diamond. Idle only.
- **Placement diamond kept** — the violet `TileHighlight` diamond survives **only** for
  held-item placement targeting (D22 on a hollow, etc.), and `SteppingSlotHint` diamonds for
  D14 stepping slots. Diamonds where a targeting UI makes sense, per spec.
- **"E 채집" pill** — unchanged; still only for the adjacent idle target (`_prompt_text` reads
  `_target_object`/`_target_cell`, both now adjacency-filtered), anchored above the target.
- **While moving** → object brighten cleared, tile glow hidden, diamond hidden (preserves the
  v0.3.1 no-jitter rule).

Wiring: `starting_grove.tscn` gains a `TileGlow` node (z 3, below YSort z 5) wired to
`Interaction.tile_glow_path`. `test_map` has no TileGlow → `get_node_or_null` guards keep it
safe (m2/m3 green).

### A3 — Interior ridge walls read as terrain  ✅
"바위 맵 뚫을수가 없거든?" — authored interior VOID bands now render as raised **rock ridges**, clearly
distinct from gathered hollows and border cliffs.

- **Classification** (`map_loader._classify_void_cells()`): the spec's flood-fill-from-outside
  rule does NOT discriminate on this map — the interior wall bands touch the L/R border void
  (row 7 spans full width; rows 14-16 likewise), so **every** V is reachable from outside.
  Used the spec's OTHER stated rule, robustly generalised to thick bands: a V cell is an
  **interior ridge** if walking outward across the contiguous VOID band reaches playable LAND
  on BOTH opposing sides along either axis (N&S or E&W). This lights up exactly the two
  authored bands: **68 ridge cells** = G3 night-path wall (row 7) + G2 corridor walls (rows
  14-16), with the gate GAPS correctly excluded (N gate (19,7)/(20,7); bush corridor (18,16)).
- **Ridge art** (`tools_gen_art.js` → `makeRidge`, `assets/tiles/ridge_rock.png`, 128×160):
  a raised grey-brown rock mound cross-section (art-guide §3 neutral greys + browns), top-
  right lit, horizontal strata + pebble specks + subtle moss hints. Placed one-per-ridge-cell
  in a `Ridges` overlay (z 3 = terrain, below YSort z 5). Visual only; the authored-V border
  collision body already seals these cells.
- **G2 corridor readability**: the dry bush already sits in the gap (authored `B` at 18,16);
  added 2-3 worn-dirt trail decals (`makeWornDirt`, `worn_dirt_patch.png`, soft low-alpha
  brown blotch) on the walkable cells directly south of the gap as a subtle "way through"
  hint (`trail_decal_count = 3`). G3 entrance gap already has night buds.
- **Ridge ≠ cliff**: `_build_cliff_skirts` openness test changed to `_is_cliff_open()` — a
  cliff skirt hangs only where the neighbour drops to EXTERIOR void / off-map, **not** where
  it is an interior ridge. Border cliff skirts (63) + gathered hollow (walkable src 11) remain
  unchanged and are now three visually distinct things: ridge = rock mound / border = cliff
  edge / hollow = flat dark walkable patch.

---

## Validation (§ — all green)

1. **Headless `--import` → 0 errors.** title / opening / starting_grove load clean (0 SCRIPT
   ERROR / Parse Error / Failed to load each). Ridge/worn PNGs import clean.
2. **13/13 harnesses PASS, 0 SCRIPT ERROR lines:** m2, m2_integration, m3, m4, m5, m6a, m8,
   e2e, m7, v021, v030, v031, **v040 (new)**.
   - **v031 cursor asserts UPDATED** to the new API (coverage kept): while moving, asserts
     BOTH the placement diamond AND the soft tile glow are hidden (the gather cursor is now
     object-brighten + glow, not a diamond).
   - **v040_test_harness (new, 24 asserts)** on the real grove:
     - A1: a gatherable 3 cells away is NOT the resolved E-target and E does not gather it;
       an adjacent gatherable IS the target and E gathers it (+1). (Pre-existing scatter is
       torn down first to isolate the two test objects.)
     - A2: the adjacent target is object-brightened (`set_targeted`) with NO floor diamond;
       hover-preview state field exposed; holding D14 still shows placement diamonds over the
       stepping slots, cleared when the held item is dropped.
     - A3: 68 interior ridge cells all authored-V; G3 row 7 + G2 rows 14-16 present; gate gaps
       excluded; 68 ridge sprites in a `Ridges` overlay below YSort; corridor trail decals
       present; a border-fringe V gets a cliff skirt and is NOT a ridge; a gathered HOLLOW
       (src 11, walkable) is neither ridge nor cliff.
3. **Version 0.4.0-dev** in `project.godot`. Export presets left at 0.3.1 (part B bumps them).
4. **No exports rebuilt. No git commit.**

Deterministic-art invariant re-checked: re-running `tools_gen_art.js` reproduces
`ridge_rock.png` + `worn_dirt_patch.png` byte-identically, and all pre-existing PNGs are
unchanged.

---

## Files touched

New:
- `scripts/world/tile_glow.gd` — soft radial glow decal for tile-gather targets.
- `assets/tiles/ridge_rock.png`, `assets/tiles/worn_dirt_patch.png` — ridge + trail art.
- `scenes/dev/v040_test_harness.{gd,tscn}` — v0.4.0-A acceptance harness (24 asserts).

Modified:
- `project.godot` — version 0.3.1 → 0.4.0-dev.
- `scripts/world/interaction_controller.gd` — adjacency-gated targeting/interact;
  object-brighten + tile-glow + placement-diamond split (`_update_targeting`).
- `scripts/world/gatherable.gd` — `set_targeted()` / `is_targeted()` brighten pulse.
- `scripts/world/map_loader.gd` — `_classify_void_cells` / `_scan_reaches_land` (ridge
  classification), `_build_ridges` + `_build_corridor_trail`, `_is_cliff_open` (ridge ≠ cliff).
- `scripts/world/tile_highlight.gd` — (unchanged logic; now used for placement only).
- `scripts/world/stepping_slot_hint.gd` — doc reference fix (`_update_slot_hint`).
- `scenes/world/starting_grove.tscn` — +TileGlow node, wired to Interaction.
- `scenes/dev/v031_test_harness.gd` — cursor asserts updated to the new API.
- `tools_gen_art.js` — `makeRidge` + `makeWornDirt`.

**Untouched:** `data/map_layout.txt` / `map_legend.json` (ridge is derived from the existing
authored V bands, no re-authoring), recipes/items data, export_presets.cfg, export/ zips.

## Notes / deviations
- **A3 classification rule**: used the spec's opposite-playable-sides rule (generalised across
  contiguous VOID bands) rather than flood-fill-from-outside, because on this map every V is
  border-connected so the flood-fill would classify zero ridges. Result matches the level-
  design intent (§A-5 gate walls) exactly. Documented inline.
- The soft tile glow fakes a radial gradient with concentric `draw_circle` bands under a 2:1
  transform (no shader) — cheap, palette-strict, CanvasModulate-tintable like the ground.
