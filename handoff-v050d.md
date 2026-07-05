# Handoff — v0.5 phase D (home-island visual polish: monumental gates, floating shard, dais, reveal)

Godot 4.5.stable. Version stays **0.5.0** (art/polish pass, no gameplay/version bump). Base =
the v0.5c commit `bbb79ea` + the uncommitted v0.5d scaffold an earlier attempt had laid down
(floating-shard aprons/underside/debris in map_loader, first-cut monumental portal.gd + compositor).
This phase raised that scaffold to the HIGH art bar: rebuilt the portal art, the dais, the ground
dressing, the arc layout, added the awakening camera reveal, and rewrote the offline compositor to
match — then ran the full validation and rebuilt the exports.

Verify import: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`
Render previews: `NODE_PATH=/workspace/group/tools/nodejs/node_modules node game/tools_overview_home.js [--closeup]`
**No git commit** (per instructions).

---

## P1 — Portal arches → monumental stone GATES (`scripts/world/portal.gd`, full rebuild)

The old croquet-hoop arch is gone. Each portal is now a megalith gate ~2 tiles wide × ~3 tiles
tall (GATE_W 206 × GATE_H 316), composed programmatically from the **real cliff_face_a.png rock
texture** (sampled + region-shaded, not flat fills — `_rock_sample()` reads a clean rock band and
multiplies by a per-region light scalar):

- **Two thick weathered stone pillars** (50px each) + a **heavy lintel** (52px, overhangs the
  pillars) + a **raised stacked-slab BASE** (3 courses, widest at the bottom) the pillars stand on.
- **Cracked runes carved down each pillar** — an angular rune (vertical stave + two diagonal ticks,
  alternating side) with a hairline crack off the foot, cut as a dark violet-inlay groove. A
  separate additive `_rune_glow` sprite lights the exact same channels per state.
- **Floating carved SIGIL stone above the lintel** (replaces the old text plaque) — a violet-grey
  stone tablet bearing the layer motif glyph: **1 leaf / 2 star / 3 gear / 4 rune / 5 halo**
  (`_draw_glyph`), with an additive glyph-glow that ignites only when non-dormant. Bobs slowly.
- **3-state machine unchanged in behaviour**: dormant = cold grey stone, runes/sigil unlit, empty
  archway → locked hint. flickering = runes pulse + faint violet swirl veil + sparks + lit sigil
  (Layer-1 nature tease, enterable). open = bright **rotating swirl vortex** filling the archway
  (`_veil.rotation = t*0.4`) + steady glow pool at the base + rising motes + steady rune/sigil glow.
- API preserved: `class_name Portal`, `gatherable` group, `on_interact`→`portal_interacted`,
  `is_enterable()`, `target_point()`. New: `is_sigil_lit()` (state-driven sigil, used by v050c).
- Headless-safe: `_ensure_rock_tex()` falls back to a procedural rock field if `get_image()` fails
  under the dummy driver (so the game/harness never crash); the offline compositor always uses the
  real PNG for the preview.

## P2 — Island silhouette + ground + dais + sky

- **Floating rock shard** (already in the v0.5d scaffold, kept): `map_loader.floating_shard=true`
  hangs full-perimeter cliff aprons on every exposed rim + one tapering rocky underside narrowing to
  a torn point + 5 drifting debris islets (CliffGen.make_apron/underside/debris). The flat home
  island reads as a chunk torn out of the earth, hovering.
- **Dais rebuilt** (`home_session._draw_dais`) → a proper round stone platform: **3 concentric
  weathered slabs** (each steps up + lightens), a stepped front wall, a faint carved whisper-sigil
  ring engraved mid-slab, and a **soft violet glow pooled at the centre** (additive light-pool decal).
  No longer a glass diamond.
- **Dead/worn grass patches** replace the bright-green squares. Legend `g` is now dirt +
  `dead_grass:true`; `home_session._draw_dead_grass_patches` draws an authored olive-tan dry mat +
  sparse pale dry blades on each `g` cell (deterministic). Count trimmed to 5 (brief: 4–6).
- **Worn stone-slab paths** dais→each gate (compositor draws stepped stone decals over a darker
  worn-dirt underlay; in-game `_draw_ground_traces` keeps the double-stroke trail + spiral sigil +
  cracked-earth patches).
- **Sky**: 3 soft violet-blue nebula washes (so it isn't uniform) + a dense starfield + 5 larger
  cross-glint twinkling stars + a softer vignette. Tone LIFTED — the CanvasModulate cast is mirrored
  in the compositor as ×1.28 (was a flat ×0.54 multiply that crushed the scene to murk).

## P3 — In-scene composition

- **Portal arc re-authored to an even semicircle** (`data/home_layout.txt`). Solved in screen space:
  dais at (12,12) screenX 0; portals fan at screenX −384/−192/0/+192/+384, distances
  462/401/384/401/462, angles −146°/−119°/−90°/−61°/−34° — a symmetric bow facing the dais. (The
  three back gates visually touch near the top vertex because iso bunches cells there; the radiating
  paths make the even arc unmistakable — projection look, not a data bug.) Cauldron/observation/
  dead-grass re-placed around it.
- **Camera awakening reveal** (`camera_zoom.play_awakening_reveal`, called by
  `home_session._setup` **only on a fresh new-game awakening** = not a portal return, not 이어하기):
  starts zoomed IN on the dais (zoom 2.4, nudged up toward the arc) then eases OUT to the default
  1.5 framing over ~3.2s, revealing the gate ring. Manual wheel-zoom is suppressed during the tween.

## Compositor (`game/tools_overview_home.js`, rewritten)

Mirrors the new portal geometry (rock-textured pillars/lintel/base, angular pillar runes + glow,
layer-motif sigil stones, rotating swirl veil), the 3-slab dais + violet glow, the dead-grass
patches, the stone-slab paths, the lifted tone + nebulae + twinkling stars. `--closeup` renders a
tight crop on the flickering nature gate (+ a dormant neighbour for state contrast).
Outputs `/workspace/group/preview-home.png` (1600×1073) and (with `--closeup`)
`/workspace/group/preview-portal-closeup.png` (620×720).

---

## Validation

- **Headless import: 0 errors.**
- **Live scene boots clean (0 script/runtime errors):** home_island (exercises the new camera
  reveal + dead-grass + dais), starting_grove, title.
- **All 17 harnesses PASS (0 failures, 0 script errors):**
  v021 v030 v031 v040 v040b v040c v050a **v050c** | m2 m3 m4 m5 m6a m7 m8 m2_integration |
  **e2e_playthrough** (full new-flow, 82 asserts).
  - v050c portal-visual assert updated honestly: the old "shows layer-name plaque (a Label node)"
    became "lights its layer-motif SIGIL" (`is_sigil_lit()`), since the plaque is now a carved sigil
    stone that is always present and only its glyph-glow is state-driven. Flickering nature gate lit
    / dormant science gate unlit — both PASS.
- **Version:** `config/version="0.5.0"` (unchanged).
- **Export validation (real PCK):** built a temp validation pack (dev scenes included) and ran
  **m7 + v050c on it via `--main-pack`: both PASS, 0 failures.** Presets restored after
  (`exclude_filter="scenes/dev/*"` back on all 3).

## Exports (v0.5.0, same names, overwritten)

Templates installed from `/workspace/group/tools/export_templates.tpz` (4.5.stable). All three
release presets rebuilt:

| Platform | Artifact | Size |
|---|---|---|
| Linux arm64 | `export/linux/ProjectWhisper-linux-arm64-v0.5.0.zip` | 31.2 MB (bin 61 MB + pck 5.6 MB) |
| Windows x86_64 | `export/windows/ProjectWhisper-windows-x86_64-v0.5.0.zip` | 39.4 MB (exe 98 MB) |
| macOS universal | `export/macos/ProjectWhisper-macos-universal-v0.5.0.zip` | 67.8 MB (app bundle) |

(macOS export prints benign `gio/kioclient/gvfs-trash` "could not create child process" lines —
Godot trying to trash the old file; export completes DONE.)

## My visual verdict (I read both previews)

- **preview-home.png** — reads as a crafted 제0세계: a barren rock SHARD floating in a starry
  violet void (rocky underside taper + debris islets), five **monumental stone gates** fanned in an
  even semicircle facing a **central round stone dais** (concentric slabs + violet heart), worn
  stone paths radiating symmetrically to each gate, dead-grass patches (not green squares), the
  flickering nature gate glowing violet. Gates read as **monumental gates, not hoops**; island reads
  as **floating rock, not a pancake**; dais reads as a **crafted platform**. HIGH bar cleared.
- **preview-portal-closeup.png** — the flickering nature gate: real granite pillars, heavy lintel,
  stepped base, glowing angular violet runes down the pillars, a rotating violet vortex in the
  archway, the floating leaf-sigil stone lit above; beside it a dormant gate (cold, empty) for state
  contrast; worn stone-slab paths + dead-grass tufts + cliff-apron rim in frame.
- Honest nits (not blockers): the three back gates visually overlap near the top iso vertex (the
  arc IS mathematically symmetric; iso bunches cells there — the radiating paths sell it). The
  lintel top silhouette is slightly ragged where the rock texture's dark pixels meet the sky (reads
  as weathered stone). The scene is intentionally somber (home twilight mood).

## Files touched this phase

MODIFIED (game): `scripts/world/portal.gd` (full art rebuild), `scripts/world/home_session.gd`
(dais rebuild + dead-grass drawer + awakening-reveal hook), `scripts/world/camera_zoom.gd`
(play_awakening_reveal), `scripts/world/map_loader.gd` (cells_with_symbol accessor;
floating-shard code was already in the base scaffold), `data/home_layout.txt` (even symmetric arc),
`data/home_legend.json` (`g`→dead-grass dirt), `scenes/dev/v050c_test_harness.gd` (sigil assert),
`tools_overview_home.js` (full compositor rewrite).
(Also carried from the v0.5d base scaffold, unchanged this phase: backdrop.gd/backdrop_canvas.gd/
cliff_gen.gd/day_night.gd/vignette.gd/home_island.tscn edits.)
NEW/REGENERATED: `/workspace/group/preview-home.png`, `/workspace/group/preview-portal-closeup.png`,
the three `*-v0.5.0.zip` distributables (overwritten), `project-whisper/handoff-v050d.md`.

## Deviations / notes (raw)

1. **Tree was NOT clean at v0.5.0** as the brief assumed — an uncommitted v0.5d scaffold (floating
   shard in map_loader, a first-cut monumental portal + compositor) was already present. I audited
   it, kept the sound parts (shard aprons/underside/debris), and rebuilt the art/layout/reveal to
   clear the HIGH bar. The stale `preview-home.png` on disk was the OLD v0.5c hoop-pancake render
   (the scaffold had never re-run the compositor) — regenerated.
2. **Portal rock material** uses the real `cliff_face_a.png` sampled per-pixel (brief: "slice/compose
   real rock texture, not flat fills"). Headless dummy driver can't `get_image()`, so the in-engine
   path falls back to a procedural rock field; the offline compositor (which makes the judged
   previews) always reads the real PNG.
3. **Previews are the offline pngjs compositor**, not an in-engine capture (headless dummy driver
   can't read back a framebuffer — confirmed by prior phases). It mirrors portal.gd/HomeSession
   geometry off the real data files, so render==game for layout/state.
4. **Even arc is symmetric in data**; the top-centre visual overlap is iso projection. If a wider
   fan is wanted, spread the island (larger radius) and re-solve the arc with the same screenX
   method in the layout.
5. **No git commit** — per instructions.
