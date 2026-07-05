# Project Whisper — v0.2.1 Handoff (playtest-response sprint)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on v0.2.0 (clean tree). Uncommitted (project rule: do NOT git commit).

Five owner-requested items from live playtesting: new protagonist, opening
cutscene, two bugs (draw-order, walk-off-map), and fusion "juice". Game
logic / save schema / map topology / tile규격 unchanged — this sprint is art +
two feedback-only UI reworks + two physics/draw-order fixes.

---

## 1. New protagonist — 망토 두른 컨스트럭터 (cat is OUT)

Regenerated `assets/character/character_sheet.png` (288×384, unchanged 96×96 ×
[3 col idle/walk0/walk1] × [4 row SE/SW/NE/NW] layout — `player_frames.tres`
structure untouched). New `drawConstructor()` in `tools_gen_art.js` replaces
`drawCat()`:

- Hooded cream robe (`#e8dfc8`/`#ceccaa`, lit `#faf5e6`) with a violet trim band
  (`#9e7ad9`/`#d9b8ff`) down the front, a wooden staff (`#8a6a4a`, outline
  `#5c4433`) held to one side, topped with a 2×2 glowing violet orb + baked
  additive-bright glow pixels (`#d9b8ff`, no engine change needed).
- Front rows (SE/SW): hood interior shadow (`#6e6e7a`) with two violet glowing
  eyes; back rows (NE/NW): hood back + a small violet sigil diamond on the cloak.
- Walk frames: hem sway + vertical bob + staff swing.
- Drawn on a 24×24 logical grid, ×4 block upscale → chunky 4px pixels matching the
  old sheet; selout outlines (`#b8b4a8`, no pure black), top-right soft light,
  palette-strict (art guide §2/§4). Scene keeps the 1.25 AnimatedSprite2D scale.

The title-screen diorama's `_add_cat` still samples the idle-SE frame (0,0,96,96)
— now the cloaked figure; no code change needed there.

## 2. Opening cutscene (새로 시작 only)

New `scenes/ui/opening.{tscn,gd}` (class `Opening`). Black screen → 4 cream text
cards fade-in → hold ~2.5s → fade-out in sequence (storyline §1/§7 프롤로그 text).

- Auto-advance per card; click / E / Space → next card; "건너뛰기 (ESC)"
  bottom-right → skip all. Ends with a fade to black → `starting_grove.tscn`.
- Public `advance()` / `skip_all()` are the deterministic drive points (also the
  m7 harness entry points).
- Wiring: `title_menu.gd._on_new_game` now → `opening.tscn` (was → grove).
  이어하기 / NG+ still go straight to the grove (they never load the opening).

## 3. Bug A — draw order (things render over the player)

**Root cause:** M6a's `EdgeOverlay` (z_index 1) and `BrightnessJitter` (z_index 2)
are children of the `Ground` TileMapLayer with `z_as_relative` (default), so their
effective z is 1 / 2. The sibling `YSortLayer` (player + objects) sat at z_index 0.
Within one CanvasLayer, higher z wins → the ground treatment drew ABOVE the player.
Most visible at night, when the DayNight `CanvasModulate` darkened those overlays
and the dark diamonds painted over the character.

**Fix:** `YSortLayer.z_index = 5` in `starting_grove.tscn`. Now the required order
holds: ground tiles (0) < edge overlays (1) < jitter (2) < YSortLayer (5) < glow
(separate CanvasLayer, always above root canvas) < UI (CanvasLayers ≥2). Named
constants `MapLoader.EDGE_OVERLAY_Z / JITTER_Z / YSORT_Z` document the tiers and
back the harness assertion.

## 4. Bug B — player walks off the map (WASD bypasses walkable checks)

**Root cause:** the player samples tile *speed* under its feet but relies on
physics for blocking; only water tiles (T5A/T5B/T5M) carry a TileSet physics
polygon. VOID (T0) has none, so WASD walked straight off the southern grass edge
(and any VOID band) onto the void background — pathfinding correctly refused it,
but keyboard movement had no wall.

**Fix (physics-level, `map_loader._build_border_collision()`):** a single
`StaticBody2D "BorderCollision"` (collision_layer 1) that seals the playable area
with two layers:
1. A diamond `CollisionPolygon2D` on every **authored-layout** VOID cell (symbol
   `V`, read from `_layout`, NOT live tile data). This walls the outer VOID band.
2. A thick rectangular perimeter frame just outside the 40×40 iso bounds, catching
   the outermost walkable rows/cols that border open space with no VOID beyond.

Preserved as-is:
- **Gathered-VOID stays walkable**: gathering swaps a tile to VOID via `set_cell`
  but never touches `_layout`, so the builder / `point_in_border` don't wall it —
  interior holes remain crossable exactly as before.
- **G1 stepping stones**: water keeps its own TileSet physics; D14 swaps water→dirt
  via `set_cell` (physics auto-rebuilt) — the border body never covers water, so
  the mechanism is untouched.
- **G3 night gate**: its own StaticBody2D toggles by phase — unaffected.

Note: interior VOID cells that flank the night gate (row 8) were previously
walkable-by-accident (no physics) and are now sealed — the only north passage is
the 2-wide `N` gate, which is intended. e2e still clears the full run.

## 5. Fusion juice (조합 쾌감) — feedback only, logic/API identical

`fusion_ui.gd` reworked around the SAME `Fusion.fuse()` call and result payload
(inputs captured before the call for the fly-in; codex recipe count snapshotted for
first-discovery detection — no logic touched):

- **Success (~1.2s, click-skippable):** input slot icons fly on a Tween arc into a
  central cauldron graphic (shrink + fade) → cauldron swaps to its bubble frame,
  scale-pulses, emits a violet `CPUParticles2D` burst (0.4s anticipation) → white
  flash → result card POPS (scale overshoot `1.35→1.0`) with icon + name + flavor +
  a violet sparkle burst. A click / E / left-mouse mid-sequence skips straight to
  the popped result.
- **First discovery:** a "✦ 새로운 발견! ✦" banner slides in + a visible codex
  counter ("도감 레시피 N종") ticks with a pulse.
- **Failure:** gray-smoke `CPUParticles2D` puff + panel position-shake +
  "…반응이 없다" (+ hint-gauge dots as before).
- **World cauldron polish:** new `assets/objects/cauldron_bubble.png` (2nd brew
  frame). `cauldron.gd` alternates calm/bubble on a slow timer + a tiny scale-pulse
  breathe (cosmetic; Y-sort origin unshifted). Base `cauldron.png` also refreshed.

---

## Art regeneration

`tools_gen_art.js` is deterministic and writes to the game root. Re-running the
full generator reproduces every tile/object BYTE-IDENTICALLY except the three
intended files — verified by diffing a fresh temp-dir run against `assets/`:
only `character_sheet.png` + `cauldron.png` differ, plus the new
`cauldron_bubble.png`. Only those three were copied into `assets/`.

---

## Harnesses (validation §2 — all green, exit 0)

```
m2_test_harness        RESULT: PASS (0 failures)
m2_integration         RESULT: PASS (0 failures)
m3_test_harness        RESULT: PASS (0 failures)
m4_test_harness        RESULT: PASS (0 failures)
m5_test_harness        RESULT: PASS (0 failures)
m6a_test_harness       RESULT: PASS (0 failures)
e2e_playthrough        RESULT: PASS (0 failures)
m7_title_flow          RESULT: PASS (0 failures)   (updated: traverses the opening)
m8_icon_coverage       RESULT: PASS (0 failures)
v021_test_harness      RESULT: PASS (0 failures)   (new: bug-A, bug-B, fusion juice)
```

- **m7** gained an `AT_OPENING` state: after 새로 시작 it verifies the opening
  scene is reached, steps its real `advance()` twice, then `skip_all()` → grove.
  ALL existing assertions kept (grove reached, data intact, save round-trip,
  이어하기, survive frames).
- **v021_test_harness** (new, `scenes/dev/v021_test_harness.{gd,tscn}`), 24 asserts:
  - draw-order: EdgeOverlay/Jitter effective z < YSortLayer z; explicit
    "jitter NOT drawn after YSortLayer"; ground < edge < jitter < YSort ordering.
  - border containment: `player.test_move()` outward at all 4 border midpoints
    (N/S/E/W) is blocked (+ `point_in_border` cross-check).
  - fusion juice: real UI fuse path runs to a popped result; logic intact (D03
    crafted, codex recipe recorded); sequence not stuck animating; click-skip works.

## Import / scenes (0 errors)

```
--headless --import .            → 0 SCRIPT ERROR / Parse Error / Failed to load
title.tscn   --quit-after 90     → clean
opening.tscn --quit-after 90     → clean
grove.tscn   --quit-after 200    → clean
```

## Version → 0.2.1

`project.godot config/version="0.2.1"`; `export_presets.cfg` product/short/version
all `0.2.1`.

## Export validation flow (spec order)

1. Installed export templates 4.5.stable from `tools/export_templates.tpz`
   (none present) into `~/.local/share/godot/export_templates/4.5.stable/`.
2. Temp-cleared `exclude_filter` on all presets → debug Linux arm64 test export to
   `/tmp/testexport`. Ran on the EXPORTED binary:
   - `m7_title_flow` → PASS (opening + data-intact assertions).
   - `v021_test_harness` → PASS (bug fixes + juice in export).
3. Restored `exclude_filter="scenes/dev/*"` → built finals.

### Final exports (`export/`)
```
ProjectWhisper-win64-v0.2.1.zip          33,937,152 B   (ProjectWhisper.exe, embed_pck)
ProjectWhisper-macos-v0.2.1.zip          62,433,600 B   (Project Whisper.app release bundle)
ProjectWhisper-macos-DEBUG-v0.2.1.zip    67,135,390 B   (debug bundle)
export/linux/ProjectWhisper.arm64        63,370,728 B  + ProjectWhisper.pck 289,984 B (release, dev scenes excluded)
```
- win zip = single `ProjectWhisper.exe`. macOS zip = proper `Project Whisper.app/
  Contents/...` bundle (verified via zip listing).
- `gio/kioclient5/gvfs-trash` warnings during export are the container's missing
  trash daemon — harmless (as in prior sprints).

### git commit 하지 않음.

---

## File map (new / changed in v0.2.1)
```
game/
  project.godot                              # version 0.2.0 → 0.2.1
  export_presets.cfg                         # product/short/version → 0.2.1
  tools_gen_art.js                           # drawConstructor (was drawCat); makeCauldron(name,bubble) 2 frames
  assets/character/character_sheet.png       # regen: cloaked constructor
  assets/objects/cauldron.png                # regen: refreshed brew
  assets/objects/cauldron_bubble.png  (new)  # 2nd brew frame (+ .import)
  scenes/ui/opening.{tscn,gd}         (new)  # opening cutscene (class Opening)
  scenes/world/starting_grove.tscn           # YSortLayer z_index = 5 (bug-A)
  scripts/ui/title_menu.gd                   # 새로 시작 → opening.tscn
  scripts/ui/fusion_ui.gd                    # fusion juice (fly-in, cauldron, particles, pop, banner, shake) — logic unchanged
  scripts/world/cauldron.gd                  # 2-frame bubble anim + subtle scale pulse
  scripts/world/map_loader.gd                # z-tier constants; _build_border_collision + perimeter + point_in_border
  scenes/dev/m7_title_flow_watcher.gd        # AT_OPENING state (traverse opening; all old asserts kept)
  scenes/dev/v021_test_harness.{gd,tscn}(new)# draw-order + border containment + fusion-juice asserts
  export/ProjectWhisper-{win64,macos,macos-DEBUG}-v0.2.1.zip  (new finals)
```

## Deviations / notes
- **Letter-spacing** on opening cards: Godot `Label` has no native letter-spacing;
  approximated with size + centering + line_spacing (visual intent preserved).
- **Border collision uses authored VOID (`_layout`), not live tiles**, specifically
  so runtime gathered-VOID stays walkable — the fix targets the MAP BORDER only.
- **Fusion juice keeps `Fusion.fuse()` and its result payload byte-for-byte** — the
  animation is a pure presentation layer; m3 + e2e fusion asserts unchanged & green.
