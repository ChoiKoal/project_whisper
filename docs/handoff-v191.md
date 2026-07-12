# handoff — v1.9.1 (종의 들판 §㉙ 실루엣 변주 패스)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.9.1
- win64 40,296,392 / macos 68,628,375 (rcodesign ad-hoc 서명, verify OK — 2 slice ADHOC-signed, CodeResources sealed)
- macOS 번들 space-free 정합: ProjectWhisper.app/Contents/MacOS/ProjectWhisper + Resources/ProjectWhisper.pck (0 entries with space, 6 entries renamed).
- win64 zip: ProjectWhisper.exe + README-실행방법.md.
- 태그 v1.9.1 → main. 버전 커밋(466ff7b) 후 태그, 그 다음 빌드 순.

## 스코프 (기능 무변경 · 세이브 호환)
종의 들판(EX-L5 belfry, l5b) **§㉙ 실루엣 변주 아트 패스**. 게임플레이/데이터/게이트/세이브 스키마 무변경 — 순수 시각 다양화.
- 신규 장식 아트 15종(5종×3변주) — tools_gen_l5b_objects.js (6e4445d).
- **격자 절단**: 배치 치환 **30.1%** + 대각선 빈 회랑 **3선** (dbaaade) — 종실 격자의 단조로운 실루엣을 변주 오브젝트로 치환 + 빈 회랑으로 시선 리듬.
- tools_overview_l5b.js 신규 장식 미러 — art_variants 결정론적 변주 선택 (3c78375).

## 검증
- **전체 스윕 65/65 그린** (run_sweep.sh 재개형, 이번 세션 28 green skip → 나머지 37 실행 all PASS). game/.sweep_done 제거 완료.
- **실 배포 PCK 스모크 2종**(dev 포함 export→--main-pack→프리셋 원복): e2e_playthrough + l5s_flow 모두 **PASS (0 failures)**.
  - PCK 절차: preset.2「Linux arm64」exclude_filter 임시 해제(line 122) → `--export-pack` (dev 포함 pack 7,774,264B) → 각 하네스 `--main-pack`으로 구동 → 프리셋 원복(git status 클린 확인) → 임시 pack 제거.
- **tools_spatial_audit.py 그린** (f07bee1 — l5s 4종과 함께). 아트 변주는 walkable/게이트 재료 배치 무영향.
- 신규 장식 15종 헤드리스 재-import(.import 사이드카) 완료.

## 프리뷰
- /workspace/group/preview-l5.png (3256×1724) — 종의 들판 전체 조감, STACKED staggered. 격자 절단 자가 검수: 4변 완전 타일 종단, 절단 아티팩트 없음, 치환 변주 분포 확인.
- /workspace/group/preview-l5-hero.png (1600×1200) — 종탑 정점 great_bell + bellkeeper_shade 퍼즐실 줌인. 신규 장식 밀도/변주 반영. tools_overview_l5b.js (--hero).

## 구세이브 호환
아트-온리 패스 — 세이브 스키마·플래그·walkable 무변경. v131_saveregress 그린. 기존 세이브 로드/NG+ 리셋 정상.

## 빌드 환경 노트
- export 템플릿(4.5.stable)이 컨테이너에 **미설치**였음(세션 리셋 시 재발) — /workspace/group/tools/export_templates.tpz를 python zipfile로 추출(unzip 부재), templates/ 프리픽스 플래튼하여 /home/node/.local/share/godot/export_templates/4.5.stable/ 에 설치(36 entries, version.txt=4.5.stable)해야 build_exports.sh 통과.
- 버전 정합: project.godot config/version + export_presets.cfg 3종(product/short/application version) 모두 1.9.1 — v1.9.0 회귀 재발 없음.

## 남은 리스크
- 서명은 ad-hoc(notarize 아님) — macOS 첫 실행 시 우클릭 열기 또는 `xattr -dr com.apple.quarantine ProjectWhisper.app`. 기존 정책 동일.
- export 시 gio/kioclient5/gvfs-trash "child process" 에러 무해(컨테이너 trash 데몬 부재, 산출물 정상).
- 하네스 종료 시 "ObjectDB instances leaked at exit" / "N resources still in use at exit" WARNING — 하네스 teardown 잔여, exit 0·기능 무영향(기존과 동일).
- 이번 PCK 스모크는 스코프에 맞춰 2종(e2e + l5s_flow) — 아트-온리라 l5s_unique/데이터 하네스는 스윕 그린으로 커버.
