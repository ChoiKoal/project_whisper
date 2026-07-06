# Handoff — EG-4 (엔드게임 릴리스 v1.0.0)

날짜: 2026-07-06
HEAD(태그 시점): `1950acd` on `main` — 태그 `v1.0.0`
릴리스: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.0.0

## 요약
Project Whisper **정식 완성판 v1.0.0** 릴리스 완결. EG-1~EG-3(빛의 문 + 엔딩 E1/E2 + 진상 조각/도감) + EG-4 e2e 엔딩 스텝 + 버전 1.0.0 bump가 이미 커밋돼 있던 상태(HEAD=b4d282e)에서, **하네스 풀런 실측 → 실 PCK 검증 → 태그 → win/mac 빌드 → GitHub 릴리스**를 완주.

## 검증 (전부 exit 0)
- **endgame_harness.tscn 풀런**: A(빛의 문 스폰) / B(진입 프롬프트 [돌아선다] 게이트) / 취소([아직 아니야]→엔딩 미발동·복귀) / C(E1「완성」 완주 + control_lock·time_running 페어링) / D(조각5+[돌아선다]→E2「속삭임」 완주) / E·E2·E3(진상 조각 5종 조사→플래그·최종 카드·도감 「기록」 탭) / F(NG+ 조각 리셋·endings_seen 보존) / G(세이브/로드 지속) = **64 PASS / 0 FAIL**.
- **e2e_playthrough.tscn**(엔딩 스텝 STEP 65 「빛의 문→E1」 포함): PASS / 0 FAIL.
- **전 하네스 스위프 31/31 그린**(scenes/dev/ 전체, render 도구 `home_overview_render` 제외) — l2~l5 flow/gates/map + m2~m8 + v021~v052 + sweep + endgame, 전부 exit 0.
- **tools_verify_recipes.py**: PASS — items 254(253 canonical + 1 alias) / **recipes 220** / gatherables 37.

## 실 PCK 검증
export 템플릿 재설치(HOME 리셋 대비 `export_templates.tpz` 36파일 → `~/.local/share/godot/export_templates/4.5.stable/`). linux 프리셋 `exclude_filter` 임시 blank → dev포함 PCK(6.89MB) 익스포트 → `--main-pack`으로 **e2e_playthrough / endgame_harness 전 PASS(0 fail)**. `recipes.json`/`items.json`/`l5_map_legend.json`/`l4_map_layout.txt` PCK 실포함 바이트 확인(include_filter `data/*.json, data/*.txt` 커버). 프리셋 원복(git diff clean). 클린 릴리스 PCK(6.57MB)는 dev포함본보다 320KB 작음 = dev 씬 실제 제외 확인(잔존 문자열은 global_script_class_cache/uid_cache 참조뿐, 로드 불가).

## 버전 & 태그
버전 1.0.0 전 위치 정합 확인(`project.godot` config/version, `export_presets.cfg` win product_version + mac short_version/version 전부 1.0.0 — bump 불필요, 잔여 커밋 없음). 태그 `v1.0.0` 생성·푸시(→ 1950acd).

## 빌드 & 릴리스
`tools/build_exports.sh` (VER=project.godot에서 자동 추출) + mac 후처리(`postprocess_macos_zip.py` — 무공백 `ProjectWhisper.app` / Info.plist 1.0.0, 6엔트리 리네임):
- `ProjectWhisper-win64-v1.0.0.zip` = **39,942,831 bytes (~39.94MB)**
- `ProjectWhisper-macos-v1.0.0.zip` = **68,273,740 bytes (~68.27MB)**

두 zip export/ + dist/ 보관, dev/harness 누출 0 확인. GitHub 릴리스 v1.0.0(한국어 노트: 빛의 문 + 엔딩 2종 E1「완성」/E2「속삭임」 트루=진상 조각 5개+돌아서기, 진상 조각+도감 기록 탭, 세계 5개+홈, 레시피 220종, Whisper 3속성, NG+) 생성 + zip 2종 업로드(state=uploaded).

## 다음
릴리스 완결 상태. 후속은 밸런스 튜닝(v1.0 스코프에서 명예 기록/플레이버만) 또는 E3 침묵/E0 귀환 엔딩(v1.0 스코프 아웃, 조건 스케치는 endgame-design 부록 A) 정도가 검토 대상.
