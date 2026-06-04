#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ROOT="${ROOT:-$(mktemp -d "${TMPDIR:-/tmp}/dotweaver-provider-smoke.XXXXXX")}"
DW_BIN="${DW_BIN:-.build/debug/dw}"

if [[ ! -x "$DW_BIN" ]]; then
  swift build --product dw
fi

run_dw() {
  DOTWEAVER_APP_SUPPORT_DIR="$APP_SUPPORT" \
  DOTWEAVER_SNAPSHOT_DIR="$SNAPSHOT_DIR" \
  DOTWEAVER_USER_DEFAULTS_SUITE="$DEFAULTS_SUITE" \
  DOTWEAVER_ALLOW_UNSAFE_LOCAL_PATHS=1 \
  "$DW_BIN" "$@"
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  if [[ ! -f "$file" ]]; then
    echo "Missing file: $file" >&2
    exit 1
  fi
  if ! grep -q "$expected" "$file"; then
    echo "File does not contain expected text: $file" >&2
    exit 1
  fi
}

assert_provider_layout() {
  local provider_root="$1"
  test -d "$provider_root/.dotweaver/files"
  test -d "$provider_root/.dotweaver/manifests"
  test -d "$provider_root/.dotweaver/versions"
}

smoke_folder_provider() {
  local provider="$1"
  local case_root="$ROOT/$provider"
  local provider_root="$case_root/provider"
  local local_file="$case_root/local/$provider.conf"

  APP_SUPPORT="$case_root/app-support"
  SNAPSHOT_DIR="$case_root/snapshots"
  DEFAULTS_SUITE="com.rausth.DotWeaver.smoke.$provider"

  mkdir -p "$(dirname "$local_file")" "$provider_root" "$APP_SUPPORT" "$SNAPSHOT_DIR"
  printf 'provider=%s\n' "$provider" > "$local_file"

  run_dw provider set "$provider" >/dev/null
  run_dw provider transport "$provider" folder >/dev/null
  run_dw provider folder "$provider_root" >/dev/null
  run_dw add "$local_file" --group smoke --tag "$provider" >/dev/null
  run_dw sync >/dev/null
  run_dw snapshot create "snapshot-$provider" >/dev/null
  run_dw versions "$local_file" >/dev/null

  assert_provider_layout "$provider_root"
  assert_file_contains "$provider_root/.dotweaver/manifests/files.json" "$provider"
  test -d "$provider_root/.dotweaver/snapshots"
}

smoke_git_provider() {
  local provider="git"
  local case_root="$ROOT/$provider"
  local repo="$case_root/repo"
  local remote="$case_root/remote.git"
  local local_file="$case_root/local/git.conf"

  APP_SUPPORT="$case_root/app-support"
  SNAPSHOT_DIR="$case_root/snapshots"
  DEFAULTS_SUITE="com.rausth.DotWeaver.smoke.git"

  mkdir -p "$(dirname "$local_file")" "$APP_SUPPORT" "$SNAPSHOT_DIR"
  printf 'provider=git\n' > "$local_file"
  git init --bare --initial-branch=main "$remote" >/dev/null
  git init --initial-branch=main "$repo" >/dev/null
  git -C "$repo" config user.email "dotweaver-smoke@example.invalid"
  git -C "$repo" config user.name "DotWeaver Smoke"
  git -C "$repo" remote add origin "$remote"

  run_dw provider set git >/dev/null
  run_dw git config --path "$repo" --remote "$remote" --branch main >/dev/null
  run_dw add "$local_file" --group smoke --tag git >/dev/null
  run_dw sync >/dev/null
  run_dw git status >/dev/null
  run_dw git push >/dev/null
  run_dw snapshot create snapshot-git >/dev/null
  run_dw versions "$local_file" >/dev/null

  assert_provider_layout "$repo"
  git --git-dir="$remote" rev-parse refs/heads/main >/dev/null
}

for provider in icloud onedrive googledrive dropbox webdav sftp ftps s3; do
  echo "Smoke provider: $provider"
  smoke_folder_provider "$provider"
done

echo "Smoke provider: git"
smoke_git_provider

echo "Provider matrix smoke passed: $ROOT"
