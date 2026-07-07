# Handoff — v1.2.0 (아트 정합 패치: 아이소메트릭 오브젝트 + 8방향 캐릭터)

Status: DONE. 릴리스 완료. 세이브 100% 호환.

## 무엇을 했나 (AP-1~4)
아트 정합(coherence) 패치. 게임플레이/데이터 변경 없이 아트 에셋만 교체.
- **AP-1~2 전 오브젝트 아이소메트릭 재작업**: 6개 맵(홈/L1~L5) 100+종 오브젝트를
  정면뷰(front-view)에서 3/4 원근으로 통일. `game/assets/objects/` 157종 refs.
- **AP-3 캐릭터 8방향 이동**: `game/assets/character/character_sheet.png` 288×768(8방향 시트),
  이동 방향에 맞춘 페이싱. v040b 시트 레이아웃 어서션 8방향 288×768로 갱신.
- 솥단지(cauldron) 리디자인.

## 검증 (모두 실측)
- **전 하네스 스위프 35/35 그린**(scenes/dev/ 전체, render 도구 home_overview_render 제외, 전부 exit 0).
- **실 PCK(--main-pack)**: linux 프리셋 `exclude_filter` 임시 blank → dev포함 PCK(7.10MB) 익스포트
  → `e2e_playthrough`/`ap3_facing_harness`/`interaction_fusion_harness` 3종 전 RESULT PASS(0 failures)
  → 신규 아트 PCK 실포함 확인(character_sheet 288×768 + objects/ 157 refs + samples_iso 전부)
  → 프리셋 원복(git 무diff clean).
- **컴포지터 프리뷰 6종 재생성**: `tools_overview_home/l2/l3/l4/l5.js` + `tools_overview_v050a2.js`
  (grove→preview-v050b→preview-l1 복사) → `/workspace/group/preview-{home,l1,l2,l3,l4,l5}.png` 새 아이소
  아트 반영. l3 Read 스팟 확인(클록시티 전 오브젝트 3/4 원근·8방향 캐릭터·아이소 타일 정합 확인).

## 릴리스
- 버전 1.1.0→1.2.0 bump: `game/project.godot`(config/version) + `game/export_presets.cfg`
  (application/product_version[win], short_version·version[mac]) 4개 필드.
- 커밋 `v1.2.0 art coherence pass: isometric objects + 8-way character`(→008f534) + 태그 **v1.2.0** 푸시 — **빌드보다 먼저**.
- win/mac 클린 빌드(`tools/build_exports.sh`; dev 미포함 프리셋) + mac 후처리(무공백 ProjectWhisper.app):
  - win64: **40,059,768 bytes** (`ProjectWhisper-win64-v1.2.0.zip`)
  - macos: **68,392,669 bytes** (`ProjectWhisper-macos-v1.2.0.zip`, ad-hoc 서명)
    - rcodesign verify OK: 2슬라이스 ADHOC + CodeResources sealed, Info.plist CFBundleShortVersionString/Version=1.2.0.
    - 첫 실행: `xattr -dr com.apple.quarantine ProjectWhisper.app`
  - 산출물 export/ + dist/ 양쪽 배치. dev/harness 누출 0.
- GitHub 릴리스 v1.2.0(한국어 노트: 아트 정합 패치·전 오브젝트 아이소 재작업·캐릭터 8방향·솥단지
  리디자인·세이브 호환; zip 2종 uploaded).
  - **URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.2.0**

## 환경 노트
- Godot 하네스 실행은 반드시 `--path game` 또는 `game/`에서. 실 PCK 하네스는 `--main-pack <pck>
  res://scenes/dev/<name>.tscn`.
- 컴포지터는 offline pngjs — 실제 `game/assets/**` PNG를 로드해 그림 → 아트 에셋 교체 시 재실행만으로
  프리뷰 갱신. `NODE_PATH=/workspace/group/tools/nodejs/node_modules node <tool>.js`.
- 릴리스는 `gh` 미설치라 GitHub REST API(remote URL 임베드 토큰). export/·dist/는 .gitignore.
