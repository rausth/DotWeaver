#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-$(tr -d '[:space:]' < VERSION.txt)}"
VERSION="${VERSION%%-*}"
BUILD="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-1}}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-dist/artifacts}"
APP_ZIP="${APP_ZIP:-${ARTIFACTS_DIR}/DotWeaver-${VERSION}-macOS-universal.zip}"
DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL:-https://github.com/rausth/DotWeaver/releases/download/v${VERSION}}"
APPCAST_PATH="${APPCAST_PATH:-appcast.xml}"
REQUIRE_SPARKLE_SIGNATURE="${REQUIRE_SPARKLE_SIGNATURE:-0}"

if [[ ! -f "$APP_ZIP" ]]; then
  echo "Missing app archive: $APP_ZIP" >&2
  exit 1
fi

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" && -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  SPARKLE_PRIVATE_KEY_FILE="$(mktemp)"
  trap 'rm -f "$SPARKLE_PRIVATE_KEY_FILE"' EXIT
  printf '%s' "$SPARKLE_PRIVATE_KEY" > "$SPARKLE_PRIVATE_KEY_FILE"
fi

if [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" ]]; then
  SIGN_TOOL="$(find .build -path '*/sign_update' -type f -perm -111 | head -n 1 || true)"
  if [[ -n "$SIGN_TOOL" ]]; then
    SIGN_OUTPUT="$("$SIGN_TOOL" --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$APP_ZIP")"
    SIGNATURE="$(printf '%s\n' "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p; s/.*edSignature: //p' | head -n 1)"
  fi
fi

FILENAME="$(basename "$APP_ZIP")"
LENGTH="$(stat -f%z "$APP_ZIP")"
PUB_DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"
DOWNLOAD_URL="${DOWNLOAD_BASE_URL}/${FILENAME}"
SIGNATURE_ATTRIBUTE=""
if [[ -n "${SIGNATURE:-}" ]]; then
  SIGNATURE_ATTRIBUTE=" sparkle:edSignature=\"${SIGNATURE}\""
elif [[ "$REQUIRE_SPARKLE_SIGNATURE" == "1" ]]; then
  echo "Sparkle signature required but no signature was generated" >&2
  exit 1
fi

cat > "$APPCAST_PATH" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>DotWeaver</title>
    <link>https://github.com/rausth/DotWeaver</link>
    <description>DotWeaver macOS updates</description>
    <language>en</language>
    <item>
      <title>Version ${VERSION}</title>
      <link>https://github.com/rausth/DotWeaver/releases/tag/v${VERSION}</link>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <description><![CDATA[
        <p>See GitHub release notes for changes.</p>
      ]]></description>
      <pubDate>${PUB_DATE}</pubDate>
      <enclosure url="${DOWNLOAD_URL}" sparkle:version="${BUILD}" sparkle:shortVersionString="${VERSION}" length="${LENGTH}" type="application/octet-stream"${SIGNATURE_ATTRIBUTE} />
    </item>
  </channel>
</rss>
EOF

echo "Generated appcast: $APPCAST_PATH"
