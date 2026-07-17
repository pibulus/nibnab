# NibNab v1.0 Release Runbook

The exact path from this repo to shipped. Two distribution channels, one decision
already made: **the DMG is the flagship** (full features, unsandboxed), **the Mac
App Store build is clipboard-capture only** (the Accessibility API is unavailable
under the App Sandbox — the permission can never be granted, so selection capture
is compiled-in but inert there, and never mentioned in store copy).

## 0. One-time setup (needs the $99/yr Apple Developer account)

Certificates (Xcode → Settings → Accounts → Manage Certificates, or the portal):

| Channel | Certificates needed |
|---|---|
| DMG | Developer ID Application |
| App Store | Apple Distribution + Mac Installer Distribution |

Also one-time:
1. Notary credentials: `xcrun notarytool store-credentials "nibnab-notary" --apple-id you@example.com --team-id TEAMID --password <app-specific-password>`
2. App Store Connect: create the app record, bundle ID `com.pibulus.nibnab`.
3. Provisioning profile: portal → Profiles → Mac App Store distribution profile for `com.pibulus.nibnab` → download the `.provisionprofile`.

Check what's installed: `security find-identity -v -p codesigning`

## 1. Pre-flight (every release)

```bash
./run-tests.sh          # 28 storage checks, must be all green
rm -rf build && ./build.sh   # clean build, zero warnings expected
```

Manual QA (5 minutes):
1. Grant Accessibility, drag-select text slowly in Safari → exactly one clip.
2. Copy a password from your password manager → **no** clip.
3. Copy a markdown doc containing `---` lines, quit, relaunch → intact.
4. Drag a clip onto another color circle → arrives, survives relaunch.
5. Fresh user account: welcome window opens and closes cleanly.
6. Export both formats; try a read-only folder → polite error alert.
7. Right-click menu: toggle "Capture Text Selections" off → selecting text captures nothing.

## 2. DMG release (the flagship)

```bash
SIGNING_IDENTITY="Developer ID Application: Pablo Alvarado (TEAMID)" \
NOTARY_PROFILE="nibnab-notary" \
./build-dmg.sh
```

That builds (unsandboxed dev entitlements → full features, plain
`~/Library/Application Support` storage), signs, notarizes, staples, and
verifies. Output: `release/NibNab-1.0.0.dmg`. Test it on a clean machine or
account: mount, drag to /Applications, launch — no Gatekeeper warning.

## 3. Mac App Store release

```bash
BUILD_NUMBER=1 \
SIGNING_IDENTITY="Apple Distribution: Pablo Alvarado (TEAMID)" \
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Pablo Alvarado (TEAMID)" \
PROVISIONING_PROFILE=~/Downloads/NibNab_AppStore.provisionprofile \
./build-appstore.sh
```

Then upload `release/NibNab-1.0.0-appstore.pkg` with **Transporter.app**
(`xcrun altool` is dead since Nov 2023). In App Store Connect:

- Copy/paste from `docs/APP_STORE.md` (already scrubbed of selection-capture
  claims — keep it that way).
- Privacy: "Data Not Collected" across the board (truthfully).
- Screenshots: 1280×800 or 2880×1800, of the **sandboxed** build.
- Encryption: Info.plist already carries `ITSAppUsesNonExemptEncryption=false`.
- **Bump `BUILD_NUMBER` for every upload** — reused numbers are rejected.

## 4. Version bumps

`VERSION` (user-facing, e.g. 1.0.1) and `BUILD_NUMBER` (monotonic upload
counter) are env overrides on both build scripts — no file editing needed.
The About window reads the version from the bundle automatically.

## Gotchas that already bit once (don't repeat)

- **pkg signed with the app cert** fails App Store validation — it must be the
  installer cert (`INSTALLER_IDENTITY`). The script enforces this.
- **Ad-hoc dev builds lose the Accessibility grant on every rebuild** (each
  build looks like a new app). Sign local builds with your Developer ID
  identity when testing selection capture across rebuilds.
- **A sandboxed build looks like it "lost" your clips** — they're fine, in the
  plain path; the sandboxed build just reads the container instead. Default
  `./build.sh` is unsandboxed, so this only applies if you force
  `ENTITLEMENTS_PATH=NibNab.entitlements`.
- **Never set `GOOGLE_API_KEY`-style global env in build scripts** — n/a here
  (no network), just keeping the fleet rule visible.
