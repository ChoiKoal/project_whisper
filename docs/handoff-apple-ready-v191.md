# handoff — Apple 배포 준비 최종 검수 (#255, apple-ready v1.9.1)

트랙 A(Developer ID 공증 직접배포) + 트랙 B(Mac App Store) 배포 준비물 최종 자가검수. 코드/에셋 무변경 — 검증만.

## 산출물
- `dist/apple-ready/ProjectWhisper-apple-ready-v1.9.1.zip` (69,000,924 B, 14 entries)
  - `ProjectWhisper.app/` (Info.plist·icon.icns·ProjectWhisper.pck·_CodeSignature/CodeResources 완비)
  - `notarize_local.sh`, `entitlements.plist`, `build_mas_pkg_local.sh`
  - `apple/entitlements-mas.plist`
  - `guides/apple-notarization-guide.md`, `guides/apple-appstore-guide.md`, `guides/README-공증절차.md`
- `dist/apple-ready/screenshots/` — 전 플랫폼 세트(아래 표) + `README-screenshots.md`

## 1. 스크린샷 규격 검수 (IHDR 픽셀 실측 — 전부 OK)
| 폴더 | 규격 | 장수 | 결과 |
|---|---|---|---|
| ios-6.9 | 2868×1320 | 5 | OK |
| ios-6.5 | 2778×1284 | 5 | OK |
| ipad-13 | 2732×2048 | 5 | OK |
| android-phone | 1920×1080 | 5 | OK |
| android-tablet | 2560×1600 | 5 | OK |
| mas | 2880×1800 | 5 | OK |
| feature-graphic | 1024×500 | 1 | OK |
총 31장 전부 규격 정확. 시각 스팟체크(ios-6.9/01-home) — 프레임 구도·"PROJECT WHISPER" 타이틀·비율 정상.

## 2. apple-ready zip 검증
- Info.plist 완비: CFBundleIdentifier=com.koalstudio.projectwhisper, ShortVersion/Version=1.9.1, CFBundleIconFile=icon.icns, LSApplicationCategoryType=public.app-category.games, arch priority arm64+x86_64, LSMinimumSystemVersion(arm64 11.0 / x86_64 10.13).
- 서명: `rcodesign print-signature-info` — 양 슬라이스(arm64/x86_64) **ADHOC CodeDirectory**, identifier 정합, sha256 digest, Info/Resources 슬롯 채워짐, `_CodeSignature/CodeResources` 봉인 존재. `cms: null`(ad-hoc이므로 정상 — CMS 인증서 없음). rcodesign `verify` 서브커맨드의 CMS 에러는 ad-hoc 예상 동작(스크립트도 verify 대신 print-signature-info로 검증).
- PCK 부트 스모크: 매직 `GDPC` 확인. `Godot --headless --main-pack ProjectWhisper.pck --quit` → **exit 0, 에러 0**.

## 3. 기존 릴리스 파이프라인 무회귀
- apple-ready v1.9.1 `.app` 내부 레이아웃 ↔ 마지막 배포 v1.4.1 macos zip `.app` 내부 레이아웃 **완전 동일**(추가/누락 0). 동일 rename 결과(space-free exe + ProjectWhisper.pck), 동일 Info.plist·icon.icns·PkgInfo·PrivacyInfo.xcprivacy·_CodeSignature 경로.
- `tools/postprocess_macos_zip.py`를 실 배포 zip(v1.4.1) 복사본에 재실행 → **exit 0**, `verify OK: 2 slice(s) ADHOC-signed, CodeResources sealed`, 출력 구조 정상. 변경점(ad-hoc 서명·아이콘 주입)은 번들 내용물 in-place 조작뿐 — 경로/이름/구조 무영향.

## 4. 세이브 경로 샌드박스 호환 (정적 감사)
- `game/scripts/core/save_manager.gd`: `SAVE_PATH := "user://save1.json"`. 모든 FileAccess·has_save가 user:// 기반.
- 유일한 `ProjectSettings.globalize_path()`(133행)는 delete 시 `DirAccess.remove_absolute()` 용도이며 바로 아래 user:// 기반 fallback 있음. macOS App Sandbox에서 user://는 컨테이너로 리다이렉트 → **양쪽 트랙 호환**. 하드코딩 절대경로/`/Users/`/`OS.get_data_dir()` 이스케이프 **없음**.

## 5. 가이드 2종 검토
- 트랙 분리 명확: appstore-guide 상단 배너 + §7 트랙 A/B 차이 요약표, 각 문서 상호참조.
- notarization-guide: 매 릴리스 단일 커맨드(`./notarize_local.sh`), entitlements 표, Info.plist 완성도, spctl 검증 — 실행 가능.
- appstore-guide: App ID·인증서 2종·프로파일·App Store Connect·.pkg(build_mas_pkg_local.sh)·Transporter·심사 유의 — MAS 체크리스트 실행 가능.
- 모바일 빌드 스코프 밖 명시: `README-screenshots.md` §"모바일 빌드는 이번 스코프 밖 (백로그)" — 스크린샷 에셋만 생성, iOS/Android 실 빌드는 별도 트랙/백로그(mobile-guide 참조).

## 콸이 할 일 (맥에서)
- **트랙 A (공증 직접배포)**: apple-ready zip 풀고 → `./notarize_local.sh` (Developer ID Application 인증서 1종 키체인 필요) → staple → spctl accepted 확인. 심사 없음.
- **트랙 B (Mac App Store)**: App ID 등록 → Apple Distribution + Mac Installer Distribution 인증서 2종 + macOS App Store 프로파일 → `build_mas_pkg_local.sh`로 .pkg → Transporter 업로드 → App Store Connect 앱 레코드(스크린샷 mas/ 2880×1800 5장 그대로 업로드 가능) → 심사 제출.
- **모바일(iOS/Android)**: 이번 스코프 밖. 스크린샷 규격 세트만 준비됨. 실 빌드는 백로그(mobile-guide).
