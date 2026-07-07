# Handoff — v1.0.4 (P0 핫픽스: L2~L5 조합대 인터랙티브화)

Status: DONE. 릴리스 완료. 세이브 100% 호환.

## 무엇을 고쳤나 (P0)
제2~제5 세계(L2 terminal_station / L3 clockwork_city / L4 mage_tower / L5 cathedral)의
조합대가 단순 `Sprite2D + set_meta`로 배치돼 있어 실플레이에서 **E-조합이 Fusion UI를
못 열던** 진행 블로커. 조합창은 `Cauldron.interacted` 시그널에서만 열리므로, 게이트 조합물을
만들 수 없어 L2~L5 진행이 막혔다.

### 코드 변경
- `game/scripts/world/{terminal_station,clockwork_city,mage_tower,cathedral}.gd`
  - `_spawn_workbench()`: 조합대를 **실제 `Cauldron` 인스턴스**로 스폰(43ee7a8에서 도입).
  - `_bind_fusion_ui(caul)`: 씬 루트를 `owner if owner != null else get_tree().current_scene`로
    해석 → 실플레이(current_scene)와 테스트 하네스 부모화(owner) 양쪽에서 FusionUI 바인딩 동작.
- `game/scenes/dev/e2e_playthrough.gd`
  - `_l2_ui_path_first_craft()` 신규(NO-API-우회 구간): 플레이어를 정비대 인접 워커블 셀로 이동 →
    `InteractionController._process` → 정비대가 E-타겟('E 조합' 프롬프트)인지 어서션 →
    `_do_interact()`가 **Fusion UI를 실제로 개방**하는지 어서션(API 경로가 못 하던 검증) →
    UI 슬롯(`_on_strip_pressed`) + 조합 버튼(`_on_fuse_pressed`)으로 구리도선 D62 제작.
    **`Fusion.fuse()`를 절대 호출하지 않음** — 이게 원래 버그를 숨긴 지름길이라 의도적으로 배제.
  - 세계수 진상 카드 잔류 모달 dismiss(`world_tree._close_shard_card`) — 이후 스텝 상호작용 복원.
- `game/scenes/dev/interaction_fusion_harness.{gd,tscn,gd.uid}` (ff71c8e + 이번 .uid 커밋)
  - 6레이어(home/grove/L2~L5) 전부 실 E-조합→Fusion UI 개방→UI 제작을 `Fusion.fuse()` 없이 검증.

## 검증 (모두 실측)
- 전 하네스 스위프 **35/35 그린** — 0 FAIL / 0 SCRIPT ERR, 전부 exit 0
  (scenes/dev/ 전체, render 도구 `home_overview_render` 제외).
  - interaction_fusion_harness 67 PASS, e2e_playthrough 237 PASS(5레이어 완주).
- **실 PCK(--main-pack)**: linux 프리셋 `exclude_filter` 임시 blank → dev포함 PCK(6.9MB) 익스포트
  → `interaction_fusion_harness` + `e2e_playthrough` 전 PASS(0 fail) → 프리셋 원복(git 무diff).

## 릴리스
- 버전 1.0.3→1.0.4 bump: `game/project.godot`(config/version) + `game/export_presets.cfg`
  (application/product_version, short_version, version — win/mac).
- 커밋 `v1.0.4 P0 hotfix: interactive crafting stations in L2-L5` → 태그 **v1.0.4** 푸시.
- export 템플릿 재설치(HOME 리셋 대비): `/workspace/group/tools/export_templates.tpz` → 36파일 →
  `~/.local/share/godot/export_templates/4.5.stable/`.
- win/mac 클린 빌드(`tools/build_exports.sh`; dev 미포함 프리셋):
  - win64: **39,945,835 bytes** (`ProjectWhisper-win64-v1.0.4.zip`)
  - macos: **68,277,250 bytes** (`ProjectWhisper-macos-v1.0.4.zip`, ad-hoc 서명)
    - rcodesign verify: 2슬라이스 유니버설 Mach-O, CodeDirectory+RequirementSet+CMS 3-blob superblob,
      `_CodeSignature/CodeResources` sealed, `ProjectWhisper.app` 무공백, Info.plist 1.0.4.
    - 첫 실행: `xattr -dr com.apple.quarantine ProjectWhisper.app`
  - 산출물 export/ + dist/ 양쪽에 배치.
- GitHub 릴리스 v1.0.4(한국어 노트: L2~L5 조합창 진행 블로커 수정, 세이브 100% 호환; zip 2종 uploaded).
  - **URL: https://github.com/ChoiKoal/project_whisper/releases/tag/v1.0.4**

## 환경 노트
- **CWD 주의**: `project.godot`는 `game/`에 있음. Godot 하네스 실행은 반드시 `--path game`
  또는 `game/`에서 실행할 것. 부모 디렉터리에서 `res://scenes/dev/...`를 돌리면 프로젝트를
  못 찾아 배너만 찍히고 무한 대기(무증상 행)한다 — 이번 인수 초반 시간 소모 원인.
- 릴리스는 `gh` 미설치라 GitHub REST API(curl + GH_TOKEN/GITHUB_TOKEN) 사용.
