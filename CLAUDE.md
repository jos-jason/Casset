# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Casset is an iOS audiobook player app built with Swift and SwiftUI. It supports bookmarking, chapter navigation, and book grouping. The project targets iOS 26.2+ and was created with Xcode 26.3.

**Bundle ID:** `Babymechanical.Casset`

## Build Commands

```bash
# Build (Debug)
xcodebuild -project Casset.xcodeproj -scheme Casset -configuration Debug build

# Build (Release)
xcodebuild -project Casset.xcodeproj -scheme Casset -configuration Release build

# Build for simulator
xcodebuild -project Casset.xcodeproj -scheme Casset \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

No test targets or linting tools are configured yet.

## Architecture

The app follows a manager + SwiftUI view pattern:

**Data Models** (`Casset/`)
- `Book.swift` — individual audiobook representation
- `BookGroup.swift` — collections/groupings of books

**Managers** (ObservableObject singletons injected via environment)
- `AudioPlayerManager.swift` — AVAudioPlayer/AVAudioEngine playback, chapter tracking, seek
- `LibraryManager.swift` — library persistence, file discovery, metadata

**Views**
- `CassetApp.swift` — root app entry point; wires managers into environment
- `ContentView.swift` — top-level navigation shell
- `PlayerView.swift` — transport controls, seek bar, speed
- `CassetteView.swift` — per-book detail screen
- `GroupsView.swift` / `GroupDetailView.swift` — browse collections
- `BookmarksChaptersView.swift` / `BookmarkCreationView.swift` / `BookmarkTimelineView.swift` — bookmark workflow
- `SettingsView.swift` — user preferences
- `MarqueeText.swift` — reusable scrolling text component (for long titles)

All views are SwiftUI. The project uses `@MainActor` isolation by default (enabled in build settings) and approachable concurrency.

## Key Build Settings

- **Deployment target:** iOS 26.2
- **Swift version:** 5.0
- **Warnings as errors:** enabled
- **Previews:** enabled (`ENABLE_PREVIEWS = YES`)
- **Code signing:** automatic (no manual provisioning needed locally)
- No external Swift Package Manager or CocoaPods dependencies are configured.
