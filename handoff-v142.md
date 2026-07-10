# Handoff — v1.4.2 (L0 홈 섬 레이아웃 재저작: staggered 투영 기준, 포탈 아치 복원)

Status: DONE(레이아웃/하네스/세이브호환/스위프/프리뷰/릴리스). 게임 로직 변경 = 홈 레이아웃 데이터 + 세이브 로드 좌표 clamp뿐.

## 릴리스 (v1.4.2 — 완료 2026-07-10)
- HEAD=642f343 (버전 bump). 태그 v1.4.2 푸시 완료.
- GitHub 릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.4.2 (한국어 노트, zip 2종 uploaded).
- 산출: `ProjectWhisper-win64-v1.4.2.zip`(39,713,694 bytes) + `ProjectWhisper-macos-v1.4.2.zip`(68,045,769 bytes).
- mac ad-hoc 서명 verify OK(2슬라이스 ADHOC + CodeResources sealed, space-free ProjectWhisper.app).
- 실 PCK 검증: dev포함 linux PCK(6.83MB) → `--main-pack` v142_home_layout / e2e_playthrough / interaction_fusion 3종 PASS. 프리셋 원복(3 preset 모두 exclude scenes/dev/*, HEAD와 무차이).
- 프리뷰 재렌더: `/workspace/group/preview-home.png`(1600×824) — 컴포지터 = 인게임(staggered 정합).

## 진단 (재검증 불필요)
- 정본 투영: `whisper_tileset.tres` = ISOMETRIC / tile_layout=0 STACKED / tile_offset_axis=0 HORIZONTAL / 128×64.
  셀 로컬 = staggered `x=(col + 0.5·(row&1))·128, y=row·32` (홀수 행 +64px), map_to_local는 여기에 셀중심 오프셋(+64,+32) 가산.
- 구 `home_layout.txt`(22×22)는 옛 diamond 투영 `[(c-r)·64,(c+r)·32]`을 가정해 저작 → 실제 staggered 렌더에선
  "가로로 눌린 마름모 + 포탈이 좌측에 계단식으로 뭉침"(의도 구도 아님). KOAL 타깃 = 옛 diamond 렌더의 "포탈 아치" 구도
  (`/workspace/group/attachments/img-1783636503579-vzly.jpg`).

## 무엇을 했나

### 1. 홈 레이아웃 재저작 (staggered 기준) — `game/data/home_layout.txt`
- 그리드 22×22 → **21×17** (map_loader가 파일에서 W,H 읽음). legend/height override 무변경(height "none" 평지 유지).
- 심볼 의미 그대로(V/D/g/1~5/S/C/Y). 재배치:
  - **포탈 아치**(셀좌표): P1(7,5) P2(9,4) P3(10,3) P4(12,4) P5(13,5). P3 최상단 중앙, 좌→우 1→5.
  - **실좌표 아치**(cell_center_world, P3 기준 상대): P1(-384,+64) P2(-192,+32) **P3(0,0)** P4(+192,+32) P5(+384,+64).
    → X 완전 대칭(±384/±192, 오차 0), P1↔P5·P2↔P4 같은 Y, arch 곡선(P3 최상단).
  - **다이스 S**(10,9): 아치 중앙 X(P3와 동일 X)에 정렬, 아치 아래 중앙.
  - **솥 C**(7,12): 다이스 좌하 (실좌표 상대 x=-448, y=+96).
  - **관측석 Y**(14,11), 발광/마른풀 g 4셀 산재.
  - 섬 = staggered 스크린 bbox 1152×512 = **2.25:1**(가로로 긴 직사각), 하단 톱니 엣지(rows 14-16 taper + 알터네이팅 이빨).
- 지면 111셀 전부 S에서 4-연결 보행 도달(고립 0). 5개 포탈 남쪽 apron 셀 전부 보행 가능(포탈 EntryZone = gate 남쪽 forward+64 = (col,row+2) 셀).
- 컴포지터(`tools_overview_home.js`)는 이미 staggered 정합 → 렌더=인게임. 다이스/솥/포탈 traces·dead-grass·dais는 모두
  spawn_cell/portal_cells/cauldron_cell/g 셀 기반 data-driven이라 레이아웃 따라 자동 재배치(HomeSession 코드 무변경).

### 2. 세이브 호환 — `game/scripts/core/save_manager.gd`
- 문제: `apply_world_state`가 세이브의 플레이어 좌표를 **무검증 복원**. 구(舊)-레이아웃 홈 세이브 좌표가 새 슬랩의
  VOID(경계 충돌) 셀/슬랩 밖에 떨어지면 플레이어가 border collision에 갇힘.
- 수정: 복원 좌표를 `_nearest_walkable_world()`로 통과 — 이미 보행 가능 셀이면 **무변경**(정상 세이브 영향 0),
  아니면 링 탐색으로 가장 가까운 보행 가능 셀 중심으로 clamp(없으면 spawn_cell 폴백). 홈 전용 아님(등록된 모든 월드에 안전).

### 3. 회귀 하네스 정합
- `e2e_playthrough.gd` L211, `v050c_test_harness.gd` L147: 홈 차원 어서션 `22×22` → `21×17`. (그 외 포탈/스폰/CS-05 로직은 무변경 통과.)
- `home_overview_render.gd`: 주석 22×22→21×17.

## 신규/변경 파일
- `game/data/home_layout.txt` — staggered 재저작 (21×17, 포탈 아치).
- `game/scripts/core/save_manager.gd` — `_nearest_walkable_world` 로드 좌표 clamp.
- `game/scenes/dev/v142_home_layout_harness.{gd,tscn,gd.uid}` — 신규 하네스 (22 어서션).
- `game/scenes/dev/e2e_playthrough.gd`, `v050c_test_harness.gd`, `home_overview_render.gd` — 홈 차원 정합.
- `game/project.godot`, `game/export_presets.cfg` — 버전 1.4.1→1.4.2.
- `STATUS.md`, `KNOWN-ISSUES.md`, `handoff-v142.md`.
- 프리뷰 재렌더: `/workspace/group/preview-home.png`.

## 검증
- **신규 `v142_home_layout_harness` — 22/22 PASS**: (a)포탈 아치 대칭(P3 top·X대칭 오차0·같은 Y), (b)솥 좌하·다이스 중앙정렬,
  (c)S 보행 가능/고립 아님, (d)5 포탈 남쪽 apron 보행 가능, (e)섬 비율 2.25:1, (f)구 좌표 세이브 로드→유효 셀 착지(clamp).
- **전 하네스 스위프 46/46 그린** (tools/run_sweep.sh, .sweep_done 클리어 후 전량 재실행).
- **실 PCK**(`--main-pack`) v142/e2e/interaction_fusion 3종 PASS.

## 남은 리스크 / 다음
- 컴포지터 홈 데브리 islet 화면 오프셋은 여전히 diamond 시절 상수(장식, 인게임 미영향). v1.4.1 handoff의 underside taper 잔재 폴리시 후보와 동일 범위 밖.
- 아치 Y 스태거: staggered 홀수 행 +64px 특성상 P1/P5가 P2/P4보다 +32px 아래 → 자연스러운 아치 곡선(의도). 정확한 반원 아님(±32px 근사, 설계 허용).
- 세이브 clamp는 홈뿐 아니라 모든 월드 로드에 적용되나 "이미 보행 가능이면 무변경"이라 기존 세이브 회귀 없음(e2e 그로브 라운드트립 PASS로 확인).
