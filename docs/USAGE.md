# NibNab - Quick Usage Guide

> Color-coded clipboard collector for macOS
> **"Your clipboard deserves better"**

## 🚀 Installation

```bash
# From the nibnab directory:
./install.sh
```

This will:
- Build the latest version
- Kill any running instance
- Install to /Applications
- Optionally launch the app

## 🎯 Quick Start

### First Launch
1. Launch from Spotlight: `Cmd+Space` → type "nibnab"
2. Look for the **highlighter icon** in your menubar
3. **Right-click the icon** to choose your active color

### The New Workflow (v2)

**Active Color System:**
- NibNab has ONE active color at a time
- The menubar icon shows a **colored dot** = your active color
- **Highlight any text** → auto-saves to that color
- **No popups, no dialogs** - just seamless capture

**Changing Active Color (3 ways):**
1. **Right-click menubar icon** → pick from menu (checkmark = active)
2. **Click footer colors** in popover (white ring = active)
3. Your choice persists between launches

**Global Shortcut**: `Cmd+Ctrl+N` - Opens NibNab from anywhere

## ⚙️ Settings (Header Toggles)

- **Monitor** - Pause/resume clipboard watching
- **Auto-launch** - Start NibNab on login

*Note: Selection capture has its own toggle — right-click menubar → "Capture Text Selections". It's only available in the direct-download (DMG) build; the Mac App Store build captures via Cmd+C only.*

## 🔐 Accessibility Permission (One-Time, DMG build only)

For selection capture to work, NibNab needs to detect text selection:

1. First time you launch → macOS shows system dialog
2. Click **"Open System Settings"** button (takes you right there!)
3. Toggle **NibNab** to **ON**
4. Done! Auto-capture now works everywhere

Or manually:
- **System Settings → Privacy & Security → Accessibility**
- Find NibNab and toggle ON

## 🎨 The Colors

NibNab uses vintage highlighter colors for organizing:

- **Yellow** (#f5f617) - Default, general purpose
- **Orange** (#f68717) - Important, urgent
- **Pink** (#f60474) - Ideas, creative
- **Purple** (#8717f6) - Code, technical
- **Green** (#39ff14) - Fresh, current, close at hand

Use them however you want - they're just colors!

## 📋 Daily Usage

### Capturing Clips
1. **Set your active color** (right-click menubar icon)
2. **Highlight text anywhere** in any app
3. **Watch menubar pulse** = clip saved!
4. Switch colors anytime for different contexts

### Viewing Clips
- Click menubar icon to open popover
- **Footer color circles** switch between views
- **White ring** shows which color is active (where new clips go)
- Each clip shows:
  - Source app (blue, monospace)
  - Time ago ("just now", "5m ago")
  - Text preview (150 chars)

## 📁 Storage

All clips saved to: `<Application Support>/com.pibulus.nibnab/[color-name]/` (inside `~/Library/Containers/com.pibulus.nibnab/Data` for sandboxed builds)

Each color keeps one markdown file; each clip section has:
- Timestamp (stored in UTC)
- Source app name
- The selected text
- Optional URL (if from browser) - *coming soon*

**Limits**: 100 clips per color (oldest auto-deleted)

## 🔧 Development

### Building
```bash
./build.sh              # Builds to build/NibNab.app
open build/NibNab.app   # Run locally without installing
```

### Installing
```bash
./install.sh            # Full install workflow
```

### Building a DMG
```bash
./build-dmg.sh
```

For a signed DMG:
```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" ./build-dmg.sh
```

For a signed + notarized DMG:
```bash
SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)" \
NOTARY_PROFILE="nibnab-notary" \
./build-dmg.sh
```

Or manually:
```bash
./build.sh
cp -r build/NibNab.app /Applications/
open /Applications/NibNab.app
```

### Rebuilding & Relaunching
```bash
pkill NibNab && ./build.sh && open build/NibNab.app
```

## 🐛 Troubleshooting

**Menubar icon not showing?**
- The app is menubar-only (no dock icon by design)
- Look for the highlighter icon in your menubar
- Use Spotlight to launch if needed

**Auto-copy not working?**
- Check accessibility permissions (see above)
- Make sure "Monitor" toggle is ON
- Try highlighting text again

**Colored dot not showing on icon?**
- Quit and relaunch NibNab
- The dot indicates your active color

**Launch at Login not working?**
- Toggle it OFF then ON again
- Check System Settings → General → Login Items
- NibNab should be listed there

## 💡 Tips

✨ **Set color before browsing** - active color = where new clips go
🎯 **Footer colors are dual-purpose** - view clips AND set active color
⚡ **Watch the menubar pulse** - confirms clip was saved
🌈 **5 colors = 5 contexts** - work, personal, research, misc, fresh grabs
📦 **Local only** - no cloud, no sync, no tracking

## 🎸 Philosophy

NibNab is designed around **compression over complexity**:

- **Five colors** - Not a hundred tags
- **One active color** - Not decision fatigue every copy
- **Local markdown** - Not a cloud database
- **Menubar only** - Not another window to manage
- **One feature** - Collect clips by color, that's it

The goal is to reduce friction in capturing useful bits while maintaining creative chaos.

---

Built with Swift/SwiftUI for macOS 13.0+
Part of Pablo's SoftStack Projects
