# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iPadAudio** is a native iPadOS app that provides real-time audio analysis — reimagined from [pi-audio](https://github.com/dantanner/pi-audio) (a Raspberry Pi Python/pygame app) as a native Swift/SwiftUI experience for iPad.

**Target device:** 11" 2025 iPad (A16 chip)

## Features

- Real-time A-weighted SPL (Sound Pressure Level) measurement
- Rolling history chart of SPL over configurable time window (5s to 5min)
- YIN-based pitch detection with note name, octave, and cents deviation
- Tuner gauge showing cents offset from nearest note
- Piano-roll pitch history chart (Melodyne-style) with auto or fixed range
- Flexible panel layout: toggle up to 2 panels (Meter, Pitch) or value-only mode, adaptive for multitasking
- Settings presented as iOS-native sheet modal (no hamburger menu)
- Persistent user settings via @AppStorage/UserDefaults

## Build & Run

This is a standard Xcode project. No external dependencies — all DSP uses Apple's Accelerate framework. Uses [just](https://github.com/casey/just) as a command runner — the justfile auto-detects the connected iPad.

```bash
just              # List all available commands
just open         # Open project in Xcode
just devices      # List connected devices
just build        # Build for connected iPad
just install      # Install the built app on connected iPad
just launch       # Launch the app on connected iPad
just deploy       # Build, install, and launch (all-in-one)
just test         # Run tests in simulator
```

**Important:** The app requires microphone access. It must run on a real device (not Simulator) for meaningful audio testing.

## Architecture

MVVM with Swift's `@Observable` macro (iOS 17+). See [docs/DESIGN.md](docs/DESIGN.md) for full architecture.

### Data Flow
```
AVAudioEngine mic tap (audio thread)
  → DSP serial queue: A-weight → SPL, YIN → pitch
  → DispatchQueue.main → AudioViewModel (@Observable)
  → SwiftUI views observe and redraw
```

### Key Directories
- `iPadAudio/Models/` — data models, constants, settings
- `iPadAudio/Audio/` — audio engine, DSP processors (A-weighting, YIN)
- `iPadAudio/ViewModels/` — observable view models bridging audio to UI
- `iPadAudio/Views/` — all SwiftUI views and Canvas renderers
- `iPadAudio/Utilities/` — RingBuffer

### Key Files
- `AudioEngine.swift` — AVAudioEngine lifecycle, mic tap, DSP dispatch
- `AWeightingFilter.swift` — IEC 61672 A-weighting via Accelerate vDSP_biquad
- `YINPitchDetector.swift` — YIN pitch detection algorithm
- `AudioViewModel.swift` — central @Observable publishing SPL/pitch to UI
- `AppSettings.swift` — all user settings with @AppStorage persistence
- `ContentView.swift` — top-level view composition

## Implementation Status

See [docs/PHASES.md](docs/PHASES.md) for detailed phase tracking. Update the status there as phases are completed.

## Reference

- [docs/DESIGN.md](docs/DESIGN.md) — architecture, technology choices, file structure
- [docs/PHASES.md](docs/PHASES.md) — implementation phases with status
- [docs/DSP_REFERENCE.md](docs/DSP_REFERENCE.md) — algorithms and DSP specs ported from pi-audio
- Source project: `/Users/dantanner/code/pi-audio/` (Python/pygame)

## Conventions

- Swift, SwiftUI, iOS 17+ minimum deployment target
- No external package dependencies — use Accelerate, AVFoundation, SwiftUI only
- Custom Canvas drawing for all charts (no Swift Charts)
- `@Observable` macro, not `ObservableObject`/`@Published`
- System font (SF Pro) for text, `.monospacedDigit()` for numeric readouts only
- Dark color scheme by default (`.preferredColorScheme(.dark)`)
- Landscape orientation primary (11" iPad), adaptive for Split View / Slide Over

## Project Coding Rules
- When commenting, use evergreen style comments and only comment about the current state of the code, not how we got there
- After completing a feature or bug fix that affects the app UI or behavior, run `just deploy` to build, install, and launch on the connected iPad for on-device testing
