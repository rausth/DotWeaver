#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ACCOUNT="${SPARKLE_KEY_ACCOUNT:-com.rausth.DotWeaver}"
EXPORT_PATH="${1:-}"
TOOL="$(find .build -path '*/generate_keys' -type f -perm -111 | head -n 1 || true)"

if [[ -z "$TOOL" ]]; then
  echo "Sparkle generate_keys tool not found. Run: swift build" >&2
  exit 1
fi

echo "Sparkle public key for Info.plist / SPARKLE_PUBLIC_ED_KEY:"
"$TOOL" --account "$ACCOUNT"

if [[ -n "$EXPORT_PATH" ]]; then
  echo "Export private key for GitHub SPARKLE_PRIVATE_KEY secret: $EXPORT_PATH"
  "$TOOL" --account "$ACCOUNT" -x "$EXPORT_PATH"
fi
