# handoff-l2-5 — Layer 2 흐름 (포탈/퀘스트/정화/세이브/HUD)

> v0.6.0-wip L2-5. 기준: `docs/project-whisper-layer2-design-v1.md` Part C-3/C-4.
> 상태: **L2-5 done.** 릴리스 없음(0.6.0 미상승 — L2-6 담당).

## 감사(audit): L2-3에 이미 있던 것 vs 실제 갭
L2-3가 정화 컷신·귀환 포탈·Whisper HUD·퀘스트 데이터(L2-Q1~Q7)·multi-scene 세이브를 이미 구현. 검증 중 **3개 실제 갭** 발견 후 수정:

### 갭 1 — 홈 science 포탈이 grove로 라우팅 (핵심)
`home_session._travel_to_layer`가 `dest := SCENE_GROVE`를 **모든** 레이어에 하드코딩(v0.5 잔재) → science 포탈이 터미널 스테이션이 아니라 grove를 열었음.
- **수정**: `WorldContext`에 `SCENE_TERMINAL`/`TERMINAL_SCENE_PATH` + `layer_scene(layer)`(nature→grove, science→terminal) 추가. `_travel_to_layer`가 `WorldContext.layer_scene(layer)`로 분기.

### 갭 2 — L2 퀘스트 라인이 활성화되지 않음 + 공존 불가
QuestManager는 단일 `active_id`. L1 라인이 P3(`next:""`,`signal:never`)에서 종료 → L2-Q1~Q7이 뒤에 나열돼도 절대 시작 안 됨. 로그 공존 개념 없음.
- **수정**: QuestManager에 **2번째 독립 포인터** `l2_active_id`/`l2_progress` 추가. `_event`가 두 라인 모두에 신호 라우팅. `activate_l2_line()`(첫 L2 진입 시 terminal_station이 호출, 멱등). `_start`/`_complete`/`to_dict`/`from_dict`/`reset`가 두 라인 처리. quest_log가 두 라인의 활성 행을 ▸로 표시.

### 갭 3 — 정화 후 science 포탈이 OPEN이 되지 않음
`terminal_station._on_layer2_purified`가 machine→FLICKERING만 하고 science→OPEN 누락.
- **수정**: science→PORTAL_OPEN(자유 왕래) + machine→FLICKERING 둘 다 설정(nature→open 패턴 계승).

## 흐름 5요건 최종 상태
1. **홈 science 포탈 → terminal_station**: L1 정화 시 flickering(P1 개방조건, CS-05가 이미 set), 레이어별 라우팅 픽스. 귀환 = L2 return 포탈(L2-3 리워크) — 검증 통과.
2. **퀘스트 L2-Q1~Q7 공존**: 첫 L2 진입 활성, L1 라인과 두 포인터 독립, 세이브 지속.
3. **정화 → Layer3 flickering + science OPEN**: `_on_layer2_purified` 전파.
4. **멀티씬 세이브 v2**: terminal_station = `_worlds["terminal_station"]` 스냅샷 + powered_nodes/정화 플래그/Whisper/퀘스트 2라인 지속. NG+ = reset_layer2 + QuestManager.reset(두 라인 초기화).
5. **Whisper HUD 획득 시만**: L2-3 구현, l2_flow_harness에서 재확인(G2 후 energy>0 → 패널 visible).

## 신규 하네스
- `scenes/dev/l2_flow_harness.tscn` (27 checks). 실 terminal_station 부팅 → L1 cleared set → science flickering + 라우팅 → 첫 L2 진입 L2 라인 활성 → G1(gather/craft로 L2-Q1→Q3 진행 + bridge 급전)→G3 랜턴→G2(에너지 Whisper +1 assert)→G4(파워코어 정화) → science OPEN + machine flickering assert → 세이브 v2 2라인 지속 + 라운드트립 + NG+ 리셋.

## 검증
- **l2_flow_harness 27/27 PASS.**
- 회귀 전부 그린: e2e_playthrough(L1 플로우 무변경), v040/v040b/v040c(퀘스트), v050c/v051/v052(포탈·세이브·travel), m5(세이브), l2_map/l2_gates, m2/m3/m7/m8 — **전 21 하네스 PASS**, import 0 에러.

## 남은 것 (L2-6)
- 버전 0.6.0 상승 + 릴리스 빌드. 홈 island 씬에 science 포탈 아트/입장 최종 폴리시(포탈 오브젝트는 portal_state_changed 이미 listen → 아트 무수정 재사용).
