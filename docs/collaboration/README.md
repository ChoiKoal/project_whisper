# Whisper Git collaboration

## Source of truth

- Repository: `ChoiKoal/project_whisper`
- Integration base for this scoped work: `collab/whisper-polish`
- Initial game baseline: `c25cf55f037e3acd2d708bd036e5c3165ea45906`
- Ruby, Kana, and Memcho run on **separate machines**. No shared working directory, memory budget, or local file paths are assumed.
- Specifications, code, test results and merge requests live in Git/PRs. Chat provides notifications, not the authoritative patch. Previous chat ZIPs are reference snapshots only.

This collaboration branch initially contains the released baseline plus these specifications. It is **not** the latest Ruby map/UI/art work-in-progress. Ruby's ongoing runtime changes will be published separately at a stable checkpoint; QA must identify the exact commit/build it actually runs.

## Roles and ownership

| Owner | Branch | Owned work |
|---|---|---|
| Ruby | integration / scoped runtime branches | Artwork, animation/VFX integration, world/rendering, save/input/gameplay integration, review and merge |
| Kana | `feat/wh-harvest-001-kana` | Harvest play specification, pure action-state module, its unit harness |
| Memcho | `test/wh-harvest-001-memcho` | Independent acceptance tests, gameplay QA and defect reports |

Each owner may use subagents on their own machine. Split files or use separate worktrees/branches, respect that machine's resources, and review subagent results. Ruby's local agent limit is not a global limit across teammates' machines. Avoid simultaneous writers inside any one checkout.

## Workflow

1. `git fetch origin` and branch from the published `origin/collab/whisper-polish` commit. Record the base SHA.
2. Read the assigned specification below. Develop and run tests in your own checkout with isolated test saves.
3. Commit and **push your own task branch**. Open a PR targeting `collab/whisper-polish`; include scope, base/head SHAs, test commands/results, untested cases and evidence.
4. Do not directly push shared `main` or the integration base. Do not force-push another owner's branch.
5. Ruby reviews and runs integration checks, resolves conflicts without overwriting dirty work, and merges approved PRs. No release/deployment is implied by task-branch publication.
6. Once a runnable combined build is ready, Ruby supplies its exact commit/build and reproducible launch instructions. Memcho performs actual gameplay QA; fixes return as scoped PRs and are retested.

Use a draft PR when tests or dependencies are incomplete. If permissions prevent pushing to this repository, use a fork PR or report the access blocker to Ruby; do not request secrets in chat.

## Assigned contracts

- [WH-HARVEST-001 — play loop and isolated action state](WH-HARVEST-001.md)
- [WH-QA-001 — independent tests and gameplay QA](WH-QA-001.md)

No changes to recipe/item IDs, quantities, unique resources, gate costs, tool-tier requirements, stamina economy or shared save semantics are authorized by these narrow tasks. Preserve Alchemy-style discovery, then creation/world response. Stardew Valley is a harvesting-feel reference, not permission to turn the game into a farming simulator.

## Acceptance means more than test counts

The shared target is a clear action → material-specific response → acquisition → next experiment loop. Functional tests establish correctness, not visual quality or fun. Record confusing input, tedious repetition, unclear next goals and missing material feedback in playtests. Desktop viewport simulation is not mobile-device proof.
