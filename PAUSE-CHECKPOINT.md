# Whisper 작업 중단·재개용 저장 기록

- 사용자 최신 지시: 하던 것만 마무리하고 현재 진행 지점 저장. 새 작업은 하지 않는다.
- 출처: https://discord.com/channels/1381853645351682048/1523010172434386946/1549813719658401943
- 이 문서는 부모가 직접 확인한 저장 시점 기록이며, 작업자의 최종 보고서/프로세스 종료 확인을 대신하지 않는다.

## 어디까지 했는가

- unit16: 카나의 채집 상태 모듈을 실제 E/탭 입력에 연결, 접촉 전 취소와 정확히 한 번 지급·저장 경계 처리, 기초 반응/소리 구현. 전체 손맛·아트·재미 승인은 아니다.
- unit17: 맵1 v2 내부 V 구간의 검은 공백과 연결부·모서리 표시를 보완. 높은 옛 벽을 일괄 복원하거나 충돌/세이브 의미를 평탄화하는 방식은 쓰지 않는 범위로 작업했다.
- 완료 영수증 기준 아래 검증은 실제 실행되었고 모두 completion_verified=true다. 각기 다른 범위이므로 숫자를 합쳐 전체 승인으로 해석하지 않는다.
  - pixels-final3: 140 PASS / 0 FAIL, 엔진 ERROR 0줄.
  - movement-final-source: 211 PASS / 0 FAIL, 엔진 ERROR 0줄.
  - normal-final-v2: 199 PASS / 0 FAIL, 엔진 ERROR 26줄.
  - normal-final-legacy: 207 PASS / 0 FAIL, 엔진 ERROR 26줄.

- 정상 루프는 새 맵/기존 맵 모두 저장 후 재방문까지 실행. 각 정상 루프의 기존 Fusion lambda 오류 26줄은 미해결이다.
- 최종 비교 이미지의 검은 공백 감소·연결 개선은 부모가 확인했지만, 모든 어두운 경계 제거 또는 전체 미감 승인으로 확대하지 않는다. 위치/시간 주입 전후 캡처와 실제 정상 플레이 증거를 구분한다.

## 반드시 기억할 사용자 반려

1. **덤불 쪽 디자인 불합격 — 다음 재개 시 재설계 대상.** 기능 검증과 미감 승인 별개.
2. **디딤돌 디자인 불합격 — 다음 재개 시 재제작 대상.** 조합/배치·길 연결·세이브 계약은 보존.
3. 두 대상 모두 이번에는 기록만 한다. 지금 새로 고치지 않는다.
4. NightGate R3 야간 미감도 기존 REWORK 유지. 전체 UI/모바일/다른맵 아트/사람의 재미 검수는 미완료.

## 보존 위치 / Git 경계

- 실제 최신 작업 소스: `../whisper-world-objects/game/` (unit16+17 로컬 변경 포함).
- 근거: `../whisper-world-objects/evidence/16-harvest-integration/`, `../whisper-world-objects/evidence/17-map1-final-cleanup/`.
- 부모 소스 지문/검증 목록: `../whisper-team-handoffs/week-pause-source-receipt.json`.
- 원격 공유본 PR#4 `ea806bb96520fb766b2a54edb730ff75db830bef`는 unit15다. 로컬16/17이 원격에 올라갔다거나 main에 머지됐다고 읽지 않는다.
- 미완료 독립검수·남은오류를 보존하고 전체 프로젝트 완료로 표시하지 않는다.

## 종료 제어

- auto_resume_enabled=false, paused=true, completed=false.
- Whisper 자동재개·정기워치독·시간별보고 정지 상태를 유지. 다음 주 자동재시작도 하지 않는다.
- **최종 종료 확인:** 마지막 작업자·감독 프로세스 정상 종료(exit 0), 살아 있는 Godot/작업자/미확인 writer 없음, 양쪽 작업 잠금 해제 확인. 후속 작업을 실행하지 않았다.
- 최종 작업자 보고서: `../whisper-world-objects/evidence/17-map1-final-cleanup/CHECKPOINT.md` 및 `final-audit.json`. 최종 소스 manifest SHA-256을 부모가 확인했고, 이 중단 기록 저장 이후 게임 소스 변경은 없었다.
- 최종 검증은 위 기록에 보존. 덤불·디딤돌 디자인 반려와 기존 엔진 오류·야간 가독성 등 미완료 항목은 그대로 남긴다. **이번 주 작업 종료이며, 전체 게임 완성·배포·원격 커밋 반영을 뜻하지 않는다.**

저장 시각: 2026-09-17T01:08:04.417127+09:00
마지막 legacy 검증 이후 소스 차이: []
