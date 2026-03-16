#!/bin/bash

# ===================================================================
# NibNab Build Script
# Compiles the Swift app into a macOS application bundle
# ===================================================================

set -e

APP_NAME="NibNab"
BUNDLE_ID="com.pibulus.nibnab"
VERSION="1.0.0"
BUILD_DIR="build"

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
mkdir -p "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS"
mkdir -p "$BUILD_DIR/${APP_NAME}.app/Contents/Resources"

# Create Info.plist
cat > "$BUILD_DIR/${APP_NAME}.app/Contents/Info.plist" << EOF
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
</dict>
</plist>
EOF

# Copy entitlements
cp NibNab.entitlements "$BUILD_DIR/${APP_NAME}.app/Contents/"

# Compile Swift - build universal binary (arm64 + x86_64)
echo -e "${YELLOW}Compiling Swift code (arm64)...${NC}"
swiftc -O -parse-as-library \
    -target arm64-apple-macos13.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -o "$BUILD_DIR/${APP_NAME}_arm64" \
    Sources/*.swift

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ arm64 build failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Compiling Swift code (x86_64)...${NC}"
swiftc -O -parse-as-library \
    -target x86_64-apple-macos13.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -o "$BUILD_DIR/${APP_NAME}_x86_64" \
    Sources/*.swift

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ x86_64 build failed!${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating universal binary...${NC}"
lipo -create \
    "$BUILD_DIR/${APP_NAME}_arm64" \
    "$BUILD_DIR/${APP_NAME}_x86_64" \
    -output "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

rm "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"

# Make it executable
chmod +x "$BUILD_DIR/${APP_NAME}.app/Contents/MacOS/${APP_NAME}"

# Ad-hoc codesign with entitlements
echo -e "${YELLOW}Signing with entitlements...${NC}"
codesign --force --sign - --entitlements NibNab.entitlements \
    "$BUILD_DIR/${APP_NAME}.app"

echo -e "${GREEN}✅ Build successful!${NC}"
echo -e "${GREEN}📦 App created at: $BUILD_DIR/${APP_NAME}.app${NC}"

echo -e "\n${YELLOW}To run the app:${NC}"
echo "  open $BUILD_DIR/${APP_NAME}.app"

echo -e "\n${YELLOW}To install to Applications:${NC}"
echo "  cp -r $BUILD_DIR/${APP_NAME}.app /Applications/"
