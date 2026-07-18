#!/bin/bash

# ===================================================================
# NibNab App Store Build Script
# Builds via build.sh (sandboxed entitlements), embeds the provisioning
# profile, signs with Apple Distribution, and creates a .pkg signed with
# the Mac Installer Distribution certificate for App Store submission.
# ===================================================================

set -euo pipefail

APP_NAME="NibNab"
BUNDLE_ID="com.pibulus.nibnab"
export VERSION="${VERSION:-1.0.0}"
export BUILD_NUMBER="${BUILD_NUMBER:-1}"   # must increase for every upload
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
ENTITLEMENTS_PATH="NibNab.entitlements"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"        # "Apple Distribution: Name (TEAMID)"
INSTALLER_IDENTITY="${INSTALLER_IDENTITY:-}"    # "3rd Party Mac Developer Installer: Name (TEAMID)"
PROVISIONING_PROFILE="${PROVISIONING_PROFILE:-}"
TEAM_ID="${TEAM_ID:-}"

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

if [ -z "$INSTALLER_IDENTITY" ]; then
    echo -e "${RED}❌ INSTALLER_IDENTITY is required.${NC}"
    echo -e "${YELLOW}The App Store .pkg must be signed with the INSTALLER certificate"
    echo -e "(portal name \"Mac Installer Distribution\"), not the app certificate:${NC}"
    echo '  INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAM_ID)" ./build-appstore.sh'
    exit 1
fi

if [ -z "$PROVISIONING_PROFILE" ]; then
    echo -e "${RED}❌ PROVISIONING_PROFILE is required.${NC}"
    echo -e "${YELLOW}Set it to the path of your .provisionprofile file:${NC}"
    echo '  PROVISIONING_PROFILE=~/Downloads/NibNab_AppStore.provisionprofile ./build-appstore.sh'
    exit 1
fi

if [ ! -f "$PROVISIONING_PROFILE" ]; then
    echo -e "${RED}❌ Provisioning profile not found: ${PROVISIONING_PROFILE}${NC}"
    exit 1
fi

if [ ! -f "$ENTITLEMENTS_PATH" ]; then
    echo -e "${RED}❌ Missing entitlements file: ${ENTITLEMENTS_PATH}${NC}"
    exit 1
fi

# Derive TEAM_ID from the "(TEAMID)" suffix of the signing identity if not given.
if [ -z "$TEAM_ID" ]; then
    TEAM_ID=$(echo "$SIGNING_IDENTITY" | sed -n 's/.*(\([A-Z0-9]*\))$/\1/p')
fi
if [ -z "$TEAM_ID" ]; then
    echo -e "${RED}❌ Couldn't derive TEAM_ID from SIGNING_IDENTITY — set TEAM_ID explicitly.${NC}"
    exit 1
fi

if [ ! -f "AppIcon.icns" ]; then
    echo -e "${RED}❌ AppIcon.icns is required for App Store submission${NC}"
    exit 1
fi

# --- Build the bundle (compile + Info.plist + icon) via build.sh ---

echo -e "${YELLOW}🔨 Building app bundle...${NC}"
ENTITLEMENTS_PATH="$ENTITLEMENTS_PATH" ./build.sh

# The sandboxed build never uses the Accessibility API, so the usage string
# build.sh writes for dev builds doesn't belong in this plist.
/usr/libexec/PlistBuddy -c "Delete :NSAccessibilityUsageDescription" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# --- Embed provisioning profile ---

echo -e "${YELLOW}📋 Embedding provisioning profile...${NC}"
cp "$PROVISIONING_PROFILE" "$APP_BUNDLE/Contents/embedded.provisionprofile"

# --- Sign with App Store entitlements + required identifiers ---

# App Store validation requires the application-identifier and
# team-identifier entitlements (Xcode injects these automatically;
# hand-rolled builds must add them).
MERGED_ENTITLEMENTS="$BUILD_DIR/NibNab-appstore.entitlements"
cat > "$MERGED_ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-write</key>
	<true/>
	<key>com.apple.application-identifier</key>
	<string>${TEAM_ID}.${BUNDLE_ID}</string>
	<key>com.apple.developer.team-identifier</key>
	<string>${TEAM_ID}</string>
</dict>
</plist>
EOF

echo -e "${YELLOW}🔐 Signing with Apple Distribution certificate...${NC}"
if codesign --force \
    --entitlements "$MERGED_ENTITLEMENTS" \
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

# --- Create PKG (must be the installer cert, not the app cert) ---

PKG_PATH="release/${APP_NAME}-${VERSION}-appstore.pkg"
mkdir -p release
rm -f "$PKG_PATH"

echo -e "${YELLOW}📦 Creating installer package...${NC}"
if productbuild --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    "$PKG_PATH"; then

    echo -e "${GREEN}✅ PKG created at ${PKG_PATH}${NC}"
else
    echo -e "${RED}❌ PKG creation failed${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🏪 App Store build complete! (v${VERSION}, build ${BUILD_NUMBER})${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo -e "  1. Open ${YELLOW}Transporter.app${NC} (Mac App Store, free) and drag in ${YELLOW}${PKG_PATH}${NC}"
echo -e "     — it validates and uploads to App Store Connect."
echo -e "     (xcrun altool was retired by Apple in Nov 2023 — don't use it.)"
echo -e "  2. In App Store Connect, attach the build to the 1.0 version and submit."
echo -e "  ${YELLOW}Remember:${NC} every upload needs a higher BUILD_NUMBER:"
echo -e "     BUILD_NUMBER=2 SIGNING_IDENTITY=... INSTALLER_IDENTITY=... ./build-appstore.sh"
echo ""
