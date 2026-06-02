# DotWeaver - Documentation Index

**Version:** 1.0  
**Last Updated:** May 28, 2026  
**Status:** 100% COMPLETE - All features implemented

Welcome to the DotWeaver documentation! This index provides an overview of all available documentation for developers, contributors, and users.

---

## 📚 Documentation Structure

### For Users
| Document | Description |
|----------|-------------|
| [README.md](../README.md) | Getting started guide, installation, and basic usage |
| [Quick Start Guide](wiki/Quick-Start) | Step-by-step tutorial for new users |
| [Provider Setup](wiki/Provider-Setup) | Configuration guides for each storage provider |
| [CLI Reference](wiki/CLI-Reference) | Complete command-line interface documentation |
| [Troubleshooting](wiki/Troubleshooting) | Common issues and solutions |

### For Developers
| Document | Description |
|----------|-------------|
| [Technical Specifications](SPECS.md) | Architecture, design patterns, technology stack |
| [Requirements](REQUIREMENTS.md) | Functional and non-functional requirements |
| [Implementation Plan](IMPLEMENTATION_PLAN.md) | Development roadmap and sprint breakdown |
| [API Reference](wiki/API-Reference) | Public APIs for custom provider development |
| [Contributing Guide](CONTRIBUTING.md) | How to contribute to the project |
| [Security Model](wiki/Security-Model) | Detailed security architecture and best practices |

### For Maintainers
| Document | Description |
|----------|-------------|
| [Release Process](wiki/Release-Process) | How to cut a new release |
| [CI/CD Pipeline](.github/workflows/) | GitHub Actions workflow documentation |
| [Homebrew Formula](Formula/dotweaver.rb) | Homebrew tap configuration |
| [Notarization Guide](wiki/Notarization) | macOS notarization and Sparkle setup |
| [Next Steps](NEXT_STEPS.md) | What's left and post-release roadmap |

---

## 🚀 Quick Navigation

### I want to...
- **Install DotWeaver** → See [README.md](../README.md#installation)
- **Sync my dotfiles** → See [Quick Start Guide](wiki/Quick-Start)
- **Add a new provider** → See [API Reference](wiki/API-Reference)
- **Contribute code** → See [Contributing Guide](CONTRIBUTING.md)
- **Report a bug** → Open an issue on [GitHub](https://github.com/rausth/DotWeaver/issues)
- **Understand the architecture** → See [Technical Specifications](SPECS.md)

---

## 📖 Core Concepts

### Dotfiles
Dotfiles are configuration files that start with a dot (`.`) and control the behavior of command-line tools and applications. Common examples include:
- `.zshrc` / `.bashrc` - Shell configuration
- `.gitconfig` - Git settings
- `.vimrc` - Vim editor settings
- `~/.config/` - Application configuration directory

### Synchronization
DotWeaver supports two synchronization modes:
- **Pull**: Download remote changes to local machine
- **Push**: Upload local changes to remote storage
- **Bidirectional**: Two-way sync with automatic conflict detection

### Providers
A "provider" is a storage backend that hosts your dotfiles. DotWeaver supports:
- **Version Control**: Git (local or remote)
- **Cloud Storage**: iCloud, OneDrive, Google Drive, Dropbox
- **Self-Hosted**: WebDAV, SFTP, FTPS
- **Object Storage**: Amazon S3

### Security Model
DotWeaver prioritizes security through:
1. **Credential Isolation**: All passwords stored in macOS Keychain
2. **Biometric Protection**: Touch ID / Face ID required for sensitive operations
3. **Hardware Security**: Optional Secure Enclave key for signing
4. **Sandboxing**: App runs in macOS App Sandbox with minimal permissions
5. **Encrypted Transit**: All network traffic uses TLS/SSH

---

## 🛠️ Development

### Building from Source

```bash
git clone https://github.com/rausth/DotWeaver.git
cd DotWeaver
swift build
```

### Running Tests

```bash
swift test
```

### Creating a Release

See [Release Process](wiki/Release-Process) for detailed instructions.

---

## 📞 Support

- **Documentation Issues**: Open an issue with the `documentation` label
- **Feature Requests**: Open an issue with the `enhancement` label
- **Security Issues**: Email security@rausth.dev (do not open public issues)
- **General Questions**: [GitHub Discussions](https://github.com/rausth/DotWeaver/discussions)

---

## 📄 License

All documentation is licensed under [Creative Commons Attribution 4.0 International (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/).

---

**Maintained by:** The DotWeaver Team  
**Last Updated:** May 28, 2026  
**Status:** 100% COMPLETE - All features implemented
