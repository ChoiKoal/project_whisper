# handoff — v1.10.3 (홈 섬 언더사이드 아트 개선 v3 — 암반 로브 재구성판)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.10.3
- 태그 v1.10.3 → main HEAD `434d0d5`. GH 릴리스 zip 2종(win64 + macOS) 첨부.
- v1.10.1 언더사이드 1차안·v1.10.2 재작업판을 대체하는 검수 통과판 릴리스.
- **비주얼 온리 — 게임 로직/데이터/세이브 스키마 무변경. 세이브 100% 호환.**
- 릴리스 노트: "홈 언더사이드 v3 — 암반 로브 분할·질감 클러스터링·지층 대비 강화·
  가장자리 결함 정리. 비주얼 온리, 세이브 호환. v1.10.1~2 대체."

## v1.10.2 → v1.10.3 델타 (언더사이드 v3)
v1.10.2가 톱니 void 제거·매달린 암괴 재조각·지층 밴드 유기화로 부유섬 암반을
정리했으나, v1.10.3에서 아래 폴리시로 추가 다듬기(인게임 `cliff_gen.gd`/`map_loader.gd` +
컴포지터 `tools_overview_home.js` 미러 동일 유지):

- **암반 로브 분할**: 하부 바디를 단일 매스에서 다중 로브로 분할해 실루엣 리듬 강화.
- **질감 클러스터링**: 표면 노이즈를 균질 산포 → 클러스터 배치로 재조직해 자연 암질감 강화.
- **지층 대비 강화**: 밴드 간 톤 대비를 높여 지층 가독성 향상.
- **가장자리 결함 정리**: 엣지 잔결함/미세 void 정리.

## 검증 (v1.10.3 릴리스 구간 실측)

### 하네스 스위프 — 65/65 그린, 실패 0
- `tools/run_sweep.sh` 전량 완주: **SWEEP COMPLETE (65/65, exit 0)** — 커밋 `45cc17b`.
- (스위프는 프로세스 킬 후 `.sweep_done` 체크포인트로 재개, 무실패 완주.)

### 실 PCK 스모크 (dev 포함 real pack, `--main-pack`)
절차: `game/export_presets.cfg` preset.2「Linux arm64」 `exclude_filter` 임시 해제 →
`--export-pack` dev 포함 pack 생성 → 각 하네스 `--main-pack` 구동 → 프리셋 원복(트리 클린 확인).
- `e2e_playthrough` — **RESULT: PASS (0 failures)**, 249 assert PASS / 0 FAIL
  (L1~L5 전 라인 + G1~G4 정화 + 엔드게임 E1「완성」 + NG+ 라운드트립).
- `v142_home_layout_harness` — **RESULT: PASS (0 failures)**, 43 assert PASS / 0 FAIL
  (포탈 아치 대칭·홈데코 스폰·구 좌표 세이브 로드 clamp·코어 좌표 불변).
- (양 하네스 종료 시 Godot ObjectDB leak WARN/resource-in-use ERROR는 기존과 동일한
  무해 셧다운 로그, exit 0.)
- 프리셋 원복 후 `git status` 클린 — HEAD 무차이 확인(3 preset 모두 `exclude scenes/dev/*`).
- (dev 포함 PCK footprint는 v1.10.2 대비 아트 변경만 반영 — 비주얼 온리로 데이터/코드 무변경.)

## 릴리스 산출물
- `ProjectWhisper-win64-v1.10.3.zip` — **40,315,798 B** (Windows x86_64, ProjectWhisper.exe + README).
- `ProjectWhisper-macos-v1.10.3.zip` — **69,001,681 B** (macOS universal, ad-hoc 서명).
  - space-free 번들: `ProjectWhisper.app` / `Contents/MacOS/ProjectWhisper` /
    `Contents/Resources/ProjectWhisper.pck` (7 entries, 공백 0 확인).
- 빌드: `tools/build_exports.sh` (Godot 4.5.stable 템플릿) + `tools/postprocess_macos_zip.py`.

## 프리뷰 / 캡슐 (재렌더 없음)
- `dist/apple-ready/screenshots/capsule-candidate-home.png` = `/workspace/group/preview-home-capsule.png`
  (md5 6efa177…, 975,820 B) — 동기화됨.
- **아트 재수정·프리뷰 재렌더 금지** (검수 통과판 확정).

## 트리 / 리모트
- 태그 v1.10.3 → `434d0d5` (main HEAD), push 완료.
- `game/.sweep_done` 제거(릴리스 아티팩트 아님).
- 트리 클린, remote 동기화 완료.
