# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**iPadAudio** is a native iPadOS app that provides real-time audio analysis — reimagined from [pi-audio](https://github.com/dantanner/pi-audio) (a Raspberry Pi Python/pygame app) as a native Swift/SwiftUI experience for iPad.

**Target device:** 11" 2025 iPad (A16 chip)

## Features

- Real-time A-weighted SPL (Sound Pressure Level) measurement
- Rolling history chart of SPL over configurable time window (5s to 5min)
- Scrolling FFT-based spectrogram with logarithmic frequency axis and color mapping
- YIN-based pitch detection with note name, octave, and cents deviation
- Tuner gauge showing cents offset from nearest note
- Piano-roll pitch history chart (Melodyne-style) with auto or fixed range
- Flexible panel layout: toggle up to 2 of 3 panels (Overtones, Meter, Pitch) or value-only mode, adaptive for multitasking
- Freeze/Live toggle to pause chart display while audio continues
- Settings presented as iOS-native sheet modal (no hamburger menu)
- Persistent user settings via @AppStorage/UserDefaults

## Build & Run

This is a standard Xcode project. No external dependencies — all DSP uses Apple's Accelerate framework.

```bash
# Open in Xcode
open iPadAudio.xcodeproj

# Build from command line
xcodebuild -target iPadAudio -sdk iphoneos26.4 build CODE_SIGNING_ALLOWED=NO

# Run tests (once tests exist)
xcodebuild -scheme iPadAudio -destination 'platform=iOS Simulator,name=iPad Air' test
```

**Important:** The app requires microphone access. It must run on a real device (not Simulator) for meaningful audio testing.

## Architecture

MVVM with Swift's `@Observable` macro (iOS 17+). See [docs/DESIGN.md](docs/DESIGN.md) for full architecture.

### Data Flow
```
AVAudioEngine mic tap (audio thread)
  → DSP serial queue: A-weight → SPL, FFT → spectrum, YIN → pitch
  → DispatchQueue.main → AudioViewModel (@Observable)
  → SwiftUI views observe and redraw
```

### Key Directories
- `iPadAudio/Models/` — data models, constants, settings
- `iPadAudio/Audio/` — audio engine, DSP processors (A-weighting, FFT, YIN)
- `iPadAudio/ViewModels/` — observable view models bridging audio to UI
- `iPadAudio/Views/` — all SwiftUI views and Canvas renderers
- `iPadAudio/Utilities/` — RingBuffer, ColorLUT

### Key Files
- `AudioEngine.swift` — AVAudioEngine lifecycle, mic tap, DSP dispatch
- `AWeightingFilter.swift` — IEC 61672 A-weighting via Accelerate vDSP_biquad
- `FFTProcessor.swift` — Blackman-Harris window + 16384-point vDSP FFT
- `YINPitchDetector.swift` — YIN pitch detection algorithm
- `AudioViewModel.swift` — central @Observable publishing SPL/FFT/pitch to UI
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
