# WH-UNIT15 — 독립 실행 QA 보고 (멤쵸)

- 검수 대상 SHA: `ea806bb96520fb766b2a54edb730ff75db830bef`
- 브랜치: `test/wh-unit15-safety-memcho` → PR base `ruby/whisper-runtime-wip`
- 실행 환경: **Linux aarch64** / Godot **4.5.stable.official.876b29033** (arm64 공식 빌드)
  - 부모(루비) 실행 환경은 macOS. 같은 머신 재실행도 재현이지만, 이번처럼
    **다른 OS·아키텍처에서의 독립 재현**은 증거 수준이 한 단계 높다.
- 실행 일시: 2026-09-16 (KST)

> 이 문서는 **CURRENT15 합성 안전 게이트**에 한정된다. 전체 회귀·정상 플레이·모바일·
> 재미·아트 승인은 포함하지 않으며, 채집 통합(16)은 이 SHA에 없으므로 합산하지 않는다.

---

## 1. 실행 명령

```
python3 game/tests/run_current15_safety.py \
  --godot <GODOT-4.5-arm64> \
  --evidence <NEW_OUTPUT_DIR> \
  --case future_save_safety_harness \
  --case pending_lock_safety_harness \
  --case night_flower_art_harness
```

선행 조건으로 자산 임포트가 필요했다(`--headless --import`, 1748개). 임포트 전 실행은
오디오 리소스 로드 실패 + `SCRIPT ERROR: Nonexistent function 'new_game' in base 'Nil'`로
무너진다. 지시서의 "imported project assets" 전제가 실제로 필수임을 확인.

## 2. 결과 — 부모 publication-copy와 수치 완전 일치

| 장면 | exit | assertions | failures | script_errors | completion_verified |
|---|---|---|---|---|---|
| future_save_safety_harness | 0 | 10 | 0 | 0 | true |
| pending_lock_safety_harness | 0 | 36 | 0 | 0 | true |
| night_flower_art_harness | 0 | 78 | 0 | 0 | true |
| **합계** | | **124** | **0** | **0** | |

```
exact_set: true   passed_scenes: 3   failed_scenes: 0
source_changed: []
engine_error_lines: 3
```

**잔여 엔진 오류(별도 유지, 124 통과와 합치지 않음)** — 3장면 각각 1줄씩:

```
ERROR: 2 resources still in use at exit (run with --verbose for details).
```

`passed=true`는 script/assertion/exit/completion 실패가 없다는 뜻이며 **깨끗한 엔진 종료를
의미하지 않는다.**

원본 로그: `docs/qa/evidence-unit15/*.log`, 결과 JSON: `runner-results.json`
(개인 경로·자격정보는 `<HOME>` `<REPO>` `<EVIDENCE>` `<GODOT>`로 치환)

## 3. 격리 검증

```
생성된 격리 HOME 3개 — 각각 .cache / .local 만 보유
기본 user:// (~/.local/share/godot/app_userdata/Project Whisper)
  → 23:09:55 생성 (= --import 단계), 내용 비어 있음
  → 격리 실행(23:12:12)은 이 경로에 쓰지 않음
```

**주의**: `Inventory.clear()`는 세이브 격리가 아니다. 격리는 러너가 바인딩하는
`WHISPER_TEST_HOME` / 별도 HOME이 담당한다.

## 4. 파괴적 하네스 fail-closed — 직접 검증

카나리 세이브를 기본 `user://`에 심고 sentinel 없이 4개를 실행:

| 하네스 | exit | 가드 로그 |
|---|---|---|
| cutscene_harness | **86** | 2줄 |
| m5_test_harness | **86** | 2줄 |
| v051_test_harness | **86** | 2줄 |
| v052_travel_stress | **86** | 2줄 |

```
카나리 sha256(앞16) 사전 b361aa66aa65df17 / 사후 b361aa66aa65df17  → 보존 ✅
```

### ⚠️ 이 검증에서 내가 한 번 틀렸다 (기록으로 남김)

처음에는 씬 경로를 `game/scenes/dev/...`로 줬다. `--path`가 이미 `game/`을 가리키므로
올바른 경로는 `res://scenes/dev/...`다. 잘못된 경로에서는:

```
exit=1  "Failed loading scene"   ← 씬이 로드조차 되지 않음
카나리  보존됨
```

즉 **"세이브가 살아남았다"가 나왔지만 가드는 실행된 적이 없었다.** 경로를 고친 뒤에야
`exit=86`이 나왔고 그것이 가드가 실제로 동작한 증거다.

> 안 죽은 것은 안전의 증거가 아니다. **가드가 실행되었고 거부했다**까지 확인해야 한다.

## 5. `hover_timing_probe.gd` — fail-closed 수정 (별도 변경)

### 발견한 결함 3종 (원본 47행 한 줄에 전부 있었다)

```gdscript
var file:=FileAccess.open(OS.get_environment("FDN_EVIDENCE")+"/timing.json",FileAccess.WRITE)
file.store_string(...)
```

1. **루트 쓰기** — `FDN_EVIDENCE` 미설정 시 `"" + "/timing.json"` = `/timing.json`.
   증거 디렉터리 밖, 파일시스템 루트에 쓰려 한다.
2. **nil 호출 크래시** — `open()`이 실패해 null을 반환하면 다음 줄에서 즉사한다.
3. **증거 없는 성공** — 코드 흐름상 두 경로 모두 `quit(0)`에 도달하는 것으로 읽힌다.
   ※ 원본이 실제로 어떻게 종료하는지는 **실행으로 확인하지 않았다**(probe가 headless에서
   완주 불가). "반드시 quit(0)까지 간다"는 단정은 철회하고 정적 판독으로만 남긴다.
   원칙은 유지: **자기 출력을 기록하지 못한 진단기가 PASS를 내면 안 된다.**

### 수정

`write_evidence()`로 분리하고 각 단계에서 fail-closed:
미설정 / 상대경로 / 디렉터리 부재 / `open()` 실패 → 각각 사유를 출력하고 `false` 반환,
호출부는 **exit 87**(격리 가드의 86과 구분)로 종료. 성공 시 기록 경로와 receipt 수를 출력.

### 런타임 검증 — 저장 함수는 검증됨 / 화면·입력 타이밍은 BLOCKED

루비 지적대로 **둘은 분리 가능**했다. `hover_evidence_sink_harness`로 저장 함수만
격리 headless 실행:

| 케이스 | 결과 |
|---|---|
| `FDN_EVIDENCE` 미설정 | 거부 + 루트 파일 생성 없음 ✅ |
| 상대경로 | 거부 ✅ |
| 디렉터리 부재 | 거부 ✅ |
| 정상 저장 | 기록 ✅ |
| readback 대조 | 기록 내용 == 기대 JSON ✅ |

`failures=0 missing=0 exit=0`. 증거: `evidence-unit15/hover-evidence-sink.log`,
`hover-sink-results.json`.

또한 `open()` 실패만 보던 것을 **store 오류 + close 후 readback 대조**까지 확장했다.
close()가 flush에 실패해 파일이 잘려도 성공으로 보고되지 않는다.

### ⚠️ 여전히 BLOCKED — probe 전체 실행

`hover_timing_probe`는 **headless에서 구조적으로 완주할 수 없다**:

```
await RenderingServer.frame_post_draw   × 3회
get_viewport().warp_mouse(...)
```

headless에는 렌더 프레임이 없어 `frame_post_draw`가 오지 않는다. 실측에서 18000프레임
예산으로도 출력 2줄만 남기고 멈췄다. 또한 이 probe는 `run_current15_safety.py`의 씬
목록에 **포함되어 있지 않다**(러너는 7개 씬만 다룬다).

- 정적 근거: 결함 3종은 원본 코드에서 직접 확인됨
- `--check-only` 컴파일 오류(`Identifier not found: Inventory`)는 오토로드 부재 탓이며
  **원본에서도 동일하게 발생**함을 확인(내 패치와 무관)
- **런타임 PASS 주장 없음.** 디스플레이 서버가 있는 환경에서 재실행 필요

## 6. 집계

```
실행 검증됨 : CURRENT15 3장면(124 assertions) + 파괴적 하네스 거부 4건
BLOCKED     : hover_timing_probe 런타임 검증 (headless 불가)
확대 금지   : 전체 회귀 / 정상 플레이 / 모바일 / 재미 / 아트 승인 / 채집 통합16
아트 판정   : 밤꽃 R3 = REWORK 유지 (QA는 아트 판정 주체가 아님)
```

## 7. Godot 실행 가능 ≠ 직접 플레이 가능

이 환경에서 **headless Godot 4.5 실행은 확인**됐다. 그러나 루비 지적대로 이는 직접
플레이 QA 준비 완료와 **다른 단계**다. 남은 확인:

- 그래픽 디스플레이 서버 확보
- 실제 키보드/마우스 입력 전달
- (모바일) 실기기 또는 터치 입력 경로

`hover_timing_probe`가 headless에서 멈춘 것이 이 간극의 구체적 증거다.
