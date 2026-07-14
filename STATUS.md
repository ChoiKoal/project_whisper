# STATUS — v1.10.3 릴리스 마감 (실 PCK 스모크 인계)

## 목표
v1.10.3 — 홈 언더사이드 아트 v3(암반 로브 분할·질감 클러스터링·지층 대비·엣지 정리).
비주얼 온리, 세이브 호환. v1.10.1~2 대체.

## 상태
- 하네스 스위프 65/65 그린 완주 · 무실패 (커밋 45cc17b).
- Godot 프로세스 없음(pgrep 무매치) → 실 PCK 스모크 재실행 진입.
- **주의**: game/export_presets.cfg preset.2(Linux arm64) exclude_filter 임시 해제(dev 포함 PCK용).
  이 dirty 상태는 커밋 금지 — 스모크 후 원복.

## 절차
1. dev 포함 export → e2e_playthrough + v142_home_layout_harness 각각 --main-pack 구동.
2. 프리셋 원복(git checkout -- game/export_presets.cfg), 트리 클린 확인.
3. v1.10.3 정식 범프(project.godot config/version + export_presets 3필드) + 태그 + push.
4. build_exports.sh → postprocess_macos_zip.py → GH 릴리스 + zip 2종.
5. 캡슐 갱신, docs/handoff-v1103.md, .sweep_done 제거, 트리 클린.
