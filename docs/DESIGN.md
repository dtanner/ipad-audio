# Architecture & Design

## Technology Stack

| Concern | Framework | Notes |
|---------|-----------|-------|
| UI | SwiftUI | `@Observable` (iOS 17+), Canvas for custom drawing |
| Audio capture | AVAudioEngine | `installTap` on `inputNode` |
| DSP (FFT, filters) | Accelerate (vDSP) | `vDSP_biquad`, `vDSP_fft_zrip`, `vDSP.window` |
| Settings persistence | @AppStorage / UserDefaults | Simple key-value, no JSON file |
| Concurrency | GCD (DispatchQueue) | Dedicated serial DSP queue |

**No external dependencies.** Everything uses Apple frameworks.

## Architecture: MVVM with @Observable

```
┌─────────────────────────────────┐
│         SwiftUI Views           │
│  (observe @Observable props)    │
└──────────────┬──────────────────┘
               │ reads
┌──────────────▼──────────────────┐
│      AudioViewModel             │
│  @Observable                    │
│  - currentSPL: Double           │
│  - splHistory: RingBuffer       │
│  - currentPitch: Double?        │
│  - pitchHistory: RingBuffer     │
└──────────────┬──────────────────┘
               │ main queue update
┌──────────────▼──────────────────┐
│      DSP Serial Queue           │
│  - AWeightingFilter.apply()     │
│  - SPLCalculator.compute()      │
│  - YINPitchDetector.detect()    │
└──────────────┬──────────────────┘
               │ buffer copy
┌──────────────▼──────────────────┐
│      AVAudioEngine              │
│  inputNode.installTap()         │
│  (audio render thread)          │
└─────────────────────────────────┘
```

### Thread Model

1. **Audio render thread** — AVAudioEngine tap callback fires every ~100ms (4800 samples at 48kHz). Copies buffer data, dispatches to DSP queue. Minimal work here.
2. **DSP serial queue** — All signal processing runs here (A-weighting, RMS, FFT, YIN). Keeps audio thread unblocked and main thread responsive.
3. **Main queue** — `DispatchQueue.main.async` to update `@Observable` properties. SwiftUI observes and redraws.

No locks needed. Only main thread writes to `@Observable` properties.

### Audio Session Configuration

```swift
let session = AVAudioSession.sharedInstance()
try session.setCategory(.record, mode: .measurement)
try session.setPreferredSampleRate(48000)
try session.setActive(true)
```

- `.measurement` mode: disables AGC, noise cancellation, and other hardware processing for flat frequency response.
- 48kHz preferred sample rate matches pi-audio's configuration.
- Must check actual sample rate at runtime via `inputNode.outputFormat(forBus: 0).sampleRate` and adjust block size if different.

## File Structure

```
iPadAudio/
├── iPadAudioApp.swift                 # @main, audio session, permission request
│
├── Models/
│   ├── AudioConstants.swift           # All numeric constants
│   ├── AppSettings.swift              # @Observable + @AppStorage settings
│   ├── PitchNote.swift                # Note/freq conversion functions
│   └── PanelType.swift                # enum PanelType (meter, pitch)
│
├── Audio/
│   ├── AudioEngine.swift              # AVAudioEngine lifecycle, mic tap
│   ├── AWeightingFilter.swift         # IEC 61672 biquad cascade
│   ├── SPLCalculator.swift            # RMS → dB conversion
│   └── YINPitchDetector.swift         # YIN pitch detection
│
├── ViewModels/
│   ├── AudioViewModel.swift           # Owns AudioEngine, bridges to UI
│   └── TunerViewModel.swift           # Smoothed cents, stable note logic
│
├── Views/
│   ├── ContentView.swift              # Top-level composition
│   ├── ReadoutBar.swift               # SPL + pitch + tuner + gear icon
│   ├── TunerGaugeView.swift           # Cents gauge (Canvas)
│   ├── SPLChartView.swift             # Rolling SPL chart (Canvas)
│   ├── PitchChartView.swift           # Piano-roll chart (Canvas)
│   ├── PanelContainerView.swift       # 0/1/2 panel layout (adaptive for multitasking)
│   ├── ValueOnlyView.swift            # Large SPL + pitch (no panels)
│   ├── ToggleButtonBar.swift          # Panel toggle buttons
│   ├── SettingsView.swift             # Settings Form (presented as .sheet)
│   └── AudioInterruptedBanner.swift   # Overlay banner for audio interruptions
│
└── Utilities/
    └── RingBuffer.swift               # Generic fixed-capacity ring buffer
```

## UI Layout

### Primary Layout (landscape, 1-2 panels active)

```
┌──────────────────────────────────────────────────────────────┐
│ [O][M][P]    SPL: 72 dB    A4 ═══●═══ +3¢    [⚙]  │  ← ReadoutBar
├──────────────────────────────────────────────────────────────┤
│                          │                                   │
│     Panel 1              │          Panel 2                  │  ← PanelContainer
│  (e.g. SPL Chart)        │    (e.g. Pitch Chart)            │
│                          │                                   │
└──────────────────────────────────────────────────────────────┘
```

### Value-Only Mode (no panels active)

```
┌──────────────────────────────────────────────────────────────┐
│ [O][M][P]                                              [⚙]  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│                         72 dB                                │
│                                                              │
│                     A4  ═══●═══  +3¢                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### Navigation & Controls
- **Settings:** Gear icon (⚙) presents a `.sheet` modal — no hamburger menu, no "Exit" item

### Panel Toggle Rules
- Maximum 2 panels active simultaneously
- Toggling a third panel auto-deactivates the leftmost active one with a brief animation (panel slides out) so the change is visible, not silent
- Panel state persists via AppSettings
- Single panel uses full width; two panels split with gap

### Adaptive Layout (multitasking)
- Full width (landscape): 1-2 panels as designed
- Narrow width (Split View / Slide Over, < 600pt): force single-panel mode, readout bar stacks vertically if needed
- Use `GeometryReader` / `horizontalSizeClass` to adapt

### Typography
- **System font (SF Pro)** for labels, headings, buttons, and all non-numeric text
- **Monospaced digits (`.monospacedDigit()`)** for SPL values, frequency readouts, cents, and other numeric displays where alignment matters
- Do NOT use monospace fonts globally — this is an iOS app, not a terminal

## Settings

| Setting | Type | Range | Default |
|---------|------|-------|---------|
| History Length | Int | 5-300 seconds | 30 |
| Safe Threshold | Double | 40-95 dB | 55 |
| Caution Threshold | Double | 60-100 dB | 75 |
| Pitch Note Min | Int | -39 to +38 semitones | -27 (E2) |
| Pitch Note Max | Int | -38 to +39 semitones | +10 (G5) |
| Pitch Range Auto | Bool | — | true |
| Active Panels | [String] | max 2 of [meter, pitch] | [meter, pitch] |

Validation: safe < caution, note min < note max.

## Color Scheme

Dark theme matching pi-audio:
- Background: near-black (#0A0A14)
- SPL colors: green (safe), yellow (caution), red (loud)
- Chart grid/labels: medium gray
- Active toggle: blue background
- Inactive toggle: dimmed
