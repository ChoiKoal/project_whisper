# STATUS — Apple 배포 준비 (태스크 #255)

## 목표
v1.9.1 macOS 빌드 Apple 공증 준비물 완비 (서명·공증은 콸 로컬 맥에서 수행).
1. .app Info.plist 공증 요건 완비 (postprocess_macos_zip.py 보강)
2. 커스텀 앱 아이콘 .icns 제작 (PIL 없이 struct/zlib 순수 파이썬)
3. entitlements.plist (Godot 4.5 GL compat 최소셋)
4. tools/notarize_local.sh (콸 맥 원커맨드)
5. dist/apple-ready zip (앱+스크립트+entitlements+README 동봉)
6. docs/apple-notarization-guide.md
7. 검증: 재서명 verify, 부트 스모크, 기존 파이프라인 무회귀

## 불변
- 기존 macOS/win zip 산출 경로·이름 불변. 게임 데이터(PCK) 무변경.
- Apple 크리덴셜 절대 미취급 (문서에 절차만). ad-hoc 서명 유지.

## 진행
- 착수. 기존 Info.plist는 Godot가 이미 CFBundleIdentifier/카테고리/버전/카피라이트 채움.
  → 커스텀 아이콘(현재 Godot 기본 아이콘)·CFBundleVersion 빌드번호 동기·entitlements 추가가 델타.
