# Project Whisper — v1.1.0 「게임성 패스」 기획 문서 v1.0

> 작성: Kana (구현·설계 담당) / 2026-07-07
> 대상: **v1.1.0 게임성 패스** — 오너(KOAL) 피드백 "게임성이 많이 부족" 처방.
> 성격: **기획/설계 문서. 구현 금지 — KOAL 검토 게이트 통과 후 착수.**
> 상위/Canon:
> - 코어 구조: `/workspace/global/knowledge/domain/project-whisper.md` (포탈 허브 구조, Whisper 재화, 5레이어).
> - 세계관/서사: `docs/project-whisper-storyline-v1.md` §3(레이어 미니 아크)·§6(메아리 조력자)·§2(진상), `docs/project-whisper-gdd-v0.1.md`(연금술 정체성).
> - 레이어 레벨/게이트: `docs/project-whisper-layer2~5-design-v1.md`.
> - 코드 정합(읽고 반영): `game/scripts/core/quest_manager.gd`(5중 라인), `game/scripts/ui/fusion_ui.gd`(조합 UI/힌트 게이지), `game/scripts/core/codex.gd`(힌트 리빌 로직), `game/scripts/world/{terminal_station,clockwork_city,mage_tower,cathedral}.gd`(레이어 조합대 스폰), `game/scripts/world/{cauldron,truth_shard}.gd`(상호작용 패턴), `game/data/{recipes.json,quests.json}`.
> 상태: **확정 스코프 5개(KOAL) 단일 기준.** 이 문서 = 검토용 설계. 구현 에이전트는 KOAL 승인 후 소비.

---

## 0. 이 문서가 결정하는 것 (요약)

배경: 오너 피드백 "게임성이 많이 부족". 확정 스코프 5개를 **문서로만** 설계한다. 각 스코프는 기존 시스템 위에 얹는 **저비용 증분**을 우선한다(신규 서브시스템 최소화).

| § | 스코프 | 한 줄 처방 | 비용 |
|---|---|---|---|
| §1 | NPC 퀘스트 시스템 | 잔재 NPC(레이어당 1~2 + 홈 「메아리」)에 4~6개 퀘스트 체인. QuestManager 5중 라인 위에 **NPC 라인 추가** | 中 |
| §2 | 조합 힌트 리워크 | 재료 반쪽 노출 폐기 → **결과물 실루엣+시적 이름 먼저**, 재료를 추리. 힌트 게이지 단계 재설계 + 실패작 시스템 | 中 |
| §3 | 게이트 미니 퍼즐화 | 레이어당 1개 게이트를 1화면 미니 퍼즐로 승격(퓨즈 순서/톱니 맞물림/룬 점등/성가 음순서). 기존 장착 위 UI 레이어만 | 中 |
| §4 | 조합 UI 리워크 | fusion_ui.gd 진단 + 2슬롯+결과 미리보기(힌트 연동)/재료 필터/최근 레시피/도감 연결 | 中 |
| §5 | 솥단지 전 레이어 배치 | L2~L5 「정비대」(제각각 스킨) → **동일 솥단지 + 레이어별 불꽃 색**으로 통일. 스폰 근처 고정 | **低(선행)** |

**착수 권장 순서**: §5(저비용 선행, 즉시 체감) → §2·§4(조합 루프 개선, 상호 의존) → §1(콘텐츠 볼륨) → §3(퍼즐, 레이어별 병렬). 구현 단계 분해(GP-1~N)·코스트·하네스 계획은 §6에 수록.

---

# §5. 솥단지 전 레이어 배치 (저비용 선행)

## 5.1 현황 (코드 확인 결과 — 반드시 먼저 읽을 것)

**컨셉(오너)**: 방랑자가 각 세계에서 자기 솥을 불러낸다. 조합대는 세계마다 다른 정비대가 아니라 **같은 솥단지**여야 하고, 세계별 정체성은 **불꽃 색**으로만 준다.

코드 실측(2026-07-07):

| 레이어 | 조합대 스폰 | 실제 노드 | object_id | 발광 | 상호작용 경로 |
|---|---|---|---|---|---|
| 홈 섬 | `home_legend.json` 심볼 `C` | **`Cauldron` 클래스** (`cauldron.gd`) | `cauldron` | violet pool | `gatherable` 그룹 + `on_interact()` → FusionUI 자동 바인드 |
| L1 시작의 숲 | `map_legend.json` 심볼 `C` | **`Cauldron` 클래스** | `cauldron` | violet pool | 동일 (E 조합) |
| L2 터미널 | `terminal_station.gd::_spawn_workbench()` | **plain `Sprite2D`** `l2_workbench.png` | meta `workbench` | **cyan** pool | — |
| L3 클락워크 | `clockwork_city.gd::_spawn_workbench()` | **plain `Sprite2D`** `l3_workbench.png` | meta `workbench` | **orange** pool | — |
| L4 마탑 | `mage_tower.gd::_spawn_workbench()` | **plain `Sprite2D`** `l4_workbench.png` | meta `workbench` | **gold** pool | — |
| L5 대성당 | `cathedral.gd::_spawn_workbench()` | **plain `Sprite2D`** `l5_workbench.png` | meta `workbench` | **gold** pool | — |

**L4/L5 조합대 부재 여부 → 결론: 부재 아님. L2~L5 전부 조합대가 스폰된다.** 세션이 `_loader.l2_workbench_special_cell()`(레전드 `special.workbench_cell`)에 정비대급 조합대를 스폰하고, 레이어별 색 발광 풀(cyan/orange/gold/gold)을 붙인다. 스폰 위치는 스폰 서편 2~3칸(§A-7 "first craft ≤4분" 페이싱).

**두 가지 실측 이슈 (이 스코프가 해결):**

1. **스킨 불일치 (오너 지적의 실체).** 홈/L1은 솥단지(`cauldron.png`), L2~L5는 레이어별 **정비대 스킨**(`l2~l5_workbench.png` — L3 brass, L4 amethyst, L5 ivory 등 제각각). 오너의 "정비대 스킨 제각각"이 코드에 그대로 있음.
2. **상호작용 경로 불일치 (숨은 정합성 리스크).** L2~L5 조합대는 `Cauldron` 클래스가 아니라 meta만 단 `Sprite2D`이고 **`gatherable` 그룹에도, `on_interact()`도 없다.** `InteractionController._do_interact()`는 `gatherable` 그룹 + `on_interact()` 대상에만 E 조합을 라우팅하고, `FusionUI._autobind_cauldrons()`는 `Cauldron` 클래스만 바인드한다. **즉 현재 L2~L5 조합대는 표준 E-조합 경로로는 열리지 않을 개연성이 크다.** (별도 오픈 경로가 확인되지 않음 — 구현 시 반드시 재현/확인.) 이 통일 작업이 그 리스크도 함께 닫는다.

## 5.2 설계 — 「어디서나 솥단지」

**단일 원칙: 조합대 노드는 전 레이어에서 동일한 `Cauldron` 클래스. 레이어 정체성은 불꽃(발광 풀) 색으로만.**

- **아트**: `l2~l5_workbench.png` 폐기(또는 보류). 전 레이어 `cauldron.png`/`cauldron_bubble.png` 재사용(홈/L1과 동일한 버블 애니 + breathing pulse). 방랑자가 "자기 솥을 불러낸다" 컨셉과 1:1.
- **불꽃 색(레이어 정체성)**: 기존 발광 풀 에셋을 그대로 재사용해 색만 배정 —
  - 홈/L1 = **보라**(`light_pool_violet.png`, 현행 유지)
  - L2 = **시안**(`light_pool_cyan.png`) — 정전된 문명
  - L3 = **주황**(`light_pool_orange.png`) — 마지막 온기
  - L4 = **금색**(`light_pool_gold.png`) — 아케인/봉인
  - L5 = **호박/앰버**(`light_pool_amber.png` 필요 시 신규 1종, 없으면 gold 재사용) — 신성
  - → §5 스펙상 "시안/주황/보라·금/호박" 그대로. 색 배정 표 확정.
- **스폰 위치**: 현행 `workbench_cell`(스폰 근처 고정) 유지. 위치 변경 없음 — **스폰 노드 타입만 교체**.
- **상호작용**: `Cauldron`으로 교체하면 `gatherable` 그룹 등록 + `on_interact()`가 딸려와 FusionUI 자동 바인드가 전 레이어에서 균일하게 성립(5.1 이슈 2 자동 해결).

## 5.3 구현 노트 (저비용 — 선행 가능)

- 세션 4곳(`terminal_station/clockwork_city/mage_tower/cathedral`)의 `_spawn_workbench()`를 **공통 헬퍼로 수렴**: `_spawn_cauldron(cell, flame_pool_path)`. 각 세션은 색 인자만 다르게 호출.
  - 헬퍼는 `map_loader.gd::1395`의 `C` 심볼 처리(`cauldron.gd` set_script + `cauldron` object_id + violet pool)와 동일 로직을 재사용/추출.
- `l2_workbench_cell` 기록·`l2_workbench_special_cell()` 레전드 읽기는 그대로(위치 계약 불변).
- **회귀 안전장치**: 홈/L1은 이미 `Cauldron`이라 변경 없음 → 표준 경로 회귀 위험 0. L2~L5는 노드 타입만 상향되므로 기존 세이브의 `l2_workbench_cell` 좌표와 호환.
- **아트 부채**: `l2~l5_workbench.png` 및 생성기(`tools_gen_l{3,4,5}_objects.js`의 workbench 함수)는 제거 대신 **비활성 보류**(롤백 여지). L5 앰버 풀만 신규 1종 가능성.

**비용: 低.** 신규 시스템 없음. 세션 4곳 스폰 함수 교체 + 색 인자 + (선택)앰버 풀 1종. §5는 **KOAL 승인 즉시 선행 착수 가능** 항목으로 표기.
