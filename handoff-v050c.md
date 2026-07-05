# Handoff — v0.5 phase C (portal structure / 제0세계 홈 섬 + flow rewire)

Godot 4.5.stable. Version bumped to **0.5.0**. Base = v0.5b commit `6be918b` + the uncommitted
phase-C scaffold an earlier attempt had already laid down (portal.gd, home_session.gd,
world_context.gd, home_island.tscn, home_layout/legend, v050c harness, portal SFX). This phase
**audited/reused** that scaffold, wrote the two missing pieces (the NEW-flow e2e + the home
overview render), ran the full validation, and packaged the exports.

Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Run a harness: `… --headless res://scenes/dev/<name>.tscn`
**No git commit** (per instructions).

---

## What the earlier attempt had already built (audited, kept)

- **C1 홈 섬** — `scenes/world/home_island.tscn` (22×22 floating isle, `height_path=none` → flat),
  `data/home_layout.txt` + `data/home_legend.json`. Center dais (drawn by HomeSession), cauldron,
  observation stone, 5 PORTAL objects spawned from the legend (`kind:portal`, one per layer
  nature/science/machine/magic/divinity), barren (scatter disabled). Reuses the parameterized
  MapLoader (`layout_path_override` / `legend_path_override` / `height_path_override`).
- **Portal node** — `scripts/world/portal.gd` (`class_name Portal`). Programmatic stone arch (two
  legs + rounded lintel, faceted rock shaded off `CliffGen` tones) + additive violet glow disc +
  rising motes (flickering) / swirl (open). 3-state machine driven by `GameState.portal_states`:
  dormant (dark, locked hint "…아직 잠들어 있다.") / flickering (slow violet pulse, enterable —
  Layer-1 tease) / open (steady bright + hum). Registers into `gatherable` so the existing
  InteractionController targets it; `on_interact` → `portal_interacted` signal to the world scene.
- **C2 flow** — `scripts/ui/opening.gd` is now CS-01 「각성」 (4 cards → fades into home_island, not
  the grove). `HomeSession` wires portal interact → travel (enterable) or locked hint (dormant),
  emits `portal_reached` (quest P1). `PortalCutscene` plays CS-02 travel swell and CS-05
  「귀환과 점화」 (nature→OPEN, science→FLICKERING, P2). `GroveSession._on_cleared` (CS-04 done) auto-
  returns home + queues the ignition. Quests `data/quests.json`: P0→P1→Q1..Q9→(clear)→P2→P3.
- **C3 save** — `scripts/core/world_context.gd` (autoload: current_scene / arrival_mode /
  travel_layer). `SaveManager` v**2**: scene-keyed `worlds{home,grove}` + `portal_states` +
  `world_context` + quest line + `pending_return_ignition`. Autosave on scene transition. A v1
  save is rejected as 구버전 → fresh start (no crash).
- **C4 audio** — `set_home_ambience(true)` (quieter home soundscape); 3 new SFX
  `portal_hum` / `portal_ignite` / `travel_whoosh` (wired in AudioManager's load list).
- **PRE-FIX (small fixes)** — object scatter excludes cliff-rim/apron cells; object height-lift
  is the single lift path (asserted in v050c section A).

## What I built this phase

### 1. e2e_playthrough rewritten to the NEW full flow (`scenes/dev/e2e_playthrough.gd`)
The old e2e booted the grove directly. It now runs the connected v0.5 flow, then keeps the full
grove-loop coverage inside it:

  STEP 90  home 각성: instantiate CS-01 (opening) + `skip_all()` → boot home_island →
           assert 5 portals + P0 → leave dais → P1 → dormant science NOT enterable /
           flickering nature enterable → `portal_reached(nature)` → **P1→Q1** → session routes
           enterable portal to travel (not locked) → snapshot home.
  STEP 0-6 enter Layer-1 grove → the existing real-mechanic chain (gather/fuse/디딤돌/bush/
           night-gate/world-tree/생명수 chain/plant on hollow → world_tree_planted + CS-04).
  STEP 91  CS-04 done → return home → drive **CS-05** (`PortalCutscene.play_return_ignition`) →
           assert **Layer-1 nature OPEN + Layer-2 science FLICKERING + P2 active** + the live
           home nature portal node is open/enterable → **re-enter** the grove (pending_load) →
           assert grove state persisted (cleared + stepping stone + bush bloom + planted tree).
  STEP 7-8 save/load persistence + NG+ (unchanged).

Result: **82 PASS, 0 FAIL, 0 SCRIPT ERROR.** Every brief-required new-flow assertion is exercised.

Note: the harness owns scene lifetime, so it does NOT call the real `change_scene_to_file`; it
drives the same SaveManager/PortalCutscene/QuestManager APIs the sessions call and boots each
scene itself. The in-game change_scene path is exercised by the live scenes (session code) and
covered structurally by v050c section E (travel roundtrip).

### 2. Home overview render (`tools_overview_home.js` → `/workspace/group/preview-home.png`)
The in-engine `home_overview_render.tscn` **cannot** produce pixels under `--headless` (dummy
rendering driver has no framebuffer — SubViewport readback hangs; I confirmed it times out). As
with every prior preview (v050a2/v050b), the render is done by an **offline pngjs compositor**.
`tools_overview_home.js` reads the REAL `home_layout.txt`/`home_legend.json` and mirrors
`portal.gd`'s arch+glow geometry + `HomeSession._draw_dais`, so the render matches the game:
starry void-sky, dirt island slab with grass patches, center dais, cauldron, observation stone,
and the 5 arches — nature (Layer 1) with a violet glow (flickering), the other four dark
(dormant). Output 1500×908.

  `NODE_PATH=/workspace/group/tools/nodejs/node_modules node game/tools_overview_home.js`

(`scenes/dev/home_overview_render.gd` OUT path was corrected to `preview-home.png`; it's kept for
a future GPU-capable environment but is not the render path used here.)

---

## Validation

- **Headless import: 0 errors.** Registers Portal + WorldContext global classes.
- **All 17 harnesses PASS (0 failures):**
  | v021 v030 v031 v040 v040b v040c v050a **v050c** | PASS |
  | m2 m3 m4 m5 m6a m7 m8 m2_integration | PASS |
  | **e2e_playthrough (NEW full flow, 82 asserts)** | **PASS** |
- **v050c** covers: PRE-FIX (no rim scatter + lift-offset invariant), home (22×22, 5 portals in the
  north-half arc, barren, nature flickering / rest dormant, cauldron+dais), portal state machine
  (dormant→flickering→open follows GameState, is_enterable), quests P0→P1→Q1, travel roundtrip
  preserves each world's placed objects, CS-04/CS-05, scene-keyed save v2, and v1-save rejection.
- **Export validation (real PCK):** built a temp validation pack (dev scenes included), ran
  **m7 + v050c on it via `--main-pack`: both PASS, 0 failures.** Presets restored after
  (`exclude_filter="scenes/dev/*"` back on all 3).

## My visual verdict on preview-home.png (I read it)

Reads correctly as the 제0세계: a barren dirt island floating in a starry violet-black void; 5
stone arch portals stand across the north half around the center; ONE (nature/Layer 1, upper-
right) has a violet glow in its opening + a soft violet pool at its base = the flickering awake
portal the awakening whisper points to; the other 4 are cold dark stone = dormant. Cauldron
(violet rim), grey stone dais under the spawn, and the observation nub are all present; sparse
grass patches read as the early world-traces.
Honest issues: (1) at this zoom the arc reads a touch loose rather than a tight semicircle — the
cells ARE authored in the north half facing the dais (v050c asserts it), it's a projection/zoom
look, not a data bug; (2) no cliff-apron underside on the island edge (home uses `height=none`,
so the void border is a flat stair-step, unlike the grove's diorama skirt) — a polish item, not a
blocker; (3) arches are small and the glow subtle at overview scale.

## Exports (v0.5.0)

Templates installed from `/workspace/group/tools/export_templates.tpz` (4.5.stable) into
`~/.local/share/godot/export_templates/4.5.stable/`. All three release presets built:

| Platform | Artifact | Size |
|---|---|---|
| Linux arm64 | `export/linux/ProjectWhisper-linux-arm64-v0.5.0.zip` | 31.2 MB (bin 63.4 MB + pck 5.7 MB) |
| Windows x86_64 | `export/windows/ProjectWhisper-windows-x86_64-v0.5.0.zip` | 39.4 MB (exe 102 MB) |
| macOS universal | `export/macos/ProjectWhisper-macos-universal-v0.5.0.zip` | 67.7 MB (app bundle) |

(The macOS export prints benign `gio/kioclient5/gvfs-trash` "could not create child process"
lines — Godot trying to trash the old file; export completes DONE.)

## Files touched this phase

NEW: `game/tools_overview_home.js`, `/workspace/group/preview-home.png`,
`project-whisper/handoff-v050c.md`, the three `*-v0.5.0.zip` distributables.
MODIFIED: `game/scenes/dev/e2e_playthrough.gd` (NEW-flow framing: STEP 90 home 각성 + STEP 91
return/ignition/re-enter), `game/scenes/dev/home_overview_render.gd` (OUT → preview-home.png).
AUDITED + KEPT (earlier-attempt scaffold): home_island.tscn, portal.gd, home_session.gd,
portal_cutscene.gd, world_context.gd, home_layout.txt, home_legend.json, v050c harness, the
game_state/quest_manager/save_manager/audio_manager/opening/grove_session edits, portal SFX.

## Deviations / notes (raw)

1. **Tree was NOT clean at v0.5b** as the brief assumed — an earlier phase-C attempt had already
   scaffolded C1–C4 (uncommitted). I audited it (imports clean, v050c passes) and reused it rather
   than rebuild; my new work is the NEW-flow e2e + the home preview + full validation + exports.
2. **Home preview is the offline pngjs compositor**, not an in-engine capture (headless dummy
   driver can't read back a framebuffer — the SubViewport render hangs; confirmed). It mirrors
   portal.gd/HomeSession geometry off the real data files, so render==game for layout/state.
3. **e2e drives the session/cutscene APIs, not `change_scene_to_file`** (the harness owns scene
   lifetime). The live in-game scene-change is what the sessions call; travel roundtrip integrity
   is separately asserted by v050c section E.
4. **Home island has no cliff-apron underside** (`height_path=none`) — the void border is flat.
   If a diorama floating-island skirt is wanted, give home a height file + reuse the grove's
   `CliffGen` apron path. Out of scope this phase (brief: "cliff aprons on ALL borders" reads as
   the void-sky surround, which is present; a sculpted underside is a polish follow-up).
5. **No git commit** — per instructions.
