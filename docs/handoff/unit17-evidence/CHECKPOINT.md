# FINAL17 — bounded MAP1 cleanup complete for parent verification; STOP

Owner boundary KOAL1549791266211106898 controls. This was ONE manually authorized cleanup, not automatic full-refactor continuation. Do not start a next increment, re-enable auto-resume, unpause schedules or publish. Parent alone verifies this checkpoint and closes the week. Whole project, final art and human/device QA are NOT complete.

Final audit: `final-audit.json`, observed 2026-09-17T01:11:17.974353+09:00. Worktree `/Users/choikoal/.hermes/state/whisper-world-objects`. Git HEAD stayed `c25cf55f037e3acd2d708bd036e5c3165ea45906`; no commit/reset/push/merge/deploy. Original dirty game trees and binary diffs preserved in `entry-source/`.

## Production change, exactly two source files

1. `game/scripts/foundation/internal_trench.gd` NEW: MAP1-v2-only recessed rock/earth cut. Classifies the 43 authored V cells sandwiched between real TileSet side-neighbor banks in rows 8/14; excludes exterior void and runtime hollows. Uses four actual neighbor sides, bank endpoint heights, inset recessed floor, opposite/back banks, end returns and explicit mixed-height corner returns. Reuses existing rock material. No walkable-looking grass cap, 230px ridge restoration, global T0 recolor/alpha edit, flattened height or changed V occupancy.
2. `game/scripts/foundation/foundation_map.gd`: v2-only trench ownership/rebuild; prevents exterior 176px skirts from owning internal cuts. Re-presents only adjoining existing low LAND tops so the retained full-rectangle T0 cannot cut their corners away. Low-bank owners mirror live source/atlas/erase changes during `_process`, allocating a new texture only on a source/atlas change. Rebuild clears old owners. A real gather/save/load regression was found and fixed before final testing.

Legacy rendering path remains unchanged. Logical height/traversal functions, authored map/height/legend, all assets, gates/IDs, physics/collision/path/save logic, unit16 harvesting, pure Kana module, Player/Touch/Interaction/Fusion sources were not modified. Final audit verifies no content delta in assets/data or unit16 gameplay/core/player/world sources. Integration/Fusion worktree game: all 2,159 files unchanged. World: entry 2,539 files, final 2,553; additional files are the scoped harnesses, new terrain module and engine-generated .uid metadata. Full manifest includes all non-.godot game files; receipt content binding excludes generated .uid/.import/.pyc when older receipts precede editor import.

### Exact SHA-256

`foundation_map.gd` BEFORE:
`0824d8a161ed73fa49f76a13585b451357e803795f3ccc11d2751948b74668ec`

`foundation_map.gd` AFTER:
`7b7ea9713102f05816b7bc2df8a1cdd3d6c99f32c568522630d00196a76db677`

`internal_trench.gd` AFTER (absent before):
`387b82393359018cf697a03ebf35b740a09afdd956d951f6560aa8f7ec07df30`

`source-hash-manifest.json`:
`1f6119becf6504f313d5550d7c9c6338710f747ebe3f3889050207b7698719a6`

Reviewable delta from actual dirty entry, not Git HEAD: `production-from-entry.patch`.

## RED → GREEN, retained failures

- `terrain-red`: 33 PASS, 32 FAIL, 0 script/engine ERROR. Actual raw-T0 center detector failed across both bands and mouths. `terrain-green1` was a type-inference compilation failure, NOT a valid pass. `terrain-green2` passed only center pixels and was visually REJECTED by Astra; not the final fix.
- `bank-red`: six low-bank raster failures reproduced the retained T0 rectangle covering adjacent low LAND. Restoring those actual land tops fixed these, but Astra found small mixed-height join triangles. `bank-green` is intermediate, not final acceptance.
- `corners-red`: seven full-cut raster failures. At a shared corner, low and high bank owners project the same logical endpoint to different heights; merely meeting an inset floor left a triangle. Explicit vertical corner-return triangles fixed it. No generic black paint-over.
- First all-cell accounting found expected43/actual41 (`pixels-final`, `pixels-final2`): the rightmost two cells had not been enumerated. Extended the right-mouth column window; did not weaken the detector. Final `pixels-final3`: all43, 140 PASS, 0 FAIL, 0 SCRIPT/engine ERROR.
- Independent review found stale low-bank textures after gathering or save restore. `mutation-red`: 5 PASS/3 FAIL, actual public ground gather + isolated disk reload + explicit erase. A first `TileMapLayer.changed` approach remained RED (`mutation-green`); that signal did not observe these cell mutations here. Final owner-local source/atlas check: `mutation-green2` 8 PASS/0 FAIL, no errors. Includes actual hollow display, loaded save overlay, erase and restore.
- `movement1` was an invalid fixture: it paused time, which correctly disables input, and used a lifted NightGate art root as a logical cell. Corrected only the harness. `movement2`/`movement-timing` physically traversed routes but had an overstrict gate-path admission expectation and cross-frame contact detector. Preserved timing logs show coroutine-resumed physics state differed while same-frame post-draw sprite/root error was exactly0. Final oracle checks every presented frame within `frame_post_draw`, never calls global unlock, and retains actual passage/blocking/V assertions. Existing closed-gate path admission is a disclosed limitation, not newly fixed behavior.
- `finalize_audit.py` initially compared manifests with inconsistent generated Python-cache inclusion; corrected the audit's declared generated-file treatment. This was an audit-normalization failure, not a gameplay pass/failure.

Every attempt remains in `final-audit.json:attempts_including_failed` and its original log. Final totals below exclude intermediate attempts.

## Final executed scope — exact 10 scenes, 1,086 assertions

All final receipts are bound to unchanged final content-source hashes and explicit finish markers. No full65 or other-map campaign.

| Receipt | Assertions | Failed | SCRIPT ERROR | engine ERROR |
|---|---:|---:|---:|---:|
| pixels-final3 | 140 | 0 | 0 | 0 |
| mutation-green2 | 8 | 0 | 0 | 0 |
| movement-final-source | 211 | 0 | 0 | 0 |
| ramp-surface-final, v2 | 172 | 0 | 0 | 0 |
| harvest-focused / reward | 13 | 0 | 0 | 0 |
| harvest-focused / integration | 53 | 0 | 0 | 0 |
| harvest-focused / save | 16 | 0 | 0 | 0 |
| harvest-focused / terrain-object physics | 67 | 0 | 0 | 0 |
| normal-final-v2 | 199 | 0 | 0 | 26 inherited Fusion lambda |
| normal-final-legacy | 207 | 0 | 0 | 26 inherited Fusion lambda |

Final totals: 52 engine ERROR lines, all `Lambda capture at index 0 was freed. Passed "null" instead.`; 4 separate `ObjectDB instances leaked at exit` WARNING lines. NOT a clean-engine pass. No resource-still-in-use ERROR in these final receipts; such errors in intermediate attempts remain disclosed in the audit. No unrelated Lambda rewrite was attempted.

### Actual raster and movement outcomes

- Entire authored internal-cut set: 43/43 cells, 10,313 sampled full-cut pixels, raw-void hits0. Low-bank samples2,013, raw-void hits0. Core/low-bank/full-cut tests are raster evidence; node presence alone was not used as visible acceptance.
- Focused physical fixture: 34 continuous movement cases, 17 keyboard +17 public tap-path requests, 20 successful passages +14 expected blocks. Both NightGates closed/open, both directions when open; bush closed, actual water-tap open, both directions; four V barrier approaches in both modes; first/last ramp-end crossings in both modes/directions.
- 1,548 recorded physics samples, 1,642 same-frame post-draw contact samples, authored-V entries0, projection errors0. Each route has exact start/target/end/trail in `movement-final-source/movement-receipt.json`. No teleport during a route. Initial positions, phase time and bush water are explicit fixture injection, NOT normal-input evidence.
- Repeated elevation rebuild: one trench set, stable ledge count. Actual isolated save/re-entry/resave retains logical position, object/placement/hollow/stepping/gate/layout data. No duplicate faces after rebuild/re-entry.
- v2 normal: 277.31 seconds,199 assertions, title→new game→Home→L1 actual harvest/Fusion/nest/G1/ramp/G2→rest/natural night/G3/I9/D22→CS04/05/Home→saved revisit. 9,514 observed presented frames, 2,378 recorded motion samples, V hits0/projection errors0.
- Default legacy normal: 294.15 seconds,207 assertions, same actual loop and saved revisit AFTER the final unit16 held-ground cancellation fix and current production changes. 10,564 observed presented frames, 2,641 recorded motion samples, V hits0/projection errors0. Replaces the pending finallegacy validation; historical unit16 legacy204 was not reused as final evidence.
- Normal capture subclass inherits `harvest_progression_capture.gd` unchanged, adds only passive observations/PNG receipts. Its three extra assertions explain 199 vs196 and207 vs204. No normal-route item/time/player/gate/quest/clear injection. Explicit v2 new-run selection, public touch movement/callbacks, direct Opening skip handler and Fusion UI callbacks remain disclosed automation seams. Normal route did not pass ramp endpoint16; that endpoint is covered by the separate actual-input fixture, not mislabeled as normal journey.

## Before/after and Astra assessment

Normal-root diagnostic BEFORE: `terrain-red/{bands,left-mouth,right-mouth}.png`.
Matched AFTER: `pixels-final3/{bands,left-mouth,right-mouth}.png`.
Comparisons: `pixels-final3-{bands,left-mouth,right-mouth}-before-after.png`.
Exact image SHA-256, source paths: `pixels-final3-before-after-receipts.json`.
All are 1600×900 root frames at production zoom1, same camera/player frames and day tint. They explicitly inject fresh v2/scene/player positions/day. See `PROVENANCE-ERRATA.md` for early inherited generic metadata that was inaccurate; no BEFORE is claimed as normal input.

Separate normal-input captures: `normal-final-v2/normal-motion-bank-row-{7,8,9,13,14,15}.png`, `normal-motion-ramp-end-22.png`, and the route/revisit PNGs. Full manifests and passive traces persisted and read back.

Vision routing was read-only verified as `auxiliary.vision.provider=openai-codex`, `model=gpt-6-astra-900k`; the main worker is Astra. The tool does not expose an independent per-call resolved-model ID, so no stronger per-call provenance is claimed. No Sol art verdict used.

Astra final narrow judgments:
- Latest same-camera left-mouth comparison: PASS. Large gouge and repeated raw triangles replaced with coherent material faces; shared-end returns closed, external void retained.
- Latest both-band comparison: bounded MAP1 visible-fix approval. Distinct recessed nonwalkable cut, no grass-cap disguise, no obvious gate-join raw-void leak. Not whole-art approval.
- Actual normal B-gate crossing: visible feet, no observed burial or gap, narrow acceptance.
- Actual normal nighttime N crossing: no obvious deep burial/large missing terrain; precise foot/bank readability remains uncertain because of low contrast. This is a disclosed visual limitation, not erased by test counts.
- Actual normal ramp22: feet visible; retained dark triangle reads as an attached side face, no distinct opening. Actual fixture ramp16: feet visible, but a still frame cannot decisively resolve the dark end-face depth. All7 live v2 ramps passed the independent projected-surface raster/ownership/ordering/end-band oracle (172 assertions), and both endpoint routes physically passed. The dark side silhouette is not redesigned or advertised as final art.

## Independent review

`INDEPENDENT-REVIEW.md` records all scoped verdicts. Held-ground final Touch production AND complete test body reviewed PASS (code-only), targeted runtime53 confirms execution. Terrain review initially BLOCKED for low-bank stale texture, reproduced as3 real failures; final focused follow-up confirms the fix and executed8-pass receipt. Independent Sol code review is separate from Astra visual acceptance and parent publication approval.

## Remaining limitations / exact stopping state

- The 52 inherited Fusion lambda errors and 4 ObjectDB exit warnings remain. NightGate night-art/contrast is still not final; some ramp side-face depth is visually ambiguous. Other exterior/river silhouettes shown incidentally were not expanded into a new terrain campaign.
- Existing navigation may accept a route toward a closed NightGate/bush; physical collision stops it. This run proves actual blocking and no V crossing, NOT smarter closed-gate path planning.
- Automated normal input and staged physics are not human fun/playability endorsement or physical mobile device/export acceptance. No other maps, art/UI/mobile overhaul, harvest expansion, full65, packaging or deployment.
- Original owner's screenshot exact build remains unknown; layout match/diagnosis are strong, not a newly invented artifact SHA.
- Supervisor98235 and worker98236 retain inherited FD4/5 for both exact lock inodes; flag1 checked. Never acquired, replaced, truncated, unlinked or unlocked either lock. Final lsof in `final-lock-ownership.txt`. No launched engine remains; all jobs were serial foreground and returned.
- Final readback: auto_resume_enabled=false, paused=true, completed=false. Hourly `f49f0390b564` and watchdog `da915110ed26` both enabled=false/state=paused, original pause timestamps retained. No control/config/cron/gateway/permission changes, process killing or external messages. WORK-QUEUE read only. Real saves untouched.

STOP HERE. Parent verification/weekly closure pending. No next task selected, no automatic continuation scheduled, no promise of work after process exit.
