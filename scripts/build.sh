#!/bin/bash
set -euo pipefail

# Build OllamaGateway macOS .app bundle
# Usage: ./scripts/build.sh [release|debug]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_MODE="${1:-release}"
APP_NAME="OllamaGateway"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUNDLE_ID="com.ollamagateway.app"

cd "$PROJECT_DIR"

echo "🔨 Building $APP_NAME v$APP_VERSION ($BUILD_MODE)..."

# Determine architecture
ARCH="${ARCH:-$(uname -m)}"
SWIFT_FLAGS="-c $BUILD_MODE"

if [ "$ARCH" = "universal" ]; then
    echo "📦 Building Universal Binary (arm64 + x86_64)..."
    swift build $SWIFT_FLAGS --arch arm64 --arch x86_64
    BINARY_PATH=".build/apple/Products/Release/$APP_NAME"
elif [ "$ARCH" != "$(uname -m)" ]; then
    echo "📦 Cross-compiling for $ARCH..."
    swift build $SWIFT_FLAGS --arch "$ARCH"
    BINARY_PATH=".build/${ARCH}-apple-macosx/${BUILD_MODE}/$APP_NAME"
else
    swift build $SWIFT_FLAGS
    BINARY_PATH=".build/$BUILD_MODE/$APP_NAME"
fi

if [ ! -f "$BINARY_PATH" ]; then
    echo "❌ Build failed - binary not found at $BINARY_PATH"
    exit 1
fi

echo "✅ Build successful"

# Create .app bundle
APP_DIR="$PROJECT_DIR/build/$APP_NAME.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "📁 Creating app bundle..."

# Copy binary
cp "$BINARY_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

# Copy app icon (pre-built .icns)
if [ -f "$PROJECT_DIR/logo.icns" ]; then
    cp "$PROJECT_DIR/logo.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
    echo "✅ Copied logo.icns → AppIcon.icns"
else
    echo "⚠️  logo.icns not found, app will have no icon"
fi

# Copy status bar icon (pre-built .icns)
if [ -f "$PROJECT_DIR/statuslogo.icns" ]; then
    cp "$PROJECT_DIR/statuslogo.icns" "$APP_DIR/Contents/Resources/StatusBarIcon.icns"
    echo "✅ Copied statuslogo.icns → StatusBarIcon.icns"
else
    echo "⚠️  statuslogo.icns not found, using fallback SF Symbol"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh-Hans</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Ollama Gateway</string>
    <key>CFBundleDisplayName</key>
    <string>Ollama Gateway</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.developer-tools</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>LSUIElement</key>
    <false/>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
    </dict>
    <key>NSMainStoryboardFile</key>
    <string></string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

# Ad-hoc code sign
echo "🔐 Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "⚠️  Code signing skipped"

echo ""
echo "✅ App bundle created: $APP_DIR"
echo "📏 Size: $(du -sh "$APP_DIR" | cut -f1)"
echo ""
echo "To run: open $APP_DIR"
