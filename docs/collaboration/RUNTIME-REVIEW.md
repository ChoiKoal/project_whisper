# Current review scope — unit 15

This document retains prior independent review history below. For current unit-15 scope use RUNTIME-WIP.md and CURRENT15-QA.md. Former future-save, pending-action and unsafe-harness findings now have implemented fixes and focused execution receipts; historical blocker lists below are not an assertion that those exact defects remain open.

Parent publication-copy verification: exact 3 selected safety scenes / 124 assertions, unchanged source, 3 resource-teardown ERROR lines. No whole-suite, final-art, mobile-device or human-fun approval. Merge remains blocked.

Independent unit-15 review inspected the 35-file delta against `848c1c2e5cd5c1aed2c5f09d01a21f6c461b2842`. It found no new critical/high production issue or credential/privacy leak, but **initially blocked draft publication** because CURRENT15-QA did not distinguish the historical R2 smoke from the separate final-R3 publication-copy run. The parent corrected that provenance statement and added the omitted Pillow regeneration prerequisite; code/assets remain exactly those reviewed and tested. Parent resolution permits labeled draft sharing only, not a new independent approval or merge readiness.

One low-severity diagnostic issue remains: `hover_timing_probe.gd` does not validate `FDN_EVIDENCE` or a failed output-file open. **Do not run that standalone diagnostic in this draft.** It is not part of the portable three-scene safety command; its fail-closed output handling remains follow-up work.

---

# Independent reviews — runtime source draft

## Unit 14 delta review

Independent read-only verdict: **safe to publish the labeled draft; merge-ready: false**. The reviewed delta against `acb5766dd780d53f2577b9c1f6ebdb75fce02afe` covered 32 staged files. Changed game-file hashes matched the manifest, and the three generic flower assets reproduced byte-for-byte. No new severe logic, security/privacy or publication-accuracy defect was found in that bounded review.

Explicit-v2 normal progression completed with 172 assertions; legacy completed with 174 before the v2-only flower dispatch. These are parent-verified automated receipts, not human QA or clean engine runs. The intermittent far-hover ghost failure remains unresolved; a passing retry did not establish a fix. Future-save-version handling, cinematic pending-action lifetime, unsafe historical harness isolation, Lambda errors and incomplete regression/device/art/fun acceptance keep merge blocked. See RUNTIME-WIP.md for the exact scope. No new engine run was performed by this reviewer.

## Historical unit-13 review

The old nest-placement failure below predates the scoped unit-14 normal-loop completions. Other findings are not automatically cleared by them.

**Publication scope:** source-sharing draft only. **Merge readiness: NO.** No gameplay, visual, mobile, release or complete-project approval is granted.

An independent read-only review inspected the staged source snapshot, manifest and references. It found no credentials, private saves/documents, executables or missing mandatory production resource references in the inspected package. This is not a copyright/provenance certification or proof of runtime correctness.

## Merge blockers / follow-up

- Latest explicit L1-v2 normal progression fails at nest-placement episode activation. Default new-game is still v1. Final legacy and v2 normal loops need fresh verification.
- `TouchController._pending` may survive cinematic/time-lock route cancellation and trigger a stale action after a later movement. Reproduce and invalidate according to the real lock lifecycle; never globally unlock as a workaround.
- `SaveManager._migrate` accepts future save versions with a warning. Reject newer versions without applying or overwriting their data; verify byte-preserving load/autosave behavior.
- `cutscene_harness`, `m5_test_harness`, `v051_test_harness`, and `v052_travel_stress` delete `user://save1.json` without their own fail-closed isolation guard. **Never run them against normal game data.** Add the guard and negative isolation tests before merge.
- No single final-revision full gameplay/regression pass exists; engine resource/Lambda errors, art/HUD/harvesting and device/export checks remain.

## Packaging limitations

- Several dev harnesses depend on external historical evidence fixtures not in this Git snapshot. Missing fixtures are setup failures, not gameplay passes.
- `world_object_presence_harness` names a missing `placed_object_art.gd` and corresponding placed-art resources. It is an unfinished acceptance contract, not an implemented production feature.
- Optional missing L2/L2-subzone/L5 presentation assets have guarded fallbacks; those appearances are not finished artwork.
- Two trailing-empty-line warnings were cleaned in the publication copy after the review. This is whitespace-only and does not fix any gameplay issue. The source manifest was regenerated for the exact published bytes.

## Collaboration rules

Use [RUNTIME-WIP.md](RUNTIME-WIP.md) and an isolated test environment. Report Git base/head SHA, actual commands and untested cases in every review. Other machines can inspect and return scoped PRs without merging this entire WIP into the shared base. Ruby remains the integration owner; known blockers must stay visible.
