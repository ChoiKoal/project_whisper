# Apple 공증(Notarization) 가이드 — Project Whisper macOS

이 문서는 Project Whisper 의 macOS 배포물을 **콸의 로컬 맥**에서 Apple 공증하는
전체 절차와, 이를 뒷받침하는 빌드 파이프라인 변경점을 정리한다.

> **보안 원칙**: Apple ID / app-specific password / Team ID / Developer ID 인증서는
> **콸의 맥에서만** 다룬다. 이 리포지토리와 빌드 호스트에는 어떤 크리덴셜도 저장하지
> 않으며, 스크립트는 값을 하드코딩하지 않고 `security find-identity` 자동 감지 +
> 키체인 프로파일(`whisper-profile`)만 참조한다.

---

## 1. 배경 — 리눅스 빌드 vs 맥 공증

Project Whisper 는 리눅스 arm64 호스트에서 Godot 4.5 로 export 된다. 그 호스트에서
할 수 있는 macOS 관련 작업은 **rcodesign 을 이용한 ad-hoc 서명까지**다
(`tools/postprocess_macos_zip.py`). Apple 의 진짜 서명·공증 도구
(`codesign`, `notarytool`, `stapler`, `spctl`, `hdiutil`)는 macOS 전용이므로,
Developer ID 서명 + 공증은 **콸의 맥에서** 수행한다.

역할 분담:

| 위치 | 도구 | 산출물 |
|---|---|---|
| 리눅스 빌드 호스트 | Godot export + `postprocess_macos_zip.py`(rcodesign ad-hoc) | `ProjectWhisper-macos-v<VER>.zip` (ad-hoc 서명, 커스텀 아이콘/Info.plist 반영) |
| 콸의 맥 | `notarize_local.sh` (codesign + notarytool + stapler) | 공증+staple 된 `.zip` / `.dmg` |

`dist/apple-ready/ProjectWhisper-apple-ready-v1.9.1.zip` 는 위 두 위치를 잇는 전달물이다.
콸이 이 zip 을 풀어 `./notarize_local.sh` 한 줄만 실행하면 공증이 끝난다.

---

## 2. 콸이 하는 일 (단계별)

### 2.0 최초 1회 준비
1. **Xcode Command Line Tools**: `xcode-select --install`
2. **Developer ID Application 인증서** 키체인 설치 확인:
   `security find-identity -v -p codesigning` → `"Developer ID Application: ..."` 존재
3. **app-specific password** 발급: appleid.apple.com → 로그인 및 보안 → 앱 암호
4. **Team ID** 확인: developer.apple.com → Membership → Team ID (10자리)
5. **자격증명 등록(1회)**:
   ```bash
   xcrun notarytool store-credentials whisper-profile \
       --apple-id cjuny814@naver.com \
       --team-id <TEAM_ID> \
       --password <app-specific-password>
   ```

### 2.1 매 릴리스
```bash
# apple-ready zip 을 풀고, 그 폴더에서:
./notarize_local.sh
```
스크립트 단계: identity 자동 감지 → `codesign`(hardened runtime, entitlements) →
`ditto` → `notarytool submit --wait` → `stapler staple` → `spctl -a -vv` →
배포 `.zip`/`.dmg` 재패키징. 각 단계 실패 시 원인을 한국어로 안내한다.

### 2.2 확인
```bash
spctl -a -vv ProjectWhisper.app     # accepted / source=Notarized Developer ID
```

---

## 3. Entitlements (하드닝 런타임)

파일: `tools/apple/entitlements.plist`

Project Whisper 는 **순수 GDScript** Godot 게임이다 (렌더러 `gl_compatibility`,
C#/Mono 없음, GDExtension/네이티브 애드온 없음, 카메라/마이크/위치 미사용).
따라서 하드닝 런타임 entitlement 는 **최소셋** 하나만 포함한다:

```xml
<key>com.apple.security.cs.disable-library-validation</key>
<true/>
```

**포함하지 않은 것과 이유** (Godot 공식 macOS export 문서 기준):

| Entitlement | 제외 이유 |
|---|---|
| `cs.allow-jit` | GDScript 는 JIT 가 아니라 바이트코드 인터프리터. Mono/C# 또는 네이티브 애드온 전용. |
| `cs.allow-unsigned-executable-memory` | 위와 동일 — 실행 메모리 자가수정 코드 없음. |
| `cs.allow-dyld-environment-variables` | dylib 주입 애드온 없음. |
| `get-task-allow` (Debugging) | 공증 시 **반드시 off** — 켜져 있으면 Apple 이 거절. |
| audio-input/camera/location 등 | 해당 기능 미사용. |
| `app-sandbox` | Mac App Store 전용. 우리는 Developer ID + 공증 직접배포이므로 불요. |

`disable-library-validation` 만 유지한 이유: Godot 이 게임 데이터
(`Resources/ProjectWhisper.pck`)를 로드하고 유니버설 Mach-O 슬라이스를 매핑할 때
하드닝 런타임 하에서 library-validation 거절을 피하기 위한 안전 최소 권한. Godot 문서도
ad-hoc 서명/애드온 로딩 export 에 이를 권장한다.

---

## 4. .app 번들 완성도 (Info.plist)

macOS export preset(`game/export_presets.cfg`)가 이미 아래를 채우므로 Godot 생성
Info.plist 는 공증 요건을 충족한다. `postprocess_macos_zip.py` 가 스페이스-프리 이름으로
`CFBundleExecutable`/`CFBundleName` 만 패치한다.

| 키 | 값 | 출처 |
|---|---|---|
| `CFBundleIdentifier` | `com.koalstudio.projectwhisper` | preset `application/bundle_identifier` (기존값 유지) |
| `CFBundleShortVersionString` | `1.9.1` | preset `application/short_version` (빌드 버전 동기) |
| `CFBundleVersion` | `1.9.1` | preset `application/version` (빌드 버전 동기) |
| `LSApplicationCategoryType` | `public.app-category.games` | preset `application/app_category=Games` |
| `LSMinimumSystemVersionByArchitecture` | arm64=11.00 / x86_64=10.13 | preset `min_macos_version_*` |
| `NSHumanReadableCopyright` | `© 2026 KoalStudio` | preset `application/copyright` |
| `CFBundleIconFile` | `icon.icns` | Godot 기본. 아이콘 파일 자체는 아래 파이프라인이 교체 |
| `NSHighResolutionCapable` | `true` | Godot 기본 |

버전은 `game/project.godot` 의 `config/version` 과 export preset 의 short/version 이
동기되어 있어 빌드 버전과 자동 일치한다. (릴리스 시 preset 만 bump 하면 plist 자동 반영.)

---

## 5. 커스텀 앱 아이콘

- 생성기: `tools/make_app_icon.py` — **서드파티 의존성 없음**(Pillow/png2icns/iconutil
  불필요). `struct`+`zlib` 만으로 밤 장면 아이콘(달빛 + 보라 "위스퍼" wisp + 침엽수
  실루엣 + 둥근 캐노피 나무 + 별)을 절차적·결정론적으로 렌더한다.
- 산출물: `assets-src/appicon/`
  - `icon_1024.png` (마스터)
  - `iconset/` (icon_16x16 … icon_512x512@2x, `iconutil` 파리티용)
  - `ProjectWhisper.icns` — **PNG-backed icns**. 타입 `icp4/icp5/ic07~ic10` +
    Retina `ic11~ic14` (16~1024 전 사이즈). 기존 Godot 기본 아이콘은 256px 가 최대라
    Retina 슬라이스가 없었다.
- 재생성:
  ```bash
  python3 tools/make_app_icon.py
  ```

---

## 6. 파이프라인 통합 노트 (`postprocess_macos_zip.py` 변경점)

기존 동작(스페이스-프리 rename + rcodesign ad-hoc 서명)은 **완전 불변**. 추가된 것:

- **커스텀 아이콘 주입**: rewrite 루프에서 번들의
  `Contents/Resources/icon.icns` 엔트리 바이트를 `assets-src/appicon/ProjectWhisper.icns`
  로 교체. Info.plist 는 이미 `CFBundleIconFile=icon.icns` 를 선언하므로 plist 수정·rename
  불필요.
- **무해 폴백**: 커스텀 아이콘이 없거나 `icns` 매직이 아니면 경고만 찍고 Godot 기본
  아이콘으로 진행한다. 아이콘은 미관 요소이므로 **릴리스를 절대 막지 않는다.**
- **아이콘 경로 탐색**: 이 스크립트는 (a) 공유 `<repo-parent>/tools/` 와
  (b) 리포 vendored `<repo>/tools/` 두 위치에 동일 사본으로 존재한다
  (`build_exports.sh` 는 `$REPO/../tools/` 사본을 호출). 두 레이아웃 모두에서 아이콘을
  찾도록 후보 경로를 순회하며, `$PW_APP_ICNS` 로 오버라이드 가능.
- **기존 산출 경로/이름 불변**: `export/ProjectWhisper-macos-v<VER>.zip`,
  `export/ProjectWhisper-win64-v<VER>.zip` 그대로. `build_exports.sh` 재실행으로 무회귀 확인.

---

## 7. 검증 결과 (리눅스 빌드 호스트, v1.9.1)

- `build_exports.sh` 재실행: win64 + macOS zip 정상 생성, 경로/이름 불변.
- postprocess: 6 엔트리 rename, 커스텀 아이콘(417,468 B) 주입 확인, rcodesign ad-hoc
  재서명 후 `print-signature-info` → 2 유니버설 슬라이스 모두 `ADHOC`(LINKER_SIGNED 아님),
  `_CodeSignature/CodeResources` 봉인 확인.
- Info.plist 필드 전수 확인(§4 표) 통과.
- PCK 부트 스모크: `Godot --headless --main-pack ProjectWhisper.pck` → 게임/스크립트
  에러 0, exit code 0.
- ICNS 구조 검증: 매직/길이 일치, 10개 타입 모두 유효 PNG(16~1024).
