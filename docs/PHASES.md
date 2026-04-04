# Implementation Phases

Update status as each phase is completed. Each phase is independently testable.

## Phase 1: Project Setup + Audio Capture + SPL Display
**Status:** COMPLETE

**Goal:** Xcode project with mic capture, A-weighted SPL computation, live dB number on screen.

**Files to create:**
- `iPadAudio.xcodeproj` (Xcode project with iPadAudio target, iOS 17+, landscape)
- `iPadAudio/iPadAudioApp.swift` — app entry, audio session config, mic permission
- `iPadAudio/Models/AudioConstants.swift` — SAMPLE_RATE (48000), BLOCK_SIZE (4800), FFT_SIZE (16384), SPL_MIN (20), SPL_MAX (100), CALIBRATION_DB (94), threshold defaults
- `iPadAudio/Audio/AudioEngine.swift` — AVAudioEngine setup, installTap on inputNode (4800 samples), copy buffer to DSP queue, lifecycle (start/stop)
- `iPadAudio/Audio/AWeightingFilter.swift` — IEC 61672 A-weighting filter (see DSP_REFERENCE.md), pre-computed SOS coefficients for 48kHz, vDSP_biquad application with persistent delay state
- `iPadAudio/Audio/SPLCalculator.swift` — RMS via vDSP, dB conversion: `20*log10(rms) + 94`
- `iPadAudio/ViewModels/AudioViewModel.swift` — @Observable, owns AudioEngine, exposes `currentSPL: Double`, starts/stops engine
- `iPadAudio/Views/ContentView.swift` — displays SPL value as large colored text (green/yellow/red based on thresholds)

**Key decisions:**
- Audio session: `.record` category, `.measurement` mode (flat response, no AGC)
- Verify actual sample rate at runtime; adjust block size proportionally if not 48kHz
- Permission flow: show explanation text, then request mic access

**How to test:** Run on iPad, grant mic permission, see a live dB number. Clap near mic → should spike to 80-90 dB range. Quiet room → 30-50 dB range.

---

## Phase 2: SPL History Chart + Settings
**Status:** NOT STARTED

**Goal:** Rolling SPL line chart and full settings screen.

**Files to create:**
- `iPadAudio/Utilities/RingBuffer.swift` — generic `RingBuffer<T>` struct, fixed capacity, push/subscript/count/array
- `iPadAudio/Models/AppSettings.swift` — @Observable class with @AppStorage for each setting (see DESIGN.md table), validation logic
- `iPadAudio/Models/PanelType.swift` — `enum PanelType: String, CaseIterable { case overtones, meter, pitch }`
- `iPadAudio/Views/SPLChartView.swift` — SwiftUI Canvas: line chart of SPL history, Y-axis 20-100 dB with grid every 10 dB, time X-axis, segments colored by threshold (green/yellow/red)
- `iPadAudio/Views/SettingsView.swift` — SwiftUI Form/NavigationStack: sliders for history length, thresholds, overtone freq range (log scale), pitch note range, pitch auto toggle. Presented as `.sheet` from gear icon, not full-screen navigation

**Files to modify:**
- `AudioViewModel.swift` — add `splHistory: RingBuffer<Double>`, update on each audio callback, respect `settings.historySeconds`
- `ContentView.swift` — embed SPLChartView, add gear icon that presents SettingsView via `.sheet(isPresented:)`

**How to test:** See scrolling SPL chart. Change history length in settings → chart time scale adjusts. Change thresholds → colors change. Kill and relaunch → settings preserved.

---

## Phase 3: FFT Spectrogram
**Status:** NOT STARTED

**Goal:** Scrolling spectrogram with log-frequency axis and color mapping.

**Files to create:**
- `iPadAudio/Audio/FFTProcessor.swift` — Blackman-Harris window (vDSP.window), zero-pad to 16384, vDSP_fft_zrip, magnitude → dB array
- `iPadAudio/Utilities/ColorLUT.swift` — 256-entry `[Color]` or `[(r,g,b)]` table: dark blue → blue → cyan → yellow → red (see DSP_REFERENCE.md for exact color stops)
- `iPadAudio/Views/SpectrogramView.swift` — Canvas: each column is a vertical strip, log-frequency row mapping (precomputed), frequency labels on left (100, 200, 500, 1k, 2k, 4k, 8k Hz)

**Files to modify:**
- `AudioEngine.swift` — add FFT processing in DSP pipeline (on raw unfiltered audio)
- `AudioViewModel.swift` — add `spectrogramColumns: RingBuffer<[Float]>`

**Rendering strategy:** Start with SwiftUI Canvas drawing colored rectangles per cell. If >300 columns at 10fps is too slow on A16, switch to CGBitmapContext → UIImage approach.

**How to test:** Whistle → bright horizontal band at whistle frequency. Play music → see harmonic structure. Verify log-frequency labels are correct (octaves equally spaced).

---

## Phase 4: YIN Pitch Detection + Tuner + Pitch Chart
**Status:** NOT STARTED

**Goal:** Real-time pitch detection with note display, tuner gauge, and piano-roll chart.

**Files to create:**
- `iPadAudio/Audio/YINPitchDetector.swift` — full YIN algorithm (see DSP_REFERENCE.md): silence gate, FFT-based difference function (vDSP), CMNDF, absolute threshold (0.15), parabolic interpolation, frequency bounds (30-5000 Hz), C6 ceiling
- `iPadAudio/Models/PitchNote.swift` — `freqToNote(hz:) -> (name: String, octave: Int, cents: Int)`, `semitoneToFreq(_:) -> Double`, `noteNameFromSemitone(_:) -> String`, note names array, A4=440 reference
- `iPadAudio/ViewModels/TunerViewModel.swift` — EMA smoothing (alpha=0.15 for cents), 5-frame note stability threshold, 10-frame timeout to clear, decay cents toward 0 when no pitch
- `iPadAudio/Views/TunerGaugeView.swift` — Canvas: horizontal bar, center tick, moving indicator colored green (±8¢), yellow (±20¢), red (>±20¢)
- `iPadAudio/Views/PitchChartView.swift` — Canvas: piano-roll Y-axis (semitone grid, octave major lines, note labels), scrolling X-axis, connected line for continuous pitch, dots for isolated, auto-range (median ±1 octave) or fixed range
- `iPadAudio/Views/ReadoutBar.swift` — HStack: toggle buttons (left), SPL value colored by level (center-left), pitch note name + tuner gauge + cents (center-right), "Freeze"/"Live" labeled toggle + gear icon for settings sheet (right)

**Files to modify:**
- `AudioEngine.swift` — add YIN to DSP pipeline (on raw audio)
- `AudioViewModel.swift` — add `currentPitch: Double?`, `pitchHistory: RingBuffer<Double?>`

**How to test:** Sing a note → correct note name displayed, tuner gauge responds. Play piano → piano-roll shows note trace. Silence → display clears after ~300ms. Verify C6 ceiling.

---

## Phase 5: Panel Layout + Toggle Buttons
**Status:** NOT STARTED

**Goal:** Flexible 0/1/2 panel layout with toggle buttons.

**Files to create:**
- `iPadAudio/Views/PanelContainerView.swift` — GeometryReader: 1 panel → full width, 2 panels → HStack with spacing, 0 panels → show ValueOnlyView. Adaptive: force single-panel in narrow widths (< 600pt, e.g. Split View)
- `iPadAudio/Views/ValueOnlyView.swift` — large centered SPL (huge font, colored) + pitch (large note + tuner gauge + cents)
- `iPadAudio/Views/ToggleButtonBar.swift` — 3 buttons with SF Symbol icons, blue when active, dimmed when inactive, max 2 active (toggling third auto-deactivates leftmost with brief slide-out animation)

**Files to modify:**
- `ContentView.swift` — integrate PanelContainerView, ToggleButtonBar, ReadoutBar into final layout. Gear icon presents SettingsView as `.sheet`. Use `@Environment(\.horizontalSizeClass)` for adaptive layout
- `AppSettings.swift` — add `activePanels: [PanelType]` with validation (max 2)

**How to test:** Toggle all 7 combinations (3 singles, 3 pairs, none). Verify layout adapts. Toggle third → leftmost deactivates with visible animation. Panel state persists across launches. Test in Split View — should force single panel.

---

## Phase 6: Polish + iPad Optimization
**Status:** NOT STARTED

**Goal:** Production quality, native iOS behavior.

**Tasks:**
- [ ] Lock to landscape orientation (Info.plist `UISupportedInterfaceOrientations`)
- [ ] Dark mode support (already dark theme, use `.preferredColorScheme(.dark)`)
- [ ] Audio interruption handling (`AVAudioSession.interruptionNotification`) — show visible "Audio Interrupted" banner overlay with "Tap to resume" action (`AudioInterruptedBanner.swift`)
- [ ] Audio route changes — handle mic disconnect gracefully, show banner
- [ ] App lifecycle: stop engine on `.background`, restart on `.active` (observe `scenePhase`)
- [ ] Freeze/Live toggle in ReadoutBar — labeled toggle, distinct color when frozen
- [ ] Accessibility labels on all interactive elements
- [ ] Performance profiling: spectrogram at 10fps+, overall <16ms frame time
- [ ] If spectrogram Canvas too slow: CGBitmapContext or Metal fallback
- [ ] Stage Manager / multitasking: test Split View, Slide Over, window resize — verify adaptive layout degrades gracefully
- [ ] App icon in Assets.xcassets

---

## Phase 7: Gesture Enhancements (Future)
**Status:** NOT STARTED

**Goal:** iPad-native touch interactions on charts.

**Tasks:**
- [ ] Pinch-to-zoom on spectrogram (time axis)
- [ ] Pinch-to-zoom on pitch chart (time axis)
- [ ] Tap on spectrogram to show crosshair with frequency/dB readout
- [ ] Long-press on chart point for detail popover
