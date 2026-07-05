# Handoff — v0.3.1 recipe-integration (canonical recipe tree)

Project Whisper / Godot 4.5.stable. Version stays **0.3.1** (no bump — this is a
recipe-data + harness revision on top of the v0.3.1 release). **No git commit.**

Verify: `cd game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import .`

---

## What changed (this pass)

The owner supplied a canonical revision of every base-element combo. A prior agent
applied the **data** (items.json → 69 records / 68 canonical + 1 alias, recipes.json →
62 recipes, icons D50–D61 added, D11 석기 retired + icon deleted, tools_gen_icons.js
updated) and verified data integrity, then stopped before touching the harnesses. This
pass **rewrote the test suite to the new canonical truth** and re-ran the full export
validation.

### New canonical facts the harnesses now assert
- All 18 base gather-pairs are recipes (owner CSV). Key ones the tests key on:
  - I5꽃+I2풀 = **D54 초원 (R07)**  ← was 씨앗 D03 under the old tree
  - I6바위+I8돌 = **D61 암석 (R17)**
  - I1흙+I6바위 = **D52 자갈 (R05)**
  - I1흙+I4나무 = **D04 새싹 (R03)**
  - I9정수+I7물 = **D19 생명수 (R33)** (unique-catalyst, I9 not consumed)
- **G1 rewire:** 디딤돌 D14 = **암석 D61 + 자갈 D52 (R28)** — no longer 바위+돌 directly.
- **G4 rewire:** 빛나는 새싹 D20 = **생명수 D19 + 새싹 D04 (R34)** → +흙 → 어린 세계수 D22 (R36).
  씨앗 D03 = 초원 D54 + 꽃 (R20) is now OFF the critical path.
- Because every base-pair is a recipe now, "non-recipe" test pairs moved to 진흙-family
  dead-ends: **I3+I4, I3+I5, I3+I6, I3+I8, I1+I3**.

---

## Per-harness fixes (all 12 GREEN, headless + on exported binary)

| harness | change |
|---|---|
| **m2_test_harness** | canonical item count 57 → **68** (records-minus-alias). |
| **m3_test_harness** | full recipe-assert rewrite: R04→**R07** (I5+I2→D54 초원); wrong-pair I1+I2 (now R02) → **I3+I4** dead-end; 5-distinct-wrong-pairs set → I3+I4/I3+I5/I3+I6/I3+I8/I1+I3; alias-fold R11→**R25** (D09+I4→D10, output unchanged); catalyst R20→**R33**; codex discovery R04→R07 + failed I1+I8→I3+I4; scene-wiring loop now I5+I2→D54(R07) then D54+I5→D03(R20). Order-independence + hint-gauge logic unchanged. |
| **m8_icon_coverage** | counts 58→**69** records, 57→**68** canonical, hash-uniqueness 57→**68**; D11 absence implicit (not in items.json). |
| **e2e_playthrough** | clear chain rebuilt (see below) + new **softlock material check** step. |
| **v021_test_harness** | fusion-juice smoke pointed at the valid new pair: I5+I2→**D54 초원 (R07)**; result-card + skip-path asserts follow D54. |
| **v030_test_harness** | codex recipe-row asserts on new formulas: craft **D54 via R07**; D54 detail = exactly 1 discovered row (R07); D03 씨앗 (output of undiscovered R20) → empty-state "아직 알아내지 못했다". 꽃-search test unchanged (item names stable). |

m4, m5, m6a, m7, m2_integration, v031 needed no recipe edits and stayed green.

### e2e new clear chain (real controllers, exercised end-to-end)
1. gather flower(I5)+grass-tile(I2, carves walkable HOLLOW) → first fuse **초원 D54 (R07)**.
2. per K slot ×3: **암석 D61 (R17)** + **자갈 D52 (R05)** → **디딤돌 D14 (R28)**; place on the 3
   water slots → AStar routes across the stream (real pathfind move).
3. gather water(I7) → use on G2 bush → corridor opens. *(unchanged)*
4. night gate → G3 passable → gather World Tree → **I9 (unique)**. *(unchanged)*
5. **생명수 D19 (R33, I9 catalyst, not consumed)** → **새싹 D04 (R03 = 흙+나무)** →
   **빛나는 새싹 D20 (R34 = D19+D04)** → **어린 세계수 D22 (R36 = D20+흙)**.
6. plant D22 on a HOLLOW/VOID tile → world_tree_planted + cleared.
7. save → load → cleared/inventory/map persist. *(unchanged)*
8. NG+ → run=2, exactly 3 recipes carried (subset of discovered ≥5). *(unchanged)*

**e2e result: PASS (0 failures), 0 SCRIPT ERROR lines.**

---

## Softlock report — G1 pre-crossing material availability

G1 (3-slot stream at col 16, rows 24–26; spawn is SOUTH at row 32) needs **3×디딤돌**.
Under the rewire each 디딤돌 = 암석(I6바위+I8돌) + 자갈(I1흙+I6바위), so the one-pass demand is
**바위 I6 ×6, 돌 I8 ×3, 흙 I1 ×3**, all gatherable on the spawn side of the stream.

Live measured supply on the spawn side at map-boot (authored + M6a scatter):

| material | source | live pre-G1 | one-pass need | verdict |
|---|---|---|---|---|
| 바위 I6 | rock objects (respawn) | **5** | 6 | short by 1 — covered by respawn |
| 돌 I8 | stone objects (respawn) | **8** | 3 | ample |
| 흙 I1 | dirt tiles (permanent) | **10** | 3 | ample |

- 바위/돌 are gatherable **objects** that respawn after `DAY_LENGTH` (ObjectRespawn), so
  they are renewable — the 1-rock shortfall is recovered by gathering, waiting a day, and
  regathering. The map is **beatable**.
- 흙 comes from **dirt tiles**, which are permanent (never respawn); 10 available ≫ 3 needed.
- All spawn-side dirt (10 tiles, rows 30–31) is on the same side as spawn, reachable
  pre-crossing. No I1 stranding.
- e2e asserts: 바위/돌 = "live renewable source present (>0)", 흙 = "≥ full need"; the
  one-pass shortfall is emitted as a `[NOTE]` line, not a failure.

**Map data left unchanged per spec (report-only).** Recommendation if the owner wants a
grind-free G1: add ~1–2 authored rocks (`R`) south of the stream (rows 28–39).

---

## Other checks
- **No hardcoded 57/58/50 counts remain** in scripts/scenes (grep clean). m7's
  `all_ids()>=30` / `all_recipes()>=50` are lower-bound guards, still valid (68 items /
  62 recipes).
- `tools_verify_recipes.py` → **RESULT: PASS** (every output reachable, G1 & G4 paths
  valid, D11 fully retired, D50–D61 present+reachable, no orphans/stranded inputs).
- Version **0.3.1** in project.godot + all three export presets.

---

## Export validation flow (ran)
1. Installed export templates from `tools/export_templates.tpz` →
   `~/.local/share/godot/export_templates/4.5.stable/` (version.txt = 4.5.stable).
2. Temp-included dev scenes in the **Linux arm64** preset (cleared its `exclude_filter`),
   exported a debug test binary with the real PCK.
3. Ran **m7 + v030 + v031 on the exported binary** → all **PASS** (data-intact, embedded PCK).
4. **Restored** export_presets.cfg (verified byte-identical to backup; all 3 presets
   re-exclude `scenes/dev/*`).
5. Built + repackaged the finals (overwriting existing v0.3.1 zips):

| file | size (B) | contents |
|---|---|---|
| ProjectWhisper-win64-v0.3.1.zip | 34,195,169 | `ProjectWhisper.exe` (embed_pck) |
| ProjectWhisper-macos-v0.3.1.zip | 62,528,872 | `Project Whisper.app` release bundle |
| ProjectWhisper-macos-DEBUG-v0.3.1.zip | 67,230,662 | debug `.app` + `Project Whisper.command` |

All three zips pass `testzip()` integrity. (Sizes grew a few KB vs the pre-recipe v0.3.1
build, reflecting the recipes.json/items.json/icon changes.)

---

## Validation summary
- **12/12 harnesses PASS** headless: m2, m2_integration, m3, m4, m5, m6a, m7, m8, e2e,
  v021, v030, v031.
- **3/3 exported-binary checks PASS**: m7, v030, v031 on the real Linux PCK.
- Data verifier PASS; no stale counts; version 0.3.1; presets pristine.

Files touched: `scenes/dev/{m2,m3,m8,v021,v030,e2e_playthrough}` harness scripts only.
No git commit.
