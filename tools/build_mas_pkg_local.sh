#!/usr/bin/env bash
# =============================================================================
# Project Whisper — Mac App Store (.pkg) 빌드 스크립트   [콸 로컬 맥 전용]
# =============================================================================
#
# 이 스크립트는 **콸의 맥에서** 실행합니다 (codesign / productbuild / security 는
# macOS 전용). 리눅스 빌드 호스트에서 만든 ad-hoc 서명 zip(dist/apple-ready)의
# ProjectWhisper.app 을, Mac App Store 제출용으로 **재서명 → .pkg 패키징** 합니다.
#
# 트랙 구분:
#   · notarize_local.sh      → Developer ID 직접배포(공증). 샌드박스 없음. .zip/.dmg 산출.
#   · build_mas_pkg_local.sh → Mac App Store. **샌드박스 필수**. .pkg 산출 → Transporter 업로드.
#   두 트랙은 인증서도 entitlements 도 다릅니다 (아래 참고).
#
# ─────────────────────────────────────────────────────────────────────────────
# 사전 준비 (최초 1회) — 자세한 단계는 docs/apple-appstore-guide.md 참고
# ─────────────────────────────────────────────────────────────────────────────
#  1) Xcode Command Line Tools:  xcode-select --install
#  2) developer.apple.com 에서 **MAS용 인증서 2종**을 발급해 키체인에 설치:
#       · "Apple Distribution" (또는 구명칭 "3rd Party Mac Developer Application")
#         → .app 서명용
#       · "3rd Party Mac Developer Installer" (또는 "Mac Installer Distribution")
#         → .pkg 서명용
#     확인:  security find-identity -v            (앱용)
#            security find-identity -v -p basic   (설치관리자 인증서 포함 전체)
#  3) App ID(com.koalstudio.projectwhisper) 로 **macOS App Store Provisioning
#     Profile** 을 만들어 다운로드 → 파일 경로를 아래 PROFILE 인자로 넘김.
#       (App Store Connect 에 앱 레코드도 먼저 만들어 둬야 빌드 업로드가 붙습니다.)
#
# ─────────────────────────────────────────────────────────────────────────────
# 사용법
# ─────────────────────────────────────────────────────────────────────────────
#   ./tools/build_mas_pkg_local.sh <ProjectWhisper.app> <embedded.provisionprofile>
#
# 예: apple-ready zip 을 푼 폴더에서 app 을 쓰고, 프로파일은 다운로드 폴더:
#   ./build_mas_pkg_local.sh ./ProjectWhisper.app ~/Downloads/ProjectWhisper_MAS.provisionprofile
#
# 환경변수(선택 — 미지정 시 security find-identity 로 자동 감지):
#   APP_IDENTITY  앱 서명 인증서 이름  (기본: "Apple Distribution" / "3rd Party Mac Developer Application")
#   PKG_IDENTITY  설치 서명 인증서 이름 (기본: "3rd Party Mac Developer Installer" / "Mac Installer Distribution")
#   ENTITLEMENTS  entitlements 파일   (기본: tools/apple/entitlements-mas.plist)
#   OUT           산출 .pkg 접두어    (기본: ProjectWhisper-mas)
# =============================================================================
set -euo pipefail

APP="${1:-}"
PROFILE="${2:-}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTITLEMENTS="${ENTITLEMENTS:-$HERE/apple/entitlements-mas.plist}"
OUT="${OUT:-ProjectWhisper-mas}"
BUNDLE_ID="com.koalstudio.projectwhisper"

fail() { echo ""; echo "✗ 실패: $*" >&2; exit 1; }
step() { echo ""; echo "▶ $*"; }

# --- 0. 플랫폼/인자/도구 확인 ------------------------------------------------
[ "$(uname)" = "Darwin" ] || fail "이 스크립트는 macOS 에서만 동작합니다 (현재: $(uname))."
command -v codesign     >/dev/null || fail "codesign 없음 → xcode-select --install 먼저 실행."
command -v productbuild >/dev/null || fail "productbuild 없음 → Xcode Command Line Tools 설치 필요."
command -v security     >/dev/null || fail "security(키체인 도구) 없음."
[ -n "$APP" ]    || fail "1번째 인자로 ProjectWhisper.app 경로를 주세요.  사용법: $0 <app> <profile>"
[ -d "$APP" ]    || fail "앱 번들을 찾을 수 없음: $APP"
[ -n "$PROFILE" ] || fail "2번째 인자로 provisioning profile(.provisionprofile) 경로를 주세요."
[ -f "$PROFILE" ] || fail "provisioning profile 파일을 찾을 수 없음: $PROFILE"
[ -f "$ENTITLEMENTS" ] || fail "entitlements-mas.plist 없음: $ENTITLEMENTS"

# --- 1. 서명 인증서 자동 감지 ------------------------------------------------
# 앱용: "Apple Distribution" (신) 또는 "3rd Party Mac Developer Application" (구).
if [ -z "${APP_IDENTITY:-}" ]; then
  step "앱 서명 인증서 자동 감지 (security find-identity)"
  APP_IDENTITY="$(security find-identity -v 2>/dev/null \
      | grep -Ei 'Apple Distribution|3rd Party Mac Developer Application' | head -n1 \
      | sed -E 's/^[^"]*"([^"]+)".*/\1/')"
  [ -n "$APP_IDENTITY" ] || fail "'Apple Distribution' / '3rd Party Mac Developer Application' 인증서를 못 찾음.
     → developer.apple.com → Certificates 에서 발급/다운로드 후 더블클릭으로 키체인 설치.
     → 확인:  security find-identity -v"
fi
# 설치관리자용: "3rd Party Mac Developer Installer" 또는 "Mac Installer Distribution".
if [ -z "${PKG_IDENTITY:-}" ]; then
  step "설치관리자(.pkg) 서명 인증서 자동 감지"
  PKG_IDENTITY="$(security find-identity -v -p basic 2>/dev/null \
      | grep -Ei '3rd Party Mac Developer Installer|Mac Installer Distribution' | head -n1 \
      | sed -E 's/^[^"]*"([^"]+)".*/\1/')"
  [ -n "$PKG_IDENTITY" ] || fail "'3rd Party Mac Developer Installer' / 'Mac Installer Distribution' 인증서를 못 찾음.
     → developer.apple.com → Certificates 에서 'Mac Installer Distribution' 발급 후 키체인 설치."
fi
echo "  앱 서명:   $APP_IDENTITY"
echo "  설치 서명: $PKG_IDENTITY"

# --- 2. provisioning profile 임베드 ------------------------------------------
# MAS 빌드는 .app/Contents/embedded.provisionprofile 이 반드시 있어야 하며,
# 그 프로파일의 App ID 가 번들ID($BUNDLE_ID)와 일치해야 업로드가 통과합니다.
step "provisioning profile 임베드 → Contents/embedded.provisionprofile"
cp "$PROFILE" "$APP/Contents/embedded.provisionprofile" \
  || fail "프로파일 복사 실패. $APP 쓰기 권한 확인."

# --- 3. codesign (샌드박스 entitlements + 하드닝 런타임) ----------------------
# --deep 로 번들 전체(실행/pck/_CodeSignature)를 앱 인증서로 재서명. 기존 ad-hoc
# 서명은 덮어씀. MAS 는 entitlements-mas.plist(app-sandbox=true)를 반드시 반영.
step "codesign — 샌드박스 + Apple Distribution 서명"
codesign --force --deep --options runtime --timestamp \
         --entitlements "$ENTITLEMENTS" \
         --sign "$APP_IDENTITY" \
         "$APP" \
  || fail "codesign 실패. 인증서 유효기간/키체인 잠금(security unlock-keychain)/프로파일 App ID 일치 확인."

step "codesign --verify (서명 무결성)"
codesign --verify --deep --strict --verbose=2 "$APP" \
  || fail "서명 검증 실패 — 번들 일부만 서명됐거나 손상."

step "codesign -d --entitlements (샌드박스 적용 확인)"
if codesign -d --entitlements :- "$APP" 2>/dev/null | grep -q "app-sandbox"; then
  echo "  ✔ app-sandbox entitlement 적용 확인"
else
  fail "서명된 번들에 app-sandbox 가 없음 — MAS 는 샌드박스 필수. entitlements 경로 확인."
fi

# --- 4. productbuild (.pkg, 설치관리자 인증서로 서명) -------------------------
# MAS 업로드는 .app 이 아니라 --component 로 감싼 서명된 .pkg 를 요구합니다.
PKG="$OUT.pkg"
step "productbuild — 설치 .pkg 생성 및 서명: $PKG"
rm -f "$PKG"
productbuild --component "$APP" /Applications \
             --sign "$PKG_IDENTITY" \
             "$PKG" \
  || fail "productbuild 실패. 설치관리자 인증서/키체인 확인."

# --- 5. 산출물 안내 (Transporter 업로드는 수동) ------------------------------
echo ""
echo "============================================================"
echo "✔ MAS 패키지 생성 완료:"
echo "    $PKG"
echo ""
echo "  다음 단계 (업로드):"
echo "    1) Transporter.app 실행 (App Store 에서 무료 설치) → Apple ID 로그인"
echo "    2) $PKG 를 창에 끌어다 놓기 → '전송(Deliver)' 클릭"
echo "       (또는 CLI:  xcrun altool --upload-app -f \"$PKG\" -t macos \\ )"
echo "       (           --apple-id <APPLE_ID> --password <app-specific-pw> )"
echo "    3) App Store Connect → 해당 앱 → 빌드 처리 완료(수 분~수십 분) 후 빌드 선택 → 심사 제출"
echo ""
echo "  자세한 단계별 절차: docs/apple-appstore-guide.md"
echo "============================================================"
