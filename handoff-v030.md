# Project Whisper — v0.3.0 Handoff (diorama map + UI wireframes)

> Built: 2026-07-05 | Godot 4.5.stable (arm64 headless)
> Project root: `/workspace/group/project-whisper/game/`
> Builds on v0.2.1 (clean tree). Uncommitted (project rule: do NOT git commit).

Two owner-requested workstreams: (A) map visual escalation toward the reference
floating-island diorama grammar, and (B) an in-game UI per the owner wireframes
(command bar + restyled 도감 + new 캐릭터 window). Game logic / save schema / map
topology / tile규격 unchanged — this sprint is art + presentation + one input remap.

---

## A. Map visual escalation

### A1 — Diorama cliff skirts ★
`tools_gen_art.js` `makeCliffSkirt()` generates three 128×112 lit earth→rock
cross-section sprites (`cliff_skirt_s/e/se.png`): a soil/moss lip under the diamond's
lower rim dropping into horizontal rock strata with pebble specks and a selout
silhouette (top-right lit, palette browns/greys, deterministic).

`map_loader._build_cliff_skirts()` (was CALLED at line 112 but the method did not
exist in the inherited partial tree — a guaranteed runtime miss; now implemented)
hangs a skirt under every authored playable cell whose outer neighbour is off-island:
`+row` (screen SW) → `s` skirt, `+col` (screen SE) → `e` skirt, both → `se` corner.
Sprites are children of the Ground tilemap at `CLIFF_SKIRT_Z = -1` (z_as_relative →
effective z −1, BELOW the ground tiles) so the island reads as a floating slab.
Island membership is read from `_layout` (authored VOID), NOT live tiles, so a
runtime gathered-VOID hole in the interior does not sprout a wall. Visual only — no
collision, base tiles untouched. Exposes `cliff_skirt_count` /
`cliff_skirt_south_cells` for the harness.

### A2 — Atmospheric backdrop
`scripts/world/backdrop.gd` (CanvasLayer, **layer −1**, `follow_viewport` OFF →
screen-fixed) hosts `scripts/world/backdrop_canvas.gd` (Control) which paints a deep
navy-violet vertical gradient (`#12121c → #1e1a2e`), a deterministic star field (90
tiny cream/violet twinkling dots) + 140 faint dust specks + 7 slow drifting violet
motes (wrap-around). Layer −1 sits below the root canvas, so the day/night
CanvasModulate (which tints only the root canvas) never touches it — the void sky
stays constant behind the lit island. Node added to `starting_grove.tscn`.

### A3 — Local light pools
`scripts/world/light_pool.gd` + three radial-gradient PNGs
(`light_pool_violet/violet_lg/cyan.png`, `makeLightPool()` in the generator). The
loader's `_add_light_pool()` lays a soft additive pool under the cauldron (violet,
0.85), world tree (violet_lg, 1.0), and mystic water (cyan, 0.7). Pools reparent
onto the glow CanvasLayer (like GlowSprite) so they are CanvasModulate-immune and
bloom at night; per-phase alpha ceilings ramp day→night with a gentle breathe.
Plus `scripts/world/night_fireflies.gd`: 8 tiny additive violet glints on a slow
lissajous drift around the world-tree centroid, **night-only** (alpha → 0 by day),
on the glow layer. Node added to the grove scene.

### A4 — Tile texture density
`makeTile()` gained a procedural interior-texture pass (own seed stream, so the
flower/clover dot placement is byte-identical to v0.2.x): grass = directional blade
strokes + 2-3 green tonal patches; dirt = pebbles + strata specks; water = shimmer
bands + sparkle glints; mud = wet blotches + gloss specks. Silhouettes + soft v0.2.0
edges unchanged, palette-strict (all tones from art-guide §3). 8 ground tiles
regenerated (`t1_dirt, t2a-d, t4_mud, t5a/b_water`); everything else byte-identical.

### A5 — Water animation
Deferred: covered visually by A4's shimmer-band texture on the two water tiles. A
2-frame swap was scoped but the TileMapLayer animated-tile path added state for no
visible gain over the denser static shimmer under the new lighting; the water reads
as moving via the band contrast + glints. (Noted as the one deviation from the A
list — see Deviations.)

---

## B. UI per owner wireframes

New coordinator `scripts/ui/ui_hub.gd` (UIHub CanvasLayer) owns the command bar AND
is the single authority for the one-window rule + ESC precedence.

### B1 — Bottom command bar
Centered bottom bar of 4 buttons with hotkey labels: `캐릭터 (C)` `인벤토리 (I)`
`도감 (R)` `메뉴 (ESC)`. A click does exactly what the hotkey does (routed through the
hub). Dark `#2a2a33` panel + violet `#9e7ad9` border + cream text.
**KEY REMAP:** `codex` action C → **R** (도감/Recipe); new `character` action = **C**
(project.godot input map). The hub owns all three hotkeys + ESC.

### B2 — 도감 (R) rewrite
`codex_ui.gd` fully rewritten to a fullscreen-ish panel: title "도감" + 검색 LineEdit
(top-right, filters the grid by name substring, Korean ok — only discovered items
expose a name to the filter). GRID of ALL catalogued items (discovered = real icon;
undiscovered = darkened silhouette + "???"). Click item → detail pane: big icon +
name + flavor + a **"조합법"** section listing DISCOVERED recipes that OUTPUT the item
as `[icon] + [icon] = [icon]` rows (undiscovered recipes hidden; "아직 알아내지
못했다" when none known). Discovery % header + hint-gauge line kept. `set_search()`
is the harness drive point.

### B3 — 캐릭터 창 (C)
New `scripts/ui/character_window.gd`: left = the new 192×192 cloaked-constructor
portrait (`makeCharPortrait()` bakes a dedicated bust — hood + dark face cavity with
two glowing violet eyes, violet chest trim, staff-orb glint — to
`assets/character/character_portrait.png`). Right = 6 equipment slots in the
wireframe H/A/M/T/G/B arrangement, all LOCKED/dimmed placeholders ("?" + tooltip
"아직 잠겨 있다", no equipment system yet — layout reserved). Below = stats: 발견률 %,
진행 일차, 회차(NG+ run), 심은 세계수 여부. `slot_boxes` is the harness drive point.

### B4 — Held-item HUD no overlap
The held HUD stays bottom-LEFT (x=24, InventoryUI), the command bar is CENTER-bottom
(UIHub) — horizontally separated, no overlap. Inventory opens via the bar button too
(hub `toggle(INVENTORY)`); visual style unchanged (already matched the wireframe).

### B5 — One window at a time + ESC precedence
The hub closes every other registered window before opening one (`toggle` / `open`
via bar or hotkey; windows also self-report via `request_focus`). ESC: if any window
is open the hub closes it and consumes the event (pause menu does NOT open); with no
window open ESC falls through to the pause menu. InventoryUI/CodexUI/CharacterWindow
each expose `open()/close()/is_open()/set_hub()`; the hub resolves them by class.

---

## Validation (§2 — all green, exit 0)

### Import / scenes (0 errors)
```
--headless --import .            → 0 SCRIPT ERROR / Parse Error / Failed to load
title.tscn   --quit-after 90     → clean
opening.tscn --quit-after 90     → clean
grove.tscn   --quit-after 200    → clean (backdrop + skirts + fireflies + UI)
```

### Harnesses (all PASS, 0 failures)
```
m2_test_harness    m2_integration    m3_test_harness    m4_test_harness
m5_test_harness    m6a_test_harness  e2e_playthrough    m7_title_flow
m8_icon_coverage   v021_test_harness v030_test_harness  (new)
```
- **Key remap** did not break any harness (they drive UI by method call, not key).
- **v030_test_harness** (new, `scenes/dev/v030_test_harness.{gd,tscn}`), 36 asserts:
  - A1: CliffSkirts overlay present, sprites placed, z < 0, south-edge cells recorded
    + every south skirt cell has an off-island south neighbour + a bottom-row skirt.
  - A2: Backdrop CanvasLayer at layer −1, screen-fixed, has its painting canvas child.
  - B1: command bar has 4 buttons with the correct remapped hotkey labels;
    `character` + `codex` actions exist.
  - B2: codex search "꽃" matches 꽃/꽃즙/꽃다발 (discovered) and excludes 씨앗; cleared
    search restores the full catalog; D03 씨앗 detail lists exactly 1 discovered recipe
    row (R04); D04 (no discovered recipe) shows "아직 알아내지 못했다".
  - B3: character window opens with 6 locked equipment slots (dimmed + locked tooltip).
  - B5: opening one window closes the others; exactly one open at a time; close_all.

### Version → 0.3.0
`project.godot config/version="0.3.0"`; `export_presets.cfg` product/short/version
all `0.3.0`.

### Export validation flow (spec order)
1. Installed export templates 4.5.stable from `tools/export_templates.tpz` (none
   present) into `~/.local/share/godot/export_templates/4.5.stable/`.
2. Temp-cleared `exclude_filter` on all presets → debug Linux arm64 test export to
   `/tmp/testexport`. Ran on the EXPORTED binary:
   - `m7_title_flow` → PASS (opening + data-intact assertions).
   - `v030_test_harness` → PASS (diorama + UI asserts survive export).
3. Restored `exclude_filter="scenes/dev/*"` → built finals.

### Final exports (`export/`)
```
ProjectWhisper-win64-v0.3.0.zip          34,181,209 B   (ProjectWhisper.exe, embed_pck)
ProjectWhisper-macos-v0.3.0.zip          62,514,710 B   (Project Whisper.app release bundle)
ProjectWhisper-macos-DEBUG-v0.3.0.zip    67,216,500 B   (debug bundle)
export/linux/ProjectWhisper.arm64        63,370,728 B  + ProjectWhisper.pck 377,784 B (release, dev scenes excluded)
```
- win zip = single `ProjectWhisper.exe`. macOS zip = proper `Project Whisper.app/
  Contents/...` bundle (verified via zip listing).
- macOS export prints one `execute (os_unix.cpp)` line = the container's missing
  codesign/xattr tool — harmless (as in prior sprints), export completes DONE.

### git commit 하지 않음.

---

## File map (new / changed in v0.3.0)
```
game/
  project.godot                              # version 0.2.1 → 0.3.0; codex C→R; +character=C
  export_presets.cfg                         # product/short/version → 0.3.0
  tools_gen_art.js                           # makeTile tex-density; makeCliffSkirt×3;
                                             #   makeLightPool×3; makeCharPortrait
  scripts/world/map_loader.gd                # CLIFF_SKIRT_Z; _build_cliff_skirts (+ south-cell
                                             #   bookkeeping); _add_light_pool wiring (A3)
  scripts/world/light_pool.gd         (new)  # additive ground light-pool decal
  scripts/world/backdrop.gd           (new)  # void-sky CanvasLayer (layer -1)
  scripts/world/backdrop_canvas.gd    (new)  # gradient + stars + dust + motes painter
  scripts/world/night_fireflies.gd    (new)  # night-only firefly motes near world tree
  scripts/ui/ui_hub.gd                (new)  # command bar + one-window/ESC coordinator
  scripts/ui/character_window.gd      (new)  # 캐릭터 창 (portrait + 6 locked slots + stats)
  scripts/ui/codex_ui.gd                     # rewrite: fullscreen grid + search + 조합법 rows
  scripts/ui/inventory_ui.gd                 # hub API (open/close/is_open/set_hub); hub owns hotkey
  scenes/world/starting_grove.tscn           # +Backdrop, +NightFireflies, +CharacterWindow, +UIHub
  assets/tiles/{t1_dirt,t2a-d,t4_mud,t5a/b_water}.png   # denser interior texture (regen)
  assets/tiles/cliff_skirt_{s,e,se}.png      (new)  # diorama cliff cross-sections
  assets/objects/light_pool_{violet,violet_lg,cyan}.png (new)  # radial glow decals
  assets/character/character_portrait.png    (new)  # 192×192 cloaked-constructor bust
  scenes/dev/v030_test_harness.{gd,tscn}     (new)  # 36 diorama + UI asserts
  export/ProjectWhisper-{win64,macos,macos-DEBUG}-v0.3.0.zip  (new finals)
```

## Deviations / notes
- **A5 water animation**: shipped as the A4 static shimmer-band + glint texture on
  the two water tiles rather than a 2-frame TileMapLayer swap — under the new local
  lighting the band contrast + sparkle reads as motion without the extra runtime
  state. Only intentional divergence from the A list.
- **Inherited partial tree**: v0.3.0 began from a v0.2.1 tree that already contained
  interrupted A1/A3/A4 work (regen'd tiles, light_pool + pool PNGs, skirt PNGs, and a
  `_build_cliff_skirts()` CALL with no definition). All prior assets were verified
  byte-reproducible from the deterministic generator; the missing skirt method and
  everything in A2/B/validation were built this sprint.
- **test_map (dev)**: has Inventory/CodexUI but no UIHub, so those windows are not
  keyboard-toggleable there (hub owns hotkeys). Dev-only map; m2/m3 drive by method
  call and stay green. Null-hub guards keep both UIs safe without a hub.
- **Backdrop / pools / fireflies** are all deterministic and CanvasModulate-immune
  (layer −1 for the sky, glow CanvasLayer for the pools/fireflies), matching the
  reference dioramas' constant void-sky + blooming local light.
```
