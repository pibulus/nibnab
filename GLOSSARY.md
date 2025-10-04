# NibNab - Code Glossary

Quick reference for NibNab's single-file Swift architecture.

## App Structure

**NibNabApp** - Main app entry (menubar-only, no windows)
`NibNab.swift` - @main

**AppDelegate** - Menubar + popover management, clipboard monitoring
`NibNab.swift` - @NSApplicationDelegateAdaptor

## Views (SwiftUI)

**ContentView** - Main popover with color tabs + clips
`NibNab.swift` - 4 color-coded sections

**ColorTab** - Individual color category tab (Yellow/Orange/Pink/Purple)
`NibNab.swift` - Tab button with neon gradient

**ClipView** - Single clip display with metadata
`NibNab.swift` - Clip content + timestamp + source app

**ColorPickerView** - Floating window for color selection
`NibNab.swift` - Appears on clipboard change, 3s timeout

## State Management

**AppState** - ObservableObject managing all clipboard data
`NibNab.swift` - Published clips dictionary, monitoring state

**EventMonitor** - Click outside detection for popover
`NibNab.swift` - Closes popover when clicking away

**AutoCopyMonitor** - Text selection detection (Cmd+D)
`NibNab.swift` - Auto-saves selected text without Cmd+C

## Data & Storage

**StorageManager** - Markdown file persistence
`NibNab.swift` - Saves to ~/.nibnab/[colorname]/

**NibColor** - Color theme definitions
`NibNab.swift` - 4 neon highlighter colors with hex values

**NibGradients** - LinearGradient definitions
`NibNab.swift` - Matching gradients for each color

## Core Concepts

**Color-First Organization** - 4 predefined categories
- Yellow (#FFEB3B) - Highlighter Yellow
- Orange (#f68717) - Highlighter Orange
- Pink (#f60474) - Highlighter Pink
- Purple (#8717f6) - Highlighter Purple

**Clipboard Monitoring** - Timer-based NSPasteboard polling
- Polls every 0.5s checking changeCount
- Shows color picker on new clipboard content

**Storage Format** - Markdown with YAML frontmatter
- Files: `~/.nibnab/[colorname]/YYYY-MM-DD_HHMMSS.md`
- Metadata: source app, timestamp, URL (TODO)
- Max 100 clips per color category

**Global Shortcuts**
- Cmd+Shift+V: Toggle NibNab window
- Cmd+Ctrl+1-4: Set active color (Yellow/Orange/Pink/Purple)
