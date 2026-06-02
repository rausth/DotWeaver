# 💎 DotWeaver

**Sophisticated Dotfiles Manager for macOS**

DotWeaver is a high-end, professional utility designed to synchronize and manage your development environment with a focus on aesthetics, security, and absolute reliability. Built specifically for the modern macOS ecosystem (macOS 15+), it features a stunning "Liquid Glass" interface and robust background synchronization.

---

## ✨ Key Features

- **Liquid Glass UI**: A breathtaking interface powered by macOS 15 `MeshGradient` and `.ultraThinMaterial`, providing a native, immersive experience.
- **Sophisticated Sync**: Seamless bidirectional synchronization with **Git**, **iCloud**, **OneDrive**, **Dropbox**, and **Google Drive**.
- **Secret Vault 🔒**: Securely handle sensitive files (SSH keys, `.env` files). Encrypt them locally before they ever touch the cloud.
- **Snapshot & Rollback 🕒**: Instant system-wide backups. Messed up your terminal config? Roll back to a previous state in one click.
- **Background Watcher**: Real-time monitoring of your dotfiles. Changes are detected and logged as soon as you save them in your favorite editor.
- **Template Gallery 🪄**: Quick-start your environment with curated templates for Zsh (Oh My Zsh), Starship, Vim, and more.
- **Smart Grouping**: Organize your configuration files by project, workstation, or custom tags.
- **System Doctor 🩺**: Automated health checks to ensure all symlinks and file paths are valid.
- **Pro CLI (`dw`)**: A powerful command-line interface for power users who never want to leave the terminal.

---

## 🛠 Command Line Interface (`dw`)

DotWeaver comes with a professional CLI for terminal-centric workflows.

### Installation

You can install the `dw` tool directly from the **DotWeaver App**:
1. Open **Settings** (`Cmd + ,`).
2. Go to the **CLI** tab.
3. Click **"Install 'dw' to /usr/local/bin"**.

Alternatively, you can manually symlink it:
```bash
ln -sf /Applications/DotWeaver.app/Contents/MacOS/dw /usr/local/bin/dw
```

### Usage

```bash
# Initialize a new repository
dw init

# Add a file to monitoring
dw add ~/.zshrc

# Sync all files with your chosen provider
dw sync

# Encrypt a sensitive file in the Vault
dw vault ~/.ssh/id_ed25519

# Check current system status
dw status
```

---

## 🚀 Getting Started

### Installation

1. Clone the repository.
2. Run the local build script:
   ```bash
   ./script/build_local.sh
   ```
3. Open the generated app:
   ```bash
   open .build/release/DotWeaver.app
   ```

### First Sync

1. Open **DotWeaver**.
2. Go to **Sync Providers** and select your preferred storage (e.g., Git or OneDrive).
3. If using a Cloud provider, choose the destination folder in the native macOS picker.
4. Add your first file in the **Monitored Files** tab.

---

## 🎨 Visual Identity

DotWeaver uses a sophisticated dark-themed visual identity with neon accents and deep translucency. It is designed to be "invisible" yet powerful, sitting quietly in your **Menu Bar** and **Dock** while keeping your environment in perfect harmony across all your Macs.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*Created with ❤️ for the macOS Developer Community.*
