# Handoff — v0.4.0c ("쾌감/목표" sprint: 배치 + 퀘스트 + 오디오)

Godot 4.5.stable. Base commit = v0.4.0b (42da59c). Version stays **0.4.0**.
Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Run a harness: `… --headless res://scenes/dev/<name>.tscn`
**No git commit made** (per instructions).

---

## Audit of inherited uncommitted work

The previous agent left placement **partially** wired and quest/audio **absent**:

- **Placement (mature, kept):** `scripts/world/placed_object.gd`, `scripts/world/placement_ghost.gd`
  (new); `item_db.gd` placement query API (`get_placement/is_placeable/placement_class/
  placement_tiles/placement_blocks/placement_glows/can_place_expanded`); `game_state.gd`
  signals `placed_object_placed/recalled`; `interaction_controller.gd` ghost preview + recall
  targeting + `_spawn_placed_object` + stack-guard; `starting_grove.tscn` PlacementGhost +
  ysort/ghost node paths. **19 items** had `placement` records. All sound — I kept it and built on it.
- **Gaps I closed:** 6 spec items still lacked `placement` (D08/D18/D49/D55/D56/D60); PlacedObjects
  were **not persisted** in the save; no quest system; no audio.

---

## Per-system status

### 1. Placement (12+ 배치) — DONE
- **items.json:** added the 6 missing records → **25 placement items** total (23 real placeables +
  D14/D22 functional, unchanged). Classes per spec: structures block (D08 이끼바위, D24 울타리,
  D32 물레방아, D44 허수아비, D45 돌탑, D46 벽, D49 생명의정원), decor never blocks (D10/D13/D18/
  D26/D28/D29/D30/D33/D34/D41/D42/D43/D48/D55/D56/D60), glow decor D41/D48. Ground tile set = T1/T2A-D/T0.
- **Placement mode:** ghost preview (green valid / red invalid per `on` rule) drives off the held
  placeable; structure/decor spawn a persistent y-sorted `PlacedObject` (icon @1.7x + drop-offset,
  squash-in spawn pop); `blocks:true` → StaticBody2D + pathfinding refresh; can't stack on an
  occupied cell (floating "이미 무언가 놓여 있다").
- **Recall:** E on a placed object → `recall()` returns the item to inventory (non-destructive),
  prompt reads "E 회수". Functional D14/D22 stay consumed (unchanged tile-swap path).
- **Persistence (new this sprint):** `save_manager.gd` serializes `map.placed_objects`
  (`{item_id, cell}` each) and rebuilds them under YSortLayer on load — **no** placement signal
  re-fires on load (so quests/audio don't double-trigger). NG+/new_game reset clears them (world reset).

### 2. Quest system (11 속삭임, MVP Q1–Q9) — DONE
- **data/quests.json:** Q1–Q9 with `{id, whisper, type, signal, target, count, sub_steps?, next}`.
- **QuestManager autoload** (`scripts/core/quest_manager.gd`): linear chain, tracks `active_id` +
  `progress`, listens to **existing** signals only (`item_gathered`, `item_crafted` [new — see below],
  `stepping_stone_placed`, `item_used_on_object`, `day_phase_changed`, `player_entered_area` [new
  signal], `world_tree_planted`). Target filter resolves item aliases; non-item targets (phase/object
  ids) match raw. Q9 completion emits `all_quests_completed` → drops into the existing clear sequence.
  Emits `quest_started/progress/completed/advanced/all_quests_completed` for UI.
- **New plumbing:** `GameState.item_crafted(output, recipe)` fires on **every** fuse (Fusion.fuse),
  so repeat crafts count (recipe_discovered only fires once). `GameState.player_entered_area(id)` +
  `QuestAreaWatcher` node polls player proximity to the world-tree cells (Q6) — the tree is spawned
  procedurally so there's no authored Area2D to attach.
- **HUD** (`scripts/ui/quest_hud.gd`): top-left 「whisper」 + (cur/need) when countable; fade-swap +
  soft chime on advance; ✓ flash on completion; panel fades out when the line finishes.
- **Quest log** (`scripts/ui/quest_log.gd`, **J** key): centered window, done = ✓ dimmed,
  active = ▸ + progress, unreached = "…" (no spoilers). ESC/J close; pushes a modal lock.
- **Persistence:** `save.quests = {active_id, progress, done[]}`; NG+/new_game → `QuestManager.reset()`
  (fresh Q1 line).

### 3. Audio (procedural, no external assets) — DONE
- **Synth tool** `game/tools_gen_audio.py` (Python stdlib, fixed seed 20400703 → deterministic).
  Generates 22050Hz 16-bit mono WAVs into `assets/audio/`. Re-run: `python3 tools_gen_audio.py`.
- **AudioManager autoload** (`scripts/core/audio_manager.gd`): `play_sfx(name)` (8-voice pool);
  `crossfade_bgm` / `crossfade_bgm_for_phase` (day↔night) on `day_phase_changed`; ambience layer;
  runtime SFX/BGM buses; master/sfx/bgm volumes persisted to `user://audio.cfg` (pause-menu sliders).
  Loop streams get `loop_mode=FORWARD` set in code on load (no per-file .import edits). Headless-silent
  but never errors (every play guards a missing stream/player).
- **Wiring** (centralized on signals, robust): gather→pop, craft→success chime / new-recipe→discovery
  sting, stepping/placed→thud, water-on-bush→bloom, world-tree→fanfare, modal open/close→ui chime,
  quest advance→chime (from QuestHUD), footsteps (Player timer, 0.34s cadence, 2 alternating variants).

---

## Validation results

1. **Headless import: 0 script errors, scenes clean.** Audio silent headless, no errors.
2. **All 14 harnesses + new v0.4.0c harness PASS, 0 script errors:**
   m2, m2_integration, m3, m4, m5, m6a, m8, v021, v030, v031, v040, v040b, **v040c**, e2e, (+m7).
   - **`scenes/dev/v040c_test_harness.{gd,tscn}` — 45 asserts, all PASS.** Covers: placement data
     (25 placeable, functional=exactly D14/D22, class/blocks per spec, 6 newly-added, ghost validity
     per tile rule); placement world (node exists + group + StaticBody2D for blocks, decor no
     collision, recall returns item + frees, **save→load roundtrip** rebuilds the object); quest chain
     (drive **Q1→Q9** via signals, each advances in order, target filters reject wrong item, Q9 →
     all_quests_completed); audio (18 WAVs exist, AudioManager loaded streams, bgm loops forward,
     play_sfx + crossfade no-error incl. unknown-name no-op).
3. **e2e still PASS** (quests + audio overlay the full clear + NG+ flow with 0 interference).
4. **Version 0.4.0** unchanged (project.godot + export_presets.cfg all read 0.4.0).
5. **Exports rebuilt** (templates installed from `tools/export_templates.tpz` → 4.5.stable). Overwrote
   `export/{linux,windows,macos}/` and produced versioned zips. **Export-validation flow:** built a
   temp validation .pck (dev-scene exclude filter cleared, presets restored immediately after),
   ran the **exported linux binary** with `--main-pack`: **m7 + v040c both PASS, 0 script errors.**
   Temp pack removed; `export_presets.cfg` byte-identical to pre-flight backup.

---

## Audio files (assets/audio/, 22050Hz 16-bit mono, 5.2 MB total — under 15 MB)

| file | KB | file | KB |
|---|--:|---|--:|
| bgm_day.wav | 2067 | fuse_bubble.wav | 43 |
| bgm_night.wav | 2067 | fuse_discovery.wav | 35 |
| day_amb.wav | 345 | fuse_success.wav | 30 |
| night_amb.wav | 345 | quest_advance.wav | 26 |
| clear_fanfare.wav | 103 | fuse_fail.wav | 13 |
| bush_bloom.wav | 52 | place_thud.wav | 12 |
| ui_open.wav | 10 | ui_close.wav | 10 |
| gather_pop.wav | 8 | footstep_grass1/2.wav | 5 ea |
| ui_click.wav | 3.5 | | |

18 files, all with `.import`. bgm = ~48s Am-F-C-G pad + pentatonic music-box melody (night = darker,
octave-down). Ambience = 8s loops (crickets / soft wind). All loops fade-matched at edges.

## Export sizes (overwrite builds in export/{platform}/)

| platform | file | size |
|---|---|--:|
| linux | ProjectWhisper.arm64 + .pck | 63.4 MB + 1.61 MB |
| windows | ProjectWhisper.exe (embedded pck) | 98.2 MB |
| macos | ProjectWhisper.zip | 63.6 MB |

Versioned zips: `ProjectWhisper-linux-arm64-v0.4.0.zip` (27.1 MB), `-win64-v0.4.0.zip` (35.3 MB),
`-macos-v0.4.0.zip` (63.6 MB). PCK verified to contain quests.json, audio WAVs, audio_manager,
quest_manager.

## New/changed files

**New:** `scripts/core/quest_manager.gd`, `scripts/core/audio_manager.gd`, `scripts/ui/quest_hud.gd`,
`scripts/ui/quest_log.gd`, `scripts/world/quest_area_watcher.gd`, `data/quests.json`,
`tools_gen_audio.py`, `assets/audio/*.wav (+.import)`, `scenes/dev/v040c_test_harness.{gd,tscn}`.
(Inherited-but-uncommitted new: `scripts/world/placed_object.gd`, `placement_ghost.gd`.)

**Modified:** `data/items.json` (+6 placement records; file reflowed to 2-space), `project.godot`
(+QuestManager/AudioManager autoloads, +quest_log J input), `scenes/world/starting_grove.tscn`
(+QuestHUD/QuestLog/QuestAreaWatcher nodes), `scripts/core/game_state.gd` (+item_crafted/
player_entered_area signals), `scripts/core/fusion.gd` (emit item_crafted), `scripts/core/item_db.gd`
(placement API — inherited), `scripts/core/save_manager.gd` (placed_objects + quests persistence),
`scripts/world/interaction_controller.gd` (ghost/recall — inherited), `scripts/world/grove_session.gd`
(start_world_audio), `scripts/player/player.gd` (footstep timer), `scripts/ui/pause_menu.gd` (volume sliders).

## Known limitations / notes for next sprint
- PlacedObject world sprite = item icon @1.7x with drop-offset (spec-approved "icon-based acceptable").
  Dedicated world sprites for structures would read better later.
- Structure-completion "subtle glow" is via the reused GlowSprite on glow-flagged decor (D41/D48);
  a generic build-complete glow pulse for all structures is not yet added.
- Audio is intentionally simple synthesis (oscillator/noise/envelope). Fine for MVP mood; a later
  pass could layer reverb/richer timbres.
- BGM/ambience crossfade + volumes are unverified by ear (headless-silent env); logic is harness-tested.
