# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NibNab is a macOS menubar application that captures clipboard contents and organizes them into color-coded collections. Built with Swift/SwiftUI, it runs as a background menubar app with no cloud dependencies - all data is stored locally in markdown files.

## Build & Development Commands

### Building the Application
```bash
./build.sh                           # Build the complete macOS app bundle
open build/NibNab.app               # Run the built application
cp -r build/NibNab.app /Applications/  # Install to Applications folder
```

### Development Workflow
```bash
# Quick compile check (no app bundle)
swiftc -parse-as-library -target arm64-apple-macos13.0 -framework Cocoa -framework SwiftUI NibNab.swift

# Clean build
rm -rf build && ./build.sh
```

## Architecture & Code Structure

### Single-File Swift Application
The entire app is contained in `NibNab.swift` with clear section divisions using `// MARK:` comments:

- **Color Theme System**: `NibColor` and `NibGradients` structs define the four neon color palette (pink, blue, yellow, green)
- **App Lifecycle**: `NibNabApp` (main) → `AppDelegate` (manages menubar and popover)
- **State Management**: `AppState` class handles clipboard monitoring and data persistence
- **UI Components**: SwiftUI views (`ContentView`, `ColorTab`, `ClipView`, `ColorPickerView`)
- **Storage**: `StorageManager` saves clips as markdown files in `~/.nibnab/`

### Key Architectural Patterns

**NSPopover-based UI**: The app uses `NSPopover` attached to a menubar status item rather than MenuBarExtra (which was crashing)

**Clipboard Monitoring**: Timer-based polling of `NSPasteboard.general.changeCount` every 0.5 seconds

**Color-First Organization**: Four predefined neon colors serve as clip categories - users pick a color when copying

**Markdown Storage**: Each color category saves to separate markdown files with timestamps and source app metadata

**Floating Color Picker**: When clipboard changes, a borderless floating window appears near the cursor for 3 seconds

## Development Patterns & Conventions

### Code Style
- Epic section dividers: `// ===================================================================`
- MARK comments for major sections: `// MARK: - Section Name`
- SwiftUI property wrappers: `@Published`, `@EnvironmentObject`, `@State`
- Neon color palette with specific hex values and gradients

### UI Design System
- **Colors**: Neon pink (#FF10F0), electric blue (#00D4FF), laser yellow (#FFFF00), toxic green (#39FF14)
- **Typography**: System fonts with rounded design, monospace for metadata
- **Gradients**: Linear gradients for visual elements with specific color combinations
- **Shadows**: Colored shadows matching the neon theme
- **Dark Theme**: Black/gray backgrounds with high contrast neon accents

### Data Management
- **Local Storage**: `~/.nibnab/[colorname]/` directories with markdown files
- **No Cloud**: Completely offline, no external dependencies
- **Clip Limits**: Maximum 100 clips per color category
- **Metadata Capture**: Source app name, timestamp, optional URL (TODO)

## Target Platform & Requirements

- **macOS**: 13.0+ (Ventura and later)
- **Architecture**: Apple Silicon (arm64) native compilation
- **Frameworks**: Cocoa, SwiftUI
- **App Type**: Menu bar utility (LSUIElement = true)
- **Bundle ID**: com.pibulus.nibnab

## Build Configuration

The `build.sh` script creates a complete `.app` bundle with:
- Optimized Swift compilation (`-O` flag)
- Proper Info.plist with LSUIElement for menubar app behavior
- Target architecture: arm64-apple-macos13.0
- App bundle structure in `build/` directory

## Planned Features (TODOs in code)

- Screenshot capture alongside text clips
- Browser URL extraction via AppleScript (`getCurrentURL()` currently returns nil)
- Keyboard shortcuts (1-4 keys for color selection)
- Search functionality across all clips
- Export capabilities to Obsidian/Notion
- Dark mode themes

## Key Implementation Details

**Clipboard Change Detection**: Uses `NSPasteboard.general.changeCount` comparison rather than continuous string monitoring for performance

**Color Picker UX**: Floating window positioned near mouse cursor, auto-closes after 3 seconds, supports hover animations

**State Architecture**: Single `AppState` ObservableObject manages all clipboard data and UI state, with weak delegate reference to AppDelegate

**Memory Management**: Timer-based monitoring with proper cleanup, weak references to prevent retain cycles

**Storage Format**: Human-readable markdown with YAML-style frontmatter for metadata