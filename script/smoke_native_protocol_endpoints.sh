#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -x dist/release/DotWeaver.app/Contents/MacOS/dw ]]; then
  script/package_release.sh --local
fi

ROOT="${ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotweaver-native-smoke.XXXXXX")}"
LOCAL_ROOT="${DOTWEAVER_NATIVE_LOCAL_ROOT:-$HOME/.dotweaver/native-provider-smoke-local}"
CLI_BIN="dist/release/DotWeaver.app/Contents/MacOS/dw"

mkdir -p "$ROOT"

run_dw() {
  local provider="$1"
  shift
  DOTWEAVER_APP_SUPPORT_DIR="$ROOT/$provider/app-support" \
  DOTWEAVER_SNAPSHOT_DIR="$ROOT/$provider/snapshots" \
  DOTWEAVER_USER_DEFAULTS_SUITE="com.rausth.DotWeaver.native-provider-smoke.$provider" \
  DOTWEAVER_ALLOW_UNSAFE_LOCAL_PATHS=1 \
  "$CLI_BIN" "$@"
}

smoke_native_provider() {
  local provider="$1"
  local endpoint="$2"
  local username="$3"
  local case_root="$LOCAL_ROOT/$provider"
  local local_file="$case_root/local/$provider-native.conf"

  if [[ -z "$endpoint" ]]; then
    echo "Skip native provider smoke: $provider endpoint not configured"
    return 0
  fi

  mkdir -p "$ROOT/$provider/app-support" "$ROOT/$provider/snapshots" "$(dirname "$local_file")"
  printf 'provider=%s\nendpoint=%s\n' "$provider" "$endpoint" > "$local_file"

  echo "Native provider smoke: $provider -> $endpoint"
  run_dw "$provider" provider set "$provider" >/dev/null
  run_dw "$provider" provider transport "$provider" native >/dev/null
  if [[ -n "$username" ]]; then
    run_dw "$provider" native config "$provider" --endpoint "$endpoint" --username "$username" >/dev/null
  else
    run_dw "$provider" native config "$provider" --endpoint "$endpoint" >/dev/null
  fi
  run_dw "$provider" add "$local_file" --group native-provider-smoke --tag "$provider" >/dev/null
  run_dw "$provider" sync >/dev/null
}

smoke_native_provider webdav "${DOTWEAVER_NATIVE_WEBDAV_ENDPOINT:-}" "${DOTWEAVER_NATIVE_WEBDAV_USERNAME:-}"
smoke_native_provider sftp "${DOTWEAVER_NATIVE_SFTP_ENDPOINT:-}" "${DOTWEAVER_NATIVE_SFTP_USERNAME:-}"
smoke_native_provider ftps "${DOTWEAVER_NATIVE_FTPS_ENDPOINT:-}" "${DOTWEAVER_NATIVE_FTPS_USERNAME:-}"
smoke_native_provider s3 "${DOTWEAVER_NATIVE_S3_ENDPOINT:-}" "${DOTWEAVER_NATIVE_S3_USERNAME:-}"

echo "Native protocol endpoint smoke complete: $ROOT"
