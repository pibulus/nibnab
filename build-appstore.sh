#!/bin/bash

# ===================================================================
# NibNab App Store Build Script
# Builds, signs with Apple Distribution cert, and creates a .pkg
# for Mac App Store submission.
# ===================================================================

set -euo pipefail

APP_NAME="NibNab"
BUNDLE_ID="com.pibulus.nibnab"
VERSION="1.0.0"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
ENTITLEMENTS_PATH="NibNab.entitlements"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🏪 Building ${APP_NAME} for Mac App Store...${NC}"
echo ""

# --- Validate prerequisites ---

if [ -z "$SIGNING_IDENTITY" ]; then
    echo -e "${RED}❌ SIGNING_IDENTITY is required.${NC}"
    echo -e "${YELLOW}Set it to your Apple Distribution certificate name:${NC}"
    echo '  SIGNING_IDENTITY="Apple Distribution: Your Name (TEAM_ID)" ./build-appstore.sh'
    exit 1
fi

if [ -z "$PROVISIONING_PROFILE" ]; then
    echo -e "${RED}❌ PROVISIONING_PROFILE is required.${NC}"
    echo -e "${YELLOW}Set it to the path of your .provisionprofile file:${NC}"
    echo '  PROVISIONING_PROFILE=~/Downloads/NibNab_AppStore.provisionprofile ./build-appstore.sh'
    exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo -e "${RED}❌ Missing entitlements file: ${ENTITLEMENTS_PATH}${NC}"
    exit 1
fi

if [ ! -f "$PROVISIONING_PROFILE" ]; then
    echo -e "${RED}❌ Provisioning profile not found: ${PROVISIONING_PROFILE}${NC}"
    exit 1
fi

# --- Clean & Build ---

echo -e "${YELLOW}🔨 Building Swift code...${NC}"

# Clean previous build
rm -rf "$BUILD_DIR"

# Create bundle structure
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
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>LSUIElement</key>
    <true/>
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
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024 Pibulus. All rights reserved.</string>
</dict>
</plist>
EOF

# Compile
if swiftc -O -parse-as-library \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -o "$APP_BUNDLE/Contents/MacOS/${APP_NAME}" \
    Sources/*.swift; then

    echo -e "${GREEN}✅ Compilation successful${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# Copy app icon if it exists
if [ -f "AppIcon.icns" ]; then
    cp "AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    echo "App icon bundled."
else
    echo -e "${RED}❌ AppIcon.icns is required for App Store submission${NC}"
    exit 1
fi

# --- Embed provisioning profile ---

echo -e "${YELLOW}📋 Embedding provisioning profile...${NC}"
cp "$PROVISIONING_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"

# --- Sign ---

echo -e "${YELLOW}🔐 Signing with Apple Distribution certificate...${NC}"
if codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS_PATH" \
    --sign "$SIGNING_IDENTITY" \
    "$APP_BUNDLE"; then

    echo -e "${GREEN}✅ Signed with: ${SIGNING_IDENTITY}${NC}"
else
    echo -e "${RED}❌ Signing failed${NC}"
    exit 1
fi

# Verify signature
echo -e "${YELLOW}🔍 Verifying signature...${NC}"
codesign --verify --verbose "$APP_BUNDLE"

# --- Create PKG ---

PKG_PATH="release/${APP_NAME}-${VERSION}-appstore.pkg"
mkdir -p release
rm -f "$PKG_PATH"

echo -e "${YELLOW}📦 Creating installer package...${NC}"
if productbuild --component "$APP_BUNDLE" /Applications \
    --sign "$SIGNING_IDENTITY" \
    "$PKG_PATH"; then

    echo -e "${GREEN}✅ PKG created at ${PKG_PATH}${NC}"
else
    echo -e "${RED}❌ PKG creation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🏪 App Store build complete!${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Validate: ${YELLOW}xcrun altool --validate-app -f ${PKG_PATH} -t macos${NC}"
echo -e "  2. Upload:   ${YELLOW}xcrun altool --upload-app -f ${PKG_PATH} -t macos${NC}"
echo -e "     or use ${YELLOW}Transporter${NC} app"
echo ""
