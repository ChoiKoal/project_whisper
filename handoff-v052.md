# Handoff — v0.5.2 hotfix (grove→home return-portal crash)

Godot 4.5.stable. Version bumped **0.5.1 → 0.5.2**. Base = clean tree at v0.5.1 commit `32c9ca5`
(HEAD was `4c98fff` docs; this fix is `c0d798a`). Committed + pushed to `main` + GitHub release
**v0.5.2** published with both zips (release commits are the established exception for this repo,
per the v0.5.1 handoff).

Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Run the stress harness: `… --headless res://scenes/dev/v052_travel_stress.tscn` → PASS (0 failures)
Rebuild exports: `tools/build_exports.sh` (reads version from project.godot; bakes the mac rename).

---

## ROOT CAUSE (specific)

**`game/scripts/world/placed_object.gd`, `_add_glow()` (was lines 92–98).**

A glowing placed decor (등불꽃 **D48** / 연꽃 **D41**) builds a night-glow additive overlay. The old
code built it as:

```gdscript
_glow = Node2D.new()
_glow.set_script(GlowScript)   # GlowScript = res://scripts/world/glow_sprite.gd
```

`GlowSprite` **`extends Sprite2D`**. Assigning a Sprite2D-derived script to a **Node2D** is rejected
by the engine:

```
ERROR: Script inherits from native type 'Sprite2D', so it can't be assigned to an object of type 'Node2D'.
   at: instance_create (modules/gdscript/gdscript.cpp:420)
```

**Why release-only:** in the editor/debug template this fails *soft* — `set_script` is refused, the
glow is silently dropped, the game keeps running (the owner never saw it in-editor). In a **release**
template the same rejected assignment is not the safe editor path; the mis-typed node is left in an
inconsistent state that the scene-restore / renderer path then trips over → SIGSEGV on the owner's
macOS release build. (This is the same class as the v0.1.2 macOS crash: a fault that errors
gracefully in-editor but hard-crashes in release.)

**Why it fires on the grove→home RETURN specifically:** every persistent placed object is
re-instantiated from the scene-keyed save on **every** scene load via
`SaveManager._apply_placed_objects` → `PlacedObject.new()` → `_ready()` → `_add_glow()`. So a glowing
decor the player placed is **rebuilt mid-scene-change** during the manual return-portal travel
(`GroveSession._on_return_portal` → `_return_home(false)` → `save_game()` →
`get_tree().change_scene_to_file(home)`). The broken glow construction runs right inside the
teardown/rebuild window the owner was in when it "died". The home→grove leg didn't crash the owner
because they hadn't placed a glowing decor yet on that leg.

`world_tree.gd` and `mystic_water.gd` construct the glow correctly (`GlowSprite.new()`); `placed_object.gd`
was the ONLY incorrect construction site.

### Reproduction

A stress driver (home→grove via the real travel cutscene → **place D48** + gather + fusion in the
grove → manual return) reproduced the exact `Script inherits from native type 'Sprite2D'` error on
BOTH the editor binary and the **exported Linux arm64 release** binary. After the fix the error is
gone on both. (The bare return with no glowing placement never errored — that's why v050c/e2e, which
don't place a glowing decor across a real `change_scene_to_file`, never caught it.)

---

## THE FIX

**`placed_object.gd` `_add_glow()`** — construct a real `GlowSprite`, matching the other two sites,
with the object's own icon as the additive overlay texture:

```gdscript
func _add_glow() -> void:
	var glow := GlowSprite.new()
	glow.texture = ItemDB.icon(item_id)
	glow.offset = offset
	_glow = glow
	add_child(_glow)
```

### Defense-in-depth on the travel path (no remaining unguarded engine-object access)

- **`glow_sprite.gd` `_reparent_to_glow_layer()`** — added `is_instance_valid(layer)` to the guard.
  This runs `call_deferred`, so between the `_ready` that queued it and the deferred call, a portal
  scene-change can free the spawner and its whole scene (incl. the glow layer). Reparenting onto a
  freed layer would SIGSEGV in release.
- **`grove_session.gd` `_spawn_return_portal()`** — set the return portal OPEN *before* `add_child`
  so `Portal._ready` adopts the OPEN state on build (it reads `GameState.portal_state("return")` in
  its own `_ready`); null-check the instanced portal; `has_signal("portal_interacted")` guard before
  `connect`.
- **`home_session.gd` `_wire_portals()`** — skip invalid portals and guard against double-connecting
  `portal_interacted` on a re-wire.

---

## NEW HARNESS — `scenes/dev/v052_travel_stress.tscn`

Drives the **real in-game travel API** (`get_tree().change_scene_to_file` through the sessions'
portal hooks — NOT direct scene loads like v050c). It reparents itself under the tree **root** so
`change_scene_to_file` (which frees the current scene) doesn't free the harness.

**Scenario (5 cycles):** home → grove (via the flickering nature portal's travel cutscene) → in the
grove: a **gather** (tile → HOLLOW + AStar rebuild), a **fusion** (`Fusion.fuse`), and a **placement
of a glowing decor** (D48, night-time so the glow is at full ramp) → **manual return** grove→home via
the return portal (the crash path) → re-enter with `pending_load` to force the **save-restore rebuild
of the glowing placed object** (the exact release-only path).

**Asserts:** each hop lands in the expected scene, the return portal exists + is OPEN each grove
visit, the glowing decor places each cycle, the return lands home with no crash, and the placement
round-trips through the scene-keyed save (5/5). Engine/script errors can't be captured from GDScript,
so the runner greps the output for `SCRIPT ERROR` / `inherits from native type` (present before the
fix, absent after).

**Result:** PASS (0 failures) in the editor AND on the **exported Linux arm64 release binary**
(dev scenes temporarily included in the Linux preset for the release-binary run, then the preset was
restored to `exclude_filter="scenes/dev/*"`).

---

## Validation

- **Headless import: 0 errors.**
- **All 19 harnesses PASS (0 failures):** e2e_playthrough, m2, m2_integration, m3, m4, m5, m6a,
  m7_title_flow, m8_icon_coverage, v021, v030, v031, v040, v040b, v040c, v050a, v050c, v051,
  **v052_travel_stress**.
- **Exported-binary stress:** built a temp Linux arm64 release with dev scenes included; ran
  `v052_travel_stress` on it → **PASS, 0 failures, zero `Script inherits…` errors**. Preset restored
  after (all 3 presets exclude `scenes/dev/*` again).

## Exports (v0.5.2)

`tools/build_exports.sh` (unchanged; version auto-read from `project.godot`):
- `export/ProjectWhisper-win64-v0.5.2.zip` — Windows x86_64 (embedded pck) + README-실행방법.md (39.4 MB).
- `export/ProjectWhisper-macos-v0.5.2.zip` — macOS universal, post-processed → `ProjectWhisper.app`
  (verified: 6 entries, all space-free; `MacOS/ProjectWhisper` + `Resources/ProjectWhisper.pck`) (67.8 MB).
- The mac export still prints the benign `gio/kioclient5/gvfs-trash` "could not create child process"
  lines (Godot trying to trash the old file); export completes DONE.
- `export/` is gitignored — zips ship only on the GitHub release.

## Release

Committed (`c0d798a`) + pushed to `main`; GitHub release **v0.5.2** published on
`ChoiKoal/project_whisper` with both zips attached. Korean body: 크래시 원인 한 줄 + 수정 내용.
URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v0.5.2

## Notes for next agent

- **Placed objects / tiles do NOT persist across in-game portal travel** — only across a full
  save + 이어하기 (the destination session restores only when `SaveManager.pending_load` is true;
  normal travel `save_game()`s on the way out but the destination doesn't `load_game`). This is a
  pre-existing design choice, not a bug I changed; if per-travel persistence is wanted, have the
  session `load_game()` its scene's snapshot on portal arrival (not just on 이어하기).
- The `Node2D.new(); set_script(<Sprite2D-derived>)` anti-pattern only existed at
  `placed_object.gd`; the other glow sites are correct. If new glow overlays are added, always use
  `GlowSprite.new()`.
- Stale "keep aspect" doc-comment in `title_menu._viewport_height()` still un-tidied (carried from v0.5.1).
