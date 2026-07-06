# Handoff — L4 (마법의 세계) → v0.8.0 릴리스

## 요약
Layer 4 「봉인이 풀린 마탑」(unsealed mage tower) 구현 완료 + v0.8.0 릴리스. 4레이어 연속 플레이(홈→L1 세계수→L2 정화→L3 대시계 정화→L4 최심부 봉인 재구축→magic OPEN + divinity(L5) 포탈 flickering→귀환) 완주. **구조 역전**: 되살리는 정화(L1~L3)에서 풀려난 것을 다시 봉인하는 정화(L4)로.

## 검증 (실측)
- **버전 문자열 bump 0.7.0 → 0.8.0**: project.godot `config/version`, export_presets(win `product_version` / mac `short_version`·`version`) 4개 전부 0.8.0. mac Info.plist는 export 시 프리셋에서 생성 — 별도 plist 파일 없음(빌드 산출물에서 CFBundleShortVersionString/CFBundleVersion=0.8.0 확인).
- **전 하네스 스위프**: 29/29 그린(scenes/dev/ 전체, render 도구 home_overview_render 제외). tools_verify_recipes.py PASS(items 205 = 204 canonical + 1 alias / recipes 178 / gatherables 30), m8_icon_coverage 204 canonical 아이콘 byte-unique PASS.
- **Export 실빌드 검증**: export 템플릿 재설치(HOME 리셋 → export_templates.tpz 36파일 4.5.stable/ 복원, python zipfile 사용 — unzip 부재). linux 프리셋 exclude_filter 임시 blank → dev 포함 PCK(6.60MB) 익스포트 → `--main-pack`으로 **e2e_playthrough / l4_gates_harness / l4_flow_harness 3종 전 PASS(0 failures)** (시간 절약 위해 3종만; e2e 184 PASS 4레이어 완주 포함). **l4_map_layout.txt / l4_map_height.txt / l4_map_legend.json PCK 실포함 바이트 확인**(include_filter `data/*.json, data/*.txt`가 신규 l4 파일 커버). 검증 후 프리셋 원복(git diff clean), 임시 PCK/바이너리 삭제.

## 릴리스 산출물 (export/)
- **ProjectWhisper-win64-v0.8.0.zip** — 39,785,916 bytes (~39.8 MB; ProjectWhisper.exe embed-pck + README-실행방법.md, dev/harness 누출 0)
- **ProjectWhisper-macos-v0.8.0.zip** — 68,116,574 bytes (~68.1 MB; 공백 없는 `ProjectWhisper.app`, Info.plist CFBundleShortVersionString/CFBundleVersion=0.8.0, postprocess 6엔트리 리네임, PCK에 l4 데이터 포함)

## 콘텐츠 (스펙: docs/project-whisper-layer4-design-v1.md)
- 봉인/결계 게이트 4종: **G1 룬 다리**(룬석 접합→금빛 룬 다리 walkable) / **G2 마력샘 재정화**(결계 분수 정화→밸브문 개방 + **마력 Whisper 첫 획득** = 2번째 재화) / **G3 균열 통과**(보호 부적 소지형→별하늘 균열 통행) / **G4 최심부 봉인 재구축**(마력 소모→봉인구 재건 = 정화; 마력 0 시 조합 거부 clean no-op).
- **마력 Whisper 신설** — 에너지에 이은 2번째 재화(WhisperCurrency mana). P 원소 7종(P1~P7 룬석/마력결정/은가루/양피지/봉인밀랍/별빛이슬/공허파편) + 레시피 37종(D140~D176, 누적 총 178).
- 정화 시 magic 포탈 OPEN + divinity(Layer 5) 포탈 flickering 전파, 멀티씬 세이브 v2(마력 포함) 지속, NG+ 4레이어 union 리셋(+마력 0 리셋).

## 알려진 항목
- `home_overview_render.tscn`은 하네스 아님(헤드리스 GPU 프레임버퍼 없음 → SubViewport 캡처 불가). 릴리스 블로커 아님.
- macOS 빌드 로그의 `gio/kioclient5/gvfs-trash` 에러는 무해(리눅스 휴지통 폴백 실패 → zip 정상 생성, postprocess OK).
- `--main-pack` 종료 시 "N resources still in use at exit"는 헤드리스 teardown 경고(exit 0, 테스트 결과 무관).

## 릴리스
- GitHub 릴리스 v0.8.0 (한국어 노트) + win/mac zip 2종 첨부.
- URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v0.8.0
