# NibNab 🎯

> A menu bar friend that collects the good bits
> *Currently brewing in Bangkok ☕*

![WIP](https://img.shields.io/badge/status-work%20in%20progress-FF69B4)
![macOS](https://img.shields.io/badge/macOS-13.0+-9370DB)
![Swift](https://img.shields.io/badge/Swift-5.9-FFB6C1)

## What's this?

You copy stuff all day. Links, quotes, code snippets, random thoughts. Where does it all go?

NibNab sits in your menu bar and catches everything you copy, sorting it into four color-coded collections. No cloud, no accounts, no tracking. Just your clips, organized by vibe.

## The colors mean whatever you want

- **Peach** - Maybe for inspiration?
- **Lavender** - Could be research
- **Sky** - Perhaps todos
- **Sage** - Whatever feels right

Copy text → Pick a color → It's saved forever (or until you delete it)

## Current status

This is super early. Like, "still figuring out the color picker" early. But it works:

- ✅ Catches clipboard changes
- ✅ Color picker pops up when you copy
- ✅ Saves everything to markdown files
- ✅ Won't crash (probably)

## What's coming

- Screenshot snippets alongside text
- Browser URL grabbing
- Keyboard shortcuts (1-4 for colors)
- Search across all collections
- Export to Obsidian/Notion
- Maybe themes? Dark mode?

## Install

For now:
```bash
git clone https://github.com/pibulus/nibnab.git
cd nibnab
./build.sh
open build/NibNab.app
```

Or drag the built app to `/Applications` if you're feeling permanent about it.

## Storage

Everything lives in `~/.nibnab/` as markdown files. One file per color. No database, no complexity. You own your data.

## Why?

Because every clipboard manager is either:
- Too complicated (I don't need 47 features)
- Too simple (just a list? really?)
- Too corporate (why does it need an account?)

This is the 80/20 version. Does less, does it better.

## Tech bits

- Swift/SwiftUI (because native feels better)
- NSPopover architecture (MenuBarExtra kept crashing)
- No dependencies (just macOS 13.0+)

## Contributing

Got ideas? Found bugs? The code is right there. PRs welcome if they keep things simple.

## Who

Made by [Pablo](https://github.com/pibulus) in Bangkok, where it's always monsoon season and the coffee is strong.

Part of the anti-scale movement. This will never have a pricing page.

---

*"Your clipboard deserves better than CMD+V into Notes.app"*