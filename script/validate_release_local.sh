#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

script/package_release.sh --local
script/generate_appcast.sh

APP="dist/release/DotWeaver.app"
APP_BIN="$APP/Contents/MacOS/DotWeaver"
CLI_BIN="$APP/Contents/MacOS/dw"
APP_ZIP="$(find dist/artifacts -name 'DotWeaver-*-macOS-universal.zip' -maxdepth 1 -type f | head -n 1)"
CLI_TAR="$(find dist/artifacts -name 'dw-*-macOS-universal.tar.gz' -maxdepth 1 -type f | head -n 1)"

test -d "$APP"
test -x "$APP_BIN"
test -x "$CLI_BIN"
test -f "$APP_ZIP"
test -f "$CLI_TAR"
test -f dist/artifacts/SHA256SUMS.txt
test -f appcast.xml

codesign --verify --deep --strict --verbose=2 "$APP"
otool -l "$APP_BIN" | grep -q '@executable_path/../Frameworks'
"$CLI_BIN" --help | grep -q 'DotWeaver CLI'
plutil -extract SUFeedURL raw "$APP/Contents/Info.plist" | grep -q '^https://github.com/.*/releases/latest/download/appcast.xml$'
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
