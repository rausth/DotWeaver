#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -d dist/release/DotWeaver.app ]]; then
  script/package_release.sh --local
fi

ROOT="${ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotweaver-ui-smoke.XXXXXX")}"
APP_SUPPORT="$ROOT/app-support"
SNAPSHOT_DIR="$ROOT/snapshots"
APP_BIN="dist/release/DotWeaver.app/Contents/MacOS/DotWeaver"
CLI_BIN="dist/release/DotWeaver.app/Contents/MacOS/dw"

mkdir -p "$APP_SUPPORT" "$SNAPSHOT_DIR"

DOTWEAVER_APP_SUPPORT_DIR="$APP_SUPPORT" \
DOTWEAVER_SNAPSHOT_DIR="$SNAPSHOT_DIR" \
DOTWEAVER_USER_DEFAULTS_SUITE="com.rausth.DotWeaver.ui-smoke" \
DOTWEAVER_ALLOW_UNSAFE_LOCAL_PATHS=1 \
"$APP_BIN" &
APP_PID=$!

cleanup() {
  if kill -0 "$APP_PID" >/dev/null 2>&1; then
    kill "$APP_PID" >/dev/null 2>&1 || true
    wait "$APP_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

for _ in {1..30}; do
  if kill -0 "$APP_PID" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! kill -0 "$APP_PID" >/dev/null 2>&1; then
  echo "DotWeaver app did not stay running" >&2
  exit 1
fi

"$CLI_BIN" --help | grep -q 'DotWeaver CLI'

if [[ "${DOTWEAVER_ENABLE_AX_UI_TEST:-0}" == "1" ]]; then
  if ! osascript <<'APPLESCRIPT'
tell application "System Events"
  repeat 30 times
    if exists process "DotWeaver" then return
    delay 1
  end repeat
  error "DotWeaver process not visible to System Events"
end tell
APPLESCRIPT
  then
    echo "AX UI smoke failed. Grant Accessibility/Automation permission for this terminal or Codex host, then retry with DOTWEAVER_ENABLE_AX_UI_TEST=1." >&2
    exit 1
  fi
fi

echo "App launch smoke passed: $ROOT"
