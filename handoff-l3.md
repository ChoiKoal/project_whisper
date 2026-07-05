# Handoff — L3 (기계의 세계) → v0.7.0 릴리스

## 요약
Layer 3 「태엽이 멈춘 도시」(clockwork city) 구현 완료 + v0.7.0 릴리스. 3레이어 연속 플레이(홈→L1 세계수→L2 정화→L3 대시계 정화→machine OPEN + magic(L4) 포탈 flickering→귀환) 완주.

## 검증 (실측)
- **버전 문자열**: project.godot `config/version="0.7.0"`, export_presets(win product_version / mac short_version·version) 전부 0.7.0. bump 불필요(이미 정합).
- **전 하네스 스위프**: 25/25 그린, **908 PASS / 0 FAIL** (render 도구 home_overview_render 제외).
  - 신규 L3: `l3_map_harness` 24, `l3_gates_harness` 49, `l3_flow_harness` 29 — 전부 0 fail.
  - `e2e_playthrough` PASS(0 fail): 홈 각성 → L1 grove(디딤돌/물/밤/세계수 식재·클리어) → CS-05 점화 → L2 terminal_station(G1~G4 정화) → **L3 clockwork_city(G1~G4 대시계 재가동 정화)** → machine 포탈 OPEN + magic(Layer4) 포탈 flickering → 세이브/재진입 지속 → NG+ 3레이어 union 리셋.
- **Export 실빌드 검증**: linux 프리셋 exclude_filter 임시 blank → dev 포함 PCK(6.39MB) 익스포트 → `--main-pack`으로 e2e/l3_map/l3_gates/l3_flow/l2_flow/v052/sweep 전 PASS(0 fail). **l3_map_layout.txt / l3_map_height.txt / l3_map_legend.json PCK 실포함 바이트 확인**(include_filter `data/*.json, data/*.txt`가 신규 l3 파일 커버). 검증 후 프리셋 원복(git clean).

## 릴리스 산출물 (export/ + dist/)
- **ProjectWhisper-win64-v0.7.0.zip** — 39.67 MB (ProjectWhisper.exe embed-pck + README-실행방법.md)
- **ProjectWhisper-macos-v0.7.0.zip** — 68.0 MB (공백 없는 `ProjectWhisper.app`, Info.plist CFBundleShortVersionString/CFBundleVersion=0.7.0, postprocess 6엔트리 리네임, 잔여 공백경로 0건, PCK에 l3 데이터 포함 확인)

## 콘텐츠 (스펙: docs/project-whisper-layer3-design-v1.md)
- 게이트 4종: 톱니(브리지)/보일러(증기)/승강기(리프트)/대시계(정화 컷신) — 동력 게이트 체인.
- K원소 7종(K1~K7 채집) + 레시피 37종(태엽심장 등 게이트키 조합).
- 정화 시 machine 포탈 OPEN + magic(Layer 4) 포탈 flickering 전파, 멀티씬 세이브 v2 지속, NG+ 3레이어 리셋.

## 알려진 항목
- `home_overview_render.tscn`은 하네스 아님(헤드리스 GPU 프레임버퍼 없음 → SubViewport 캡처 불가). 프리뷰는 offline compositor 사용. 릴리스 블로커 아님.
- macOS 빌드 로그의 `gio/kioclient5/gvfs-trash` 에러는 무해(리눅스 휴지통 폴백 실패 → zip 정상 생성).

## 릴리스
- GitHub 릴리스 v0.7.0 (한국어 노트) + win/mac zip 2종 첨부. URL은 STATUS.md 로그 참조.
