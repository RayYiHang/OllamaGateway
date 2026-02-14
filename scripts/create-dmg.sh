#!/bin/bash
set -euo pipefail

# Create DMG for distribution
# Usage: ./scripts/create-dmg.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="OllamaGateway"
APP_VERSION="${APP_VERSION:-1.0.0}"

APP_PATH="$PROJECT_DIR/build/$APP_NAME.app"
DMG_ARCH="${ARCH:-$(uname -m)}"
DMG_NAME="${APP_NAME}-v${APP_VERSION}-${DMG_ARCH}"
DMG_PATH="$PROJECT_DIR/build/${DMG_NAME}.dmg"
STAGING_DIR="$PROJECT_DIR/build/dmg-staging"

if [ ! -d "$APP_PATH" ]; then
    echo "❌ App bundle not found. Run build.sh first."
    exit 1
fi

echo "📦 Creating DMG: $DMG_NAME.dmg..."

# Cleanup
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy app to staging
cp -R "$APP_PATH" "$STAGING_DIR/"

# Create Applications symlink
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Cleanup staging
rm -rf "$STAGING_DIR"

echo ""
echo "✅ DMG created: $DMG_PATH"
echo "📏 Size: $(du -sh "$DMG_PATH" | cut -f1)"
