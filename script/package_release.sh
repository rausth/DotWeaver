#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

LOCAL_BUILD=0
if [[ "${1:-}" == "--local" ]]; then
  LOCAL_BUILD=1
fi

APP_NAME="DotWeaver"
BUNDLE_NAME="${APP_NAME}.app"
BUNDLE_ID="${PRODUCT_BUNDLE_IDENTIFIER:-com.rausth.DotWeaver}"
VERSION_RAW="$(tr -d '[:space:]' < VERSION.txt)"
VERSION="${VERSION_RAW%%-*}"
BUILD="${VERSION_RAW#*-}"
if [[ "$BUILD" == "$VERSION_RAW" ]]; then
  BUILD="${GITHUB_RUN_NUMBER:-1}"
fi

DIST_DIR="${DIST_DIR:-dist}"
RELEASE_DIR="${DIST_DIR}/release"
APP_DIR="${RELEASE_DIR}/${BUNDLE_NAME}"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
ARTIFACTS_DIR="${DIST_DIR}/artifacts"
SIGN_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARIZE="${NOTARIZE:-0}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://github.com/rausth/DotWeaver/releases/latest/download/appcast.xml}"
SPARKLE_PUBLIC_ED_KEY="${SPARKLE_PUBLIC_ED_KEY:-}"
ENTITLEMENTS_FILE="DotWeaver.entitlements"

if [[ "$NOTARIZE" == "1" && -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  echo "SPARKLE_PUBLIC_ED_KEY required for production notarized releases" >&2
  exit 1
fi

rm -rf "$DIST_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$ARTIFACTS_DIR"
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PWD/.build/module-cache}"
mkdir -p "$CLANG_MODULE_CACHE_PATH"

echo "Build arm64"
swift build -c release --arch arm64

echo "Build x86_64"
swift build -c release --arch x86_64

ARM_DIR=".build/arm64-apple-macosx/release"
X86_DIR=".build/x86_64-apple-macosx/release"

echo "Create universal binaries"
lipo -create "${ARM_DIR}/DotWeaverApp" "${X86_DIR}/DotWeaverApp" -output "${MACOS_DIR}/DotWeaver"
lipo -create "${ARM_DIR}/dw" "${X86_DIR}/dw" -output "${MACOS_DIR}/dw"
chmod +x "${MACOS_DIR}/DotWeaver" "${MACOS_DIR}/dw"
install_name_tool -add_rpath "@executable_path/../Frameworks" "${MACOS_DIR}/DotWeaver"

cp AppIcon.icns "${RESOURCES_DIR}/AppIcon.icns"

copy_sparkle_framework() {
  local framework
  framework="$(find .build -path '*/Sparkle.framework' -type d | head -n 1 || true)"
  if [[ -z "$framework" ]]; then
    echo "Sparkle.framework not found under .build" >&2
    return 1
  fi

  echo "Copy Sparkle.framework"
  ditto "$framework" "${FRAMEWORKS_DIR}/Sparkle.framework"
}

copy_sparkle_framework

RESOURCE_BUNDLE="${ARM_DIR}/DotWeaver_DotWeaver.bundle"
if [[ -d "$RESOURCE_BUNDLE" ]]; then
  echo "Copy DotWeaver resource bundle"
  ditto "$RESOURCE_BUNDLE" "${RESOURCES_DIR}/DotWeaver_DotWeaver.bundle"
fi

RPATH_CHECK_FILE="${RELEASE_DIR}/DotWeaver.rpaths.txt"
otool -l "${MACOS_DIR}/DotWeaver" > "$RPATH_CHECK_FILE"
if ! grep -q "@executable_path/../Frameworks" "$RPATH_CHECK_FILE"; then
  echo "Missing Sparkle runtime rpath" >&2
  exit 1
fi

cat > "${CONTENTS_DIR}/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DotWeaver</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>DotWeaver</string>
    <key>CFBundleDisplayName</key>
    <string>DotWeaver</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
    <key>SUFeedURL</key>
    <string>${SPARKLE_FEED_URL}</string>
    <key>SUEnableInstallerLauncherService</key>
    <true/>
EOF

if [[ -n "$SPARKLE_PUBLIC_ED_KEY" ]]; then
  cat >> "${CONTENTS_DIR}/Info.plist" <<EOF
    <key>SUPublicEDKey</key>
    <string>${SPARKLE_PUBLIC_ED_KEY}</string>
EOF
fi

cat >> "${CONTENTS_DIR}/Info.plist" <<EOF
</dict>
</plist>
EOF

plutil -lint "${CONTENTS_DIR}/Info.plist"

if [[ -n "$SIGN_IDENTITY" ]]; then
  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "APPLE_TEAM_ID required when signing with Developer ID entitlements" >&2
    exit 1
  fi
  ENTITLEMENTS_FILE="${RELEASE_DIR}/DotWeaver.release.entitlements"
  perl -pe 's/\$\(TeamIdentifierPrefix\)/'"${APPLE_TEAM_ID}."'/g' DotWeaver.entitlements > "$ENTITLEMENTS_FILE"
  plutil -lint "$ENTITLEMENTS_FILE"
fi

sign_path() {
  local path="$1"
  if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --timestamp --options runtime --entitlements "$ENTITLEMENTS_FILE" --sign "$SIGN_IDENTITY" "$path"
  else
    codesign --force --deep --sign - "$path"
  fi
}

echo "Sign app"
if [[ -n "$SIGN_IDENTITY" ]]; then
  find "${FRAMEWORKS_DIR}" -type f -perm -111 -print0 | while IFS= read -r -d '' executable; do
    sign_path "$executable" || true
  done
  find "${FRAMEWORKS_DIR}" -name '*.framework' -type d -maxdepth 2 -print0 | while IFS= read -r -d '' framework; do
    sign_path "$framework"
  done
  sign_path "${MACOS_DIR}/dw"
  sign_path "$APP_DIR"
else
  sign_path "$APP_DIR"
fi

codesign --verify --deep --strict --verbose=2 "$APP_DIR"

APP_ZIP="${ARTIFACTS_DIR}/DotWeaver-${VERSION}-macOS-universal.zip"
CLI_TAR="${ARTIFACTS_DIR}/dw-${VERSION}-macOS-universal.tar.gz"

ditto -c -k --keepParent "$APP_DIR" "$APP_ZIP"
tar -C "$MACOS_DIR" -czf "$CLI_TAR" dw

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ -z "$SIGN_IDENTITY" ]]; then
    echo "DEVELOPER_ID_APPLICATION required for notarization" >&2
    exit 1
  fi
  if [[ -z "${APPLE_ID:-}" || -z "${APPLE_TEAM_ID:-}" || -z "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
    echo "APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD required for notarization" >&2
    exit 1
  fi

  echo "Submit app zip to Apple notary service"
  xcrun notarytool submit "$APP_ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --wait

  echo "Staple notarization ticket"
  xcrun stapler staple "$APP_DIR"
  xcrun stapler validate "$APP_DIR"

  rm -f "$APP_ZIP"
  ditto -c -k --keepParent "$APP_DIR" "$APP_ZIP"
fi

shasum -a 256 "$APP_ZIP" "$CLI_TAR" > "${ARTIFACTS_DIR}/SHA256SUMS.txt"

echo "Artifacts:"
echo "  $APP_ZIP"
echo "  $CLI_TAR"
echo "  ${ARTIFACTS_DIR}/SHA256SUMS.txt"

if [[ "$LOCAL_BUILD" == "1" ]]; then
  echo "Local app: $APP_DIR"
fi
