# Handoff — M6b (패키징 + 엔드-투-엔드 QA · 최종 마일스톤)

Status: DONE. Import clean(0 errors), title + starting_grove headless 무오류,
**E2E 풀 플레이스루 하니스 59/59 PASS**, 이전 6개 하니스(m2·m2_integration·m3·m4·m5·m6a)
전부 PASS, 데스크톱 3종 익스포트 아티팩트 생성 + Linux 익스포트 헤드리스 부팅 확인.
Uncommitted (프로젝트 규칙: 커밋은 리드가). Godot 4.5.stable ·
`/workspace/group/tools/Godot_v4.5-stable_linux.arm64`.

M0~M6a 위에 쌓음(handoff-m4/m5/m6a 참조). 게임 로직/맵/세이브 스키마는 **변경 없음**;
M6b 는 (A)통합 테스트 하니스, (B)익스포트 파이프라인, (C)이슈 목록만 추가하고
프로젝트 설정 2줄만 손봄(아래 "변경 파일").

---

## A. E2E 플레이스루 하니스 (진짜 QA 게이트)

`scenes/dev/e2e_playthrough.{tscn,gd}` — **실제 starting_grove 씬**을 프로그램적으로
전체 게임 루프에 태운다. 가능한 곳은 실제 컨트롤러를 쓴다:
`InteractionController.interact_with_object/_with_cell`, `TouchController.move_to`,
`Fusion.fuse`. 라이트한 대량 재료만 `Inventory.add` 로 채운다(스펙 허용).

### 실제로 수행되는 메커니즘 (각 최소 1회 진짜 실행)
- 실제 타일채집: 잔디 타일 → 풀 + VOID 구멍(`interact_with_cell`)
- 실제 오브젝트채집: 꽃(I5)·바위(I6)·신비한물(I7)·세계수(I9, unique)(`interact_with_object`)
- 실제 배치: 디딤돌 D14 → K 물 슬롯(walkable), 어린세계수 D22 → VOID(클리어)
- 실제 사용: 물 I7 → 마른 덤불 → bloom(통로 개방)
- 실제 조합: Fusion API 로 씨앗(R04)/디딤돌(R15)/생명수(R20)/빛나는새싹(R21)/어린세계수(R23)
- 실제 길찾기 이동: `TouchController.move_to` 로 3칸 개울을 디딤돌 밟고 횡단

### 9단계(스펙) 매핑 → 결과
0. 부팅·월드 등록 → PASS
1. fresh state → 채집(꽃/타일) → 씨앗 R04 조합 → PASS
2. 디딤돌 R15 → **K 슬롯 3개**에 배치 → 개울 across 경로/횡단 → PASS
3. 물 채집 → 마른 덤불에 use → bloom/통로 → PASS
4. 밤 세팅 → G3 통과 가능 → 세계수 채집 I9(월드 잔존·unique) → PASS
5. 생명수 R20(I9 catalyst 미소모) → 빛나는새싹 R21(씨앗 재조합) → 어린세계수 R23(흙 I1) → PASS
6. D22 를 VOID 타일에 심음 → world_tree_planted + cleared → PASS
7. save → load → cleared/인벤/맵 상태 유지 → PASS
8. NG+ → run=2, 정확히 3레시피 carry(discovered 부분집합), 월드 리셋·인벤 비움 → PASS

**결과: `RESULT: PASS (0 failures)` · exit 0 · SCRIPT ERROR 0줄.**

### 하니스 설계 노트 / 카베아트
- 시간은 명시 구동: `GameState.time_running=false` + `set_game_time()` 로 낮/밤 결정론화
  (벽시계 드리프트가 4단계 밤 게이트 판정을 흔들지 않도록). 길찾기·리스폰은 `_process`/
  `_physics_process` 로 여전히 틱한다.
- **G1 개울은 3칸 깊이** — K 슬롯이 세로 3칸((16,24)/(16,25)/(16,26))이라 디딤돌 3개가
  있어야 건넌다. 초기 구현이 1개만 놓고 실패했던 것을 3개 배치로 교정(진짜 게임 규칙).
- 클리어 연출 트윈(~6초)을 실시간으로 기다리는 대신 `mark_cleared()` 직접 호출로
  cleared 를 결정론적으로 검증(인게임은 연출 종료 시 GroveSession 이 자동 저장).
- 대량 재료 top-up 은 `_ensure_at_least()` 로 직접 add — 위 메커니즘은 전부 진짜 실행됨.

### E2E 출력 꼬리
```
--- STEP 8: NG+ start → run=2, exactly 3 recipes carried (subset), world reset ---
[PASS] run discovered >= 5 recipes (clear chain) — discovered=5
[PASS] NG+ run number is 2 — run=2
[PASS] NG+ carried exactly 3 recipes — carried=["R04", "R21", "R20"]
[PASS] NG+ carried are a subset of discovered
[PASS] NG+ fresh codex has exactly the 3 carried discovered — fresh=3
[PASS] NG+ inventory empty
[PASS] NG+ time reset to 0
[PASS] NG+ cleared flag reset
[PASS] NG+ world reset (base ground intact, not VOID) — cell=(12, 30) src=2
[PASS] NG+ player back on spawn
[PASS] NG+ inventory still empty in fresh world
=== RESULT: PASS (0 failures) ===
```

### 회귀 — 이전 6개 하니스 (최종 상태 재실행, 전부 PASS · err 0)
```
m2_test_harness   RESULT: PASS (0 failures)
m2_integration    RESULT: PASS (0 failures)
m3_test_harness   RESULT: PASS (0 failures)
m4_test_harness   RESULT: PASS (0 failures)
m5_test_harness   RESULT: PASS (0 failures)
m6a_test_harness  RESULT: PASS (0 failures)
```
메인 씬도 헤드리스 무오류: title.tscn / starting_grove.tscn (exit 0, err 0).

---

## B. 데스크톱 익스포트

### 익스포트 프리셋 — `game/export_presets.cfg` (신규)
- **Windows Desktop**: x86_64, `embed_pck=true` → 단일 exe. product "Project Whisper",
  product_version 0.1.0, company "KoalStudio".
- **macOS**: universal, ad-hoc/unsigned(codesign 0, notarization 0), short/version 0.1.0,
  min macOS 10.13(x86_64)/11.00(arm64). zip 산출.
- **Linux arm64**: arm64, `embed_pck=false`(바이너리+.pck 분리, 로컬 스모크용).
- 세 프리셋 공통 `exclude_filter="scenes/dev/*"` → 테스트 하니스는 빌드 제외.

### 프로젝트 설정 변경(익스포트 성립에 필수) — `game/project.godot`
- `[display]` 1600×900 기본, `resizable=true`, `mode=0`(전체화면 아님).
- `[rendering] textures/vram_compression/import_s3tc_bptc=true`
  → **이걸 안 켜면 macOS universal export 가 실패**한다(S3TC/BPTC required).

### 익스포트 템플릿 설치
스펙에는 "이미 설치됨"이라 되어 있었으나 실제로는
`~/.local/share/godot/export_templates/4.5.stable/` 가 **비어 있었고**,
`/workspace/group/tools/export_templates.tpz`(1.3GB, version.txt=4.5.stable)만 존재.
`.tpz`(zip)를 `templates/` 프리픽스 제거하며 `4.5.stable/` 로 추출해 설치함(36개 파일).

### 산출 아티팩트 — `/workspace/group/project-whisper/export/`
| 파일 | 크기 | 비고 |
|---|---|---|
| `windows/ProjectWhisper.exe` | ~93 MB (96,825,384 B) | embed_pck, 단일 파일 |
| `macos/ProjectWhisper.zip` | ~60 MB (62,372,137 B) | universal, unsigned(ad-hoc) |
| `linux/ProjectWhisper.arm64` | ~61 MB (63,370,728 B) | + `linux/ProjectWhisper.pck`(~200 KB) 동반 |
| `ProjectWhisper-win64-v0.1.0.zip` | ~34 MB (34,038,515 B) | windows 폴더 압축(배포용) |
| `README-실행방법.md` | — | win/mac/linux 실행법(한국어) |

### Linux 익스포트 스모크 테스트(진짜 부팅)
```
cd export/linux
./ProjectWhisper.arm64 --headless --quit-after 120   → exit 0, SCRIPT ERROR 0줄 (타이틀 씬 부팅)
timeout --signal=SIGKILL 8 ./ProjectWhisper.arm64 --headless → 8초 후 SIGKILL(정상 구동 확인), err 0줄
```

### 재빌드 방법 (how to rebuild)
```
cd /workspace/group/project-whisper/game
GODOT=/workspace/group/tools/Godot_v4.5-stable_linux.arm64

# (최초 1회) 익스포트 템플릿 설치 — 이미 설치돼 있으면 생략
python3 - <<'PY'
import zipfile, os, shutil
dest='/home/node/.local/share/godot/export_templates/4.5.stable'; os.makedirs(dest,exist_ok=True)
z=zipfile.ZipFile('/workspace/group/tools/export_templates.tpz')
for n in z.namelist():
    if not n.startswith('templates/') or n=='templates/': continue
    t=os.path.join(dest,n[len('templates/'):]); os.makedirs(os.path.dirname(t),exist_ok=True)
    with z.open(n) as s, open(t,'wb') as o: shutil.copyfileobj(s,o)
PY

"$GODOT" --headless --import .                                  # 임포트(S3TC 켜진 상태)
mkdir -p ../export/windows ../export/macos ../export/linux
"$GODOT" --headless --export-release "Windows Desktop" ../export/windows/ProjectWhisper.exe
"$GODOT" --headless --export-release "macOS"           ../export/macos/ProjectWhisper.zip
"$GODOT" --headless --export-release "Linux arm64"     ../export/linux/ProjectWhisper.arm64
# windows zip:
cd ../export && python3 -c "import zipfile,os; z=zipfile.ZipFile('ProjectWhisper-win64-v0.1.0.zip','w',zipfile.ZIP_DEFLATED); z.write('windows/ProjectWhisper.exe','ProjectWhisper.exe'); z.close()"
```

### 하니스 재실행
```
cd /workspace/group/project-whisper/game
"$GODOT" --headless res://scenes/dev/e2e_playthrough.tscn      # 59/59 PASS, exit 0
for h in m2_test_harness m2_integration m3_test_harness m4_test_harness m5_test_harness m6a_test_harness; do
  "$GODOT" --headless res://scenes/dev/$h.tscn
done
```

---

## C. 알려진 이슈

`/workspace/group/project-whisper/KNOWN-ISSUES.md` (한국어, 심각도 태그 🔴게임진행/🟡체감/🟢외관).
핵심: 🔴 블로커 없음. 🟡 디딤돌=흙 타일 재활용/밤 글로우 틴트블리드/G1 3디딤돌 안내부재.
🟢 플레이스홀더 아트·라이팅 방향 불일치·SFX 전무·macOS 미서명·엣지 스프라이트오버레이.
+ E2E/빌드 카베아트(시간 명시구동, S3TC 필수, Linux .pck 분리).

---

## 변경/추가 파일 (M6b)
```
game/
  scenes/dev/e2e_playthrough.{tscn,gd}   (신규)  # E2E 풀 플레이스루 하니스
  export_presets.cfg                     (신규)  # Windows/macOS/Linux arm64 프리셋
  project.godot                          (수정)  # display 1600×900 resizable, import_s3tc_bptc=true
project-whisper/
  export/…                               (신규 산출물, 위 표)
  KNOWN-ISSUES.md                        (신규)
  handoff-m6b.md                         (이 문서)
```
게임플레이 스크립트/데이터/맵/세이브 스키마는 **무변경**. project.godot 의 두 줄만 손댐.

## 편차(deviations)
- **익스포트 템플릿이 실제로는 미설치** 상태여서 `.tpz` 를 추출·설치함(스펙 가정과 상이). 위 B 참조.
- **S3TC/BPTC 프로젝트 설정 활성화**가 macOS universal 익스포트에 필수라 project.godot 에 추가.
- **G1 개울 3디딤돌**: E2E 초기 구현이 디딤돌 1개로 실패 → 실제 게임 규칙(3칸 깊이)대로 3개 배치로 교정.
- macOS 는 스펙대로 unsigned(ad-hoc). Godot 는 미서명 macOS 에 경고를 낼 수 있음 → README 에 우회법 문서화.
- Linux 는 로컬 스모크 목적이라 `embed_pck=false`(바이너리+.pck). Windows/macOS 는 자기완결형.
