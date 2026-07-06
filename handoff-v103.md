# Handoff — v1.0.3 (L2 기름 softlock 핫픽스 + 전 레이어 공간 진행 감사)

날짜: 2026-07-06 · Godot 4.5.stable · HEAD 태그 v1.0.3

## 요약
KOAL 실플레이 발견 진짜 softlock 수정 + 회귀 방지 하네스/도구 신설.

## 진단 (실측)
- L2 「꺼진 관문 기지」의 oil_leak(`m`, gather **J5 기름**) 소스 4개 = (11,9)(27,9)(11,12)(26,12) — 전부 냉각수 협곡(W, row24–26) **북쪽**.
- 스폰 S=(18,32) 남쪽. G1 에너지 브리지 B(row23–27)는 전지 D64 장착 전 통행 불가(협곡 유일 크로스).
- 전지 = 구리도선(J1+J2) + 정류회로(**J4+J5**) → **기름 없이 G1 못 열고, 기름은 G1 뒤에만 = 데드락.**
- 남측(pre-G1) J1/J2/J4/J3 소스는 존재, J5만 0개였음.

## 수정
- `game/data/l2_map_layout.txt`: 남측 잔해밭에 walkable oil_leak `m` 3개 추가 — **(12,35)(26,37)(21,38)**. 전부 기존 `G` 셀, 스폰 진입로·브리지 스파인(col17–19) 미침범.
- `docs/project-whisper-layer2-design-v1.md`: §A-2 ASCII byte-identical 재동기화 + §A-4/§A-6(softlock 표)/§B-1/§B-2 남측 배치 명기.

## 신규 도구/하네스
- `tools/tools_spatial_audit.py`: 전 레이어(L2~L5) 스폰→게이트 순차 BFS로 각 게이트 열쇠 레시피 체인(recipes.json 역추적)의 gather 원소가 게이트 앞 구역 소스≥1인지 전수 검증. parts_box J2/J4 셀패리티((x+y)%2, map_loader._l2_gather_item_id 동형) 반영. **총 위반 0** (수정 전 L2 J5 1건 검출 → 수정 후 0; L3/L4/L5 원래 클린).
- `game/scenes/dev/l2_map_harness.gd`: `_test_oil_south_progression` 추가(협곡 남측 oil_leak ≥1·≥3) + tile count m 4→7 / G 401→398.

## 검증
- 전 하네스 스위프 34/34 그린(render 제외, exit 0), e2e 완주 PASS, verify_recipes 220 PASS.
- 실 PCK(--main-pack): l2_map·e2e PASS, l2_map_layout.txt 남측 oil 바이트 PCK 포함 확인. dev 누출 footprint = shipped v1.0.2와 byte-동일(class-cache 메타 문자열뿐).

## 릴리스
- 버전 1.0.2→1.0.3 bump + 태그 v1.0.3. win/mac 클린 빌드(mac ad-hoc 서명 verify OK).
- 산출: ProjectWhisper-win64-v1.0.3.zip(39,944,516 B) / ProjectWhisper-macos-v1.0.3.zip(68,276,129 B, ad-hoc). export/+dist/.
- **세이브 호환**.
- URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.0.3

## 후속(선택)
- tools_spatial_audit.py를 CI/사전-릴리스 게이트로 상시 실행 권장(신규 레이어 추가 시 자동 softlock 감지).
