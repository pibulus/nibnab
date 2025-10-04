# NibNab User Guide 📖

A quick guide to getting the most out of your clipboard highlighter.

## Getting Started

### First Launch

1. **Open NibNab** - Look for the highlighter icon in your menubar (top right)
2. **Grant Accessibility** (optional) - If you want auto-capture of selected text
   - macOS will prompt you
   - Open System Settings → Privacy & Security → Accessibility
   - Enable NibNab
   - **Or skip it** - you'll still capture Cmd+C copies

3. **You're done!** Start copying stuff

## How Capturing Works

NibNab captures text in two ways:

### Method 1: Cmd+C (Always works)
- Copy anything with Cmd+C
- NibNab auto-saves to your active color
- Menubar icon flashes to confirm

### Method 2: Text Selection (Requires accessibility)
- Select text anywhere
- Hold for a moment
- NibNab auto-saves it
- No need to Cmd+C

**Both methods save to your currently active color.**

## Using Colors

### What Colors Mean
Whatever you want! Here are some ideas:

- **🟡 Yellow** - Ideas & inspiration
- **🟠 Orange** - Research & references
- **🩷 Pink** - Quotes & highlights
- **🟣 Purple** - Code snippets & commands

### Changing Active Color

**Method 1: Footer (in main window)**
- Click any colored circle at bottom
- That's now your active color

**Method 2: Right-click menubar**
- Right-click the menubar icon
- Select a color from dropdown
- All future copies go there

### Visual Cues
- Menubar icon shows a colored dot (your active color)
- Footer shows "Active: [color name]"

## Managing Clips

### Viewing Clips

**Open NibNab:**
- Click menubar icon, OR
- Press **Cmd+Shift+V** (global shortcut)

**Browse clips:**
- Scroll through your collection
- Each clip shows:
  - Source app name
  - How long ago it was captured
  - Preview of text (first 150 chars)

### Searching

Use the search bar (top of window):
- Searches clip text AND app names
- Updates results live as you type
- Clear with X button

### Sorting

Click the sort icon (↕️) to organize:
- **Newest First** - Most recent at top (default)
- **Oldest First** - Chronological order
- **By App Name** - Group by source application
- **By Length** - Longest clips first

### Quick Actions (Hover on clip)

When you hover over any clip, you see:
- **📄 Copy** - Copy to clipboard
- **❌ Delete** - Remove clip

### Detail View (Click on clip)

Click any clip to see:
- Full text (scrollable)
- Source app & timestamp
- Character count
- Copy and delete buttons

## Exporting Clips

Click the export icon (⬇️) and choose format:

### Markdown Export
```markdown
# NibNab Export - Yellow
Exported: Jan 15, 2025 2:30 PM

---
### Chrome
*Jan 15, 2025 2:15 PM*

Your clip text here...
```

**Good for:**
- Keeping context (where it came from)
- Sharing with teammates
- Documentation
- Archiving

### Plain Text Export
```
Your clip text here...

---

Another clip...

---

Third clip...
```

**Good for:**
- Clean compilation of quotes
- Pasting into other apps
- Code snippet collections
- No metadata needed

## Settings

**Right-click the menubar icon** to access:

### Launch at Login
- ✅ = Starts with macOS
- Turn off if you prefer manual launch

### Sound Effects
- ✅ = Plays subtle sounds
  - "Pop" when capturing clips
  - "Tink" when deleting clips
  - "Pop" when changing colors
- Turn off for silent operation

### About
- App info and version
- Link to GitHub

### Quit
- Or use Cmd+Q from the app

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **Cmd+Shift+V** | Toggle NibNab window |
| **Cmd+C** | Copy & auto-capture |
| **Cmd+Q** | Quit (when app is focused) |

## Where Your Data Lives

All clips are saved locally at:
```
~/.nibnab/
```

Each color gets its own folder with a markdown file:
- `highlighter yellow/highlighter yellow_clips.md`
- `highlighter orange/highlighter orange_clips.md`
- `highlighter pink/highlighter pink_clips.md`
- `highlighter purple/highlighter purple_clips.md`

### You Can:
- Read these files in any text editor
- Edit them manually (why not?)
- Back them up to Dropbox/iCloud
- Grep through them with terminal
- Delete them to start fresh

**NibNab never sends your data anywhere.** No cloud. No sync. No tracking.

## Tips & Tricks

### Organizing Strategy

**By Project:**
- Yellow = Work project
- Orange = Side project
- Pink = Personal
- Purple = Learning/research

**By Content Type:**
- Yellow = Links
- Orange = Text snippets
- Pink = Code
- Purple = Commands

**By Action:**
- Yellow = To read later
- Orange = To reply to
- Pink = To share
- Purple = To archive

### Quick Workflows

**Research Mode:**
1. Set active color (e.g., Orange)
2. Browse and copy relevant bits
3. Everything auto-saves to Orange
4. Export as Markdown when done

**Writing Mode:**
1. Collect quotes in Pink
2. Gather references in Orange
3. Export both as Plain Text
4. Paste into your writing app

**Code Snippets:**
1. Capture commands to Purple
2. Sort by app name
3. Export as Plain Text
4. You've got a command reference!

## Troubleshooting

### Clips aren't capturing
- Check accessibility permission (System Settings)
- Try Cmd+C instead of text selection
- Make sure NibNab is running (menubar icon visible)

### Wrong color capturing
- Check footer: "Active: [color]"
- Click a different color to switch
- Or right-click menubar → select color

### Can't find old clips
- Use search bar to filter
- Try sorting by date or app name
- Check the markdown files in `~/.nibnab/`

### Sounds not working
- Right-click menubar → check "Sound Effects" is ✅
- macOS volume must be on
- Some Mac sounds require restart

### App feels slow
- Too many clips? Each color maxes at 100
- Older clips auto-delete when limit hit
- Or manually delete clips you don't need

## Privacy & Data

### What NibNab Tracks
- Nothing. Zero. Nada.

### What NibNab Stores
- Your copied text
- Source app names
- Timestamps
- All saved locally in markdown

### What NibNab Sends
- Nothing. No network requests.
- No analytics, no telemetry, no "anonymous usage data"

### What You Own
- Everything. It's your data.
- Stored in plain markdown you can read
- Delete `~/.nibnab/` to wipe everything

## Need More Help?

- **Found a bug?** → [github.com/pibulus/nibnab/issues](https://github.com/pibulus/nibnab/issues)
- **Have an idea?** → Same place
- **Want to contribute?** → PRs welcome

---

*Happy highlighting! 🎨*
