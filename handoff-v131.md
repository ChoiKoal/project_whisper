# Handoff — v1.3.1 (세이브/진행 회귀 핫픽스: save regression fix)

Status: DONE. 릴리스 완료. 세이브 100% 호환(스키마 무변경).

## 무엇을 했나 (save regression fix)
KOAL 실플레이에서 발견된 진행 회귀 2건 + 이미 잠긴 세이브 자동 복구.

- **BUG A — L1 재방문 시 L2 포탈 재잠금.** L1(자연 숲)을 클리어해 science 포탈이 OPEN 된 뒤,
  L1을 다시 방문했다가 집으로 돌아오면 홈의 월드 스냅샷이 진행 플래그보다 오래되어 science
  포탈이 DORMANT로 되돌아가 진행이 막혔다.
- **BUG B — 정화한 숲 덤불 재입장 리셋.** 물을 준 숲 덤불이 숲을 나갔다가 재입장(포탈 왕복)하면
  원상태로 리셋됐다. 인-런 재입장 경로가 등록된 월드 스냅샷을 복원하지 않았다.
- **잠긴 세이브 자동 복구.** 위 버그로 이미 science/nature 포탈이 잠긴 채 디스크에 저장된
  세이브도, 로드 시 진행 플래그 기준으로 포탈을 재계산해 OPEN으로 자동 복구(마이그레이션 불필요).

## 원인 & 수정 (파일:라인)
- 근본 원인: 홈/월드 부팅이 오래된(혹은 이미 손상된) 스냅샷을 무조건 신뢰해 정화 완료 세계의
  포탈을 재잠금. 진행 플래그를 기준으로 한 단일-소스 재계산이 없었다.
- **`game/scripts/core/game_state.gd` — `reconcile_portal_line()` 신설.**
  진행 플래그(SaveManager.cleared / layer2~5_purified_flag) 기준으로 각 포탈을 "진행이 보장하는
  최소 상태"까지 UPGRADE(다운그레이드 없음·idempotent). 매 월드 부팅 시 호출 →
  포탈 라인 자기 치유. 이것이 BUG A 및 잠긴 세이브 자동 복구의 핵심.
- **`game/scripts/world/home_session.gd:~109` — CS-05 점화 비트 이후로 치유 지연.**
  return-ignition(첫 클리어 복귀 컷신)이 재생되는 부팅에서는 점화 연출이 끝난 뒤에
  `reconcile_portal_line()`을 호출해 오프닝/리빌 연출과 충돌하지 않게 함(픽스 커밋 c159434).
- **`game/scripts/core/save_manager.gd:440` — `restore_registered_world()`.**
  인-런 재입장 시 현재 씬의 인-메모리 월드 스냅샷 복원(BUG B). 각 world_session에서
  reconcile와 함께 호출(예: `game/scripts/world/grove_session.gd:62`, `:65`).
- 전 world_session(home/grove/cathedral/clockwork_city/mage_tower 등)이 부팅 시
  `GameState.reconcile_portal_line()` 호출 + 재입장 시 스냅샷 복원하도록 통일.

## 검증 (모두 실측)
- **재현 하네스 `v131_saveregress_harness`**: 재현→픽스 후 9 PASS / 0 fail.
  - A. L1 클리어 → L2 왕복 → 홈 복귀 시 science 포탈 OPEN 유지(노드 open+진입 가능).
  - B. 숲 덤불 개화(물주기) → 숲 나갔다 재입장 시 개화 상태 유지.
  - C. 디스크에 DORMANT로 저장된 잠긴 세이브 로드 시 science/nature 포탈 OPEN 자동 복구.
- **전 하네스 스위프 44/44 그린** (`tools/run_sweep.sh`, scenes/dev/ 전체, render 도구
  home_overview_render 제외, 전부 exit 0). 재개형 체크포인트(game/.sweep_done). 픽스 여파가 큰
  home/cutscene/save harness 5종(cutscene_harness·e2e_playthrough·endgame_harness·
  l2_flow_harness·sweep_harness)은 체크포인트를 신뢰하지 않고 강제 재실행해 재확인 — 전부 PASS.
- **실 PCK(--main-pack)**: linux 프리셋(preset.2) `exclude_filter` 임시 blank → dev포함 PCK(7.20MB)
  익스포트 → `v131_saveregress_harness`(9 PASS) / `e2e_playthrough`(0 failures) 전 RESULT PASS →
  프리셋 원복(3 preset 모두 exclude scenes/dev/* 확인)·임시 PCK 삭제.
- 익스포트 템플릿: 4.5.stable을 `/workspace/group/tools/export_templates.tpz`에서
  `~/.local/share/godot/export_templates/4.5.stable/`로 재설치(세션 초기 미설치 상태였음).

## 릴리스
- 버전 1.3.0→1.3.1 bump(project.godot config/version + export_presets win product_version·mac
  short_version/version). **버전 커밋·태그 v1.3.1을 빌드보다 먼저** 수행 후 푸시.
- win/mac 클린 빌드 (`tools/build_exports.sh`, dev 미포함):
  - win64: ProjectWhisper-win64-v1.3.1.zip (40,096,234 bytes, exe + README-실행방법.md)
  - macos: ProjectWhisper-macos-v1.3.1.zip (68,430,094 bytes, ProjectWhisper.app 무공백)
    - postprocess가 rcodesign ad-hoc 서명 + verify 수행 → "verify OK: 2 slice(s) ADHOC-signed, CodeResources sealed"
- GitHub 릴리스 v1.3.1 생성 + zip 2종 업로드(state=uploaded).
  URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.3.1

## 주의
- remote origin URL에 토큰이 임베드돼 있음 — 스크립트에서 변수로 추출하고 **절대 출력 금지**.
  (push·릴리스 API 호출 시 token을 변수에만 담고 로그에 노출하지 않음. 출력은 sed로 스크럽.)
- 세이브 100% 호환(진행 플래그 기준 재계산만 추가, 데이터/스키마 무변경). 잠긴 v1.3.0 세이브도
  로드 시 자동 복구되므로 별도 마이그레이션 안내 불필요.
