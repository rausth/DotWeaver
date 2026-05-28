# DotWeaver

A modern, native macOS application and CLI tool for managing dotfiles.

DotWeaver makes it simple to synchronize, version, and manage your shell configuration files (`.zshrc`, `.gitconfig`, `~/.config/*`, etc.) across multiple machines.

## Features

- Native SwiftUI macOS interface
- Powerful CLI (`dotweaver`)
- Bidirectional synchronization
- Support for Git, iCloud, OneDrive, Google Drive, Dropbox, WebDAV, SFTP, FTPS and S3
- Built-in file editor
- Template system (Chezmoi-style)
- Touch ID / Face ID + Secure Enclave support
- Home Folder Access only (sandboxed)

## Installation

### Homebrew (recommended)

```bash
brew tap rausth/dotweaver
brew install dotweaver
