# Runtime WIP snapshot — unit 15 candidate

**Draft source for scoped QA. Not release-ready; merge remains blocked.**

Use the exact Git commit supplied with this handoff, not the moving development worktree or the specs-only collaboration base. Unit 15 does not integrate Kana's harvesting module or Memcho's PR #3 harness.

## Included changes and evidence

- Future integer save versions are refused before state application; blocked-write handling preserves bytes through explicit save and close/autosave. Synthetic focused test: 10 assertions.
- Pending touch/path actions cancel on modal/control/cinematic/time-request edges, including same-frame pause/resume. Synthetic focused test: 36 assertions.
- Four destructive legacy harnesses now check fail-closed isolation before touching a save. Twelve negative synthetic-HOME cases refused execution with unchanged sentinel save bytes. Never test this against real user data.
- Intermittent far-hover observation was traced to checking before presentation under a stalled frame. The oracle now awaits process and post-draw presentation rather than retrying until success. No new production-preview patch is claimed.
- Exact NightGate closed/open flower textures reauthored, with separate pollen emission. Final R3 gate contract: 78 assertions across v1/v2. **Day narrowly retained; night still REWORK** because open-state, stem and ground-contact readability remain inadequate. This is not final art approval.

The parent independently ran the portable command on this publication copy with final R3: exact 3 scenes, 124 assertions, 0 failed scenes, unchanged source, and 3 engine resource-teardown ERROR lines. Exit success does not mean clean engine teardown. See `CURRENT15-QA.md` for prerequisites and isolated execution.

Final development-source automated normal routes: explicit v2 172 assertions and legacy v1 174 assertions, both verified saved revisit, exit 0 and unchanged source. Each retains 26 inherited freed-lambda ERROR lines. These are automated route receipts, not human enjoyment or mobile-device acceptance. Normal routes were not rerun in the publication copy; its focused safety suite was.

## Remaining gates

- Fix inherited Fusion/lambda errors; reconcile regression and export dependencies.
- Integrate and test harvesting action state, node guard, state-before-signal reward ordering, cancellation and respawn identity.
- Refine night flowers and complete representative scene/art, UI and player feedback.
- Verify v2 gate-prefix reload/respawn, portal aprons, saturated placements and full ramp-end visual coverage.
- Complete touch-only, device/export/performance and human play/fun QA.
- Default new game remains **l1-v1**. **l1-v2 is an explicit candidate**, not the enabled default.

Source-sharing approval, scoped safety execution, whole-game regression, human fun, visual acceptance and release readiness are separate judgments. Main and the integration base have not received this runtime draft by merge.
