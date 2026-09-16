# Independent review — unit-13 runtime draft

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
