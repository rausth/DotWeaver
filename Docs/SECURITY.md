# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

We take the security of DotWeaver seriously. If you discover a security vulnerability, please follow this process:

### 1. Do NOT create a public GitHub issue

Security vulnerabilities should be reported privately to protect users.

### 2. Email the security team

Send an email to **security@rausth.dev** with the following information:

- **Description** of the vulnerability
- **Steps to reproduce** the issue
- **Potential impact** assessment
- **Suggested fix** (if any)

### 3. Response Timeline

- **Initial Response:** Within 48 hours
- **Status Update:** Within 7 days
- **Resolution Target:** Within 30 days (depending on severity)

### 4. What to Expect

- We will acknowledge receipt of your report
- We will investigate and validate the vulnerability
- We will keep you informed of our progress
- We will credit you in the security advisory (unless you prefer to remain anonymous)

## Security Features

DotWeaver implements multiple layers of security:

### Credential Protection
- All passwords stored in macOS Keychain
- Biometric authentication (Touch ID / Face ID) required for sensitive operations
- Optional Secure Enclave hardware-backed keys
- Keychain Access Groups for secure sharing between app and CLI

### Network Security
- TLS 1.3 enforcement for all HTTP providers
- Certificate pinning for known providers
- SSH key authentication for SFTP (no password transmission)
- 30-second connection timeout with exponential backoff

### Application Security
- App Sandbox with Home Folder Access only
- No Full Disk Access required
- No telemetry or analytics collection
- Zero-knowledge architecture (credentials never leave device)

### Data Protection
- All data encrypted at rest using macOS Data Protection
- No cloud storage of sensitive configuration
- Secure deletion of temporary files

## Security Best Practices for Users

1. **Enable FileVault** on your Mac for full disk encryption
2. **Use a strong device passcode** as fallback for biometric authentication
3. **Keep macOS updated** to receive security patches
4. **Review provider permissions** regularly in Settings
5. **Use SSH keys** instead of passwords for SFTP when possible

## Vulnerability Disclosure

We follow responsible disclosure practices:

- Confirmed vulnerabilities will be fixed in a timely manner
- Security advisories will be published after fixes are released
- Credit will be given to reporters (with permission)

## Contact

For security-related inquiries:
- **Email:** security@rausth.dev
- **PGP Key:** Available upon request

---

**Last Updated:** May 28, 2026
