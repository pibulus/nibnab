#!/bin/bash

# ===================================================================
# NibNab Build Script
# Compiles the Swift app into a macOS application bundle
# ===================================================================

set -euo pipefail

APP_NAME="NibNab"
BUNDLE_ID="com.pibulus.nibnab"
VERSION="1.0.0"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
ENTITLEMENTS_PATH="NibNab.entitlements"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔨 Building ${APP_NAME}...${NC}"

# Clean previous build
if [ -d "$BUILD_DIR" ]; then
    echo "Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Create build directory structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
    <key>NSAccessibilityUsageDescription</key>
    <string>NibNab needs accessibility access to auto-capture selected text. You can still use NibNab with just Cmd+C if you deny this permission.</string>
    <key>UTExportedTypeDeclarations</key>
    <array>
        <dict>
            <key>UTTypeIdentifier</key>
            <string>com.pibulus.nibnab.clip</string>
            <key>UTTypeDescription</key>
            <string>NibNab Clip</string>
            <key>UTTypeConformsTo</key>
            <array>
                <string>public.data</string>
                <string>public.json</string>
            </array>
            <key>UTTypeTagSpecification</key>
            <dict>
                <key>public.filename-extension</key>
                <array>
                    <string>nibclip</string>
                </array>
            </dict>
        </dict>
    </array>
    <key>NSAppleEventsUsageDescription</key>
    <string>NibNab may use Apple Events to capture the current URL from your browser when saving clips.</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Pibulus. All rights reserved.</string>
</dict>
</plist>
EOF

# Compile Swift
echo -e "${YELLOW}Compiling Swift code...${NC}"
if swiftc -O -parse-as-library \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -o "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" \
    Sources/*.swift; then

    echo -e "${GREEN}✅ Build successful!${NC}"
    echo -e "${GREEN}📦 App created at: $APP_BUNDLE${NC}"

    # Make it executable
    chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

    echo -e "${YELLOW}Signing app bundle...${NC}"
    if [ "$SIGNING_IDENTITY" = "-" ]; then
        codesign --force --sign - --entitlements "$ENTITLEMENTS_PATH" "$APP_BUNDLE"
        echo "Signed with ad hoc identity for local use."
    else
        codesign --force --options runtime \
            --entitlements "$ENTITLEMENTS_PATH" \
            --sign "$SIGNING_IDENTITY" \
            "$APP_BUNDLE"
        echo "Signed with identity: $SIGNING_IDENTITY"
    fi

    echo -e "\n${YELLOW}To run the app:${NC}"
    echo "  open $APP_BUNDLE"

    echo -e "\n${YELLOW}To install to Applications:${NC}"
    echo "  cp -r $APP_BUNDLE /Applications/"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi
