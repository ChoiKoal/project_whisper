# handoff — v1.10.2 (홈 섬 언더사이드 아트 개선 v2 — 부유섬 암반 검수 통과판)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.10.2
- 태그 v1.10.2 → main HEAD `32a3ee7`. GH 릴리스 zip 2종(win64 + macOS) 첨부.
- 태스크 #257. v1.10.1 언더사이드 1차안 KOAL 반려 → 재작업 검수 통과판 릴리스.
- **비주얼 온리 — 게임 로직/데이터/세이브 스키마 무변경. 세이브 100% 호환.**
- 릴리스 노트: "홈 섬 언더사이드 아트 개선 v2 — 부유섬 암반(유기 지층·침식 실루엣).
  비주얼 온리, 세이브 호환. v1.10.1 1차안 대체."

## v1.10.1 → v1.10.2 델타 (언더사이드 재작업)
v1.10.1이 외곽 추종 top_profile + 지층 밴딩으로 부유섬 암반을 도입했으나 KOAL 판정에서
1차안 반려. v1.10.2에서 아래 폴리시로 재작업(인게임 `cliff_gen.gd`/`map_loader.gd` +
컴포지터 `tools_overview_home.js` 미러 동일 유지):

- **톱니 V노치 void 제거**: top_profile을 전 island 타일 하부 엣지 + 타일 상단 정점까지 확장
  → 톱니 내부 노치 컬럼(63개) 하늘 관통 void 제거 (인게임+컴포지터 미러).
- **매달린 암괴 재조각**: 밝은 tan 컵/스파이크 제거 → 어둡게 recessed relief(스파인 하이라이트
  있는 3D 릴리프). 하부 바디 facet 구조 유지, 보라 rim 사이드 가중 강화.
- **지층 밴드 유기화**: 밴드 경계 지그재그+디더, 엣지 스트릭 제거(연속 wob), 딥팁 톤 통일.
- **캡슐 크롭**: 섬 전체 프레임인 재작성(1920×1080).

## 검증 (v1.10.2 릴리스 구간 실측)

### 하네스 스위프 — 65/65 그린, 실패 0
- `tools/run_sweep.sh` 전량 완주: **SWEEP COMPLETE (65/65, exit 0)** — 커밋 `32a3ee7`.
- (스위프는 프로세스 킬 후 `.sweep_done` 체크포인트로 재개, 9/65→65/65 무실패 완주.)

### 실 PCK 스모크 (dev 포함 real pack, `--main-pack`)
절차: `export_presets.cfg` preset.2「Linux arm64」 `exclude_filter` 임시 해제 →
`--export-pack` dev 포함 pack 생성 → 각 하네스 `--main-pack` 구동 → 프리셋 원복(트리 클린 확인).
- **dev 포함 PCK 크기: 7,802,948 B** (v1.10.1 릴리스 시 7,802,276 B 대비 +672 B).
- `e2e_playthrough` — **RESULT: PASS (0 failures)**, 250 assert PASS / 0 FAIL
  (L1~L5 전 라인 + G1~G4 정화 + 엔드게임 E1「완성」 + NG+ 라운드트립).
- `v142_home_layout_harness` — **RESULT: PASS (0 failures)**, 43 assert PASS / 0 FAIL
  (포탈 아치 대칭·홈데코 스폰·구 좌표 세이브 로드 clamp·코어 좌표 불변).
- (양 하네스 종료 시 Godot ObjectDB leak WARN/resource-in-use ERROR는 기존과 동일한
  무해 셧다운 로그, exit 0.)
- 프리셋 원복 후 `git status` 클린 — HEAD 무차이 확인.

## 릴리스 산출물
- `ProjectWhisper-win64-v1.10.2.zip` — **40,313,893 B** (Windows x86_64, ProjectWhisper.exe + README).
- `ProjectWhisper-macos-v1.10.2.zip` — **68,999,539 B** (macOS universal, ad-hoc 서명).
  - space-free 번들: `ProjectWhisper.app` / `Contents/MacOS/ProjectWhisper` /
    `Contents/Resources/ProjectWhisper.pck` (6 entries renamed).
  - 2 슬라이스 ADHOC CodeDirectory + `_CodeSignature/CodeResources` sealed 확인.
- 빌드: `tools/build_exports.sh` (Godot 4.5.stable 템플릿 + rcodesign 0.29.0).

## 프리뷰 / 캡슐 (재렌더 없음 — v1.10.1 산출 유지)
- `dist/apple-ready/screenshots/capsule-candidate-home.png` = `/workspace/group/preview-home-capsule.png`
  (md5 e6923c3…, 967,325 B) — 이미 동기.
- **아트 재수정·프리뷰 재렌더 금지** (검수 통과판 확정).

## 트리 / 리모트
- 태그 v1.10.2 → `32a3ee7` (main HEAD), push 완료.
- `game/.sweep_done` 제거(릴리스 아티팩트 아님).
- 트리 클린, remote 동기화 완료.
