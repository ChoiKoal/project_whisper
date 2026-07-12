# handoff — v1.7.0 (EX-L3: 태엽 광산)

릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.7.0
- win64 40,070,606 / macos 68,403,206 (rcodesign ad-hoc 서명)

## 스코프
설계 정본 `docs/project-whisper-expansion-l3-design-v1.md` 구현.
- 신규 존 「태엽 광산」 — clockwork_city에서 승강로 하강 진입, 4단 하강 티어, GM1~GM4 게이트 체인, 최심부 excavator_core. SCENE_MINE + mine_purified 플래그 + NG+ 리셋.
- 데이터: K8~K12 + D278~D300, EX-L3 레시피 체인(l3x_recipes.py 멱등화 PASS), 아이콘 28종 — 도감 총 353 (m8 L3 44→72)
- map_loader l3xobj 스폰 분기 신설 (기존 오브젝트 미스폰 갭 실픽스 d95bffe)
- 실루엣 신기준(멤쵸 v1.6.0 QA): 설비 변주 4종×3 + 빈 타일 리듬 — 단일 구조물 줄반복 없음

## 검증
- 신규 하네스 4종(l3s_map/l3s_gates/l3s_flow/l3s_unique) 그린 — flow는 실경로(실제 Cauldron), unique는 A1~A3
- tools_spatial_audit.py EX-L3(l3m) 확장 — GM1~GM4 공간 순서 강제 + K12 self-offering, TOTAL VIOLATIONS 0
- 전체 스윕 57/57 그린 (53 + l3s 4종; v040c EX-L3 반영 포함)
- 배포 PCK 부트 스모크(win64 임베디드, 300프레임): 에러 0
- 실 PCK 3종(dev 포함 export) 수행 기록은 릴리스 직후 세션 킬로 재차 불명 — 부트 스모크·57/57로 대체 확인, 멤쵸 QA 커버 요청 (v1.5.0/v1.6.0과 동일 패턴)

## 구세이브 호환
reconcile_portal_line 비역행 + _nearest_walkable_world 클램프 + v131_saveregress 그린. L3 클리어 세이브 → 승강로 진입 게이팅 정상.

## 세션 킬 복구 이력
4회 (salvage 3회: f23a879 데이터, 64f770f 하네스 uid, a7579ec v040c). 손실 0. 릴리스는 3차 재개 에이전트 완료, handoff·정리는 카나 마감.

## 프리뷰
- /workspace/group/preview-l3.png — 광산 전체 조감 (tools_overview_l3m.js, STACKED staggered)
- /workspace/group/preview-l3-hero.png — 승강로+GM 게이트 구간 줌인 (최심부는 스포일러 회피로 미노출)

## 백로그
- EX-L4 「부유 서고」 구현 (다음 기본안), EX-L5 「침묵의 종탑」 대기
- L0 허브 확장, 스팀 준비, preview-l4/l5 STACKED 재렌더 확인
