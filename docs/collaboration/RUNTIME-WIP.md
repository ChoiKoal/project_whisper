# Runtime WIP snapshot — unit 14 candidate

**Draft review only. Not release-ready and not approved for merge.**

This candidate includes the unit-14 held-ground placement/input fixes and three small generic flower sprites for explicit L1-v2. The source manifest identifies the exact packaged game files. It does not merge Kana's harvest action module or represent the requested large rare flowers as fixed.

## Verified scope and remaining failures

- Latest explicit v2 normal automated progression completed: actual gathering, Fusion, nest, G1/cairn/G2/Rest/night/G3/world tree/clear, Home return and saved revisit. `v2-flower-normal`: exit 0, 172 assertions, 0 failures, persisted completion. No inventory, gate, time, clear or teleport injection; public input/Fusion UI callbacks are disclosed automation seams, not human playtesting.
- Legacy normal progression completed on the final input changes before the v2-only flower dispatch: exit 0, 174 assertions. This is not all-platform or final full-suite coverage.
- These normal runs retained 26 engine Lambda-error lines each. They are not clean engine passes.
- A far-hover ghost/placement-preview check remains intermittent: two failed runs followed by a passing retry do not establish a fix. Cause remains unknown.
- Default new-game and NG+ remain `l1-v1`; `l1-v2` is explicit candidate only.
- Unit-13 nest-placement failure is historical and repaired in this candidate; its old evidence remains preserved, not re-labeled passing.
- Save future-version handling, cinematic pending-action lifetime and unsafe dev-harness isolation findings from [RUNTIME-REVIEW.md](RUNTIME-REVIEW.md) remain tracked until specifically reproduced/fixed/verified.
- Full regression, final art/HUD/harvesting feel, mobile-device/export/performance and human fun review are incomplete.

## Safety before execution

Use Godot **4.5** and Python 3. **Never run against normal game user data.** `cutscene_harness`, `m5_test_harness`, `v051_test_harness`, and `v052_travel_stress` can delete `user://save1.json` without their own fail-closed guard.

For a POSIX environment, prepare disposable data:

```sh
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_HOME/.local/share" WHISPER_TEST_HOME="$TEST_HOME" godot --path game
```

Before any save-writing/destructive harness, verify resolved `user://` lies in the disposable location. If a platform ignores these environment variables, stop and configure an isolated test project. This is not Windows/mobile-device validation.

Several historical dev harnesses need external evidence fixtures absent from this snapshot; report those as setup-blocked. Do not invent fixtures and label them historical evidence. No real-user saves are included.

## Collaboration

This is Ruby's isolated runtime branch, not the shared integration base. Teammates should cite the exact Git commit they inspect, use their own worktrees and return scoped PRs. No main or integration merge while blockers remain. Publication means source sharing, not gameplay acceptance. Unit-14 candidate delta requires independent review before publication; runtime and art conclusions remain separately scoped.
