# Provider Setup Guide

This guide covers current provider configuration. DotWeaver stores managed files under:

```text
<provider folder>/.dotweaver/files/machines/<machine-id>/
```

DotWeaver also writes:

```text
<provider folder>/.dotweaver/manifests/
<provider folder>/.dotweaver/versions/
<provider folder>/.dotweaver/snapshots/
```

Folder-backed providers keep each machine in its own namespace. Use Settings > Storage > Sync From to restore from a different machine while this Mac writes back to its own namespace.

For non-Git providers, choose one transport:

- **Path**: selected folder is local, mounted, or synchronized by the provider desktop client.
- **Native Protocol**: DotWeaver transfers files directly to the configured endpoint through system `curl`.

## Git Provider

1. Open DotWeaver Settings.
2. Select Git.
3. Choose a local repository folder.
4. Optional: configure remote URL and branch.

DotWeaver writes managed files into `.dotweaver/files/machines/<machine-id>/` inside the repository. `push()` stages `.dotweaver`, creates a sync commit when needed, and pushes to `origin <branch>`.

## iCloud Drive

Choose an iCloud Drive folder in Settings or during onboarding. DotWeaver uses that folder as the sync root.

## OneDrive / Google Drive / Dropbox / WebDAV / SFTP / FTPS / Amazon S3

1. Open DotWeaver Settings
2. Select your provider
3. Grant file access permission when prompted
4. Choose the local folder used by that provider

Examples:
- OneDrive: `~/OneDrive`
- Google Drive: `~/Library/CloudStorage/GoogleDrive-*`
- Dropbox: `~/Dropbox`
- WebDAV/SFTP/FTPS: a Finder-mounted or `sshfs`/rclone-mounted folder
- S3: an `rclone mount`, `s3fs`, or equivalent local mount

## Native Protocol Mode

Native Protocol mode is available for WebDAV, SFTP, FTPS, and S3-compatible endpoints.

1. Open DotWeaver Settings.
2. Select provider.
3. Set transport to **Native Protocol**.
4. Enter endpoint URL.
5. Optional: enter username.

Endpoint examples:

```text
https://example.com/webdav/dotweaver/
sftp://example.com/home/user/dotweaver/
ftps://example.com/dotweaver/
https://bucket.s3.amazonaws.com/prefix/
```

Native mode uses system `curl` for protocol transfer. Passwords are not stored by DotWeaver. Use SSH keys, `.netrc`, endpoint tokens, or provider credential helpers.

## Provider Validation

Run isolated smoke checks against mounted or synchronized provider folders:

```bash
DOTWEAVER_REAL_ICLOUD_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs/DotWeaverSmoke" \
DOTWEAVER_REAL_ONEDRIVE_ROOT="$HOME/Library/CloudStorage/OneDrive-Personal/DotWeaverSmoke" \
DOTWEAVER_REAL_GOOGLEDRIVE_ROOT="$HOME/Library/CloudStorage/GoogleDrive-example@gmail.com/My Drive/DotWeaverSmoke" \
script/smoke_real_provider_folders.sh
```

Run live Native Protocol checks when endpoints and credentials are configured outside DotWeaver:

```bash
DOTWEAVER_NATIVE_WEBDAV_ENDPOINT=https://example.com/webdav/dotweaver/ \
DOTWEAVER_NATIVE_SFTP_ENDPOINT=sftp://example.com/dotweaver/ \
DOTWEAVER_NATIVE_FTPS_ENDPOINT=ftps://example.com/dotweaver/ \
DOTWEAVER_NATIVE_S3_ENDPOINT=https://s3.example.com/bucket/dotweaver/ \
script/smoke_native_protocol_endpoints.sh
```

## Security Notes

- Files marked as vaulted are encrypted before provider storage.
- Vault encryption uses a local Keychain-protected master key.
- Snapshot restore, vaulted sync, and credential reads require biometric/device-owner authentication when enabled.
- Pre/post sync hooks are disabled by default and must be explicitly enabled in Settings. Hook paths must point to zsh scripts under `~/.dotweaver/hooks`.
- DotWeaver does not store remote-provider passwords for folder-backed providers.
- Remote authentication is handled by the desktop sync client, mount tool, SSH keys, `.netrc`, or endpoint credential helper.
- Protect the selected provider folder with normal account, disk, and provider security controls.
- Enable 2FA on all cloud provider accounts.
