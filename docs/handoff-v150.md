# handoff — v1.5.0 (EX-L1: 고요의 화원 + 생명의 심장)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.5.0
- win64 39,887,215 / macos 68,220,351 (rcodesign ad-hoc 서명)

## 스코프
설계 정본 `docs/project-whisper-expansion-l1-design-v1.md` 구현 (멤쵸 QA 수정 반영: R33 = I15 소모).
- 신규 존 2: quiet_garden.tscn(고요의 화원) + life_heart.tscn(생명의 심장), grove→존 포탈, l1x_gate_controller
- 데이터: items.json I10~I17 + D222~D254, recipes.json EX-L1-R01~R33, 아이콘 41종 (m8 카운트 L1 71→112, 총 297)
- 퀘스트: N-gardener / N-constructor 2계열 + 진상 조각(비게이팅)
- 세이브: garden/heart_purified 플래그, WorldContext SCENE_GARDEN/SCENE_HEART, 구세이브 호환(reconcile_portal_line 비역행 + _nearest_walkable_world 클램프)

## 검증
- 하네스 3종 신설(map/gates/l1x_flow 실경로 — 실제 Cauldron, API 직접 호출 없음) + l1x_unique(유니크 촉매 A1~A3: I14 미소모·×2 없음·체인 무결)
- tools/tools_spatial_audit.py EX-L1 확장 (self-offering order-safe 모델) — TOTAL VIOLATIONS 0
- tools/l1x_bfs.py·l1x_recipes.py 증명 PASS (충돌검사 post-merge 정합)
- 전체 스윕 49/49 그린 (run_sweep.sh, v131_saveregress·v141_ysort·v142_home_layout 포함)
- 배포 PCK 부트 스모크(win64 zip 임베디드 pck, --main-pack 300프레임): 스크립트/파스/로드 에러 0

## 세션 킬 복구 이력
구현 중 세션 킬 6회 — wip 커밋 규율 + salvage 4회(eb15e38, d26918d, ea398a1, 0d477d7)로 손실 0. 릴리스는 5차 재개 에이전트가 완료, 최종 정리(본 문서·.sweep_done 제거)는 카나가 마감.

## 실픽스 (검증 과정에서 건진 것)
- 5896f33: EX-L1 닫힌 게이트 셀이 실제로 sealed되지 않던 버그 (flow 하네스가 검출)
- bc123e4 / 92c5e13: v040c functional-placement·m8 아이콘 커버리지 EX-L1 정합

## 프리뷰
- /workspace/group/preview-l1.png — 3면 합성(기존 숲 / 고요의 화원 / 생명의 심장), tools_overview_l1_ex.js (STACKED staggered)
- /workspace/group/preview-l1-hero.png — 생명의 심장 존 줌인 (2400×1800 캡처 → 1600×1200 area-avg)

## 남은 리스크 / 백로그
- 실 PCK 하네스 3종(e2e+l1x_flow+l1x_unique dev-포함 export) 재실행은 5차 에이전트 사망으로 수행 기록 불명 — 배포 PCK 부트 스모크·49/49 스윕으로 대체 확인, 멤쵸 QA에서 커버 요청
- L0 허브 확장 패스 백로그 유지, EX-L2~L5 구현 대기 (설계 QA 완료 상태)
