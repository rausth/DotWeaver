#!/bin/bash
set -e

# Move to project root
cd "$(dirname "$0")/.."

# 1. Versioning
VERSION_FILE="VERSION.txt"
if [ ! -f "$VERSION_FILE" ]; then
    echo "1.0.0-1" > "$VERSION_FILE"
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")
BASE_VERSION=$(echo "$CURRENT_VERSION" | cut -d'-' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'-' -f2)

NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
NEW_VERSION="$BASE_VERSION-$NEW_BUILD_NUMBER"

echo "$NEW_VERSION" > "$VERSION_FILE"
echo "Building Specialized Versions $NEW_VERSION (Dedicated Paths)..."

# 2. Base Dist Dir
DIST_DIR="dist"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# 3. Function to create app bundle
create_bundle() {
    local ARCH=$1
    local FOLDER_NAME=$2
    local TARGET_DIR=".build/$ARCH-apple-macosx/release"
    
    echo "▸ Compiling for $FOLDER_NAME ($ARCH)..."
    swift build -c release --arch "$ARCH"
    
    local APP_NAME="DotWeaver.app"
    local ARCH_DIST_DIR="$DIST_DIR/$FOLDER_NAME"
    local APP_DIR="$ARCH_DIST_DIR/$APP_NAME"
    local CONTENTS_DIR="$APP_DIR/Contents"
    local MACOS_DIR="$CONTENTS_DIR/MacOS"
    local RESOURCES_DIR="$CONTENTS_DIR/Resources"

    echo "▸ Packaging $APP_NAME in $FOLDER_NAME/..."
    mkdir -p "$MACOS_DIR"
    mkdir -p "$RESOURCES_DIR"

    # Copy binaries
    cp "$TARGET_DIR/DotWeaverApp" "$MACOS_DIR/DotWeaver"
    cp "$TARGET_DIR/dw" "$MACOS_DIR/dw"
    cp AppIcon.icns "$RESOURCES_DIR/"

    # Create Info.plist with LSUIElement to hide Dock icon
    cat > "$CONTENTS_DIR/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>DotWeaver</string>
    <key>CFBundleIdentifier</key>
    <string>com.rausth.DotWeaver</string>
    <key>CFBundleName</key>
    <string>DotWeaver</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$BASE_VERSION</string>
    <key>CFBundleVersion</key>
    <string>$NEW_BUILD_NUMBER</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    # Ad-hoc Codesign
    echo "▸ Signing $APP_NAME..."
    codesign --force --deep --sign - "$APP_DIR"
}

# 4. Build both in separate folders
create_bundle "arm64" "AppleSilicon"
create_bundle "x86_64" "Intel"

# 5. Success & Instructions
echo ""
echo "✅ All builds successful! Each version is named 'DotWeaver.app'."
echo "------------------------------------------------"
echo "M1/M2/M3 Version: $DIST_DIR/AppleSilicon/DotWeaver.app"
echo "Intel Version:    $DIST_DIR/Intel/DotWeaver.app"
echo "------------------------------------------------"
echo "Behavior: App runs as a background utility (Menu Bar only)."
echo "To test locally (ARM64), run:"
echo "open $DIST_DIR/AppleSilicon/DotWeaver.app"
