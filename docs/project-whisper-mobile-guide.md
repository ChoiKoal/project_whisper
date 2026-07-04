# Project Whisper — 모바일(iOS/AOS) 빌드 가이드 v1.0

> 작성: Kana / 2026-07-05 · 결론부터: **스택 변경 없음.** 같은 Godot 프로젝트에서 4플랫폼 export.

## 0. 공통 준비 (이미 되어 있는 것)
- 렌더러 `gl_compatibility` = 모바일 표준 렌더러 ✅
- 뷰포트 stretch `canvas_items` = 해상도 대응 ✅
- 남은 공통 작업: **터치 입력** (탭투무브 + 탭 상호작용 + UI 터치 타깃 44px+) — 개발 플랜 M6.5

## 1. Android (리눅스/맥 어디서든 빌드 가능)
1. Android Studio 또는 cmdline-tools 설치 → SDK Platform 34+, Build-Tools, NDK
2. Godot 에디터 설정 → Export → Android: SDK 경로 + 디버그 키스토어 지정
   - 디버그 키스토어 생성: `keytool -genkey -v -keystore debug.keystore -alias androiddebugkey -storepass android -keypass android -keyalg RSA -validity 10000`
3. Export preset "Android" 추가 → 패키지명 `com.koalstudio.projectwhisper` → APK(테스트) / AAB(플레이스토어)
4. 플레이스토어: Google Play Console $25(1회), AAB 업로드, 내부 테스트 트랙부터
- 성능 노트: 타일맵+2D라 저사양에서도 여유. 다만 CanvasModulate 낮/밤 + 발광은 GLES3 기준 검증 필요

## 2. iOS (KOAL 맥 필수)
1. Xcode + Apple Developer Program($99/년)
2. Godot Export → iOS: Bundle ID `com.koalstudio.projectwhisper`, Team ID 지정 → Xcode 프로젝트로 export
3. Xcode에서 서명 → 실기기 테스트 → TestFlight → App Store 심사 (보통 1~3일)
- 아이패드 대응: 우리 뷰포트 설정이면 자동 레터박스 없이 스케일됨. 세이프에어리어(노치)만 UI 마진 확인

## 3. 데스크톱과 다른 점 체크리스트
- [ ] 터치 입력 (M6.5)
- [ ] UI 최소 터치 타깃 44×44pt (인벤토리/도감/조합 슬롯)
- [ ] 모바일 세이브 경로: `user://` 그대로 동작 (Godot이 플랫폼별 매핑) — 추가 작업 없음
- [ ] 오디오 포커스/백그라운드 처리 (전화 수신 시 일시정지) — 폴리시 단계
- [ ] 스토어 에셋: 아이콘 1024×1024, 스크린샷 (아이폰/아이패드/안드로이드 각 규격)

## 4. 순서 권장
데스크톱 MVP 검증 → 터치 입력(M6.5) → Android 내부 테스트(빠름, $25) → iOS TestFlight → 양대 스토어 정식. 스팀과 모바일 스토어는 빌드만 다르고 코드는 하나다.
