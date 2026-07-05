# Project Whisper — 개발 진행 상태

> 랄프 루프용 상태 파일. 각 마일스톤 완료 시 갱신.
> 기준 문서: /workspace/group/project-whisper-gdd-v0.1.md, project-whisper-art-style-guide.md, project-whisper-dev-plan.md

## 환경
- Godot 4.5 stable headless: `/workspace/group/tools/Godot_v4.5-stable_linux.arm64`
- 게임 프로젝트 경로: `/workspace/group/project-whisper/game/`
- 검증 명령: `cd /workspace/group/project-whisper/game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import . 2>&1 | tail -5` (임포트+파스 체크)

## 마일스톤 상태
| 마일스톤 | 상태 | 검수 | 비고 |
|---|---|---|---|
| M0+M1 셋업+아이소 코어 | done | 카나 검수 통과 | |
| M2 채집 | done | 하네스 38/38 | |
| M3 Fusion+도감 | done | 하네스 56/56 + M2 회귀 통과 | 촉매 규칙 포함 |
| M4 시작의 숲 맵 | done | 하네스 30/30 + 회귀 전부 통과 | 게이트 4종+낮밤+리스폰 |
| M5 세이브/로드 | done | 하네스 34/34 + 회귀 통과 | NG+/타이틀/일시정지 포함 |
| M6 폴리시+패키징 | done | E2E 59/59 + 전 하네스 그린 | win/mac/linux 빌드 산출 |
| L2-1 과학 타일셋+오브젝트 | done | l2_map_harness 26/26 | M/m/C/c/G/A/W 타일 + 금속 절벽 + 오브젝트 12종 아트/씬 |
| L2-2 터미널 스테이션 맵 | done | l2_map_harness 26/26 | l2_map 데이터 3종(§A-2 byte-identical) + terminal_station.tscn + 프리뷰 |
| L2-3 게이트+전력계 (+귀환 포탈 리워크) | done | l2_gates_harness 41/41 + v052 stress 32/32 + 전 하네스 그린 | PowerNode(power_node_energized)/G1 브리지 순차점등/G2 차폐문+에너지Whisper/G3 정전 소지형/G4 관제탑 정화컷신 + WhisperCurrency(에너지) HUD·세이브·조합 재화소모 + J1-J7 채집 스텁 + 게이트체인 레시피 L2-R01~R08 + 귀환 포탈 리워크(grove+L2, 진입존 프롬프트/E/클릭워크) |
| L2-4 데이터 (아이템/레시피/아이콘/채집) | **L2-4 done** | verify_recipes 104/104 PASS + m8 아이콘 116/116 유니크 + m3 56/56 + l2_map/gates 그린 | items.json D62~D102 완비(41 조합물, layer:2 + placement 클래스) + recipes.json L2-R01~R42 전종(42 레시피; L2-R23=J7 반환; L2-R08 파워코어 whisper_cost) + 아이콘 48종 신규(과학 팔레트: 금속 회색/시안 발광/네온, tools_gen_icons 확장) ItemDB 커버리지 + 채집 소스(J1-J7 legend wired, A타일 J7, parts_box J2/J4 분기) — Part B와 1:1 |
| L2-5 흐름 (포탈/퀘스트/정화/세이브/HUD) | **L2-5 done** | l2_flow_harness 27/27 + e2e(L1)/v040/v050c/v051/v052 회귀 그린 + 전 21 하네스 PASS | (1) 홈 science 포탈 → **terminal_station 라우팅**(home_session `_travel_to_layer` 레이어별 분기 + WorldContext.layer_scene/SCENE_TERMINAL — v0.5 grove 하드코딩 픽스). (2) **L2 속삭임 라인 L2-Q1~Q7 공존**(QuestManager 2번째 활성 포인터 `l2_active_id`, 첫 L2 진입 시 activate_l2_line, 두 라인 세이브 지속·퀘스트 로그 동시 표시). (3) 정화 → **science OPEN + machine(Layer3) flickering** 전파(terminal_station `_on_layer2_purified`). (4) 멀티씬 세이브 v2(powered_nodes/정화 플래그/Whisper/2라인) + NG+ 리셋. (5) Whisper HUD 획득 시만(L2-3 검증). |
| **v0.6.1 안정화 스윕** | **done** | sweep_harness 26/26 + 22 회귀 하네스 그린 + 실 PCK(--main-pack) sweep/e2e/v052 PASS | 정적 감사 클린(assert 0·set_script 타입정합·FileAccess null가드·export필터 L2데이터 커버). 버그 2건 수정: clear_sequence 클리어 후 time_running 미복원(🔴 홈 시간정지) + player 컷신 중 키보드워크 미프리즈(🟡 연출관통). is_world_frozen() 헬퍼 추출. 신규 sweep_harness(클리어전 귀환 왕복/컷신 중 이동/G3 무랜턴·G4 에너지0 거부/ESC연타). 버전 0.6.1. |
| **L2-6 릴리스 (E2E 양레이어 완주 + v0.6.0)** | **done** | **e2e_playthrough 전 PASS(0 fail, 양레이어 완주) + 실 PCK(--main-pack) e2e/l2_flow/v052 전 PASS + 테스트 하네스 22/22 그린** | E2E 풀저니 확장(`_stepL2_science_journey`): science 포탈(flickering) 진입 → terminal_station 부팅 → 게이트키 실 Fusion 조합(전지 D64/랜턴 D65/퓨즈 D66/파워코어 D69, 같은 코덱에 discover) → G1 브리지 순차점등 walkable → G3 네온랜턴 소지 통행 → G2 퓨즈/발전기+에너지 Whisper +1 → G4 파워코어(whisper_cost 1 소모) → Layer2 정화컷신 → science OPEN·machine flickering 전파 → 세이브→재진입 지속 → NG+ 양레이어 리셋(L1+L2 union에서 3레시피 계승). Export 실빌드 검증(임시 dev-포함 linux PCK로 e2e/l2_flow/v052 전 PASS, include_filter data/*.json·txt 유지 확인, 프리셋 원복). project.godot·export_presets 버전 0.6.0. win/mac 클린 빌드(dev 미포함) + mac 후처리(ProjectWhisper.app 공백제거). *note: home_overview_render.tscn은 테스트 하네스 아님 — 헤드리스 SubViewport 캡처 불가(GPU 프레임버퍼 없음), 프리뷰 PNG 생성 도구로 offline compositor(tools_overview_l2.js) 대체.* |

## 로그
- 2026-07-06 01:3X — **v0.6.1 stability sweep**. 정적 감사 클린: assert() 0건(과거 제거 완료 확인), set_script 5건 전부 노드타입 정합(quest_marker/ground_jitter=Node2D, cauldron=Sprite2D, backdrop_canvas=Control), light_pool scr.new() 풀 전부 Sprite2D 정합, FileAccess.open 8곳 전부 null 가드, export include_filter(data/*.json,*.txt)가 L2 신규 데이터(l2_map_*.txt, l2_map_legend.json 등) 전부 커버. **버그 2건 발견·수정**: (1) 🔴 `clear_sequence.gd:120` — CS-04 정화 컷신이 `time_running=false`만 걸고 `cleared` emit 전에 복원 안 함 → 클리어 후 홈 섬이 시간 정지 상태로 부팅(낮/밤 정지·HomeSession 영구 락). autoload 플래그라 씬 넘어가도 잔류. `cleared` emit 직전 `time_running=true` 복원. (2) 🟡 `player/player.gd:98` — 키보드 워크가 `ui_modal_open()`만 프리즈 → 컷신(time_running=false/control_lock) 중 이동키 유지 시 연출 뚫고 걸어감(v0.5.1 키 고착 계열). freeze 조건을 TouchController._world_locked()와 동일하게(modal OR not time_running OR control_locked) 확장, `is_world_frozen()` 헬퍼로 추출(하네스 검증 가능). L2 정화 컷신은 time_running false→true 페어링 확인(별도 버그 아님). **신규 sweep_harness**: A 클리어컷신 time 복원, B 컷신 중 키보드-워크 프리즈, C 클리어 전 수동 귀환 왕복+재진입, D G3 무랜턴 정전벽·G4 에너지0 파워코어 거부, E 컷신 ESC연타 idempotent. 22 기존 하네스 회귀 그린. 버전 0.6.1 bump.
- 2026-07-05 02:36 — 루프 시작. Godot 4.5 arm64 확보, M0+M1 서브에이전트 착수.
- 2026-07-05 03:2X — M3 완료(레시피 50종로 확장 반영), 캐릭터 개선, 레벨디자인 v1 커밋. M4 착수.
- 2026-07-05 03:5X — M4 완료 (40x40 시작의 숲, 게이트/낮밤/클리어 연출). M5 착수 (세이브+NG+).
- 2026-07-05 04:0X — M5 완료 (세이브/NG+ 랜덤3계승/타이틀·일시정지). M6 착수.
- 2026-07-05 04:4X — M6 완료. E2E 플레이스루(채집→조합→G1~G4→클리어→세이브→NG+) 전체 통과. 설치형 빌드 3종 산출. 루프 완료.
- 2026-07-05 05:0X — v0.1.1: QA픽스 2건 (G1 디딤돌 안내 하이라이트+힌트, 밤 글로우 CanvasLayer 분리). 전 하네스 그린, 리빌드.
- 2026-07-05 10:4X — v0.1.2: macOS 크래시 하드닝 (유력: map_legend assert가 릴리스에서 제거되어 null FileAccess 참조 → 세그폴트) + 널 가드 6개소 + 타이틀 화면 리뉴얼 + m7 타이틀 플로우 하네스 추가. 8하네스 그린.
- 2026-07-05 11:0X — v0.1.3: 진범 확정+픽스. export include_filter 누락으로 data/*.json,*.txt가 PCK 미포함 → v0.1.1 크래시(assert 제거+null 핸들)와 v0.1.2 빈 맵의 공통 원인. 필터 추가, m7에 export 데이터 무결성 어서션 추가, 실제 export 빌드에서 m7 전체 통과 확인.
- 2026-07-05 12:0X — v0.2.1: 망토+지팡이 주인공, 오프닝 컷신, 드로우순서 버그(YSort z), 맵 경계 충돌, 조합 연출(쾌감). 하네스 10종 그린 + export 실빌드 검증.
- 2026-07-05 13:3X — v0.3.1 완성: UX 5건 + KOAL 조합식 CSV 통합(69아이템/62레시피, 디딤돌=암석+자갈 재배선, 석기 은퇴) + 남쪽 바위 스캐터 상향(G1 노가다 방지). 12/12 하네스 + export 실빌드 검증.
- 2026-07-05 15:2X — v0.4.0 완성: (a)인접채집/오브젝트발광커서/능선 (b)A안 캐릭터/가시덤불/모달UI/감성타이틀 (c)속삭임 퀘스트 Q1-Q9/배치 시스템 25종/프로시저럴 오디오 18종+BGM. 15하네스 그린.
- 2026-07-05 23:0X — v0.6.0-wip L2-1/L2-2 완료: 제2세계(과학) 「꺼진 관문 기지」 40×40. 과학 타일셋(금속/콘크리트/황무지/재/냉각수 + 금속 절벽 리컬러) + 데이터 드리븐 L2 오브젝트(관제탑/스크린/안테나/발전기/배전반/브리지/차폐문/네온/잔해/부품상자/유리돔/가로등/정비대). l2_map_layout.txt는 설계 §A-2와 byte-identical. terminal_station.tscn 클린 부팅(L2 오브젝트 115개 전부 텍스처, 게이트 STATIC-CLOSED, 고도 +2관제탑/+1플랫폼). l2_map_harness 26/26. 프리뷰 preview-l2.png(+협곡 클로즈업) — 남색/시안 무드·냉각수 협곡 확인. 게이트 로직 = L2-3.
- 2026-07-05 23:5X — v0.6.0-wip L2-3 완료 (+귀환 포탈 리워크): (A) 전력 게이트 4종 — GameState.power_node_energized 시그널(디딤돌 패턴 대응) + 배전반 장착. G1 전지→브리지 순차점등+walkable(AStar 갱신), G2 퓨즈→발전기 수리→차폐문 개방 + **에너지 Whisper +1**(WhisperCurrency 오토로드, 좌상단 HUD 보유시만, 획득 연출, 세이브), G3 네온랜턴 소지형(정전 병목 Area2D+국소암전), G4 파워코어(에너지 1 소모)→관제탑 정화컷신→machine 포탈 flickering 전파+귀환. RecipeDB.whisper_cost 필드 + Fusion 재화 게이트. J1-J7 채집 스텁(items.json, L2-2 오브젝트 wired, s상자 J2/J4 셀패리티) + 게이트체인 레시피 L2-R01~R08(전지/랜턴/퓨즈/코어골격/조각/파워코어). (B) 귀환 포탈 리워크 — ReturnPortalController 공용 클래스(진입존 프롬프트 루프+E+클릭워크), grove/L2 양측 홈 포탈과 동일 패턴("E 홈으로 돌아가기"). l2_gates_harness 41/41(gather→craft→mount 풀체인), v052 stress 32/32(신 포탈 진입존 + 발광데코 + 오픈 fusion 닫힘 hop 추가), 전 21 하네스 그린, import 0 에러. 릴리스 없음.
- 2026-07-06 01:1X — **v0.6.0 L2-6 릴리스 완주**: E2E 풀저니 하네스에 Layer 2 전 여정 확장(`_stepL2_science_journey`, +290줄) — science 포탈→terminal_station→게이트키 실조합→G1 브리지/G3 랜턴/G2 퓨즈+에너지Whisper/G4 파워코어(whisper_cost)→정화→science OPEN·machine flickering 전파→세이브/재진입 지속→NG+ 양레이어 리셋(union 3레시피 계승). **재검증 실측**: e2e_playthrough 0 fail(양레이어), 테스트 하네스 22/22 그린(home_overview_render는 프리뷰 렌더 도구, 헤드리스 GPU 캡처 불가라 제외). Export 실빌드 검증 — 임시 dev-포함 linux PCK 익스포트 후 실 PCK(--main-pack)로 e2e/l2_flow/v052 전 PASS(패킹된 data/*.json 정상 로드 = v0.1.1 데이터 미포함 회귀 없음), include_filter 유지 확인, 프리셋 원복. project.godot·export_presets 버전 0.6.0. win/mac 클린 빌드 + mac 후처리(ProjectWhisper.app 공백제거·pck 리네임·Info.plist 0.6.0). 산출: ProjectWhisper-win64-v0.6.0.zip(39.6MB), ProjectWhisper-macos-v0.6.0.zip(67.9MB) → export/ + dist/. 커밋·푸시 + GitHub 릴리스 v0.6.0.
