# Handoff — v0.4.0-B (visual/UI sprint, part B)

Godot 4.5.stable. Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Run a harness: `… --headless res://scenes/dev/<name>.tscn`

Continues **handoff-v040a.md** (part A: adjacent-E, object-brighten cursor, ridge walls — all
landed & green). This sprint is **B1–B4**: character A production art, bush/gate readability,
UI fixes (modal-block / close chrome / discovery banner / codex hints / fusion polish), and a
title 감성 pass. **No git commit** (per brief).

---

## Audit of inherited tree (before trusting the task log)

The previous agent (v040b) died mid-sprint. Its task log claimed "B1 done / B2 in-progress /
B3+B4 pending", but the tree told a different story — verified by pixel-sampling and reading
every touched file:

- **B1 (character A) — DONE & correct.** `character_sheet.png` (288×384, unchanged
  player_frames.tres layout) + `character_portrait.png` re-baked. Dominant colors are the dark
  cloak ramp (#262e2e / #16161c / #0e0e12 — rgb 38,38,46 etc.), staff wood, violet orb. NOT
  cream. Matches candA. `tools_gen_art.js` `makeProtagonist`/portrait are candA-faithful.
- **B2 (bush) — DONE.** `tools_gen_art.js::makeThornbush` produces `bush_dry.png` /
  `bush_bloom.png` (128×128 — canvas kept for the −80 offset + diamond collision; the thornbush
  body occupies the wide lower band). Dry = brown-grey tangle + thorn spikes on a dirt patch;
  bloom = same silhouette + pink/violet blossoms. `bush_dry.gd` already builds a GlowSprite
  shimmer cue (`_add_shimmer_cue`, reparents to the glow layer) and keeps object_id/gate logic.
- **B3 — mostly DONE** by the dead agent: modal registry (`GameState.push/pop_modal` +
  `ui_modal_open`) wired into player/interaction/touch; `WindowChrome.make_close_button` ✕ on
  all 5 windows; single composed `DiscoveryBanner`; codex "힌트" chip + inline fusion "힌트 보기";
  fusion slot borders + dividers. **Gap found: no "ESC 닫기" hint labels.**
- **B4 — mostly DONE**: `title_menu.gd` had night-sky gradient, moon+halo, 3 parallax bands,
  world-tree hill + dawn glow, fog, vignette, fireflies, letter-spaced logotype + subtitle,
  minimal menu. **Gaps found: no constructor figure on the hill; opening had no per-card tint.**

**Cleanup done:** ~55 stray root-level PNGs (generator scratch — `tools_gen_art.js` writes to
`OUT=__dirname`) were byte-identical dupes of the committed `assets/` copies; deleted them and
their bogus root `.import` files. Removed an empty duplicate `game/handoff-v040a.md` (the real
one lives in the project root).

---

## Work completed this session (the actual gaps)

### B3.2 — "ESC 닫기" close-affordance labels
- New `WindowChrome.make_esc_hint()` → a dim, centered `Label` named `EscHint`.
- Added to the bottom of all 5 window panels: fusion, inventory, codex, character, pause.
- Also added `FusionUI.close()` (the other 4 windows had `close()`; fusion only had
  `_set_visible`) for a consistent window API.

### B4 — title constructor figure + opening per-card tint
- `title_menu.gd::_add_constructor_figure()` — a tiny hooded back-view silhouette on the near
  hill crest, just left of the world tree: A-line cloak + hood disc + staff, with a floating
  violet orb glint (additive, breathes with the moon via `_glow_nodes`). Reads as part of the
  diorama (tone nudged just above the hill so the silhouette separates).
- `opening.gd` — per-card `CARD_TINTS` (4 deep near-black tints: waking → cool → violet →
  warm-stir); backdrop cross-fades between them (`_drift_tint`, TINT_FADE 1.4s). Fades
  lengthened (FADE_IN 0.7→1.0, FADE_OUT 0.6→0.9, FINAL_FADE 0.9→1.1) for a softer feel.

### New harness: `scenes/dev/v040b_test_harness.{gd,tscn}` (46 asserts, all PASS)
On the real grove + generated assets:
- **B3.1 modal-block**: opening fusion pushes a modal; a queued click/tap path is dropped and
  `velocity==0` while up; player doesn't drift; interaction targeting suppressed; movement
  resumes after close.
- **B3.2 close chrome**: every window exposes a `CloseButton` (✕) AND an `EscHint` label.
- **B3.3 banner**: exactly ONE composed `DiscoveryBanner` (name "✦ 새로운 발견! — <item>" + 도감
  count share the SAME panel; no legacy floating counter → the overlap bug is structurally
  impossible).
- **B3.4 codex hints**: gauge→threshold reveals a hint; codex `HintChip` section lists it; the
  inline fusion "힌트 보기" list mirrors it.
- **B1 character art**: sheet is 288×384; sheet + portrait dominant color is the dark cloak
  family (lum<90), not cream.
- **B2 bush art**: `bush_dry`/`bush_bloom` exist at 128×128; dry dominant is dry brown wood
  (not green); bloom carries pink/violet blossom pixels; the gate BushDry holds a GlowSprite
  shimmer cue.

---

## Validation (all green)

1. **Headless `--import` → 0 errors.** `title` / `opening` / `starting_grove` each load with 0
   SCRIPT ERROR / Parse Error / Failed-to-load.
2. **14/14 harnesses PASS, 0 SCRIPT ERROR lines:** m2, m2_integration, m3, m4, m5, m6a, m8,
   e2e, m7, v021, v030, v031, v040 (part A, 24 asserts), **v040b (part B, 46 asserts, NEW)**.
3. **Version 0.4.0** — `project.godot` (`0.4.0-dev`→`0.4.0`) + `export_presets.cfg`
   (product/short/version `0.3.1`→`0.4.0`, all 3 presets). Export templates were **not**
   installed; extracted `/workspace/group/tools/export_templates.tpz` (v4.5.stable) into
   `~/.local/share/godot/export_templates/4.5.stable/`.
4. **Exports rebuilt** (release, v0.4.0):
   - Linux arm64: `export/linux/ProjectWhisper.arm64` — **63,370,728 B** (+ `ProjectWhisper.pck`
     431,416 B)
   - Windows x86_64: `export/windows/ProjectWhisper.exe` — **97,051,976 B**
   - macOS: `export/macos/ProjectWhisper.zip` — **62,558,162 B**
   (`gio/kioclient5/gvfs-trash` "Could not create child process" lines during macOS export are
   harmless — Godot trying to trash the old zip; it overwrites fine.)
5. **Export-validation on the exported linux binary** (m7 + v040 + v040b): dev scenes are
   `exclude_filter`-ed from the release pack, so built a temporary validation `.pck` (dev
   exclusion cleared, presets restored immediately after), then ran the exported binary with
   `--main-pack`: **m7 / v040 / v040b all PASS, 0 script errors.** The exported binary also boots
   the real title→autoloads headless with 0 errors. Temp pack removed.

---

## Files touched

**New:**
- `scripts/ui/window_chrome.gd` (+ `make_esc_hint`) — inherited from v040b-dead; this session
  added the ESC-hint factory. *(untracked)*
- `scenes/dev/v040b_test_harness.{gd,tscn}` — part-B acceptance harness (46 asserts). *(new)*
- `tools_title_preview.js` + `preview-title-v040b.png` — a **schematic** 1280×720 title layout
  reference (see note below). *(new)*

**Modified this session:**
- `scripts/ui/fusion_ui.gd` — `+close()`, `+EscHint` at panel bottom.
- `scripts/ui/inventory_ui.gd`, `codex_ui.gd`, `character_window.gd`, `pause_menu.gd` — `+EscHint`.
- `scripts/ui/title_menu.gd` — `+_add_constructor_figure` (hill-crest constructor + orb).
- `scripts/ui/opening.gd` — per-card `CARD_TINTS` + `_drift_tint`; longer fades.
- `project.godot`, `export_presets.cfg` — version 0.4.0.

**Inherited from the dead v040b agent (already in tree, verified, left as-is):** the B1/B2
assets + `tools_gen_art.js` thornbush/protagonist, `bush_dry.gd` shimmer, the modal registry in
`game_state.gd` + `player.gd` + `interaction_controller.gd` + `touch_controller.gd`, close ✕ on
all windows, the composed discovery banner + codex hint surfaces in `fusion_ui.gd`/`codex_ui.gd`,
plus all the part-A files from handoff-v040a (ridge/tile_glow/etc.).

**Untouched:** recipes/items data, map layout, the export zips are gitignored (not committed).

---

## Notes / deviations

- **Bush dimensions**: brief said "~112×96"; kept the existing **128×128** canvas because
  `bush_dry.gd`'s −80 offset + the iso-diamond collision are tied to it, and the thornbush body
  fills the wide lower band regardless. The harness asserts the actual 128×128 rather than the
  approximate figure.
- **Shimmer cue**: implemented as a breathing `GlowSprite` (reparented onto the shared glow
  layer so day/night doesn't dim it) rather than a discrete "every ~3s glint particle" — same
  readability intent ("뭔가 있다"), fits the existing glow system, and survives CanvasModulate.
- **Preview PNG is a schematic, NOT a screenshot.** This environment is GPU-less; headless
  viewport capture with the dummy driver hangs (verified). The real title is drawn at runtime by
  `title_menu.gd` with additive GPU compositing/parallax. `preview-title-v040b.png` is a
  pngjs render (palette + arrangement faithful; glow approximated by alpha, title/subtitle/menu
  shown as placeholder bars) so the owner can see the composition. Capture a true screenshot on
  a GPU host by running the game and pressing print-screen, or add a capture harness there.
- **Title is code-built** (`title_menu.gd`), not a `.tscn` with visual nodes — the brief said
  "rebuild title.tscn visuals", but the established architecture keeps all title visuals in
  code (deterministic, m7-drivable). Kept that; menu logic/flow untouched.
