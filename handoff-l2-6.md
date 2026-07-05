# handoff-l2-6 — Layer 2 최종 릴리스 (v0.6.0)

> v0.6.0. 기준: `docs/project-whisper-layer2-design-v1.md`.
> 상태: **L2-6 done — v0.6.0 릴리스 완료.** Layer 2 「꺼진 관문 기지」 완주.

## 요약
직전 에이전트(L2-6)가 남긴 미커밋 잔여물(E2E 확장 + KNOWN-ISSUES + export_presets 버전 + tools_overview_l2 --powered)을
**실측 재검증**하여 정상 확인 후 살려서 릴리스. 되돌린 것 없음. 모든 검증은 이 세션에서 실제 실행한 숫자.

## 1. 미커밋 잔여물 검토 (되살림)
- **`game/scenes/dev/e2e_playthrough.gd` (+290줄)** — `_stepL2_science_journey()` 추가. 참조 API 전수 확인
  (GameState.energize_power_node / is_power_node_energized / layer2_purified(_flag) / portal_state /
  reset_layer2 / powered_nodes, WhisperCurrency.energy, WorldContext.SCENE_TERMINAL, SaveManager.start_ng_plus /
  build_save_dict / unregister_world, MapLoader.legend_gates / l2_object_nodes / is_cell_walkable) — 전부 존재. **커버 충분, 보강 불필요.**
- **`KNOWN-ISSUES.md`** — v0.6.0 헤더 + 🔬 Layer 2 절(정직 수집 6항). 정상.
- **`game/export_presets.cfg`** — product/short/version 0.6.0(win/mac). include_filter `data/*.json, data/*.txt` 3프리셋 모두 유지. exclude_filter `scenes/dev/*` 유지. 정상.
- **`game/tools_overview_l2.js`** — `--powered` 모드(post-G4 점등 상태 offline 렌더). 정상.

## 2. E2E 풀저니 커버리지 (요건 1:1)
`_stepL2_science_journey`가 검증하는 실제 여정:
- science 포탈 flickering(첫 진입 = L1 개방 방식) → terminal_station 부팅(loader + L2GateController) → L2 라인(L2-Q1) 활성 + L1 라인(P2) 공존
- 게이트키 **실 Fusion 조합**(코덱에 discover): 전지 D64(구리도선+정류회로) / 네온랜턴 D65 / 퓨즈 D66 / 코어골격 D67→조각 D68×2→파워코어 D69
- G1 전지→브리지 순차점등 후 walkable(물리+AStar) → G3 랜턴 소지 시 정전 병목 통행(벽 콜리전 off) → G2 퓨즈/발전기 수리→차폐문 개방 + **에너지 Whisper +1**
- G4 파워코어(**whisper_cost 에너지 1 소모** 실측: energy N→N-1) → control_core 급전 → 정화 플래그 set + `layer2_purified` 시그널 발화
- 정화 전파: **science OPEN + machine(Layer3) flickering**
- 세이브 v2(powered_nodes[bridge,control_core] + 정화 플래그) → reset_layer2로 클로버 → 재진입+로드 → 정화/bridge/control_core/science OPEN **지속**
- NG+: L1+L2 union 코덱에서 3레시피 계승 + **양레이어 리셋**(전력노드/정화/포탈라인/Whisper 에너지 0)

## 3. 검증 결과 (실측)
- **e2e_playthrough.tscn: PASS, 0 failures** (Layer 1 + Layer 2 연속 완주, NG+ 포함).
- **테스트 하네스 스위프: 22/22 그린** (dev 씬 23개 중 `home_overview_render.tscn` 제외).
  - 그린: e2e, l2_flow, l2_gates, l2_map, m2/m2_integration/m3/m4/m5/m6a/m7/m8, v021/v030/v031/v040/v040b/v040c/v050a/v050c/v051/v052.
  - **`home_overview_render.tscn`는 테스트 하네스가 아님** — 홈섬 프리뷰 PNG를 뽑는 렌더 도구. `--headless` 더미 드라이버에는 GPU 프레임버퍼가 없어 SubViewport `get_image()`/`RenderingServer.frame_post_draw`가 멈춤(exit 124 타임아웃, 어서션 실패 아님). 프리뷰는 offline compositor(tools_overview_l2.js / home compositor)로 대체 — KNOWN-ISSUES에 문서화된 기존 환경 제약. 릴리스 블로커 아님.
- **Export 실빌드 검증**: 임시로 linux 프리셋 exclude_filter를 비워 dev 씬 포함 PCK 익스포트(6.18MB) → 실 PCK `--main-pack`으로:
  - e2e_playthrough: **PASS(0 fail)** / l2_flow_harness: **PASS(0 fail)** / v052_travel_stress: **PASS(0 fail)**
  - → 패킹된 `data/*.json`이 배포 빌드에서 정상 로드(= v0.1.1 데이터 미포함 크래시 회귀 없음). 검증 후 프리셋 **원복**(3프리셋 exclude=`scenes/dev/*` 복원, git diff는 버전 3줄만).
- **버전**: project.godot `config/version="0.6.0"` + export_presets 0.6.0(win product/mac short·version) + mac Info.plist CFBundleShortVersionString/CFBundleVersion 0.6.0.

## 4. 릴리스 산출물
`tools/build_exports.sh` (dev 미포함 클린 프리셋 + mac 후처리):
- **ProjectWhisper-win64-v0.6.0.zip** — 39.6 MB (ProjectWhisper.exe + README-실행방법.md)
- **ProjectWhisper-macos-v0.6.0.zip** — 67.9 MB (공백 없는 `ProjectWhisper.app`, `Resources/ProjectWhisper.pck`, `MacOS/ProjectWhisper`, Info.plist 0.6.0 — postprocess_macos_zip.py 6엔트리 리네임)
- 위치: `export/` + `dist/` 양쪽. mac zip에 "Project Whisper"(공백) 잔여 경로 0건 확인.
- 빌드 로그의 `gio/kioclient5/gvfs-trash` 에러는 무해(Godot가 리눅스에서 구파일 휴지통 이동 시도 실패 → 폴백 정상, zip 생성됨).

## 5. 릴리스
- 커밋: `v0.6.0 L2 complete: terminal station, power gates, whisper currency, full E2E` → push.
- GitHub 릴리스 v0.6.0 (한국어 노트) + win/mac zip 첨부.

## 알려진 항목 (KNOWN-ISSUES 참조)
- G4 파워코어 = D68+D68(조각 2개)+에너지 1 (2-입력 시스템 유지, whisper_cost로 재화소모 반영).
- 레시피 총계 104 (L1 62 + L2 42; L2-R23=J7 반환이라 신규 조합물 41).
- L2 아트 = 절차생성 아이콘/오브젝트(과학 팔레트), 손그림 패스 이전.
- 정전 병목(G3) = 국소 암전 오버레이 + 병목 벽 콜리전 토글(물리 라이팅 연출 TODO).
