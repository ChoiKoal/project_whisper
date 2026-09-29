# Whisper pause recovery — source available, NOT a release

## Ownership and scope

Requested by Kana/Memcho after KOAL reassigned game development and QA to Memcho. Ruby only recovers the paused source and evidence here: no resumed implementation, no new engine execution, no merge to main, no deployment, no automatic restart. Kana's previous reviewer role is withdrawn per the latest handoff; do not use older role tables as current assignments. Memcho owns subsequent development/QA and the independent QA-agent procedure.

- Recovery branch: `ruby/whisper-pause-recovery`.
- Parent snapshot: `ea806bb96520fb766b2a54edb730ff75db830bef` (PR #4 unit15).
- Recovered runtime: paused world-object worktree with unit16 harvest integration and unit17 MAP1 cleanup.
- All recovered non-cache game bytes match the original pause source receipt. See `unit17/GAME-SHA256.json` for exact hashes; copied file count is recorded there rather than inferred from Git base HEAD.
- The original worktree HEAD stayed `c25cf55`; that HEAD alone does NOT describe these formerly uncommitted changes.
- `PAUSE-CHECKPOINT.md` contains the parent's pause record, with its historical local-only Git status explicitly superseded by this recovery publication.

## What was preserved

1. Current paused `game/` source, scenes, assets, data, harnesses and focused runner.
2. Unit16/17 top-level text logs, summaries, failed-attempt evidence and checkpoints under `docs/handoff/16-harvest-integration/` and `17-map1-final-cleanup/`. These are masked historical copies, not fresh executions.
3. Historical queue/tracker under `unit17/`; they are archival records, NOT authorization to resume tasks or publish.

Godot import cache, Python bytecode, evidence HOME directories, save fixtures, private local state, large raw captures and unrelated Fusion-worktree edits are excluded. Existing tracked art-backup cache from the base is left unchanged, not treated as new source. Raw screenshots remain local; no screenshot receipt is advertised as a packaged image. Historical receipt paths use `[WORLD]`, `[FUSION_WORKTREE]`, `[AUDIT]`, `[HANDOFF]`, `<HOME>` placeholders and may reference omitted artifacts. Some inherited art tools reference the original `/workspace` environment; those tools are NOT guaranteed portable.

## Known state — must not be promoted to full PASS

Historical FINAL17 records:
- MAP1 pixels: 140 assertions, 0 failures; movement: 211, 0 failures.
- Normal v2: 199 assertions, 0 failures, **26 engine error lines**.
- Normal legacy: 207 assertions, 0 failures, **26 engine error lines**.
- Errors include `Lambda capture at index 0 was freed. Passed "null" instead.`; original records preserve them. Engine teardown warnings also remain documented.

These historical counts are not fresh-run evidence, full regression, mobile/device/export, human gameplay/fun or final art approval. Unit16 integration and unit17 scoped source exist; that does not guarantee all outstanding acceptance criteria are met.

**Rejected art remains rejected:** bush and stepping-stone designs need redesign; NightGate R3/night contrast remains REWORK. Do not turn functional assertions into design approval. MAP1 dark-side silhouettes and nighttime foot readability limitations remain in FINAL17.

## Safe intake / execution boundary

Read this file, `PAUSE-CHECKPOINT.md`, and `17-map1-final-cleanup/CHECKPOINT.md` before executing. Do NOT run any development harness against your normal Godot user directory. Some legacy harnesses can delete `user://save1.json`; isolated user data and guard verification are prerequisites, not optional conveniences.

The recovered portable focused runner is `game/tests/run_current16_harvest.py`:

```sh
python3 game/tests/run_current16_harvest.py \
  --godot /absolute/path/to/Godot-4.5 \
  --evidence /absolute/path/to/NEW-isolated-evidence \
  --case harvest_action_state_harness
```

Inspect it first and run it from a disposable clean checkout, never your only working copy: editor import generates metadata in that checkout. It creates fresh HOME/XDG directories and WHISPER_TEST_HOME per case, rejects an existing evidence directory, and records completion/source hashes. It is a focused automated runner, not interactive/device QA. Its `passed` field does not require engine-error count zero: read `engine_errors` and `engine_error_lines` separately. This publication has NOT rerun it or verified portability on Memcho's machine. Use an external wall-clock timeout/supervision when executing; the runner itself uses frame limits.

MAP1 raster/normal captures need a working display/render loop; `frame_post_draw`/mouse-dependent capture is not established by headless execution. Historical evidence fixture homes are intentionally not distributed. Reconstruct only isolated synthetic test fixtures, never real user saves.

## First handoff actions (not auto-executed here)

- Fetch this recovery branch and verify `GAME-SHA256.json` before changing code.
- Compare unit16/17 against the unit15 parent, not against only `c25cf55` or an obsolete chat snapshot.
- Read retained errors and rejected designs; define/commit QA criteria before new implementation per the new owner's process.
- Keep branch/source publication separate from merge, release and final acceptance.

The earlier `docs/collaboration/RUNTIME-WIP.md`, `CURRENT15-QA.md` and source manifest refer to unit15. They are preserved as historical evidence; this recovery handoff and GAME-SHA256 manifest govern the recovered source identity.
