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

### Build Script Shortcut

`build.sh` now ad hoc signs the bundle by default so local builds verify cleanly on your own Mac.

For a real release build, pass your signing identity:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" ./build.sh
```

### DMG Release Shortcut

Create a local DMG:

```bash
./build-dmg.sh
```

Create a signed DMG:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" ./build-dmg.sh
```

Create a signed and notarized DMG:

```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
NOTARY_PROFILE="nibnab-notary" \
./build-dmg.sh
```

### Add to Build Script

If you want to sign manually outside the script:

```bash
codesign --force --deep --options runtime \
  --entitlements NibNab.entitlements \
  --sign "Developer ID Application: Your Name (TEAM_ID)" \
  build/NibNab.app

codesign --verify --verbose build/NibNab.app
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

### 2. Build, Sign, and Package (one command)

`build-appstore.sh` does the whole thing — builds with the sandboxed
`NibNab.entitlements`, embeds the provisioning profile, injects the
`com.apple.application-identifier` / `team-identifier` entitlements that App
Store validation requires, signs with your Apple Distribution cert, and
creates a `.pkg` signed with the **installer** cert:

```bash
SIGNING_IDENTITY="Apple Distribution: Your Name (TEAM_ID)" \
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Your Name (TEAM_ID)" \
PROVISIONING_PROFILE=~/Downloads/NibNab_AppStore.provisionprofile \
./build-appstore.sh
```

Notes:
- The `.pkg` **must** be signed with the installer certificate (portal name
  "Mac Installer Distribution", Keychain name "3rd Party Mac Developer
  Installer") — signing it with the app certificate fails validation.
- Bump `BUILD_NUMBER=2` (3, 4, …) for every upload; App Store Connect
  rejects reused build numbers.
- The sandboxed App Store build is clipboard-capture only (no selection
  capture — the Accessibility API is unavailable under the App Sandbox).

### 3. Upload to App Store

Use Transporter.app (free, Mac App Store) to upload the signed `.pkg` to
App Store Connect. `xcrun altool` was retired by Apple in November 2023 —
don't use it.

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
