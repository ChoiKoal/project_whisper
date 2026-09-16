# Runtime WIP snapshot — unit 13

**Draft review only. Not release-ready, not a passing gameplay build.**

This branch snapshots Ruby's map/render/UI work through unit 13. The collaboration specifications remain under `docs/collaboration/`. The source manifest identifies the exact packaged game files; do not equate the original baseline SHA with this dirty-work snapshot.

## Known state

- Versioned `l1-v1` / `l1-v2` data and revision-aware loading exist; old saves remain on legacy data.
- Normal new-game / NG+ still select v1. V2 is an explicit candidate via `new_game_for_layout("l1-v2")`; it is not the default released level.
- Latest v2 normal progression **FAILED** after gathering/crafting the nest, at the assertion that placing it triggers the optional episode. The cause is not established.
- An earlier legacy playthrough completed before later versioning changes. It is not evidence that final v2 or final legacy source passes the complete loop.
- Focused tests cover subsets of revision preflight, geometry, input and persistence. They were executed on intermediate revisions, not one final all-tests-green build.
- Engine resource/Lambda errors and incomplete artwork, HUD, harvesting feel and mobile-device/export checks remain.
- No game save or test-user data is shipped. Use a temporary HOME/user data directory.

## Local review setup

Use Godot **4.5** and Python 3. **Do not run this snapshot against your normal game user directory.** In particular, `cutscene_harness`, `m5_test_harness`, `v051_test_harness`, and `v052_travel_stress` can delete `user://save1.json` without their own fail-closed isolation guard. They must not be launched directly from a regular editor/game profile.

For a POSIX review environment, prepare a disposable data directory:

```sh
TEST_HOME="$(mktemp -d)"
HOME="$TEST_HOME" XDG_DATA_HOME="$TEST_HOME/.local/share" WHISPER_TEST_HOME="$TEST_HOME" godot --path game
```

Verify Godot's resolved `user://` is inside the disposable location **before** any save-writing or destructive harness. On platforms where these environment variables do not isolate Godot user data, stop and configure a platform-appropriate isolated test project; the command above is not Windows/device validation.

This command is a launch instruction, not a claim that this published branch was tested on every platform. For automation, set an isolated `HOME` and `WHISPER_TEST_HOME`. Some historical development harnesses refer to external evidence fixtures that are **not** in the repository; those harnesses must report missing-fixture setup failures rather than pretend a gameplay pass. A reproducible focused QA bundle will be supplied after the current normal-loop blocker is resolved.

## Review / merge policy

Do not merge this branch to `collab/whisper-polish` or `main` while the normal-progression blocker remains. Teammates may inspect it by Git commit, identify defects, or prepare isolated test branches; do not mix its partial state with earlier successful reports. Ruby owns core integration and most art. Kana's pure action module and Memcho's independent tests remain separate PRs.
