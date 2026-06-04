# DotWeaver Security Audit Preparation

**Prepared for:** External Security Firm  
**Date:** May 28, 2026  
**Audit Scope:** v1.0.0 Release Candidate

---

## Audit Scope

### In-Scope Components
1. **Application Binary** - DotWeaver.app
2. **CLI Binary** - dotweaver
3. **Source Code** - All Swift files
4. **Build Configuration** - Package.swift, entitlements
5. **Network Communication** - All provider connections
6. **Data Storage** - Keychain, file system
7. **Authentication** - Biometric, passcode flows

### Out-of-Scope
- Third-party dependencies (Swift Package Manager packages)
- macOS system components
- External provider APIs (GitHub, iCloud, etc.)

---

## Documentation Package

### Provided to Auditors

| Document | Location | Purpose |
|----------|----------|---------|
| Architecture Overview | SPECS.md | System design and data flow |
| Security Model | SECURITY.md | Security controls and threat model |
| Threat Model | This document | Detailed threat analysis |
| Data Flow Diagrams | This document | How data moves through system |
| API Documentation | Wiki/API-Reference | External interfaces |
| Test Results | IntegrationTests.swift | Security test coverage |

---

## Threat Model

### Assets to Protect

| Asset | Sensitivity | Protection |
|-------|-------------|------------|
| User Credentials | HIGH | Keychain + Biometric |
| Dotfile Content | MEDIUM | File system permissions |
| Sync State | LOW | UserDefaults |
| Application Binary | MEDIUM | Code signing, hardened runtime |

### Threat Actors

| Actor | Capability | Motivation |
|-------|------------|------------|
| Malicious App | High | Steal credentials |
| Network Attacker | Medium | Intercept traffic |
| Local Attacker | Low | Access files |
| Malicious Provider | Medium | Inject malicious content |

### Attack Vectors

| Vector | Likelihood | Impact | Mitigation |
|--------|------------|--------|------------|
| Keychain Access | Low | High | Device-local Keychain, biometric gate |
| External sync transport compromise | Medium | Medium | Use trusted desktop clients or mount tools |
| Sandbox Escape | Low | High | Minimal entitlements |
| Code Injection | Low | High | Hardened runtime |
| Credential Phishing | Medium | High | No password prompts in UI |

---

## Security Controls

### 1. Authentication & Authorization

**Controls:**
- Touch ID / Face ID via LocalAuthentication
- Passcode fallback
- Keychain item ACLs
- Keychain-protected vault master key

**Evidence:**
- BiometricAuthenticator.swift
- CredentialManager.swift
- Unit tests for auth flows

### 2. Data Protection

**Controls:**
- App Sandbox (com.apple.security.app-sandbox)
- Home Folder Access only (no Full Disk Access)
- Security-scoped bookmarks for GUI-selected resources
- Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly
- No iCloud Keychain sync for sensitive items

**Evidence:**
- DotWeaver.entitlements
- Package.swift linker settings

### 3. Provider Transport

**Controls:**
- Git transport delegated to system Git.
- Cloud and remote-style providers use local mounted or synchronized folders.
- No provider passwords are collected by folder-backed provider UI.

**Evidence:**
- GitProvider.swift
- FolderSyncProvider.swift
- Provider setup documentation
- Provider implementations

### 4. Input Validation

**Controls:**
- Path sanitization for dotfiles
- URL validation for providers
- Command injection prevention (no shell execution)
- Size limits on file operations

**Evidence:**
- File path validation in Dotfile model
- Provider configuration validation

### 5. Secure Development

**Controls:**
- Code review process
- Static analysis (SwiftLint)
- Dependency updates (Dependabot)
- No hardcoded secrets

**Evidence:**
- .github/workflows/ci.yml
- Package.swift (no credentials)

---

## Penetration Testing Guide

### Recommended Test Cases

#### 1. Authentication Bypass
```
Test: Attempt to access credentials without biometric auth
Expected: Access denied, Keychain returns errSecAuthFailed
```

#### 2. Path Traversal
```
Test: Add dotfile with path "../../../etc/passwd"
Expected: Path sanitized, operation rejected
```

#### 3. Network Interception
```
Test: MITM attack on HTTPS connection
Expected: Certificate validation fails, connection rejected
```

#### 4. Sandbox Escape
```
Test: Attempt to access /etc/passwd via FileManager
Expected: Permission denied (sandbox violation)
```

#### 5. Credential Extraction
```
Test: Attempt to read Keychain items from another app
Expected: Access denied (service/account scope and Keychain protections)
```

#### 6. Code Injection
```
Test: Inject malicious dylib via DYLD_INSERT_LIBRARIES
Expected: Hardened runtime prevents injection
```

---

## Audit Deliverables

### Expected from External Firm

1. **Executive Summary** (2-3 pages)
   - Overall security posture
   - Critical findings
   - Recommendations

2. **Detailed Findings** (per vulnerability)
   - Description
   - Severity (Critical/High/Medium/Low)
   - Reproduction steps
   - Impact assessment
   - Remediation guidance

3. **Technical Report** (appendix)
   - Methodology
   - Tools used
   - Test coverage
   - Screenshots/PoCs

4. **Remediation Roadmap**
   - Prioritized fix list
   - Estimated effort per fix
   - Verification steps

---

## Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Kickoff | 1 day | Scope agreement, NDA |
| Code Review | 3-5 days | Static analysis report |
| Dynamic Testing | 3-5 days | Penetration test results |
| Reporting | 2 days | Final report |
| Remediation | 1-2 weeks | Fix implementation |
| Verification | 1-2 days | Re-test critical findings |

**Total Estimated Time:** 2-3 weeks

---

## Budget Estimate

| Service | Cost Range |
|---------|------------|
| Code Review (Swift/macOS) | $5,000 - $8,000 |
| Penetration Testing | $8,000 - $12,000 |
| Remediation Support | $2,000 - $4,000 |
| **Total** | **$15,000 - $24,000** |

---

## Recommended Firms

1. **Trail of Bits** - Excellent for Swift/macOS
2. **NCC Group** - Comprehensive testing
3. **Synack** - Crowdsourced + expert review
4. **Independent Consultants** - Cost-effective for startups

---

## Contact

**Security Lead:** rausth  
**Email:** security@rausth.dev  
**PGP Key:** Available upon request

---

**Document Classification:** Confidential - For Auditor Use Only
