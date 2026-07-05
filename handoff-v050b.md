# Handoff — v0.5 phase B (object art + round-hood character + BGM finalize + quest affordance)

Godot 4.5.stable. Base = v0.5a commit **b5752d6** (clean tree). Version stays **0.4.0** (no bump).
Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Run a harness: `… --headless res://scenes/dev/<name>.tscn`
**No version bump, no export rebuild, no git commit** (per instructions — phase B only).

---

## B1 — Object art pass (owner: "cliff로 들어가있는 이런거 좀 어색하지 않니?")

New tool: **`game/tools_gen_objart_v050b.js`** (node + pngjs, `NODE_PATH=/workspace/group/tools/nodejs/node_modules`).
Draws painterly ground objects to match the CC0 terrain palette, every ground object with a
**baked soft AO ellipse shadow** at its base and guaranteed-clean alpha:

- **rock.png** — was tall cliff-pillar fragments from `rock_cliffs.png` (owner's complaint). Now a
  small ROUNDED boulder cluster (3 faceted lobes, lit upper-right) with **grass tufts at its base**
  + AO shadow. Reads as a natural boulder, not a severed cliff chunk.
- **stone.png** — small low pebble pile (3 flat lobes, no grass on top) + AO. (Fixed the old dark
  square/muddy look.)
- **grass_tuft.png** — clean blade clump. **bush_green.png / bush_bloom.png** — leafy rounded shrubs
  (bloom adds blossoms). All AO-seated.
- **flower / flower_violet / flower_pink** — clustered 5-petal blossoms on stems with a grass base +
  AO. **No more lollipops.**
- **cauldron.png / cauldron_bubble.png** — repainted rounded pot, legs, AO seat, and the **violet
  glow rim** kept (bubble variant adds rising bubbles).
- **rest_stump.png** — repainted mossy stump with ring-cut top + moss skirt + AO.

**Alpha-bug sweep (the "black-box"/dark-blob artifact):** the CC0 tree/bush slices
(`tree_a/b/c`, `young_tree`, `world_tree`, `bush_dry`) each carried a large semi-transparent
**near-black cast shadow baked into the sprite** (an offset iso-render shadow). On grass it read as
a dirty dark blob. `tools_gen_objart_v050b.js` **strips** those pixels (near-black AND not fully
opaque — the opaque trunk/branches are kept) and bakes ONE clean centred AO ellipse under each trunk.
Idempotent: the pristine CC0 slices are cached in `game/.artcache/*.png.orig` (has a `.gdignore`, so
Godot never scans it) and restored before each strip, so re-running never eats its own AO.

- **Trees**: all gatherable + scatter trees use the new CC0 art consistently (no old flat pines).
  Deshadow + AO seat applied uniformly.
- **Dry bush**: reads as dead brown wood against the new grass (v040b dominant-colour assert still
  green-negative: rgb 48,40,25).

## B2 — Character: round-hood redraw (owner: "머리만 둥글둥글하게 하면 되겠네")

New standalone tool: **`game/tools_gen_char_v050b.js`** — regenerates ONLY the character sheet
(288×384, 96×96 frames, same 4-dir × 3-frame layout) + portrait (192×192). It does **not** touch
tiles/objects (unlike the legacy `tools_gen_art.js`, which would clobber the CC0 tiles + the v050b
object art — do NOT run that tool wholesale).

- Kept: 방랑자/wanderer concept, black cloak + violet trim/sigil, staff w/ floating violet orb,
  cream face + glowing violet eyes.
- Changed (v050b): hood is a **soft ROUND dome** (native radius 7.2 → **8.1**, larger head ratio for
  charm; rounder lower-cowl merge; smoother quadratic shoulder taper on the cloak silhouette). No
  angular crown, no back-point. Portrait rebaked to match (bigger round dome bust).
- Sheet dimensions unchanged → the existing `data/player_frames.tres` region slicing still works.
- Review strip (idle, 4 dirs, 4× upscale, on grass): **`/workspace/group/char-v050b-review.png`**.
- **Scene scale note:** the brief said "keep 1.25", but the live scene's Player uses
  `scale = Vector2(1.15, 1.15)` (starting_grove.tscn). I left it at 1.15 (not touched — changing it
  wasn't the ask and no 1.25 exists in the scene). Flag if the owner truly wants 1.25.

## B3 — BGM/ambience finalize + fix v040c

VERIFIED the interrupted agent's CC0 music deliverable and finished it:
- CC0 loops present + play: `assets/audio/bgm_day.ogg` (day) + `bgm_night.ogg` (night). AudioManager
  already prefers `.ogg` over `.wav`, so the game plays the CC0 music, not the synth.
- **Set `.ogg.import` `loop=true`** on both BGM oggs (was `false`) so they loop via the importer
  (AudioManager also sets `stream.loop = true` defensively).
- **DELETED the old synth WAVs from the build**: `bgm_day.wav`, `bgm_night.wav`, `day_amb.wav`,
  `night_amb.wav` (+ their `.import`). The CC0 BGM carries the day/night soundscape; the redundant
  synth ambience layer is retired. AudioManager updated: `LOOP_NAMES` + stream load list drop the
  ambience names; `_update_ambience` is now a graceful no-op (guarded, no warnings); stale header
  comment rewritten.
- **Volume balance**: BGM default lowered `0.7 → 0.4` (≈ −8 dB) so music sits under the SFX. SFX kept.
- **CREATED `CREDITS.md`** (project root) — all CC0 sources listed (music: isaiah658 day /
  congusbongus night; tiles/trees: rubberduck grassland packs; SFX + char + repaints in-house).
- **Fixed the failing v040c assert `bgm_day loops forward`**: it loaded `bgm_day.wav` and checked
  `AudioStreamWAV.LOOP_FORWARD` (the WAV's import had `loop_mode=0`). Rewrote `_test_audio` honestly
  to the new reality: 14 SFX WAVs exist; `bgm_day/night.ogg` exist (CC0); old synth `bgm_day.wav` +
  `day_amb.wav` are deleted; both BGM oggs loaded; **`bgm_day` loads as `AudioStreamOggVorbis` with
  `loop == true`**. v040c now PASSES (0 failures).

## B4 — Watering/gate affordance (owner: "물을 줘야 된다는 느낌이 전혀 안 듦")

New generic node: **`game/scripts/world/quest_marker.gd`** (`class_name QuestMarker`). A small
bobbing icon + soft periodic pulse ring, visible ONLY while its `quest_id` is the active whisper
(polls `QuestManager.active_id`); self-frees once that quest has been completed. Variants:
`"wisp"` (violet whisper, additive-tinted) and `"drop"` (Q4 water-drop, uses `water_drop_cue.png`).

- **Q4 (물→마른덤불)**: `bush_dry.gd` now spawns a QuestMarker(`Q4`,`drop`) — bobbing 💧 + pulse ring
  above the bush during Q4 (replaces the old ad-hoc `_drop` sprite). Added a **warm hover glow**:
  `bush_dry.set_water_hover(true/false)` fades a warm additive glow when the player hovers with water
  (I7) held. The InteractionController drives it (`_update_water_hover`) and the E-prompt now reads
  **"E 물 주기"** (not generic "E 사용") when I7 is held on the dry bush.
- **Q6 (world tree / night path)**: `map_loader._spawn_object` attaches a QuestMarker(`Q6`,`wisp`)
  to the world tree via the new `_add_quest_marker()` helper — a violet wisp bobs at the world-tree
  entrance while Q6 is active.

---

## Validation

**Headless import: 0 errors.** Live grove scene runs clean (QuestMarkers instantiate, no runtime errors).

Harness suite (`--headless res://scenes/dev/<name>.tscn`) — **16/16 PASS, 0 failures**:

| Harness | Result |
|---|---|
| v021 v030 v031 v040 v040b v040c v050a | **PASS** |
| m2 m3 m4 m5 m6a m7 m8 m2_integration | **PASS** |
| e2e_playthrough (full G1–G4 clear + NG+) | **PASS** |
| **v040c** (previously the lone pre-existing FAIL) | **PASS (fixed this phase)** |

Harnesses updated honestly this phase:
- **v040c `_test_audio`** — rewritten to the OGG BGM + deleted synth reality (see B3).
- **v040b `_test_bush_node`** — the old `_drop` Sprite2D assert replaced with asserts on the new
  Q4 QuestMarker (`quest_id=="Q4"`, `variant=="drop"`) + the `set_water_hover` warm-glow node. Bush
  art asserts (108×128 withered / green bloom) still pass with the new art.

## Renders + visual verdict (I read them)

Regenerated via `game/tools_overview_v050a2.js` (now outputs the v050b names):
- **`/workspace/group/preview-v050b.png`** (1600×986) + **`preview-v050b-closeup.png`** (4736×2628).
- **`/workspace/group/char-v050b-review.png`** — round-hood review strip (SE/SW/NE/NW idle, 4×).
- Object contact sheet: `/workspace/group/objart_v050b_contact.png`.

**My visual verdict (read the renders):**
- **Rocks look like natural rounded boulders** with grass tufts + soft AO — NOT severed cliff chunks.
- **Flowers are clustered blossoms** on grass — NOT lollipops.
- **No black-box / dark-blob sprites** anywhere: the trees + bushes are cleanly deshadowed and sit on
  the grass with subtle AO. Cauldron reads with its violet potion rim; stump reads as mossy wood.
- Elevation terrain (plateau + continuous rock cliff walls + ramp + animated water) from phase A2 is
  intact and unaffected.
- Character: the hood is now a big soft round dome with charm; black cloak + violet sigil + orb staff;
  front views show glowing eyes, back views the hood interior + spine — smooth silhouette all 4 dirs.

---

## Files touched (git-relative to repo root)

NEW: `CREDITS.md`, `game/tools_gen_objart_v050b.js`, `game/tools_gen_char_v050b.js`,
`game/scripts/world/quest_marker.gd`, `game/.artcache/*.png.orig` (+`.gdignore`),
`/workspace/group/preview-v050b.png`, `preview-v050b-closeup.png`, `char-v050b-review.png`,
`objart_v050b_contact.png`, `handoff-v050b.md`.

MODIFIED:
- Object art PNGs: `rock stone grass_tuft bush_green bush_bloom flower flower_violet flower_pink
  cauldron cauldron_bubble rest_stump tree_a tree_b tree_c young_tree world_tree bush_dry` (.png).
- Character: `character_sheet.png`, `character_portrait.png`.
- Audio: `assets/audio/bgm_day.ogg.import`, `bgm_night.ogg.import` (loop=true);
  `scripts/core/audio_manager.gd`.
- Deleted: `assets/audio/{bgm_day,bgm_night,day_amb,night_amb}.wav(.import)`.
- Affordance: `scripts/world/bush_dry.gd`, `scripts/world/interaction_controller.gd`,
  `scripts/world/map_loader.gd`.
- Harnesses: `scenes/dev/v040c_test_harness.gd`, `scenes/dev/v040b_test_harness.gd`.
- Render tool: `game/tools_overview_v050a2.js` (v050b output names).

## Deviations / notes (raw)
1. **Object art is programmatic repaint, not raw sheet slices.** The sheet's small pieces are upright
   stone cairns (still menhir-ish), not the rounded low boulders the owner asked for. Drawing them to
   the CC0 palette (brief explicitly allows repaint-to-match) gives full control over roundness, clean
   alpha, and the AO seat, and directly kills the "cliff fragment" + "black box" complaints. The CC0
   rock TONE is sampled so they read as the same stone family as the cliffs. Trees/world-tree/dry-bush
   stay the CC0 art (only deshadowed + AO-seated).
2. **`tools_gen_art.js` is a landmine** — it's the OLD full procedural-art generator and would
   overwrite the CC0 tiles + the v050b object art. The char redraw was extracted into the standalone
   `tools_gen_char_v050b.js` for exactly this reason. Don't run `tools_gen_art.js` wholesale.
3. **Ambience layer retired**, not just muted — the CC0 day/night music is itself ambient, so the
   separate synth `day_amb/night_amb` were redundant. `_update_ambience` stays as a guarded no-op.
4. **Scene scale 1.15, not 1.25** — see B2 note; left as-is (no 1.25 in the scene).
5. **No version bump / export / commit** — per instructions.
