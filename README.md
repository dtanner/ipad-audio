# iPadAudio

Real-time audio analysis app for iPad — A-weighted SPL metering, YIN pitch detection, tuner, and piano-roll visualization. Built with Swift/SwiftUI and Apple's Accelerate framework. No external dependencies.

Reimagined from [pi-audio](https://github.com/dantanner/pi-audio) (Raspberry Pi + Python/pygame) as a native iPadOS experience.

## Features

- **SPL Meter** — real-time A-weighted sound pressure level with color-coded thresholds
- **History Chart** — rolling SPL line chart (5s–5min window, adjustable dB range)
- **Pitch Detection** — YIN algorithm with note name, octave, and cents deviation
- **Tuner Gauge** — visual cents offset indicator (green/yellow/red)
- **Piano Roll** — pitch history chart with key/scale-aware note grid (15 scales)
- **Flexible Layout** — toggle Meter and Pitch panels, adaptive for Split View / Slide Over

## Requirements

- iPad running iPadOS 17+
- Xcode 15+
- Microphone access (real device required for meaningful audio)

## Quick Start

Uses [just](https://github.com/casey/just) as a command runner:

```bash
just build    # Build for connected iPad
just deploy   # Build, install, and launch
just test     # Run tests in simulator
```

See [CLAUDE.md](CLAUDE.md) for full build commands and architecture overview.
