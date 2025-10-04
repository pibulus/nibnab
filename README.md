# NibNab 🎨

> A highlighter for your digital life
> *Currently brewing in Bangkok ☕*

![macOS](https://img.shields.io/badge/macOS-13.0+-FF69B4)
![Swift](https://img.shields.io/badge/Swift-5.9-FFEB3B)
![Status](https://img.shields.io/badge/status-v1.0-39FF14)

## What's this?

You copy stuff all day. Links, quotes, code snippets, random thoughts. Where does it all go?

NibNab sits in your menu bar and catches **everything you copy**, sorting it into four color-coded collections. No cloud, no accounts, no tracking. Just your clips, organized by vibe.

## How it works

1. **Copy anything** (Cmd+C or select text)
2. **It auto-captures** to your active color
3. **View, export, or delete** anytime

That's it. No color picker interrupting your flow. No "should I save this?" decisions. Just copy and it's there.

## The colors mean whatever you want

- **🟡 Yellow** - Maybe for inspiration?
- **🟠 Orange** - Could be research
- **🩷 Pink** - Perhaps quotes
- **🟣 Purple** - Whatever feels right

Pick your active color, copy text, it's saved forever (or until you delete it).

## Features

### ✅ Smart Capture
- Monitors Cmd+C clipboard changes
- Auto-captures text selections (with accessibility permission)
- Saves to your active color automatically
- Menubar icon shows current color

### ✅ Organization
- Four highlighter colors for categorizing
- Search across clips
- Sort by date, app, or length
- View full clip details

### ✅ Export Options
- **Markdown** - with metadata (app name, timestamps)
- **Plain text** - just clips with separators
- Save anywhere on your Mac

### ✅ Settings (Right-click menubar)
- Launch at login
- Sound effects toggle
- Color switching
- About & quit

### ✅ Audio Feedback (Optional)
- Subtle chime on capture
- Sound on delete
- Toggle in settings menu

### ✅ Privacy First
- Everything stored locally in `~/.nibnab/`
- Markdown files you can read/edit
- No cloud, no sync, no tracking
- You own your data

## Install

```bash
git clone https://github.com/pibulus/nibnab.git
cd nibnab
./build.sh
open build/NibNab.app
```

Or drag the built app to `/Applications` if you're feeling permanent about it.

### First Launch

NibNab will ask for:
- **Accessibility permission** - To auto-capture selected text
- **Just deny it if you only want Cmd+C capture**

That's it. No signup, no account, no BS.

## Keyboard Shortcuts

- **Cmd+Shift+V** - Toggle NibNab window
- **Cmd+C** - Auto-captures to active color
- **Right-click menubar** - Settings & color picker

## Storage

Everything lives in `~/.nibnab/` as markdown files:
```
~/.nibnab/
├── highlighter yellow/
│   └── highlighter yellow_clips.md
├── highlighter orange/
│   └── highlighter orange_clips.md
├── highlighter pink/
│   └── highlighter pink_clips.md
└── highlighter purple/
    └── highlighter purple_clips.md
```

No database. No complexity. You own your data.

## Why?

Because every clipboard manager is either:
- Too complicated (I don't need 47 features)
- Too simple (just a list? really?)
- Too corporate (why does it need an account?)

This is the 80/20 version. Does less, does it better.

## What's next? (maybe)

- Load clips from markdown on launch
- Screenshot snippets alongside text
- Browser URL capture
- Keyboard shortcuts for color selection (1-4)
- Export to Obsidian/Notion

But honestly? It's pretty much done. Adding features just to add features is how good tools become bad ones.

## Tech bits

- **Swift/SwiftUI** - Native macOS feels better
- **NSPopover architecture** - MenuBarExtra kept crashing
- **No dependencies** - Just macOS 13.0+
- **Single file** - ~1200 lines of readable Swift
- **Local storage** - Markdown files, nothing fancy

## Contributing

Got ideas? Found bugs? The code is right there. PRs welcome if they keep things simple.

Philosophy: If it makes the README longer, it probably doesn't belong.

## Who

Made by [Pablo](https://github.com/pibulus) in Bangkok, where it's always monsoon season and the coffee is strong.

Part of the anti-scale movement. This will never have:
- A pricing page
- A login screen
- A "pro" version
- Analytics
- Your email address

---

*"Your clipboard deserves better than Cmd+V into Notes.app"*
