# Quick Start Guide

Get up and running with DotWeaver in under 5 minutes.

## Installation

### Direct Download

1. Download the latest release from [GitHub Releases](https://github.com/rausth/DotWeaver/releases)
2. Open `DotWeaver.app` and follow the onboarding wizard

## Initial Setup

1. **Launch DotWeaver** - The app will guide you through initial setup
2. **Grant Permissions** - Select folders/files through DotWeaver so macOS grants access
3. **Choose a Provider** - Select where to store your dotfiles (Git recommended for beginners)
4. **Add Files** - Add your first monitored dotfile

## Your First Sync

```bash
# Add your first dotfile
dw add ~/.zshrc

# Sync with your chosen provider
dw sync
```

## Next Steps

- Explore the [Provider Setup](Provider-Setup) guide
- Learn about [Templates](Templates) for reusable configurations
- Set up [Biometric Authentication](Security) for enhanced security
- Check the [CLI Reference](CLI-Reference) for automation

## Getting Help

- Run `dw --help` for command documentation
- Visit our [GitHub Discussions](https://github.com/rausth/DotWeaver/discussions)
- Check [Troubleshooting](Troubleshooting) for common issues
