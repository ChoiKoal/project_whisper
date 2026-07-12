# v1.9.1 릴리스 구간 재개 (3차)

## 완료 (git log)
- 신규 장식 15종 + 헤드리스 재-import
- 배치 치환 30.1% + 대각선 빈 회랑 3선 (dbaaade)
- l5s 4종 · spatial_audit 그린 (f07bee1)
- tools_overview_l5b 신규 장식 미러 (3c78375)

## 진행중
1. run_sweep 전체 65종 재개 (28 green skip → 나머지 37 실행)
2. 실 PCK 스모크 (e2e + l5s_flow)
3. 릴리스 v1.9.1 (버전 커밋+태그 → build_exports → postprocess → GH 릴리스 zip 2종)
4. 프리뷰 재렌더 (preview-l5.png + preview-l5-hero.png)
5. handoff-v191.md, .sweep_done 제거, 트리 클린, remote 동기화, #253
