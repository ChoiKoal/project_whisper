# Handoff — v0.6.0-wip L2-3: 전력 게이트 + WhisperCurrency + 귀환 포탈 리워크

> 작성: 2026-07-05 / 대상: 다음 구현 에이전트 (L2-4 데이터, L2-5 퀘스트/컷신)
> 기준: `docs/project-whisper-layer2-design-v1.md` (Part A §A-4 게이트표, Part C §C-3 전력노드/소지형, 보완 §G2 에너지 Whisper)

이 페이즈는 **두 딜리버러블**: (A) L2-3 전력 게이트/전력계, (B) 오너 보고 「grove 귀환 포탈 인터랙션 약함」 리워크(폴딩).

---

## 감사(Audit) 소견 — 이전 에이전트 중단 시점

이전 에이전트가 L2-3 게이트 컨트롤러/재화/HUD/퀘스트/코어 배관은 **거의 완성**하고 사망. 커밋 안 됨(63e82bd 이후 uncommitted). 감사 결과:

- **완성돼 있던 것**: `l2_gate_controller.gd`(4게이트 전부), `whisper_currency.gd`(오토로드), `whisper_hud.gd`, GameState `power_node_energized`/`powered_nodes`/`layer2_purified` + 세이브, RecipeDB `whisper_cost`, Fusion 재화 게이트, quests.json L2-Q1~Q7, terminal_station.tscn(L2GateController+WhisperHUD 노드), audio power_hum/spark. 이 상태로도 l2_gates_harness 33/33 통과(단, 게이트를 **직접 API/아이템 주입**으로 구동 — 풀 체인 아님).
- **비어 있던 것(스펙 NOTE 위반)**: J1-J7 채집 아이템이 items.json에 **부재**(0개). 게이트체인 레시피 L2-R01/R02/R06/R07 **부재**, 중간물 D62(구리도선)/D63(정류회로) **부재**. L2-R08 파워코어가 `["D68","D67"]`로 **설계 위반**(D67은 D68의 선행물, 공동 재료 아님). J4(회로) 채집원 미배선.
- **결론**: 컨트롤러는 살리고, 데이터 갭 + 풀 체인 테스트 가능성 + 귀환 포탈을 채웠다.

---

## A. L2-3 전력 게이트 — 게이트별 상태

전부 `l2_gate_controller.gd` (terminal_station.tscn `L2GateController` 노드)가 로더 legend `gates` 블록을 소비해 배선. Layer-1 시그널 패턴 재사용.

| 게이트 | 방식 | 상태 | 비고 |
|---|---|---|---|
| **G1 에너지 브리지** | 전지 D64 → 배전반 K(bridge) 장착 → `power_node_energized("bridge")` | ✅ | 브리지 B 타일 **0.1s 순차 점등**(시안 라이트풀) + walkable 스왑(`l2_set_gate_cell_walkable` → tile_walkable_changed → AStar 갱신, 디딤돌 메커니즘 재사용) |
| **G3 정전 구역** | 네온 랜턴 D65 **소지**(비소비) | ✅ | N 병목 Area2D 폴링 `Inventory.has("D65")`. 소지 시 벽 콜리전 off + 주변 시안 라이트풀; 미소지 시 보이지 않는 벽 + 화면가장자리 암전 경고 + "…빛이 필요하다" |
| **G2 차폐문 + 에너지 Whisper** | 퓨즈 D66 → 보조발전기 e 사용(`item_used_on_object`) | ✅ | 발전기 가동 스왑 → 차폐문 D 개방(콜리전 off) + **에너지 Whisper +1**(시안 빛줄기 연출 + "…처음으로, 힘이 내 것이 되었다", 1회 가드). 보완 §필수 |
| **G4 관제탑 재가동** | 파워코어 D69 → 관제탑 배전반 K(control) 장착 → `power_node_energized("control_core")` | ✅ | Layer 2 정화 컷신(스크린 점등 → 기지 전역 순차 급전 파도 → 배경 톤 밝아짐 → 텍스트) → `layer2_purified` 시그널 → terminal_station이 machine 포탈 flickering 전파 + 세이브. L3 점화는 L2-5(현재는 정화+귀환에서 종료) |

**WhisperCurrency**(신규 오토로드): 재화=에너지 단일 자릿수. `add_energy/spend_energy/has_energy`, `to_dict/from_dict`, `reset`. HUD(WhisperHUD, layer 3, 좌상단 퀘스트 아래, 보유>0일 때만, ⚡ 시안). 세이브(`build_save_dict.whisper`), NG+/새게임 리셋. RecipeDB `whisper_cost:{energy:1}` → Fusion이 재료 소모 **전에** 지불 가능성 체크(부족 시 `failure_reason:"에너지가 부족하다"`, 무소모 no-op), fusion_ui가 사유 표시.

**데이터 갭 메움(이번 페이즈)**:
- items.json: **J1-J7**(고철/전선/유리/회로/기름/네온/재, 채집 스텁, layer:2) + **D62 구리도선/D63 정류회로**(중간물).
- recipes.json: **L2-R01~R08 전부** — R01(J1+J2→D62), R02(J4+J5→D63), R03(D62+D63→전지D64), R04(J3+J6→랜턴D65), R05(D62+J3→퓨즈D66), R06(J4+D64→골격D67), R07(D67+J6→조각D68), **R08(D68+D68→파워코어D69, whisper_cost energy:1)**. R08은 2입력 시스템 유지 위해 조각 2개(설계 L2-R07 플레이버 "아직 하나가 모자라다" 근거) + 에너지 1.
- map_loader: `s` 부품상자를 셀 좌표 패리티로 J2/J4 분기(설계 "s=랜덤 J2/J4"의 결정론적 스텁 — J4 채집원이 G1 앞 남광장에 확보되어야 R02 성립).
- **주의**: J-아이템·D62/D63은 아직 전용 아이콘 없음 → ItemDB 카테고리 폴백 사각형으로 렌더(m8 하네스가 layer:2를 아이콘 커버리지에서 제외, 실제 아트는 L2-4). 42레시피 풀데이터도 L2-4.

---

## B. 귀환 포탈 리워크 — 요약

**근본 원인**: grove 귀환 포탈은 v0.5.1 진입존 패턴 **이전**에 만들어짐 — `grove_session._spawn_return_portal`이 bare Portal에 `portal_interacted`만 연결하고, InteractionController의 **정면-셀 인접**에 의존 → 진입 apron 없음/플로팅 프롬프트 없음/클릭워크 없음 = 오너의 "인터랙션 약함". 홈 포탈은 HomeSession의 매프레임 진입존 루프를 돌린다.

**해결**: 공용 `ReturnPortalController`(신규 클래스) — 홈 게이트와 **정확히 동일**한 진입존 루프를 팩터아웃:
- 진짜 monumental Portal(state=OPEN, layer="return", 플레이스홀더 아님) + 관대한 전면 Area2D apron(Portal 내장).
- `_process` 진입존 폴링 → 플로팅 **"E 홈으로 돌아가기"** 프롬프트(Portal에 `prompt_override` 필드 신설).
- `_input` E-in-apron 입장(InteractionController보다 앞서 소비).
- 클릭/탭 → apron으로 워크덴엔터(touch_controller의 제네릭 Portal 처리 재사용, 무수정).
- 상태 글로우(OPEN 보라 vortex).
- grove(스폰 남쪽 우선 배치) + L2 터미널스테이션(스폰 남쪽) 양측 적용. L2측은 `terminal_station.gd._on_return_portal`이 홈 귀환.

**재감사(수동 귀환 경로)**: v052 stress 하네스가 리워크된 포탈로 여전히 그린 + **2개 hop 추가**: (A) apron 진입(플레이어를 `entry_stand_point`로 텔레포트 → `is_player_in_entry_zone` 참 확인 → 발광데코 배치 상태로 입장), (B) **오픈 fusion 모달을 전환 도중 닫기**(모달이 씬 해체를 가로질러 열려 있어도 wedge/크래시 없음).

---

## 검증 결과

- **Headless import: 0 에러**. 전 씬 클린.
- **하네스 21종 전부 그린**:
  - `l2_gates_harness` **41/41** — J1-J6 채집원 존재 + **gather→craft 풀체인**(전지/랜턴/퓨즈/코어조각 실제 레시피) + G1 브리지 walkable + G2 문+에너지+1 HUD + whisper_cost(부족 실패/충분 성공·소모) + G3 소지형 벽 + G4 정화 시그널·플래그·machine 전파·time_running 복구 + 세이브 dict + **L2 귀환 포탈 진입존/프롬프트**.
  - `v052_travel_stress` **32/32**(5사이클 + 2 extra hop) — 발광데코 왕복 5/5 생존, apron 진입, 오픈 fusion 닫힘. SCRIPT ERROR 스캔 클린.
  - 기존 회귀 전부(m2/m2i/m3/m4/m5/m6a/m7/m8/v021/v030/v031/v040/v040b/v040c/v050a/v050c/v051/l2_map/e2e) 0 실패.
- **recipe verify 툴** PASS(중복쌍 0, 도달성 OK). 툴의 R01..RNN 순차 체크를 L1(R**)/L2(L2-R**) 네임스페이스 분리로 갱신.

---

## 다음 (L2-4 / L2-5) 인계 포인트

1. **L2-4 데이터**: 42레시피 풀셋(L2-R09~R42) + J1-J7·D62~D102 아이콘 아트. J-아이템/D62·D63은 현재 카테고리 폴백 사각형. J7(재)은 게이트 무관 — 재지대(A) 타일 채집을 실제 배선(현재 스텁 아이템만 존재, A 타일 gatherable 미배선).
2. **L2-5 퀘스트/컷신**: quests.json L2-Q1~Q7 존재, QuestManager가 `power_node_energized`(L2-Q3/Q7) 소비. L2-Q4(blackout_gate)/Q6(control_tower)는 `player_entered_area` target 필요 — 아직 그 Area2D 이벤트 미발화(컨트롤러에 훅 자리만). 정화 컷신은 인라인 카드 — CS-04/05 정식 PortalCutscene 통합은 L2-5.
3. **아트 스왑 옵셔널**: 컨트롤러가 `l2_gen_sub_on.png`/`l2_door_open.png`/`l2_tower_on.png`/`l2_screen_on.png`를 있으면 스왑(`_tex_if_exists`) — 현재 없으면 글로우로 대체. 가동/개방 전용 아트는 L2-4 아트 패스에서.
4. **G3 병목 셀**: legend는 (18,14)(19,14)(18,15)(19,15)(18,16)(19,16) 3행이나, 로더가 ASCII의 중앙 스파인 N(row<17)에서 실제 sealed 셀을 파생(권위). 설계 §A-4는 14-15 2행 — 로더가 16행도 포함하므로 병목이 살짝 김(우회 불가엔 영향 없음, 필요시 L2-4에서 조정).

파일: 신규 `scripts/world/return_portal_controller.gd`, `scripts/core/whisper_currency.gd`, `scripts/ui/whisper_hud.gd`, `scripts/world/l2_gate_controller.gd`. 수정 grove_session/terminal_station/portal/map_loader/game_state/save_manager/recipe_db/fusion/fusion_ui/quest_manager/audio_manager + items/recipes/quests.json.
