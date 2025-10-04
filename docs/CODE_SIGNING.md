# Code Signing Guide for NibNab

## Why Code Signing?

macOS requires apps to be signed for:
- **Distribution outside Mac App Store** - Users won't get scary warnings
- **Mac App Store submission** - Required by Apple
- **Notarization** - For Gatekeeper approval

## Prerequisites

### 1. Apple Developer Account
- Individual: $99/year
- Organization: $99/year
- Sign up at: https://developer.apple.com

### 2. Certificates Needed

**For Mac App Store:**
- "Mac App Distribution" certificate
- "Mac Installer Distribution" certificate

**For Direct Distribution:**
- "Developer ID Application" certificate
- "Developer ID Installer" certificate (optional)

## Getting Certificates

### Option 1: Xcode (Easiest)
1. Open Xcode
2. Preferences → Accounts → Add Apple ID
3. Manage Certificates → + → Select certificate type
4. Xcode downloads and installs automatically

### Option 2: Manual (developer.apple.com)
1. Log into Apple Developer portal
2. Certificates, Identifiers & Profiles
3. Certificates → + → Select type
4. Create CSR from Keychain Access
5. Upload CSR, download certificate
6. Double-click to install in Keychain

## Signing the App

### Find Your Identity

```bash
# List all signing identities
security find-identity -v -p codesigning

# Look for:
# "Developer ID Application: Your Name (TEAM_ID)"
# or
# "Mac Developer: Your Name (TEAM_ID)"
```

### Sign Manually

```bash
# Sign the app bundle
codesign --force --deep --sign "Developer ID Application: Your Name" \
  build/NibNab.app

# Verify signature
codesign --verify --verbose build/NibNab.app

# Check what's signed
codesign -dv build/NibNab.app
```

### Add to Build Script

Edit `build.sh` after compilation:

```bash
# After successful compilation, add:

# Sign the app (replace with your identity)
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"

if codesign --force --deep --sign "$SIGNING_IDENTITY" \
    "$BUILD_DIR/${APP_NAME}.app"; then
    echo -e "${GREEN}✅ App signed successfully${NC}"

    # Verify
    codesign --verify --verbose "$BUILD_DIR/${APP_NAME}.app"
else
    echo -e "${YELLOW}⚠️  Signing failed - app will work but may show warnings${NC}"
fi
```

## Notarization (For Direct Distribution)

Required for distribution outside Mac App Store.

### 1. Create App-Specific Password
1. https://appleid.apple.com
2. Security → App-Specific Passwords
3. Generate password for "NibNab Notarization"
4. Save it securely

### 2. Store Credentials

```bash
# Store in keychain
xcrun notarytool store-credentials "nibnab-notary" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "app-specific-password"
```

### 3. Notarize

```bash
# Create a zip
ditto -c -k --keepParent build/NibNab.app NibNab.zip

# Submit for notarization
xcrun notarytool submit NibNab.zip \
  --keychain-profile "nibnab-notary" \
  --wait

# Staple the ticket to the app
xcrun stapler staple build/NibNab.app

# Verify
spctl --assess --verbose build/NibNab.app
```

## Mac App Store Submission

### 1. Create App Record
1. https://appstoreconnect.apple.com
2. My Apps → + → New App
3. Fill in app details, bundle ID: `com.pibulus.nibnab`

### 2. Build for App Store

```bash
# Use Mac App Distribution certificate
codesign --force --deep \
  --sign "Mac App Distribution: Your Name (TEAM_ID)" \
  --entitlements entitlements.plist \
  build/NibNab.app
```

### 3. Create Entitlements (entitlements.plist)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

### 4. Build PKG Installer

```bash
productbuild --component build/NibNab.app /Applications \
  --sign "Mac Installer Distribution: Your Name (TEAM_ID)" \
  NibNab-1.0.0.pkg
```

### 5. Upload to App Store

```bash
xcrun altool --upload-app \
  --type macos \
  --file NibNab-1.0.0.pkg \
  --username "your@email.com" \
  --password "app-specific-password"
```

Or use Transporter app (easier).

## Troubleshooting

### "No Identity Found"
- Make sure certificates are installed in Keychain
- Check they're valid (not expired)
- Verify team membership in developer portal

### "Code Signature Invalid"
```bash
# Check what's wrong
codesign --verify --verbose build/NibNab.app

# Re-sign with --force
codesign --force --deep --sign "..." build/NibNab.app
```

### "App is Damaged" Message
- App needs notarization for Gatekeeper
- Or users can right-click → Open to bypass (not ideal)

### Hardened Runtime Issues
For notarization, may need:
```bash
codesign --force --options runtime \
  --sign "Developer ID Application: ..." \
  build/NibNab.app
```

## Quick Reference

**Check signing:**
```bash
codesign -dv build/NibNab.app
```

**Verify signature:**
```bash
codesign --verify --verbose build/NibNab.app
```

**Test Gatekeeper:**
```bash
spctl --assess --verbose build/NibNab.app
```

**List identities:**
```bash
security find-identity -v -p codesigning
```

## For Now (Development)

The app works unsigned for local development. Users will need to:
1. Right-click → Open (first time only)
2. Confirm in System Settings

For production, always sign and notarize!

## Resources

- [Apple Code Signing Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)
- [App Store Submission](https://developer.apple.com/app-store/submitting/)
- [Notarization Tool](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow)
