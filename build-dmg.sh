#!/bin/bash

# ===================================================================
# NibNab DMG Release Script
# Builds the app, creates a distributable DMG, and optionally signs
# and notarizes it when Developer ID credentials are available.
# ===================================================================

set -euo pipefail

APP_NAME="NibNab"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/${APP_NAME}.app"
RELEASE_DIR="release"
VOLUME_NAME="NibNab"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
ENTITLEMENTS_PATH="NibNab-dev.entitlements"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}📦 Building DMG for ${APP_NAME}...${NC}"

if [ -n "$SIGNING_IDENTITY" ]; then
    SIGNING_IDENTITY="$SIGNING_IDENTITY" ./build.sh
else
    ./build.sh
fi

if [ ! -d "$APP_BUNDLE" ]; then
    echo -e "${RED}❌ App bundle not found at ${APP_BUNDLE}${NC}"
    exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null)
if [ -z "$VERSION" ]; then
    echo -e "${RED}❌ Failed to read version from Info.plist${NC}"
    exit 1
fi

DMG_PATH="${RELEASE_DIR}/${APP_NAME}-${VERSION}.dmg"

mkdir -p "$RELEASE_DIR"
rm -f "$DMG_PATH"

STAGING_DIR=$(mktemp -d "/tmp/${APP_NAME}-dmg.XXXXXX")
cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if ! ditto "$APP_BUNDLE" "$STAGING_DIR/${APP_NAME}.app"; then
    echo -e "${RED}❌ Failed to copy app bundle to staging directory${NC}"
    exit 1
fi

ln -s /Applications "$STAGING_DIR/Applications"

echo -e "${YELLOW}Creating DMG image...${NC}"
if ! hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"; then
    echo -e "${RED}❌ DMG creation failed${NC}"
    exit 1
fi

if [ -n "$SIGNING_IDENTITY" ]; then
    echo -e "${YELLOW}Signing DMG...${NC}"
    if ! codesign --force --sign "$SIGNING_IDENTITY" "$DMG_PATH"; then
        echo -e "${RED}❌ DMG signing failed${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No SIGNING_IDENTITY set. DMG is for local testing only.${NC}"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    if [ -z "$SIGNING_IDENTITY" ]; then
        echo -e "${RED}❌ NOTARY_PROFILE requires SIGNING_IDENTITY as well.${NC}"
        exit 1
    fi

    echo -e "${YELLOW}Submitting DMG for notarization...${NC}"
    if ! xcrun notarytool submit "$DMG_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait; then
        echo -e "${RED}❌ Notarization submission failed${NC}"
    fi

    echo -e "${YELLOW}Stapling notarization ticket...${NC}"
    xcrun stapler staple "$DMG_PATH" || true
fi

echo -e "${YELLOW}Verifying DMG checksum and mountability...${NC}"
if ! hdiutil verify "$DMG_PATH"; then
    echo -e "${RED}❌ DMG verification failed${NC}"
    exit 1
fi

echo -e "${GREEN}✅ DMG created at ${DMG_PATH}${NC}"

if [ -n "$SIGNING_IDENTITY" ]; then
    echo -e "${GREEN}Signed with: ${SIGNING_IDENTITY}${NC}"
else
    echo -e "${YELLOW}Unsigned public distribution is not recommended.${NC}"
fi

if [ -n "$NOTARY_PROFILE" ]; then
    echo -e "${GREEN}Notarized with profile: ${NOTARY_PROFILE}${NC}"
else
    echo -e "${YELLOW}No notarization performed.${NC}"
fi
