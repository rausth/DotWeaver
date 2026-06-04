#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

APPCAST_URL="${APPCAST_URL:-}"
EXPECTED_VERSION="${EXPECTED_VERSION:-$(tr -d '[:space:]' < VERSION.txt)}"
EXPECTED_VERSION="${EXPECTED_VERSION%%-*}"
REQUIRE_SPARKLE_SIGNATURE="${REQUIRE_SPARKLE_SIGNATURE:-1}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ -z "$APPCAST_URL" ]]; then
  echo "APPCAST_URL required, for example: https://github.com/rausth/DotWeaver/releases/latest/download/appcast.xml" >&2
  exit 1
fi

case "$APPCAST_URL" in
  https://*) ;;
  *)
    echo "APPCAST_URL must use HTTPS: $APPCAST_URL" >&2
    exit 1
    ;;
esac

APPCAST_FILE="$TMP_DIR/appcast.xml"
echo "Fetch appcast: $APPCAST_URL"
curl -fsSL "$APPCAST_URL" -o "$APPCAST_FILE"

PARSED_FILE="$TMP_DIR/parsed.env"
python3 - "$APPCAST_FILE" "$EXPECTED_VERSION" "$REQUIRE_SPARKLE_SIGNATURE" > "$PARSED_FILE" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

appcast = Path(sys.argv[1])
expected_version = sys.argv[2]
require_signature = sys.argv[3] == "1"
root = ET.parse(appcast).getroot()
namespaces = {"sparkle": "http://www.andymatuschak.org/xml-namespaces/sparkle"}

items = root.findall(".//item")
if len(items) != 1:
    raise SystemExit(f"Expected one appcast item, found {len(items)}")

item = items[0]
enclosures = item.findall("enclosure")
if len(enclosures) != 1:
    raise SystemExit(f"Expected one enclosure, found {len(enclosures)}")

enclosure = enclosures[0]
short_version = item.findtext("sparkle:shortVersionString", namespaces=namespaces)
build_version = item.findtext("sparkle:version", namespaces=namespaces)
url = enclosure.attrib.get("url", "")
length = enclosure.attrib.get("length", "")
signature = enclosure.attrib.get("{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature", "")

if short_version != expected_version:
    raise SystemExit(f"Expected version {expected_version}, found {short_version}")
if not build_version:
    raise SystemExit("Missing sparkle:version")
if not url.startswith("https://"):
    raise SystemExit(f"Enclosure URL must use HTTPS: {url}")
if not length.isdigit() or int(length) <= 0:
    raise SystemExit(f"Invalid enclosure length: {length}")
if require_signature and not signature:
    raise SystemExit("Missing sparkle:edSignature")

print(f"ENCLOSURE_URL={url!r}")
print(f"ENCLOSURE_LENGTH={length!r}")
print(f"SPARKLE_VERSION={build_version!r}")
print(f"SPARKLE_SHORT_VERSION={short_version!r}")
PY

source "$PARSED_FILE"

echo "Check release asset: $ENCLOSURE_URL"
HEADERS_FILE="$TMP_DIR/headers.txt"
curl -fsSLI "$ENCLOSURE_URL" -o "$HEADERS_FILE"

STATUS="$(awk 'toupper($0) ~ /^HTTP\\// { code=$2 } END { print code }' "$HEADERS_FILE")"
if [[ "$STATUS" != "200" && "$STATUS" != "302" ]]; then
  echo "Unexpected enclosure HTTP status: ${STATUS:-unknown}" >&2
  cat "$HEADERS_FILE" >&2
  exit 1
fi

REMOTE_LENGTH="$(awk 'BEGIN{IGNORECASE=1} /^content-length:/ { gsub("\r", "", $2); length=$2 } END { print length }' "$HEADERS_FILE")"
if [[ -n "$REMOTE_LENGTH" && "$REMOTE_LENGTH" != "$ENCLOSURE_LENGTH" ]]; then
  echo "Warning: remote content-length $REMOTE_LENGTH differs from appcast length $ENCLOSURE_LENGTH" >&2
fi

echo "Hosted Sparkle validation passed"
echo "Version: $SPARKLE_SHORT_VERSION ($SPARKLE_VERSION)"
