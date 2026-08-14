#!/bin/bash

# Release gate for the Developer ID (DMG) build. Ported from Spellbreak's
# release-check.sh. Known false-flag: spctl on the DMG can reject a freshly
# stapled image (same as Spellbreak) — the app-bundle Gatekeeper check is
# the one that matters.
# NibNab is arm64-only by design (swiftc -target arm64-apple-macos13.0).

set -euo pipefail

APP_NAME="NibNab"
BUNDLE_ID="com.pibulus.nibnab"
APP_BUNDLE="build/${APP_NAME}.app"
INFO_PLIST="${APP_BUNDLE}/Contents/Info.plist"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() { PASS_COUNT=$((PASS_COUNT + 1)); printf "✅ %s\n" "$1"; }
warn() { WARN_COUNT=$((WARN_COUNT + 1)); printf "⚠️  %s\n" "$1"; }
fail() { FAIL_COUNT=$((FAIL_COUNT + 1)); printf "❌ %s\n" "$1"; }

if [[ ! -d "$APP_BUNDLE" ]]; then
    fail "App bundle missing: ${APP_BUNDLE} (run ./build.sh or ./build-dmg.sh first)"
    printf "\nRelease check: %d pass, %d warn, %d fail\n" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
    exit 1
fi
pass "App bundle exists: ${APP_BUNDLE}"

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
DMG_PATH="release/${APP_NAME}-${VERSION}.dmg"

if [[ -f "$DMG_PATH" ]]; then
    pass "DMG exists: ${DMG_PATH}"
else
    fail "DMG missing: ${DMG_PATH}"
fi

if [[ -x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" ]]; then
    pass "App executable is present and executable"
else
    fail "App executable is missing or not executable"
fi

if /usr/bin/file "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" | grep -q "arm64"; then
    pass "App binary includes arm64"
else
    fail "App binary does not include arm64"
fi

if /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$INFO_PLIST" | grep -q "$BUNDLE_ID"; then
    pass "Bundle identifier is ${BUNDLE_ID}"
else
    fail "Bundle identifier is not ${BUNDLE_ID}"
fi

if /usr/libexec/PlistBuddy -c "Print :LSUIElement" "$INFO_PLIST" | grep -q "true"; then
    pass "App is configured as a menu bar accessory app"
else
    fail "LSUIElement is not enabled"
fi

if /usr/libexec/PlistBuddy -c "Print :LSApplicationCategoryType" "$INFO_PLIST" >/dev/null 2>&1; then
    pass "App category is set"
else
    fail "LSApplicationCategoryType missing"
fi

if [[ -f "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" ]]; then
    pass "App icon is bundled"
else
    fail "App icon is missing"
fi

if codesign --verify --verbose "$APP_BUNDLE" >/tmp/nibnab-codesign.log 2>&1; then
    pass "App code signature verifies"
else
    warn "App code signature does not verify"
    sed 's/^/   /' /tmp/nibnab-codesign.log
fi

if codesign -dv --verbose=4 "$APP_BUNDLE" >/tmp/nibnab-codesign-details.log 2>&1; then
    if grep -q "Authority=Developer ID Application" /tmp/nibnab-codesign-details.log; then
        pass "App is signed with Developer ID Application"
    else
        warn "App is signed, but not with Developer ID Application"
    fi

    if grep -q "runtime" /tmp/nibnab-codesign-details.log; then
        pass "Hardened runtime is enabled"
    else
        warn "Hardened runtime was not detected"
    fi
else
    warn "App signing details unavailable"
fi

if spctl -a -vvv -t execute "$APP_BUNDLE" >/tmp/nibnab-spctl-app.log 2>&1; then
    pass "Gatekeeper accepts the app"
else
    warn "Gatekeeper does not accept the app yet"
    sed 's/^/   /' /tmp/nibnab-spctl-app.log
fi

if [[ -f "$DMG_PATH" ]]; then
    if hdiutil imageinfo "$DMG_PATH" >/tmp/nibnab-dmg-info.log 2>&1; then
        pass "DMG image is readable"
    else
        fail "DMG image is not readable"
        sed 's/^/   /' /tmp/nibnab-dmg-info.log
    fi

    if xcrun stapler validate "$DMG_PATH" >/tmp/nibnab-stapler.log 2>&1; then
        pass "DMG has a valid stapled notarization ticket"
    else
        warn "DMG does not have a stapled notarization ticket"
        sed 's/^/   /' /tmp/nibnab-stapler.log
    fi

    if spctl -a -vvv -t open --context context:primary-signature "$DMG_PATH" >/tmp/nibnab-spctl-dmg.log 2>&1; then
        pass "Gatekeeper accepts the DMG"
    else
        warn "Gatekeeper does not accept the DMG yet (known spctl-on-DMG false flag if the app check passed)"
        sed 's/^/   /' /tmp/nibnab-spctl-dmg.log
    fi
fi

rm -f /tmp/nibnab-codesign.log \
    /tmp/nibnab-codesign-details.log \
    /tmp/nibnab-spctl-app.log \
    /tmp/nibnab-dmg-info.log \
    /tmp/nibnab-stapler.log \
    /tmp/nibnab-spctl-dmg.log

printf "\nRelease check: %d pass, %d warn, %d fail\n" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

if [[ "$FAIL_COUNT" -gt 0 ]]; then
    exit 1
fi
