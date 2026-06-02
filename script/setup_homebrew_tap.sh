#!/bin/bash
#
# Homebrew Tap Setup Script for DotWeaver
# This script creates and configures the Homebrew tap repository
#

set -e

echo "🍺 Setting up Homebrew tap for DotWeaver..."

# Configuration
TAP_OWNER="rausth"
TAP_NAME="dotweaver"
TAP_REPO="homebrew-${TAP_NAME}"
FORMULA_NAME="dotweaver"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Install it from: https://cli.github.com/"
    exit 1
fi

# Check if user is logged in to GitHub
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}Please log in to GitHub CLI:${NC}"
    gh auth login
fi

echo -e "${GREEN}Creating Homebrew tap repository...${NC}"

# Create the tap repository
gh repo create "${TAP_OWNER}/${TAP_REPO}" \
    --public \
    --description "🍺 Homebrew tap for DotWeaver - Modern macOS dotfiles manager" \
    --clone

cd "${TAP_REPO}"

# Create directory structure
mkdir -p Formula

# Create the formula file
cat > Formula/${FORMULA_NAME}.rb << 'EOF'
class Dotweaver < Formula
  desc "Modern native macOS dotfiles manager with CLI"
  homepage "https://github.com/rausth/DotWeaver"
  url "https://github.com/rausth/DotWeaver/releases/download/v1.0.0/DotWeaver-macOS.tar.gz"
  sha256 "PLACEHOLDER_SHA256"
  license "MIT"
  head "https://github.com/rausth/DotWeaver.git", branch: "main"

  depends_on macos: :sequoia
  depends_on xcode: ["16.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/DotWeaver" => "dotweaver-gui"
    bin.install ".build/release/dotweaver" => "dotweaver"
  end

  def caveats
    <<~EOS
      DotWeaver has been installed!
      
      To get started:
        dotweaver init
        dotweaver sync
      
      For GUI version, launch DotWeaver from Applications or run:
        dotweaver-gui
    EOS
  end

  test do
    assert_match "DotWeaver", shell_output("#{bin}/dotweaver --help")
  end
end
EOF

# Create README for the tap
cat > README.md << 'EOF'
# homebrew-dotweaver

🍺 Homebrew tap for [DotWeaver](https://github.com/rausth/DotWeaver) - Modern native macOS dotfiles manager.

## Installation

```bash
brew tap rausth/dotweaver
brew install dotweaver
```

## Usage

```bash
# Initialize dotfiles repository
dotweaver init

# Sync with your provider
dotweaver sync

# Check status
dotweaver status
```

## GUI Version

Launch the GUI application:

```bash
dotweaver-gui
```

Or find "DotWeaver" in your Applications folder.

## Updating

```bash
brew update
brew upgrade dotweaver
```

## License

MIT License - see the [DotWeaver repository](https://github.com/rausth/DotWeaver) for details.
EOF

# Create .github/workflows/update.yml for automatic formula updates
mkdir -p .github/workflows
cat > .github/workflows/update.yml << 'EOF'
name: Update Formula

on:
  repository_dispatch:
    types: [new-release]
  workflow_dispatch:

jobs:
  update:
    runs-on: macos-latest
    steps:
      - name: Checkout tap
        uses: actions/checkout@v4
      
      - name: Update formula
        run: |
          # This would be triggered by the main repo release
          echo "Formula update triggered"
      
      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Formula/dotweaver.rb
          git commit -m "chore: update formula for new release" || exit 0
          git push
EOF

# Commit and push
git add .
git commit -m "Initial Homebrew tap setup for DotWeaver"
git push -u origin main

echo -e "${GREEN}✅ Homebrew tap created successfully!${NC}"
echo ""
echo "Next steps:"
echo "1. Update the SHA256 in Formula/dotweaver.rb with the actual release archive hash"
echo "2. Users can now install with:"
echo "   brew tap ${TAP_OWNER}/${TAP_NAME}"
echo "   brew install ${FORMULA_NAME}"
echo ""
echo "Tap URL: https://github.com/${TAP_OWNER}/${TAP_REPO}"
EOF

chmod +x /home/workdir/artifacts/DotWeaver_Latest/script/setup_homebrew_tap.sh
echo "Homebrew tap script created and made executable"