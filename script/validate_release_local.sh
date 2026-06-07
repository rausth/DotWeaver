#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

script/package_release.sh --local
script/generate_appcast.sh

APP="dist/release/DotWeaver.app"
APP_BIN="$APP/Contents/MacOS/DotWeaver"
CLI_BIN="$APP/Contents/MacOS/dw"
APP_ZIP="$(find dist/artifacts -maxdepth 1 -type f -name 'DotWeaver-*-macOS-universal.zip' -print -quit)"
APP_ARM_ZIP="$(find dist/artifacts -maxdepth 1 -type f -name 'DotWeaver-*-macOS-arm64.zip' -print -quit)"
APP_X86_ZIP="$(find dist/artifacts -maxdepth 1 -type f -name 'DotWeaver-*-macOS-x86_64.zip' -print -quit)"
CLI_TAR="$(find dist/artifacts -maxdepth 1 -type f -name 'dw-*-macOS-universal.tar.gz' -print -quit)"

test -d "$APP"
test -x "$APP_BIN"
test -x "$CLI_BIN"
test -f "$APP_ZIP"
test -f "$APP_ARM_ZIP"
test -f "$APP_X86_ZIP"
test -f "$CLI_TAR"
test -f dist/artifacts/SHA256SUMS.txt
test -f appcast.xml

codesign --verify --deep --strict --verbose=2 "$APP"
unzip -q -o "$APP_ARM_ZIP" -d dist/validate-arm64
unzip -q -o "$APP_X86_ZIP" -d dist/validate-x86_64
ARM_APP_BIN="$(find dist/validate-arm64 -type f -path '*/DotWeaver.app/Contents/MacOS/DotWeaver' -print -quit)"
ARM_SPARKLE_BIN="$(find dist/validate-arm64 -type f -path '*/DotWeaver.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle' -print -quit)"
X86_APP_BIN="$(find dist/validate-x86_64 -type f -path '*/DotWeaver.app/Contents/MacOS/DotWeaver' -print -quit)"
X86_SPARKLE_BIN="$(find dist/validate-x86_64 -type f -path '*/DotWeaver.app/Contents/Frameworks/Sparkle.framework/Versions/B/Sparkle' -print -quit)"
[[ "$(lipo -archs "$ARM_APP_BIN")" == "arm64" ]]
[[ "$(lipo -archs "$ARM_SPARKLE_BIN")" == "arm64" ]]
[[ "$(lipo -archs "$X86_APP_BIN")" == "x86_64" ]]
[[ "$(lipo -archs "$X86_SPARKLE_BIN")" == "x86_64" ]]
[[ "$(otool -l "$APP_BIN")" == *"@executable_path/../Frameworks"* ]]
[[ "$("$CLI_BIN" --help)" == *"DotWeaver CLI"* ]]
[[ "$(plutil -extract SUFeedURL raw -o - "$APP/Contents/Info.plist")" == https://github.com/*/releases/latest/download/appcast.xml ]]
shasum -a 256 -c dist/artifacts/SHA256SUMS.txt

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET

appcast = Path("appcast.xml")
root = ET.parse(appcast).getroot()
enclosures = root.findall(".//enclosure")
if len(enclosures) != 1:
    raise SystemExit(f"Expected one enclosure, found {len(enclosures)}")
enclosure = enclosures[0]
for attr in ("url", "length", "type"):
    if not enclosure.attrib.get(attr):
        raise SystemExit(f"Missing appcast enclosure attribute: {attr}")
print("Appcast XML valid")
PY

echo "Local release validation passed"
