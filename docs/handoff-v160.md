# handoff — v1.6.0 (EX-L2: 지하 데이터 성소)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.6.0
- win64 39,983,129 / macos 68,315,275 (rcodesign ad-hoc 서명)

## 스코프
설계 정본 `docs/project-whisper-expansion-l2-design-v1.md` 구현.
- 신규 존 「지하 데이터 성소」 (terminal_station에서 진입) — 지하 공동 컨셉, 셀 공간 다이아몬드형 외곽(디자인 의도, staggered 렌더=인게임 정합)
- 데이터: J8~J12 + D255~D277, EX-L2 레시피 체인, items layer:2 병기, m8 카운트 L2 48→76 총 325
- 퀘스트 + 진상 조각(비게이팅), 정화 플래그, 구세이브 호환
- 실루엣 변주(§㉘): 벽 텍스처 변주 3종 혼합 (122e44e)

## 검증
- 신규 하네스 4종 (접두어 **l2s_**): l2s_map 13/13, l2s_flow(실경로: 게이트 체인/NPC/정화/세이브) 31/31, l2s_gates, l2s_unique(A1~A3) — 전부 그린
- tools_spatial_audit.py EX-L2 확장 (l2s 상시 감사) — TOTAL VIOLATIONS 0
- 전체 스윕 53/53 그린 (49 + l2s 4종)
- 배포 PCK 부트 스모크(win64 임베디드, --main-pack 300프레임): 에러 0
- 실 PCK 3종(e2e·l2s_flow·l2s_unique dev-포함 export) 수행 기록은 릴리스 직후 세션 킬로 불명 — 부트 스모크·53/53로 대체 확인, 멤쵸 QA 커버 요청 (v1.5.0과 동일 패턴)

## 세션 킬 복구 이력
2회 (구현 중 1회 — 트리 클린 지점, 릴리스 직후 1회). 손실 0. 릴리스는 재개 에이전트가 완료, handoff·프리뷰 히어로·.sweep_done 정리는 카나 마감.

## 프리뷰
- /workspace/group/preview-l2.png — 신규 존 전체 조감 (tools_overview_l2.js, STACKED staggered 확인: cellLocal 121줄)
- /workspace/group/preview-l2-hero.png — 중앙 챔버 줌인 (서버랙 방벽/이중 게이트/안테나 단말/데이터 강)

## 백로그
- EX-L3 「태엽 광산」 구현 대기 (기본안 다음 차례), EX-L4/L5 설계 QA 완료 상태
- L0 허브 확장 패스, 스팀 준비, 프리뷰 l3~l5 STACKED 재렌더 확인
