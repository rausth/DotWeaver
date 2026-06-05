#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -x dist/release/DotWeaver.app/Contents/MacOS/dw ]]; then
  script/package_release.sh --local
fi

ROOT="${ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotweaver-real-provider-smoke.XXXXXX")}"
LOCAL_ROOT="${DOTWEAVER_REAL_LOCAL_ROOT:-$HOME/.dotweaver/real-provider-smoke-local}"
CLI_BIN="dist/release/DotWeaver.app/Contents/MacOS/dw"

mkdir -p "$ROOT" "$LOCAL_ROOT"

run_dw() {
  local provider="$1"
  shift
  DOTWEAVER_APP_SUPPORT_DIR="$APP_SUPPORT" \
  DOTWEAVER_SNAPSHOT_DIR="$SNAPSHOT_DIR" \
  DOTWEAVER_USER_DEFAULTS_SUITE="com.rausth.DotWeaver.real-provider-smoke.$provider" \
  DOTWEAVER_ALLOW_UNSAFE_LOCAL_PATHS=1 \
  "$CLI_BIN" "$@"
}

smoke_provider() {
  local provider="$1"
  local provider_root="$2"
  local APP_SUPPORT="$ROOT/$provider/app-support"
  local SNAPSHOT_DIR="$ROOT/$provider/snapshots"
  local case_root="$LOCAL_ROOT/$provider"
  local local_file="$case_root/local/$provider.conf"

  if [[ -z "$provider_root" ]]; then
    return 0
  fi

  mkdir -p "$APP_SUPPORT" "$SNAPSHOT_DIR" "$(dirname "$local_file")" "$provider_root"
  provider_root="$(cd "$provider_root" && pwd -P)"
  printf 'provider=%s\nroot=%s\n' "$provider" "$provider_root" > "$local_file"

  echo "Real provider smoke: $provider -> $provider_root"
  run_dw "$provider" provider set "$provider" >/dev/null
  run_dw "$provider" provider transport "$provider" folder >/dev/null
  run_dw "$provider" provider folder "$provider_root" >/dev/null
  run_dw "$provider" add "$local_file" --group real-provider-smoke --tag "$provider" >/dev/null
  run_dw "$provider" sync >/dev/null
  run_dw "$provider" snapshot create "real-provider-smoke-$provider" >/dev/null

  test -f "$provider_root/.dotweaver/manifests/files.json"
  test -d "$provider_root/.dotweaver/files"
  test -d "$provider_root/.dotweaver/snapshots"
}

smoke_provider icloud "${DOTWEAVER_REAL_ICLOUD_ROOT:-}"
smoke_provider onedrive "${DOTWEAVER_REAL_ONEDRIVE_ROOT:-}"
smoke_provider googledrive "${DOTWEAVER_REAL_GOOGLEDRIVE_ROOT:-}"
smoke_provider dropbox "${DOTWEAVER_REAL_DROPBOX_ROOT:-}"
smoke_provider webdav "${DOTWEAVER_REAL_WEBDAV_ROOT:-}"
smoke_provider sftp "${DOTWEAVER_REAL_SFTP_ROOT:-}"
smoke_provider ftps "${DOTWEAVER_REAL_FTPS_ROOT:-}"
smoke_provider s3 "${DOTWEAVER_REAL_S3_ROOT:-}"

echo "Real provider folder smoke passed: $ROOT"
