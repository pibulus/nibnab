# NibNab - Code Glossary

Quick reference for NibNab's modular Swift architecture.

## App Structure

**NibNabApp** - Main app entry (menubar-only, LSUIElement = true)
`Sources/AppEntry.swift` - @main

**AppDelegate** - Menubar + popover management, global shortcuts, clipboard monitoring
`Sources/AppEntry.swift` - @NSApplicationDelegateAdaptor

## Views (SwiftUI)

**ContentView** - Main popover with header, clip list, footer
`Sources/UI.swift` - 5 color-coded collections

**ContentHeaderView** - Search bar, monitoring toggle, auto-copy toggle, sort menu, export/clear
`Sources/UI.swift` - Header bar with controls

**ContentFooterView** - Color tabs with active indicator, clip count, editable label
`Sources/UI.swift` - 5 color circles (drag-drop targets)

**ClipView** - Single clip display with metadata, copy/delete hover controls
`Sources/UI.swift` - Clip content + timestamp + source app

**ColorDropTarget** - Individual color circle in footer (active ring, drop target)
`Sources/UI.swift` - Color circle button

**ClipDetailView** - Full clip detail modal with edit/delete/copy
`Sources/UI.swift` - Modal overlay

**EditClipModal** - Inline text editor for clip content
`Sources/UI.swift` - Modal overlay

**AddClipModal** - Manual clip creation
`Sources/UI.swift` - Modal overlay

**WelcomeView** - First-launch onboarding
`Sources/UI.swift` - Feature cards

**ColorPickerView** - Floating window for color selection on new clips
`Sources/UI.swift` - Appears on clipboard change, 3s timeout

**AboutView** - About window content
`Sources/UI.swift` - Credits and links

## State Management

**AppState** - ObservableObject managing all clipboard data and settings
`Sources/AppState.swift` - @Published clips dictionary, monitoring state, sounds, labels

**LocationTracker** - Watches NSWorkspace frontmost app changes
`Sources/AppState.swift` - Tracks current active app for clipboard context

## Data & Storage

**StorageManager** - Markdown file persistence (full rewrite per clip)
`Sources/StorageManager.swift` - Saves to ~/Library/Application Support/com.pibulus.nibnab/

**Clip** - Data model with id, text, timestamp, url, appName, screenshotPath
`Sources/Models.swift` - Codable, Transferable, Identifiable

**ClipboardSupport** - Cmd+D text selection capture (accessibility API)
`Sources/ClipboardSupport.swift` - AutoCopyMonitor, permission handling

## Color System

**NibColor** - Color theme definitions and gradients
`Sources/ColorTheme.swift` - 5 neon highlighter colors

**Colors:**
- Yellow (#FFEB3B) - Highlighter Yellow
- Orange (#f68717) - Highlighter Orange
- Pink (#f60474) - Highlighter Pink
- Purple (#8717f6) - Highlighter Purple
- Green (#39ff14) - Highlighter Green

## Core Concepts

**Color-First Organization** - 5 predefined categories
User assigns meaning (project, type, priority, etc.)

**Clipboard Monitoring** - Timer-based NSPasteboard polling
- Polls every 0.5s checking changeCount
- Auto-captures on Cmd+C or text selection (with accessibility permission)

**Storage Format** - Single markdown file per color with clip sections
- Format: `id:`, `timestamp:`, `### AppName`, text content
- Max 100 clips per color category

**Global Shortcuts:**
- Cmd+Ctrl+N — Toggle popover
- Cmd+Ctrl+M — Toggle auto-copy (text selection capture)
- Cmd+Ctrl+1 — Switch to Yellow
- Cmd+Ctrl+2 — Switch to Orange
- Cmd+Ctrl+3 — Switch to Pink
- Cmd+Ctrl+4 — Switch to Purple
- Cmd+Ctrl+5 — Switch to Green
