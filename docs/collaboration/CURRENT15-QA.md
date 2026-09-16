# CURRENT15 portable QA handoff — draft, not release/merge approval

Scope: future-version save preservation, canceled touch pending actions, destructive-harness isolation, exact NightGate flower replacement candidate. Default new game remains l1-v1; l1-v2 is still explicitly opt-in. Whole refactor, final art, harvesting integration and mobile-device acceptance are incomplete.

## Source and prerequisites

Use the entire game/ directory from the same parent-published Git revision, not isolated script snippets. Required: Godot 4.5, Python 3, imported project assets. No private historical save or machine-local evidence fixture is needed for the three new safety harnesses: all inputs/saves are generated synthetically inside isolated HOME directories. MacOS is the actually executed platform; Linux/Windows execution is not claimed. The parent's publication checkout/PR owns commit/push; this worktree was not committed or pushed.

## Reproducible serial safety command

From repository root, replace GODOT and choose a NEW output directory:

    python3 game/tests/run_current15_safety.py --godot "$GODOT" --evidence "$NEW_OUTPUT_DIR" --case future_save_safety_harness --case pending_lock_safety_harness --case night_flower_art_harness

The runner refuses an existing output directory, generates distinct synthetic HOME directories, binds WHISPER_TEST_HOME, records source hashes, checks explicit finish markers and runs engines serially. Do not run another Godot concurrently. Current process detector recognizes the tested /Godot executable basename; renamed binaries are not covered. No process killing, locks, watchdog control or real-save cleanup occurs.

Current publication-copy verification: the parent ran the exact three scenes against final R3 source/assets: 124 assertions, 0 failures, 0 script errors, 3 resource teardown ERROR lines, source_changed=[]. Pre-run hashes match the published R3 assets, generator and harness. This is a separate run from the earlier development R2 smoke, which happened to have the same counts. Final R3 development-source normal routes are described below; they were not rerun in the publication copy. Neither receipt is a full-suite or clean-engine verdict.

No --case arguments runs the seven listed safety/regression scenes, including the longer v052 travel test. That all-seven portable invocation has NOT been executed as one final-revision suite; earlier individual positives are disclosed in the checkpoint. ERROR lines are reported separately; current passed=true excludes script/assertion/exit/completion failure but does not mean clean engine teardown.

## Synthetic fixture safety

Never launch cutscene_harness, m5_test_harness, v051_test_harness or v052_travel_stress directly against a normal user directory. They now fail closed without a correctly bound isolation sentinel. CURRENT15 negative test receipt tested absent sentinel, wrong root and sibling-prefix for all4, exact12 refusals(exit86), original synthetic save bytes preserved. The negative runner and raw evidence are in the local evidence/15-safety-night-flower/ handoff, not required by the portable positive runner.

## Normal gameplay / aesthetic scope

Final R3: foundation_dialogue_progression_capture completed v2 172 assertions and default legacy174, persisted failed=false and normal_saved_revisit. No ingredient/quest/gate/clear/time injection or teleports in these normal runs. Opening skip handler, public movement/tap requests, Fusion UI callbacks and keyboard/native-touch dialogue input are disclosed automation seams. Existing26 freed-lambda ERROR lines remain in each normal run. These are automated runtime results, not human fun QA.

The game/art/night-gate/ directory includes original open/closed backups and the final reproducible author.py. Art regeneration additionally requires Pillow (see game/art/README.md for the recorded Python 3.11 / Pillow 12.0.0 environment); Pillow is not required for the Godot safety command above. To regenerate a candidate outside production:

    python3 game/art/night-gate/author.py "$NEW_ART_OUTPUT_DIR"

NightGate native128px canvas/offset remain unchanged. Both old textures were reauthored, plus a separate pollen emission mask. Day/night collision/phase and keyboard blocking/passage were exercised for both layout revisions. Art verdict: day narrow KEEP, night REWORK (cup still reads partly closed and neck/leaves dark). SANABI/whole scene remains HOLD. Candidate R3 is implemented for continued refinement, not approved final art; no all-world multiplication.

Parent next step: use exact final-audit source hash to publish a reviewed draft delta and give Memcho an immutable runnable Git revision. Do not present this document alone as delivery of a build or QA acceptance.
