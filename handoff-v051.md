# Handoff — v0.5.1 hotfix (title fit, stuck-input, portal entry zone, mac bundle rename)

Godot 4.5.stable. Version bumped **0.5.0 → 0.5.1**. Base = commit `a8e8eb6` (v0.5d) + the
uncommitted BUG1/BUG2/BUG3 scaffold a prior agent left. This session verified BUG1+BUG2, finished
BUG3, fixed regressions the prior agent introduced, made all harnesses green, added the macOS
bundle-rename packaging step, rebuilt exports, and shipped the GitHub release.

**This release WAS committed + pushed + published** (exception to the usual no-commit rule, per the
lead's instructions — the release had to land).

Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import`
Run v051 harness: `.../Godot... --headless res://scenes/dev/v051_test_harness.tscn` → PASS (0 fail)
Rebuild exports: `tools/build_exports.sh` (macOS post-process is baked in — see PACKAGING below).

---

## BUG1 — title menu fits small windows + glow alignment (`scripts/ui/title_menu.gd`)  ✔ verified

Prior agent's work, verified correct. The title now scales its whole column responsively: a
`_compress()` factor (1.0 at ≥720px window height → 0.0 at ≤480px) drives every font size / button
height / margin via `lerpf`, and the layout rebuilds on `size_changed`. The logotype glow copy sits
directly under the main label (same x, ≤1px y — additive bloom, never a sideways ghost).
`project.godot` stretch aspect changed `keep` → `expand` so the responsive math reads the true
window rect. Harness asserts all 4 buttons fully inside the viewport at **640×480 / 768×526 /
1280×720 / 1920×1080**, and glow dx=0.00 dy=1.00. (Minor: a stale doc-comment in `_viewport_height`
still says "keep aspect" — cosmetic only.)

## BUG2 — stuck upward movement (`player.gd`, `game_state.gd`, `touch_controller.gd`, `portal_cutscene.gd`)  ✔ verified + 2 fixes

Prior agent's fix, verified and hardened. The "계속 위로 가는 키" was a swallowed key-RELEASE
surviving a lock/scene/focus boundary. Now the four move actions + any queued tap-path are released
on **every** edge that could strand input:
- modal open/close (`ui_modal_changed` → `Player.release_move_and_path`),
- cutscene control-lock (new `GameState.set_control_lock` + `control_lock_changed` signal, driven by
  `portal_cutscene.gd` on both the lock and unlock edge of travel / CS-05),
- window focus-out (`NOTIFICATION_APPLICATION/WM_WINDOW_FOCUS_OUT`, the macOS cmd-tab case),
- scene teardown (`NOTIFICATION_EXIT_TREE`).

**Two regressions the prior agent introduced, fixed here:**
1. `TouchController._world_locked()` only checked `ui_modal_open() or not time_running` — a pure
   control-lock (cutscene that locks control without pausing time in the harness path) did NOT
   refuse new taps. Added `or GameState.control_locked()`.
2. `TouchController.move_to()` (public/harness path) bypassed the lock check entirely. Added the
   `_world_locked()` guard so it honors the lock exactly like `handle_tap`.

## BUG3 — portal entry ("문으로 안 들어가짐")  ✔ finished (`portal.gd`, `home_session.gd`, `touch_controller.gd`)

Root cause: the v0.5d monumental gates are ~2×3-tile megaliths; the old adjacency/facing E-interact
targeted an anchor cell that fell inside/above the gate's own blocking pillar collision, so the
player could never get "adjacent" enough to trigger it. **Fix = a generous front-apron entry zone**,
not an anchor cell:

- **`portal.gd`**: each gate builds an `Area2D` "EntryZone" (`ENTRY_W 200 × ENTRY_H 128`, centred
  `ENTRY_FORWARD 64px` screen-DOWN of the base — in front of the steps, clear of the pillar
  collision). `is_player_in_entry_zone()` queries `get_overlapping_bodies()` authoritatively each
  call (not just the cached enter/exit flag) so a teleport/warp reads correctly on the next physics
  frame. `entry_stand_point()` = apron centre (touch walk target). `entry_prompt_text()` is
  state-driven: open→"E 들어가기", flickering→"E 다가가기", dormant→"…아직 잠들어 있다".
- **`home_session.gd`**: `_process` tracks which gate's apron the player is in and floats the state
  prompt over it; `_input` routes the `interact` action (keyboard E) to that gate's `on_interact`
  BEFORE the InteractionController sees it (`set_input_as_handled`). Existing travel hook
  (`_on_portal_interacted` → `portal_reached.emit` + `_travel_to_layer` → `play_travel` + scene
  change) verified to still fire — it was intact; the entry-zone approach just bypasses the broken
  anchor targeting.
- **`touch_controller.gd`**: click/tap on a `Portal` → walk to `entry_stand_point()` then enter on
  arrival (`_pending {"kind":"portal"}` → `on_interact` in `_on_path_finished`). Dormant gates
  surface the locked whisper and do NOT travel.

**Another regression fixed:** the prior agent replaced the `"cell"` case in `_on_path_finished`
with `"portal"`, DELETING it — so walk-then-place held-item on water/VOID (tap placement) silently
broke (`_target_cell` still queued `{"kind":"cell"}` but nothing consumed it). Restored the `"cell"`
case alongside `"portal"`.

## PACKAGING — macOS bundle rename (no space)  ✔ scripted

Owner hit quarantine confusion from the space in "Project Whisper.app". New
`tools/postprocess_macos_zip.py` rewrites the export zip so the bundle is space-free:
`Project Whisper.app/` → `ProjectWhisper.app/`, `Contents/MacOS/Project Whisper` → `.../ProjectWhisper`,
**and `Contents/Resources/Project Whisper.pck` → `.../ProjectWhisper.pck`** (the pck MUST match the
executable name or Godot can't find its data — "Couldn't load project data"; the brief listed only
the .app/exe/plist but the pck rename is required and was added). Info.plist `CFBundleExecutable` +
`CFBundleName` → `ProjectWhisper`; `CFBundleDisplayName` left as the pretty "Project Whisper" (Finder
label only). The executable entry keeps its 0755 exec bit. The script self-verifies (no space-named
entries remain, plist patched, exe+pck present) and is idempotent. Wired into new
`tools/build_exports.sh` as a mandatory macOS step so every future build gets the rename.

---

## Validation

**All harnesses green** (`--headless res://scenes/dev/<h>.tscn`, EXIT 0, 0 failures):
- **v051** (26 asserts): title fits @ 640×480/768×526/1280×720/1920×1080; glow aligned; move
  actions released on lock/unlock/cutscene-lock/focus-out; tap-path cleared on lock; tap refused
  while control-locked; portal apron detected; flickering→travel via E; dormant→locked whisper, no
  travel; click walk-then-enter queues path.
- Regression: **e2e_playthrough, m7_title_flow, v050c, m3, m4, m5, m6a, v031, v040c, v050a** — all PASS.

Also fixed the v051 harness itself (prior agent left it with 4 parse errors — untyped `:=` from
`load().instantiate()` — so it never loaded/hung): typed those vars, and added `_phys()` physics-
frame waits + `force_update_transform()` after teleports so Area2D overlap sets are honest in
headless.

## Exports (v0.5.1)

- `export/ProjectWhisper-win64-v0.5.1.zip` — Windows x86_64 (embedded pck) + README-실행방법.md.
- `export/ProjectWhisper-macos-v0.5.1.zip` — macOS universal, **post-processed** → `ProjectWhisper.app`
  (verified: all 6 entries space-free, plist Exec/Name=ProjectWhisper, ShortVersion 0.5.1, exec 0755).
- `export/` is gitignored — zips ship only on the GitHub release, not in the repo.

## Release

Committed + pushed to `main`, GitHub release **v0.5.1** published on `ChoiKoal/project_whisper`
with both zips attached. Korean release notes cover the three bug fixes, the space-free app name,
and a one-line `xattr` gatekeeper note. (Release URL in the session's final report.)

## Notes for next agent
- The stale "keep aspect" comment in `title_menu._viewport_height()` could be tidied.
- Only Layer-1 (nature→grove) is reachable; other gates stay dormant/locked by design.
- `tools/build_exports.sh` is the canonical build entry now; it bakes in the mac rename.
