# Handoff — v1.3.0 (컷신 연출 패치: cutscene quality-up)

Status: DONE. 릴리스 완료. 세이브 100% 호환.

## 무엇을 했나 (CQ — cutscene quality-up)
컷신 연출을 대폭 강화한 패치. 게임플레이/데이터 변경 없이 연출만 확장.

- **오프닝 아크 신설 (CS-01~03)**
  - 각성 심장박동: 검은 화면 보라 점 2회 심장박동 + 낮은 단음
  - 포탈 리빌: 줌아웃으로 꺼진 포탈들이 반원으로 드러나는 각성 리빌 (오프닝→홈 연계)
  - CS-03 세계수 조우 컷신 신설: 카메라 틸트 + BGM 저음 + 잎 기욺
- **세계별 정화 연출 5종**: L1 파문 링(VOID 자국 초록 물듦) / L2 도시 점등 /
  L3 대시계 첫 틱(톱니 회전) / L4 봉인 수축 / L5 잔불→온기 확산
- **엔딩 폴리시**: E2 크레딧 후 보라 점 2회를 오프닝과 같은 리듬 상수로 공유(리듬 회수)
- **컷신 재감상 갤러리**: 도감 「기록」 탭에서 열람한 컷신 재감상 추가
- **공통 부품화**: 카메라 팬/줌/틸트 Tween·레터박스·화이트 플래시·확장 링 파문·카드 타이포가
  opening/clear/portal/ending/l2~l5에 5중 중복이던 것을 CutsceneDirector 유틸로 추출·재사용.

## 검증 (모두 실측)
- **전 하네스 스위프 43/43 그린** (`tools/run_sweep.sh`, scenes/dev/ 전체,
  render 도구 home_overview_render 제외, 전부 exit 0). 재개형 체크포인트(game/.sweep_done)로
  43개 전부 SKIP(green) → "SWEEP COMPLETE: all green (43 harnesses)".
- **실 PCK(--main-pack)**: linux 프리셋(preset.2) `exclude_filter` 임시 blank → dev포함 PCK(7.14MB) 익스포트
  → `cutscene_harness`(4 PASS, 잠긴 컷신 재생 거부 포함) / `e2e_playthrough`(NG+ 양레이어 리셋 포함, 0 failures)
  전 RESULT PASS → 프리셋 원복(3 preset 모두 exclude scenes/dev/* 확인)·임시 PCK 삭제.
- 익스포트 템플릿: 4.5.stable을 `/workspace/group/tools/export_templates.tpz`에서
  `~/.local/share/godot/export_templates/4.5.stable/`로 재설치(세션 초기 미설치 상태였음).

## 릴리스
- 버전 1.3.0 bump 확인(project.godot config/version + export_presets win product_version·mac short/version).
- 태그 v1.3.0 (annotated) 푸시.
- win/mac 클린 빌드 (`tools/build_exports.sh`, dev 미포함):
  - win64: ProjectWhisper-win64-v1.3.0.zip (40,087,353 bytes, exe + README-실행방법.md)
  - macos: ProjectWhisper-macos-v1.3.0.zip (68,419,826 bytes, ProjectWhisper.app 무공백)
    - postprocess가 rcodesign ad-hoc 서명 + verify 수행 → "verify OK: 2 slice(s) ADHOC-signed, CodeResources sealed"
- GitHub 릴리스 v1.3.0 생성 + zip 2종 업로드(state=uploaded).
  URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.3.0

## 주의
- remote origin URL에 토큰이 임베드돼 있음 — 스크립트에서 변수로 추출하고 **절대 출력 금지**.
  (릴리스 API 호출 시 token을 변수에만 담고 로그에 노출하지 않음.)
- 세이브 100% 호환(연출만 변경, 데이터/스키마 무변경).
