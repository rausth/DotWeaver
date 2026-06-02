# Provider Setup Guide

This guide covers configuration for each supported storage provider.

## Git Provider

### Local Repository
```bash
dotweaver config git.path /path/to/your/dotfiles
```

### Remote Repository
```bash
dotweaver config git.remote https://github.com/username/dotfiles.git
dotweaver config git.branch main
```

## iCloud Drive

No additional configuration needed. DotWeaver automatically detects your iCloud Drive.

**Location:** `~/Library/Mobile Documents/com~apple~CloudDocs/DotWeaver`

## OneDrive / Google Drive / Dropbox

1. Open DotWeaver Settings
2. Select your provider
3. Grant file access permission when prompted
4. Choose your dotfiles folder

**Note:** These providers use folder-based sync and require the desktop sync client to be installed.

## WebDAV

```bash
dotweaver config webdav.url https://your-server.com/dav
dotweaver config webdav.username your-username
# Password will be stored securely in Keychain with Touch ID protection
```

## SFTP

```bash
dotweaver config sftp.host your-server.com
dotweaver config sftp.port 22
dotweaver config sftp.username your-username
dotweaver config sftp.keypath ~/.ssh/id_ed25519
```

## FTPS

```bash
dotweaver config ftps.host your-server.com
dotweaver config ftps.port 990
dotweaver config ftps.username your-username
# Password stored securely with biometric protection
```

## Amazon S3

```bash
dotweaver config s3.bucket your-bucket-name
dotweaver config s3.region us-east-1
dotweaver config s3.access-key YOUR_ACCESS_KEY
# Secret key stored securely in Keychain
```

## Security Notes

- All credentials are stored in macOS Keychain with biometric protection
- Passwords are never stored in plain text or transmitted over the network
- Use SSH keys instead of passwords for SFTP when possible
- Enable 2FA on all cloud provider accounts
