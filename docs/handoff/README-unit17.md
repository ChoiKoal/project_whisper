# Whisper unit16 + unit17 local checkpoint handoff (WIP)

## Status and ownership

This is a preservation handoff to Memcho, not a new implementation, merge, deployment, clean-engine PASS or final art approval. Development and QA ownership now belongs to Memcho under KOAL's instruction. Ruby has not restarted development or automation.

Parent: `ea806bb96520fb766b2a54edb730ff75db830bef` (`ruby/whisper-runtime-wip`, unit15). This branch overlays the exact locally preserved unit16+17 `game/` file set onto that parent. The original dirty worktrees remain untouched.

## Verify before opening Godot

- Root `SOURCE-MANIFEST.json` is the original pause receipt, copied byte-for-byte.
- Its original `source_sha256` object lists **2,553 game files**; it is historical evidence, not the current checkout file set.
- Original manifest SHA-256: `b1407551d2ec02eeb4941a202cc13ab0865dbc6c35ee664e9303ed50bac4171e`.
- **Use `PUBLICATION-MANIFEST.json` for remote verification:** 2,536 included files and 17 explicit excluded paths with original hashes and reason `regenerable (.pyc)`.
- Publication manifest SHA-256: `e21028eaade8a66aed850d4b649db6818ec73412001bf3702ed681fa0ef0afb2`.
- Run `python3 docs/handoff/verify_snapshot.py` immediately after checkout, before editor import can regenerate metadata.
- Count reconciliation: 2,553 original entries are ALL under `game/`. Excluding 17 bytecode files AND seven `.artcache/` entries would yield 2,529; the final publication excludes ONLY the 17 bytecode files, retaining the seven already-tracked art-cache entries. No source/asset bytes are masked or changed. Curated evidence/documents are additional files outside the game manifest.
- `.gitignore` now excludes `**/__pycache__/` and `*.pyc`. No `.godot/` import cache, credentials, isolated HOME or save directory is included. Original local files are untouched.

## What is preserved

- Unit16: action-state integration with E/tap gathering, cancellation and reward/save boundaries. Not final gathering feel/art/fun approval.
- Unit17: map1-v2 internal trench/low-bank rendering, joining corners, and corresponding diagnostic/normal-movement harnesses.
- Root `PAUSE-CHECKPOINT.md` retains the historical pause report. Its relative local paths describe the original machine; portable counterparts are below.
- `docs/handoff/unit17-evidence/`: historical checkpoint, audits, source manifest, production patch, final selected receipt summaries and three before/after images.
- `docs/handoff/unit16-evidence/`: historical checkpoint/audit/review.
- The source SHA inside historical receipts is the old dirty-worktree base `c25cf55`, NOT this publication commit. Receipt hashes bind historical content; this publication was not engine-retested.

## Known limitations — do not mark complete

- Bush and stepping-stone designs explicitly rejected by KOAL; redesign remains pending.
- NightGate R3/night readability: REWORK.
- Historical final normal v2/legacy runs each retained 26 Fusion lambda ERROR lines (52 total); ObjectDB warnings also remain disclosed in the original audit.
- Some ramp side-face/night contrast interpretation remains unresolved.
- No full-game, mobile device, human-fun or whole-art approval.
- Snapshot publication validates byte preservation, not that the current screenshot's holes are fixed in every condition.

## Safe execution

The project entry is `game/project.godot`. Import assets with the intended Godot version before running scenes. Harnesses can reset/save/delete user data. Never run them against a normal user profile: require an isolated HOME/user-data location and satisfy each harness's sentinel/runner contract. Review the supplied source and historical runner commands before execution; this handoff did not rerun them or create replacement test evidence.

The preserved `PAUSE-CHECKPOINT.md` states prior automation is paused. Do not enable Ruby's old supervisor/watchdog as part of checkout. Memcho owns any newly authorized execution.

## Integration

Draft PR target: `ruby/whisper-runtime-wip`. No main push, merge or deployment is performed by this handoff. Memcho verifies the remote file hashes and known-limitations queue before selecting or merging this snapshot.
