# iPadAudio

Real-time audio analysis app for iPad — A-weighted SPL metering, YIN pitch detection, tuner, and piano-roll visualization. Built with Swift/SwiftUI and Apple's Accelerate framework. No external dependencies.

## Features

- **SPL Meter** — real-time A-weighted sound pressure level with color-coded thresholds
- **History Chart** — rolling SPL line chart (5s–5min window, adjustable dB range)
- **Pitch Detection** — YIN algorithm with note name, octave, and cents deviation
- **Tuner Gauge** — visual cents offset indicator (green/yellow/red)
- **Piano Roll** — pitch history chart with key/scale-aware note grid (15 scales)
- **Flexible Layout** — toggle Meter and Pitch panels, adaptive for Split View / Slide Over. Both views support touchscreen zoom and range selection.

## Screenshots
Both sound level and pitch at the same time
![both](https://github.com/user-attachments/assets/4488c3c9-9b97-4312-9a15-bad6ed6a1c3e)

Pitch view
![pitch](https://github.com/user-attachments/assets/d2ec7d6e-5b56-4d3b-bd79-2abc5c3d400c)

Sound level view
![spl](https://github.com/user-attachments/assets/a493cb3e-eb2d-4154-91e0-d0a51f28748c)

Adjustable scale to highlight the in-key note lines
![scale](https://github.com/user-attachments/assets/f1c1aade-08e4-47bd-b2db-08e8fb6a1de7)

Settings available for sound level thresholds and how chart history duration
![settings](https://github.com/user-attachments/assets/ef9f04c6-cdd7-42b2-bbe7-d14a7dfae4a9)


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
