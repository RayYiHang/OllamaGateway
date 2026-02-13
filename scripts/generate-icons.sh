#!/bin/bash
set -euo pipefail

# Generate .icns from logo.png
# Usage: ./scripts/generate-icons.sh [logo.png]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

LOGO="${1:-$PROJECT_DIR/logo.png}"
STATUS_LOGO="${2:-$PROJECT_DIR/statuslogo.png}"
OUTPUT_DIR="$PROJECT_DIR/build/icons"

if [ ! -f "$LOGO" ]; then
    echo "❌ Logo not found: $LOGO"
    echo "Please place logo.png in the project root."
    exit 1
fi

echo "🎨 Generating app icons from $LOGO..."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# Create .iconset directory
ICONSET="$OUTPUT_DIR/AppIcon.iconset"
mkdir -p "$ICONSET"

# Generate all required sizes for macOS .icns
SIZES=(16 32 64 128 256 512 1024)
for size in "${SIZES[@]}"; do
    sips -z "$size" "$size" "$LOGO" --out "$ICONSET/icon_${size}x${size}.png" > /dev/null 2>&1
done

# Create @2x variants
sips -z 32 32 "$LOGO" --out "$ICONSET/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 64 64 "$LOGO" --out "$ICONSET/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 256 256 "$LOGO" --out "$ICONSET/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 512 512 "$LOGO" --out "$ICONSET/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 1024 1024 "$LOGO" --out "$ICONSET/icon_512x512@2x.png" > /dev/null 2>&1

# Convert to .icns
iconutil -c icns "$ICONSET" -o "$OUTPUT_DIR/AppIcon.icns"
echo "✅ Generated AppIcon.icns"

# Generate status bar icon (18x18 @1x, 36x36 @2x)
if [ -f "$STATUS_LOGO" ]; then
    sips -z 18 18 "$STATUS_LOGO" --out "$OUTPUT_DIR/StatusBarIcon.png" > /dev/null 2>&1
    sips -z 36 36 "$STATUS_LOGO" --out "$OUTPUT_DIR/StatusBarIcon@2x.png" > /dev/null 2>&1
    echo "✅ Generated StatusBarIcon.png"
else
    echo "⚠️  statuslogo.png not found, using default status bar icon"
fi

# Cleanup iconset
rm -rf "$ICONSET"

echo "📁 Icons saved to: $OUTPUT_DIR/"
ls -la "$OUTPUT_DIR/"
