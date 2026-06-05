#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 ]]; then
  echo "Usage: script/generate_sparkle_ci_keys.sh <private-key-output-file>" >&2
  exit 1
fi

mkdir -p .build/module-cache
swift -module-cache-path .build/module-cache script/generate_sparkle_ci_keys.swift "$1"
