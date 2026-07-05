# Project Whisper — 개발 진행 상태

> 랄프 루프용 상태 파일. 각 마일스톤 완료 시 갱신.
> 기준 문서: /workspace/group/project-whisper-gdd-v0.1.md, project-whisper-art-style-guide.md, project-whisper-dev-plan.md

## 환경
- Godot 4.5 stable headless: `/workspace/group/tools/Godot_v4.5-stable_linux.arm64`
- 게임 프로젝트 경로: `/workspace/group/project-whisper/game/`
- 검증 명령: `cd /workspace/group/project-whisper/game && /workspace/group/tools/Godot_v4.5-stable_linux.arm64 --headless --import . 2>&1 | tail -5` (임포트+파스 체크)

## 마일스톤 상태
| 마일스톤 | 상태 | 검수 | 비고 |
|---|---|---|---|
| M0+M1 셋업+아이소 코어 | done | 카나 검수 통과 | |
| M2 채집 | done | 하네스 38/38 | |
| M3 Fusion+도감 | done | 하네스 56/56 + M2 회귀 통과 | 촉매 규칙 포함 |
| M4 시작의 숲 맵 | done | 하네스 30/30 + 회귀 전부 통과 | 게이트 4종+낮밤+리스폰 |
| M5 세이브/로드 | done | 하네스 34/34 + 회귀 통과 | NG+/타이틀/일시정지 포함 |
| M6 폴리시+패키징 | done | E2E 59/59 + 전 하네스 그린 | win/mac/linux 빌드 산출 |

## 로그
- 2026-07-05 02:36 — 루프 시작. Godot 4.5 arm64 확보, M0+M1 서브에이전트 착수.
- 2026-07-05 03:2X — M3 완료(레시피 50종로 확장 반영), 캐릭터 개선, 레벨디자인 v1 커밋. M4 착수.
- 2026-07-05 03:5X — M4 완료 (40x40 시작의 숲, 게이트/낮밤/클리어 연출). M5 착수 (세이브+NG+).
- 2026-07-05 04:0X — M5 완료 (세이브/NG+ 랜덤3계승/타이틀·일시정지). M6 착수.
- 2026-07-05 04:4X — M6 완료. E2E 플레이스루(채집→조합→G1~G4→클리어→세이브→NG+) 전체 통과. 설치형 빌드 3종 산출. 루프 완료.
- 2026-07-05 05:0X — v0.1.1: QA픽스 2건 (G1 디딤돌 안내 하이라이트+힌트, 밤 글로우 CanvasLayer 분리). 전 하네스 그린, 리빌드.
- 2026-07-05 10:4X — v0.1.2: macOS 크래시 하드닝 (유력: map_legend assert가 릴리스에서 제거되어 null FileAccess 참조 → 세그폴트) + 널 가드 6개소 + 타이틀 화면 리뉴얼 + m7 타이틀 플로우 하네스 추가. 8하네스 그린.
- 2026-07-05 11:0X — v0.1.3: 진범 확정+픽스. export include_filter 누락으로 data/*.json,*.txt가 PCK 미포함 → v0.1.1 크래시(assert 제거+null 핸들)와 v0.1.2 빈 맵의 공통 원인. 필터 추가, m7에 export 데이터 무결성 어서션 추가, 실제 export 빌드에서 m7 전체 통과 확인.
- 2026-07-05 12:0X — v0.2.1: 망토+지팡이 주인공, 오프닝 컷신, 드로우순서 버그(YSort z), 맵 경계 충돌, 조합 연출(쾌감). 하네스 10종 그린 + export 실빌드 검증.
- 2026-07-05 13:3X — v0.3.1 완성: UX 5건 + KOAL 조합식 CSV 통합(69아이템/62레시피, 디딤돌=암석+자갈 재배선, 석기 은퇴) + 남쪽 바위 스캐터 상향(G1 노가다 방지). 12/12 하네스 + export 실빌드 검증.
- 2026-07-05 15:2X — v0.4.0 완성: (a)인접채집/오브젝트발광커서/능선 (b)A안 캐릭터/가시덤불/모달UI/감성타이틀 (c)속삭임 퀘스트 Q1-Q9/배치 시스템 25종/프로시저럴 오디오 18종+BGM. 15하네스 그린.
