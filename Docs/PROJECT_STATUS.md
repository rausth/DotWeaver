# DotWeaver Project Status

**Date:** June 16, 2026
**Version:** 1.0.0
**Status:** Ready for GitHub/ad-hoc distribution with passing CI, Pages, release workflow, signed Sparkle appcast generation, and local release validation. Apple notarization still requires external Apple Developer credentials.

## Current Implementation

| Area | Status | Notes |
|------|--------|-------|
| SwiftUI macOS app | Implemented | Main app, settings, onboarding, menu bar |
| State management | Implemented | `StateManager` + `DotfilesViewModel` |
| Folder-backed providers | Implemented | iCloud, OneDrive, Google Drive, Dropbox, WebDAV, SFTP, FTPS, S3 |
| Native protocol providers | Implemented | WebDAV/SFTP/FTPS/S3 through system `curl` endpoint transfer |
| Git provider | Implemented | Local folder sync plus `git pull` / `git push` |
| Conflict resolution | Implemented | Reads local and stored file copies; applies selected strategy |
| CLI | Implemented | Files, sync, providers, native config, Git config, snapshots, source-machine restore, partial restore, conflicts, doctor, hooks, templates, interop, `dw plan`, and `dw status --diff` |
| Snapshots | Implemented | Preserves nested paths, syncs snapshots to provider folder, restores local or provider-hosted snapshots from selected source machines, and supports `Restore File` or `Restore All` in the UI |
| Machine/version manifests | Implemented | Machine identity, file manifest, per-file version records |
| Vault encryption | Implemented | AES.GCM payloads, master key stored in Keychain, template vault placeholders |
| Sensitive auth gates | Implemented | Vaulted sync, snapshot restore, credential reads |
| Hook policy | Implemented | Hooks disabled by default, SHA-256 approved, path-contained, restricted-env, and audited when skipped/executed |
| Audit log | Implemented | Rotation with hash-chain fields |
| Ignore rules | Implemented | Provider-root `.dotignore` filtering for planning and sync |
| Tests | Passing | 31 unit/integration tests cover core provider, vault, snapshot, provider-hosted source-machine restore, native endpoint safety, Git remote behavior, provider permissions, shared restore, interop parsing, ignore rules, hooks, templates, audit, and CLI planning |
| Release packaging | Implemented | Universal app/CLI artifacts, Sparkle framework embedding, app icon resource bundle embedding, appcast generation, local signature/rpath verification |
| Sparkle signing | Configured | GitHub Actions secrets are configured for `SPARKLE_PUBLIC_ED_KEY` and `SPARKLE_PRIVATE_KEY`; local signed-appcast validation passes |
| Smoke validation | Implemented | Provider matrix, app launch, local appcast, signature, rpath, checksum, CLI help, real mounted-folder, and native endpoint validators |
| Native remote protocol clients | Implemented | WebDAV/SFTP/FTPS/S3 endpoint transfer via system `curl`; embedded SDK clients are not included |

## Provider Storage

Managed files are stored under:

```text
<provider folder>/.dotweaver/files/machines/<machine-id>/
<provider folder>/.dotweaver/manifests/
<provider folder>/.dotweaver/versions/
<provider folder>/.dotweaver/snapshots/<machine-id>/
```

For cloud and remote-style providers, synchronization to the remote service is handled by either selected desktop client/mount tool or Native Protocol mode.

## Release Risks

- GUI launch smoke is scripted; full interactive UI automation still depends on macOS Accessibility permission.
- Native Protocol mode depends on system `curl` and user-provided credential setup; `script/smoke_native_protocol_endpoints.sh` runs live WebDAV/SFTP/FTPS/S3 endpoint checks when endpoint environment variables are configured.
- Mackup/chezmoi interop covers common import/export paths; full preset catalogs and advanced template/script semantics remain v1.x growth work.
- Secure Enclave wrapping is opportunistic: supported hardware uses Secure Enclave wrapping; unsupported hardware falls back to Keychain-only storage.
- Live notarization requires Apple Developer credentials and remains disabled until those GitHub Actions secrets are configured.

## Last Verified

```bash
swift test
script/smoke_provider_matrix.sh
script/validate_release_local.sh
script/smoke_app_ui.sh
script/smoke_real_provider_folders.sh
script/smoke_native_protocol_endpoints.sh
```

Result: passing.
