# luksMusic

A SwiftUI-based iOS application for reading, practicing, scanning, and editing sheet music. Built with AudioKit for audio synthesis and MIDI playback, with OCR capabilities for digitizing printed scores.

## Requirements

- **Xcode 16.0+**
- **iOS 17.0+** deployment target
- **Swift 6.0**
- macOS Sonoma 14.0+ (for development)

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [AudioKit](https://github.com/AudioKit/AudioKit) | 5.6+ | Audio engine, synthesis, and real-time audio processing |
| [Tonic](https://github.com/AudioKit/Tonic) | 2.0+ | Music theory types — notes, chords, scales, intervals |

## Project Setup

### Option 1: XcodeGen (Recommended)

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the `.xcodeproj` from a declarative `project.yml` spec.

```bash
# Install XcodeGen (if not already installed)
brew install xcodegen

# Generate the Xcode project
cd luksMusic
xcodegen generate

# Open in Xcode
open luksMusic.xcodeproj
```

### Option 2: Swift Package Manager

The project also includes a `Package.swift` for SPM-based workflows:

```bash
# Resolve dependencies
swift package resolve

# Open Package.swift in Xcode (opens as a Swift Package)
open Package.swift
```

> **Note:** When opening via `Package.swift`, asset catalogs and Info.plist are not automatically linked. Use XcodeGen for the full app experience.

## Architecture

The project follows **MVVM** (Model-View-ViewModel) architecture:

```
luksMusic/
├── App/                    # App entry point & root navigation
├── Models/                 # Data models & MusicXML parsing
│   └── MusicXML/           # MusicXML import/export
├── ViewModels/             # Business logic & state management
├── Views/                  # SwiftUI views
│   ├── Score/              # Score rendering (staff, notes, measures)
│   ├── Library/            # Score library & import
│   ├── Practice/           # Practice mode with piano & falling notes
│   ├── Scanner/            # Camera-based sheet music OCR
│   ├── Editor/             # Score editing tools
│   └── Components/         # Reusable UI components
├── Services/               # Core services
│   ├── Audio/              # AudioKit engine & metronome
│   ├── MIDI/               # MIDI I/O & file playback
│   ├── OCR/                # Sheet music OCR processing
│   └── Storage/            # Local score persistence
└── Extensions/             # Swift/SwiftUI extensions
```

## Features

- 🎵 **Score Viewer** — Render and navigate MusicXML scores with staff, clef, and note rendering
- 📚 **Score Library** — Import, organize, and manage your sheet music collection
- 🎹 **Practice Mode** — Interactive practice with falling notes, piano keyboard, and real-time feedback
- 📷 **Sheet Music Scanner** — Scan printed sheet music with the camera and convert to digital scores via OCR
- ✏️ **Score Editor** — Create and edit scores with an intuitive note input interface
- 🎧 **Audio Playback** — MIDI-based playback with tempo control and metronome
- 📊 **Practice Statistics** — Track your practice sessions and progress

## License

Private project. All rights reserved.
