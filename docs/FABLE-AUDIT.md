# FABLE AUDIT — 2026-07-05

Launch-readiness audit-and-fix pass on branch `fable-audit-2026-07-05`.
Everything below was **applied and verified** unless marked "left alone".
Ranked by launch impact.

---

## 🔴 Production-breaking — fixed

### 1. **Clip text containing `---` lines corrupted storage on every rewrite** (`StorageManager.swift`)
The storage format separates clips with `\n---\n`, with **no escaping**. Any clip whose
text contained a `---` line (any markdown doc, exported NibNab clips, lots of code) shattered
into broken sections on the next load — fragments without a `###` header were **silently
dropped**. Because every delete/edit/move triggers a full-file rewrite, this is almost
certainly the "delete/move persistence is broken" bug in the project ledger: you delete one
clip, and unrelated clips mutate or vanish after relaunch.
**Fix:** divider-lookalike lines are backslash-escaped on write and unescaped on read
(stacked escapes handled, round-trip is lossless). Verified by test harness.

### 2. **Welcome/About windows crash on close** (`AppEntry.swift`)
Both windows were created with `isReleasedWhenClosed = true` and no strong reference — under
ARC that's an over-release (AppKit releases on close, ARC releases again). This is the classic
Swift/AppKit crash, and the Welcome window shows on **first launch for every new user**.
**Fix:** windows are strongly held by AppDelegate, `isReleasedWhenClosed = false`, reference
dropped via `windowWillClose`. Bonus fixes: repeated "About" clicks now focus the existing
window instead of stacking duplicates, and Welcome's "Got it!" closes *its own* window instead
of whatever `NSApp.keyWindow` happens to be.

### 3. **Passwords copied from password managers were captured and written to disk** (`AppState.swift`)
The clipboard poller grabbed everything. Password managers (1Password, Bitwarden, KeePassXC…)
mark sensitive pasteboard content with `org.nspasteboard.ConcealedType` / `TransientType`;
every serious clipboard manager skips those. NibNab didn't — your passwords ended up in
plaintext markdown.
**Fix:** concealed/transient/auto-generated pasteboard items are never captured. Also now
advertised in the README as the privacy feature it is.

## 🟠 Core-job reliability — fixed

### 4. Same-minute clips shuffled order across launches (`StorageManager.swift`)
Timestamps were persisted at **minute** precision, and reload sorted with a non-stable sort —
clips captured in the same minute (very common) reloaded with identical timestamps in random
order. Your real data file has runs of same-minute clips.
**Fix:** second-precision timestamps on write (old minute format still parses), and a stable
newest-first sort that preserves file order for ties.

### 5. Selection auto-capture sprayed partial clips while drag-selecting (`ClipboardSupport.swift`)
The AX monitor captured on every 0.5s poll, so slowly drag-selecting a paragraph could save
"Hel", "Hello wor", "Hello world…" as separate clips (each also clobbering your clipboard).
**Fix:** capture only after the selection holds steady for one full poll cycle.

### 6. Re-captures created duplicate clips; whitespace didn't round-trip (`AppState.swift`)
Copying A, then B, then A again stacked duplicate A-clips forever. And clip text was saved
raw but trimmed by the parser on reload, so clips silently "changed" after relaunch.
**Fix:** `saveClip` skips when the text matches the newest clip in that color, and trims on
save (same for `updateClip`, which also now refuses empty text).

### 7. Legacy-format parser could eat clip text starting with a date-like line (`StorageManager.swift`)
The bare-timestamp fallback (pre-`id:` format) ran on any unrecognized metadata line, so a
clip whose first line looked like `2024-01-01 11:11` lost that line and got a wrong timestamp.
**Fix:** the fallback is gated to sections that carry no keyed metadata.

## 🟡 Papercuts & polish — fixed

8. **Trim-toast spam at the 100-clip cap** — once a color hit 100 clips, *every* capture
   flashed a "1 old clip trimmed" toast next to the menubar. Steady-state trimming is now silent.
9. **Toast race** — an earlier toast's 1.8s dismiss timer could kill a newer toast early.
   Timers now only clear their own message.
10. **Redundant toast/sound on re-selecting the active color** — `switchToColor` re-fired the
    `activeColor` didSet (toast + Pop sound + icon redraw) even when the color didn't change.
11. **Search dead-end lied** — filtering to zero matches showed "Nothing nabbed yet — Copy
    something good". Now shows "No matches" with the query.
12. **Exports failed silently** — `try?` on the file write, and the save panel could open
    behind other windows (menubar apps aren't the active app). Now activates the app and shows
    an alert on write failure; the two export functions share one panel helper.
13. **In-list drag-reorder removed** — dropping a clip onto another clip persisted a reorder
    that the timestamp sort immediately un-did on screen, so the drag visibly "snapped back".
    Dead-weight feature theatre; removed (drag-to-color-circle, the real feature, unchanged).
    If you ever want manual ordering, it needs a "Manual" sort mode that trusts file order.
14. **Dead code removed** — `ColorTab` view, `NibGradients` (both unreferenced),
    `AppDelegate.shared` (assigned, never read), pointless background-queue hop in `playSound`
    (NSSound.play is already async; also fixes a Sendable warning).

## 📦 Build & assets — fixed

15. **AppIcon.icns was missing** — `build-appstore.sh` hard-fails without it and the DMG app
    showed a generic icon. Generated a proper icon (neon pink→purple gradient, white
    highlighter glyph, macOS squircle) at all 10 iconset sizes. Replace at will — it's one
    committed file.
16. **`build-dmg.sh`'s entitlements choice was silently ignored** — it set
    `ENTITLEMENTS_PATH="NibNab-dev.entitlements"` but never passed it through, so `build.sh`
    always signed with the App Store entitlements. `build.sh` now honors the env var.

## 📝 Docs truth pass — fixed

- **CLAUDE.md / AGENTS.md** described a single-file app with *four* colors (pink/blue/yellow/
  green!), `~/.nibnab/` storage, and a "floating color picker" that doesn't exist. Rewritten
  to match reality (modular Sources/, five colors, real storage paths, real formats).
- **GLOSSARY.md** listed two phantom components (`ColorPickerView`, `LocationTracker`).
- **LANDING_PAGE.md** said "Four highlighter colors" and "single file ~1200 lines".
- **README / USER_GUIDE / USAGE / APP_STORE** claimed storage at
  `~/Library/Application Support/com.pibulus.nibnab/` — true only for non-sandboxed builds
  (see decision #1 below). Paths corrected/qualified everywhere.

---

## ⚠️ Deliberately left — decisions that are yours, ranked

### 1. **The sandbox / distribution question (READ THIS FIRST)**
Both entitlements files enable `com.apple.security.app-sandbox`, and `build.sh` signs every
build with them (since the June 23 App Store prep). But **your real data lives in the plain
path** `~/Library/Application Support/com.pibulus.nibnab/` — no sandbox container exists on
this Mac, so the app you've been living with was built before sandboxing landed. The moment a
sandboxed build ships (DMG or App Store), it starts from an **empty container** and your
clips "vanish" (they're still in the plain path, just not where the sandboxed app looks).
Options: (a) drop sandbox from the dev/DMG entitlements and keep it App Store-only — the
standard indie split; (b) keep sandbox everywhere and add a one-time migration from the plain
path into the container (needs a temporary-exception entitlement like the `~/.nibnab` one).
I didn't decide this for you — it changes where user data lives, and the signing setup is
yours. The `ENTITLEMENTS_PATH` passthrough (#16) gives you the mechanism for (a).

### 2. Accessibility permission resets on every rebuild (dev-only annoyance)
Ad-hoc signing (`codesign --sign -`) produces a new signature every build, so macOS treats
each build as a different app and drops the Accessibility grant — that's the "auto-selection
capture not dependable across launches" ledger item. End users with one stable signed build
are unaffected. For dev comfort, sign local builds with your real Developer ID
(`SIGNING_IDENTITY="Developer ID Application: …" ./build.sh`).

### 3. Selection auto-capture overwrites the clipboard by design
`AutoCopyMonitor` copies every stable selection to the general pasteboard. That's the
advertised "select text → it's captured" feature, but it also means selecting text *destroys*
whatever the user had copied. There's a `UserDefaults` flag (`autoCopyEnabled`) but **no UI
toggle for it** — the ⌘⌃M / menu toggle controls all monitoring, not just selection capture.
Consider a separate "Capture selections" toggle in the right-click menu before wide release.
Left alone: product decision, not a bug fix.

### 4. `CFBundleVersion` is hardcoded to "1" in two scripts and `VERSION` is duplicated
in `build.sh` and `build-appstore.sh`. Fine for now; consolidate when you next bump.

### 5. `Clip.screenshotPath` and `getCurrentURL()` are dormant scaffolding
for planned features (screenshots, browser URLs). Left in place — they're documented TODOs,
harmless, and removing them would churn the model's Codable shape.

---

## ✅ Verification

- `./build.sh` — **builds clean, zero warnings**. Ad-hoc signed, icon bundled.
- **Storage test harness** (16 assertions, run against the real `StorageManager` with a temp
  dir): divider-line round-trip ×2 cycles, same-second order stability, second-precision
  timestamps, both legacy formats, date-like-first-line gating, delete persistence, 100-cap
  on disk, empty-rewrite cleanup, URL metadata — **all pass**.
- **Smoke launch**: built app launched, ran 8s, terminated cleanly.
- Not verified (needs eyeballs): popover interactions, drag-to-color, export panel flow,
  AX selection capture end-to-end (needs a stable-signed build + permission grant).

## Manual QA checklist before shipping
1. Rebuild, grant Accessibility, drag-select text slowly — expect exactly one clip.
2. Copy a password from your password manager — expect **no** clip.
3. Copy a markdown doc containing `---` lines, quit, relaunch — expect it intact.
4. First-launch flow in a fresh user account: welcome window opens **and closes** cleanly.
5. Export both formats to a read-only folder — expect a polite error alert.

---
---

# FABLE AUDIT ADDENDUM — 2026-07-10 · v1.0 release push

Second pass on the same branch. Every "deliberately left" decision from July 5
is now resolved, plus a fresh bug hunt (self-review + adversarial subagent).
All fixes verified: clean build, zero warnings, 28/28 storage checks, smoke launch.

## Decisions resolved

### 1. Sandbox / distribution split — DECIDED & implemented
Verified against current Apple policy: **the Accessibility API is dead under the
App Sandbox** — the prompt never appears, the app can't be added manually, and
`AXIsProcessTrusted` can never return true (plus 2.4.5 rejections for AX use).
So:
- **Dev/DMG builds are now unsandboxed** (`NibNab-dev.entitlements` = empty; the
  new `build.sh` default). Full features, data stays in the plain
  `~/Library/Application Support/com.pibulus.nibnab/` where the real data lives.
- **App Store build stays sandboxed** (`NibNab.entitlements`) and is
  clipboard-capture only: `AutoCopyMonitor` is never created in sandboxed builds
  (`SandboxInfo.isSandboxed`), so no dead permission prompt. Store copy scrubbed.
- The `~/.nibnab` temporary exception is gone (unsandboxed builds don't need it;
  the sandboxed build has no legacy data to migrate).

### 2. Selection capture now has its own toggle
"Capture Text Selections" in the right-click menu (persists to the existing
`autoCopyEnabled` key). Hidden in sandboxed builds. ⌘⌃M stays the master switch.

### 3. VERSION / CFBundleVersion consolidated
Both are env overrides on build.sh (`VERSION`, `BUILD_NUMBER`); build-appstore.sh
no longer duplicates the Info.plist heredoc — it builds through build.sh. About
window reads the version from the bundle instead of hardcoding it.

## New bugs found & fixed

1. **Drag-to-color onto a full (100-clip) color silently deleted the moved clip**
   (`AppState.moveClip` appended then prefix-trimmed). Now inserts in timestamp
   order and never trims the moved clip.
2. **Selection capture fired on NibNab's own UI** — selecting text in the edit
   modal/search field re-captured it and clobbered the clipboard. Now skips
   focused elements owned by our own PID.
3. **Modals could save/delete against the wrong color** if a ⌘⌃1-5 hotkey fired
   while open (silent edit loss). Modals now pin the color they were opened in.
4. **Launch-at-Login toggle could lie** — `try?` swallowed registration failures
   (guaranteed for builds run from `build/`). Failures now snap the toggle back
   to the real `SMAppService` status.
5. **Global hotkey registration failures were silent** — ⌘⌃1-5 clash with window
   managers; failures are now logged (also collapsed 80 lines of copy-paste into
   a table + loop, and hotkeys/handler are unregistered on quit).
6. **build-appstore.sh signed the .pkg with the app cert** — App Store requires
   the Mac Installer Distribution cert (`INSTALLER_IDENTITY`, now enforced), and
   the binary now gets the `application-identifier`/`team-identifier`
   entitlements validation requires. `xcrun altool` advice (retired 2023)
   replaced with Transporter.
7. **Test-harness safety**: `StorageManager(baseURLOverride:)` no longer runs the
   `~/.nibnab` migration (which deletes the legacy dir) when pointed at a test dir.

## New infrastructure

- `Tests/StorageTests.swift` + `./run-tests.sh` — the storage harness is now
  committed: 28 checks (round-trips, divider escaping ×2 cycles, both legacy
  formats, hostile clip text, ordering stability, cap, delete persistence, URLs).
- `docs/RELEASE_RUNBOOK.md` — certs → build → notarize/upload, both channels.
- `ITSAppUsesNonExemptEncryption=false` in Info.plist; copyright bumped to 2026.

## Still open (small, non-blocking)

- Real Developer ID / App Store certs + provisioning profile (Pablo, portal work).
- App Store screenshots of the sandboxed build.
- Support email placeholder in APP_STORE.md.
- arm64-only remains a choice (App Store allows Apple-Silicon-only apps).
