# CLAUDE.md — Casset

This file provides guidance for AI assistants working on the Casset codebase.

## Project Overview

**Casset** is an early-stage iOS audiobook player application built with Swift and SwiftUI. The app is designed to support audiobook playback, bookmark management, chapter navigation, and book grouping/collections.

- **Platform**: iOS / iPadOS (universal)
- **Language**: Swift 5.0
- **UI Framework**: SwiftUI
- **Bundle ID**: `Babymechanical.Casset`
- **iOS Deployment Target**: 26.2
- **Author**: JJ Vollum (jjvollum@gmail.com)
- **Project started**: March 2026

## Repository Structure

```
Casset/
├── CLAUDE.md                        # This file
├── Casset/                          # All Swift source files
│   ├── CassetApp.swift              # @main app entry point
│   ├── ContentView.swift            # Root view (currently placeholder)
│   │
│   ├── # Data Models
│   ├── Book.swift                   # Audiobook data model
│   ├── BookGroup.swift              # Collection/group of books
│   │
│   ├── # Managers (Business Logic)
│   ├── AudioPlayerManager.swift     # Audio playback engine
│   ├── LibraryManager.swift         # Book library persistence & management
│   │
│   ├── # Views
│   ├── PlayerView.swift             # Audio player controls UI
│   ├── CassetteView.swift           # Cassette/album art display
│   ├── GroupsView.swift             # List of book groups
│   ├── GroupDetailView.swift        # Detail view for a single group
│   ├── BookmarksChaptersView.swift  # Combined bookmarks & chapters view
│   ├── BookmarkCreationView.swift   # Create/edit a bookmark
│   ├── BookmarkTimelineView.swift   # Visual timeline of bookmarks
│   ├── SettingsView.swift           # App settings
│   │
│   ├── # UI Utilities
│   ├── MarqueeText.swift            # Scrolling/ticker text component
│   │
│   └── Assets.xcassets/             # App icon, accent color, image assets
│
└── Casset.xcodeproj/                # Xcode project configuration
    ├── project.pbxproj
    └── project.xcworkspace/
```

## Development Status

The project is in **early scaffolding phase**. Most files contain only an `import Foundation` or `import SwiftUI` statement — the file structure and naming conventions are established but implementation is pending. `ContentView.swift` shows the default Xcode placeholder ("Hello, world!"). No features are functionally implemented yet.

**What exists:**
- App entry point (`CassetApp.swift`) wired to `ContentView`
- All source files created with proper naming
- Asset catalog with app icon (1024×1024) and accent color

**What is pending (everything else):**
- All data model definitions (`Book`, `BookGroup`)
- All manager implementations (`AudioPlayerManager`, `LibraryManager`)
- All view implementations

## Build & Run

**Requirements:**
- Xcode (supporting iOS 26.2 SDK)
- No external dependencies — no Swift Package Manager packages, CocoaPods, or Carthage

**From Xcode:**
1. Open `Casset.xcodeproj`
2. Select a simulator or connected device
3. Press `Cmd+R` to build and run

**From command line:**
```bash
xcodebuild -project Casset.xcodeproj -scheme Casset -configuration Debug
```

## Testing

There are currently **no tests**. No test target has been configured in the Xcode project. `ENABLE_TESTABILITY = YES` is set for Debug builds, so a test target can be added when ready.

When adding tests:
- Use XCTest for unit tests
- Use Swift Testing (introduced in Xcode 16) for new test suites if targeting iOS 17+
- Place test files in a new `CassetTests/` directory

## Architecture & Conventions

### Intended Architecture
The project is structured for a lightweight **MVVM** pattern:
- **Models**: `Book`, `BookGroup` — plain Swift structs/classes representing domain data
- **Managers**: `AudioPlayerManager`, `LibraryManager` — `ObservableObject` classes encapsulating business logic and state
- **Views**: SwiftUI `View` structs consuming manager state via `@EnvironmentObject` or `@StateObject`

### SwiftUI Patterns to Follow
- Use `@StateObject` to own a manager in the root view; pass down via `.environmentObject()`
- Prefer `struct` views; keep view bodies short by extracting subviews
- Use `#Preview` macros (Xcode 15+) for SwiftUI previews
- Follow Apple's naming conventions: views end in `View`, data types are nouns

### File Header Convention
All files use the standard Xcode file header:
```swift
//
//  FileName.swift
//  Casset
//
//  Created by JJ vollum on M/D/YY.
//
```

### Import Conventions
- `import SwiftUI` for views
- `import Foundation` for models and managers
- `import AVFoundation` will be needed for audio playback (`AudioPlayerManager`)

### Code Style
- Standard Swift/Apple style (no explicit linter configured yet)
- `UpperCamelCase` for types, `lowerCamelCase` for properties and methods
- No external formatting tools configured; follow Xcode's default Swift indentation (4 spaces)

## Key Implementation Notes

### AudioPlayerManager
Will need `AVFoundation` and likely `AVAudioSession` for background audio. Should conform to `ObservableObject` and publish playback state (`isPlaying`, `currentTime`, `duration`). Must handle audio session categories for background playback.

### LibraryManager
Responsible for persisting the user's book library. Likely candidates for storage: `FileManager` (for audio files imported by the user) and `UserDefaults` or `CoreData` for metadata. Book files will be imported from the Files app via `UIDocumentPickerViewController` or the SwiftUI equivalent.

### Book Model
Should include: title, author, file URL (or bookmark data for security-scoped resources), current playback position, total duration, chapter list, and bookmarks.

### BookGroup Model
Should include: name, list of `Book` references, and a cover image or color.

## Git Workflow

- **Main branch**: `master`
- **Feature branches**: Use descriptive names; Claude-created branches follow the pattern `claude/<description>-<id>`
- Commit messages should be clear and imperative (e.g., "Add Book data model", "Implement AudioPlayerManager playback controls")
- There is no CI/CD pipeline; all validation is manual via Xcode

## No CI/CD or Linting (Yet)

There are no:
- GitHub Actions workflows
- SwiftLint or SwiftFormat configurations
- Pre-commit hooks

When these are added, document them here.
