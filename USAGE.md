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
3. Click it to open the clip collector

### Daily Usage

**Global Shortcut**: `Cmd+Shift+V` - Opens NibNab from anywhere

**Copying Text**:
1. Copy anything (`Cmd+C`)
2. Color picker appears near your cursor (3 second window)
3. Click a color to save the clip
4. Or ignore it and it disappears

**Viewing Clips**:
- Click menubar icon or use `Cmd+Shift+V`
- Click color circles at bottom to switch categories
- Click any clip to copy it back to clipboard

## ⚙️ Settings (In Header)

- **Monitor** - Watch clipboard for changes
- **Auto-copy** - Captures text when you select it (experimental)
- **Auto-launch** - Start NibNab on login

## 🎨 The Colors

NibNab uses vintage highlighter colors for organizing:

- **Yellow** (#f5f617) - Default, general purpose
- **Orange** (#f68717) - Important, urgent
- **Pink** (#f60474) - Ideas, creative
- **Purple** (#8717f6) - Code, technical

Use them however you want - they're just colors!

## 📁 Storage

All clips saved to: `~/.nibnab/[color-name]/`

Each clip is a markdown file with:
- Timestamp
- Source app name
- The copied text
- Optional URL (if copied from browser) - *coming soon*

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

**Keyboard shortcut not working?**
- macOS may need accessibility permissions
- Check System Settings → Privacy & Security → Accessibility
- Add NibNab if prompted

**Color picker not appearing?**
- Make sure "Monitor" toggle is ON
- The picker only shows for 3 seconds after copying
- Try copying again

**Launch at Login not working?**
- Toggle it OFF then ON again
- Check System Settings → General → Login Items
- NibNab should be listed there

## 🎸 Philosophy

NibNab is designed around **compression over complexity**:

- **Four colors** - Not a hundred tags
- **Local markdown** - Not a cloud database
- **Menubar only** - Not another window to manage
- **One feature** - Collect clips by color, that's it

The goal is to reduce friction in capturing useful bits while maintaining creative chaos.

---

Built with Swift/SwiftUI for macOS 13.0+
Part of Pablo's SoftStack Projects
