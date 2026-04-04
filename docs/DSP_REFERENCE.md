# DSP Algorithm Reference

Detailed specifications for all signal processing algorithms, ported from [pi-audio](https://github.com/dantanner/pi-audio). This document provides everything needed to implement the Swift equivalents without needing to reference the Python source.

## Audio Pipeline Constants

```
SAMPLE_RATE    = 48000       # Hz
BLOCK_SIZE     = 4800        # samples per block (100ms at 48kHz)
FFT_SIZE       = 16384       # zero-padded FFT length
FFT_BIN_HZ     = 48000/16384 ≈ 2.93 Hz/bin
UPDATE_RATE    = 10          # Hz (one block per 100ms)
CALIBRATION_DB = 94.0        # dB reference for USB mic sensitivity
```

## 1. A-Weighting Filter (IEC 61672:2003)

Models human hearing sensitivity. De-emphasizes low (<20 Hz) and high (>8 kHz) frequencies. Peak sensitivity around 1-4 kHz.

### Analog Prototype

The A-weighting curve is defined by 4 corner frequencies:

```
f1 = 20.598997    Hz
f2 = 107.65265    Hz
f3 = 737.86223    Hz
f4 = 12194.217    Hz
```

**Zeros:** 4 zeros at s=0 (numerator is s⁴)

**Poles (analog, in rad/s):**
```
p1 = -2π × f1    (double pole)
p2 = -2π × f2
p3 = -2π × f3
p4 = -2π × f4    (double pole)
```

So there are 4 zeros (all at 0) and 6 poles total (p1 appears twice, p4 appears twice).

### Digital Filter Design

1. **Pre-warp** (not done in pi-audio; uses bilinear without pre-warp):
   - Analog poles and zeros are transformed directly via bilinear transform
   - `z = (1 + s/(2*fs)) / (1 - s/(2*fs))` where fs = sample rate

2. **Bilinear transform** each analog pole/zero to digital:
   - For zeros at s=0: digital zeros at z=-1
   - For each analog pole p: `z_d = (1 + p/(2*fs)) / (1 - p/(2*fs))`

3. **Gain normalization:** Scale so response = 0 dB at 1000 Hz
   - Evaluate `H(z)` at `z = e^(j*2π*1000/fs)` and divide by magnitude

4. **Convert to second-order sections (SOS):**
   - Group zeros and poles into 3 biquad sections
   - Each section: `H(z) = (b0 + b1*z⁻¹ + b2*z⁻²) / (1 + a1*z⁻¹ + a2*z⁻²)`

### Recommended Implementation for Swift

Since the sample rate is fixed at 48kHz, **pre-compute the SOS coefficients** and hard-code them. Run the Python code once to extract:

```python
# In pi-audio's audio.py, after computing sos:
import numpy as np
sos = _a_weighting_sos(48000)
np.set_printoptions(precision=17)
print(repr(sos))
# Also print the gain: print(repr(gain))
```

Then implement as 3 cascaded `vDSP_biquad` calls in Swift. Each biquad needs persistent delay state (5 Doubles, initialized to 0) that carries across audio blocks for filter continuity.

```swift
// Pseudocode for applying A-weighting:
func apply(_ samples: [Float]) -> [Float] {
    var output = samples
    for i in 0..<3 {
        vDSP_biquad(setup[i], &delays[i], output, 1, &output, 1, UInt(output.count))
    }
    return output
}
```

## 2. SPL Calculation

```
1. Apply Blackman-Harris window to raw audio
2. Apply A-weighting filter
3. Compute RMS: sqrt(mean(samples²))
4. Convert to dB: 20 * log10(rms) + CALIBRATION_DB
   - CALIBRATION_DB = 94.0 (reference level for typical USB mics)
   - Guard against log(0): use max(rms, 1e-20)
```

**Note:** Values are relative SPL. Absolute calibration requires known microphone sensitivity.

### Display Thresholds (defaults)

```
SPL_MIN       = 20 dB    (display floor)
SPL_MAX       = 100 dB   (display ceiling)
QUIET_THRESH  = 55 dB    (green → yellow transition)
MODERATE_THRESH = 75 dB  (yellow → red transition)
```

## 3. FFT / Spectrogram

### FFT Processing

```
1. Apply Blackman-Harris window to raw (unfiltered) audio block (4800 samples)
2. Zero-pad to FFT_SIZE (16384 samples)
3. Compute real FFT → complex spectrum (8193 bins, 0 to Nyquist)
4. Compute magnitude in dB: 20 * log10(|bin| + 1e-20)
5. Store the positive-frequency magnitude array as one spectrogram column
```

### Spectrogram Display

**Frequency range:** 50-8000 Hz (configurable via settings)

**Logarithmic frequency axis mapping:**
```
For each display row (0 = top = high freq, H-1 = bottom = low freq):
    log_freq = log10(freq_max) - row * (log10(freq_max) - log10(freq_min)) / (H - 1)
    freq = 10^log_freq
    bin_index = round(freq / FFT_BIN_HZ)
```

Pre-compute this mapping once (when display size or freq range changes).

**Dynamic range:** -60 to 0 dB (relative). Values below -60 dB → darkest color. Values above 0 dB → brightest color.

### Color LUT (256 entries)

Interpolate RGB between these control points:

```
Index    R      G      B       Description
-----    ---    ---    ---     -----------
  0       5      5     15      dark background
 20      10     10     50      deep blue (noise floor)
 60      20     40    180      blue
120       0    200    220      cyan (mid-range)
180     240    220      0      yellow (signal)
255     255     60     20      red (loud)
```

Linear interpolation between control points. Map dB to index:
```
index = clamp((dB - DB_MIN) / (DB_MAX - DB_MIN) * 255, 0, 255)
```

### Frequency Labels

Draw labels at: 100, 200, 500, 1000, 2000, 4000, 8000 Hz (only those within display range).
Format: "100", "200", "500", "1k", "2k", "4k", "8k"

## 4. YIN Pitch Detection Algorithm

Monophonic pitch detection using autocorrelation. More robust than FFT peak-picking for musical signals.

### Parameters

```
SAMPLE_RATE  = 48000
THRESHOLD    = 0.15      # aperiodicity threshold (lower = stricter)
RMS_GATE     = 1e-4      # silence threshold
FREQ_MIN     = 30 Hz     # reject below
FREQ_MAX     = 5000 Hz   # reject above
C6_CEILING   = 1046.5 Hz # hard ceiling for pitch reporting
```

### Algorithm Steps

**Input:** Raw audio samples (one block, 4800 samples at 48kHz)

#### Step 1: Silence Gate
```
rms = sqrt(mean(samples²))
if rms < RMS_GATE: return nil  // too quiet
```

#### Step 2: Difference Function (FFT-based)
```
tau_max = SAMPLE_RATE / FREQ_MIN  // = 1600 for 30 Hz minimum
W = min(len(samples), tau_max)    // working window

// Efficient computation using FFT:
fft_size = next_power_of_2(2 * W)  // = 4096 for W=1600
x_padded = zero_pad(samples[0..W-1], fft_size)
X = FFT(x_padded)
acf = real(IFFT(X * conj(X)))  // autocorrelation via FFT

// Energy terms:
r_head[0] = sum(samples[0..W-1]²)
for tau in 1..<W:
    r_head[tau] = r_head[tau-1] - samples[tau-1]²

r_tail[0] = r_head[0]
for tau in 1..<W:
    r_tail[tau] = r_tail[tau-1] - samples[W-tau]² + samples[W-1]²  // see note below

// Actually computed as:
// r_tail is accumulated differently in the Python code.
// Simpler approach: precompute cumulative sums.

// Difference function:
d[tau] = r_head[tau] + r_tail[tau] - 2 * acf[tau]
```

**Note on r_head and r_tail from pi-audio source:**
```python
x_head = x[:W]          # truncate to W samples
x_sq = x_head ** 2
cs = np.cumsum(x_sq)    # cumulative sum of x²

r_head = np.empty(W)
r_head[0] = cs[W - 1]   # sum of all x²
for tau in range(1, W):
    r_head[tau] = cs[W - 1 - tau]  # = sum(x[0..W-1-tau]²)
    # Equivalently: r_head[tau] = r_head[0] - (cs[W-1] - cs[W-1-tau])

r_tail = np.empty(W)
r_tail[0] = cs[W - 1]   # same as r_head[0]
for tau in range(1, W):
    r_tail[tau] = cs[W - 1] - cs[tau - 1]  # = sum(x[tau..W-1]²)
```

#### Step 3: Cumulative Mean Normalized Difference (CMNDF)
```
d'[0] = 1.0
for tau in 1..<W:
    cumsum += d[tau]
    d'[tau] = d[tau] * tau / cumsum
    // Guard: if cumsum == 0, d'[tau] = 1.0
```

#### Step 4: Absolute Threshold Search
```
for tau in 2..<W:
    if d'[tau] < THRESHOLD:
        // Walk forward to nearest local minimum
        while tau + 1 < W and d'[tau + 1] < d'[tau]:
            tau += 1
        return tau
return nil  // no pitch found
```

#### Step 5: Parabolic Interpolation
```
if tau == 0 or tau >= W - 1:
    return tau  // can't interpolate at boundaries

s0 = d'[tau - 1]
s1 = d'[tau]
s2 = d'[tau + 1]

denominator = 2 * (2*s1 - s2 - s0)
if denominator == 0:
    return tau

tau_refined = tau + (s2 - s0) / denominator
```

#### Step 6: Frequency Conversion
```
frequency = SAMPLE_RATE / tau_refined

if frequency < FREQ_MIN or frequency > FREQ_MAX:
    return nil

return frequency
```

### Post-Detection Filtering (in AudioEngine)

```
// Hard ceiling: never report above C6
if frequency > C6_CEILING:
    return nil

// Range filtering: only report within user-configured semitone range
if frequency < semitoneToFreq(settings.pitchNoteMin):
    return nil
if frequency > semitoneToFreq(settings.pitchNoteMax):
    return nil
```

## 5. Pitch-to-Note Conversion

### Frequency → Note
```
A4_FREQ = 440.0
A4_MIDI = 69
NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

func freqToNote(hz: Double) -> (name: String, octave: Int, cents: Int) {
    let midi = 12 * log2(hz / A4_FREQ) + A4_MIDI  // continuous MIDI note number
    let midiRounded = Int(round(midi))
    let cents = Int(round((midi - Double(midiRounded)) * 100))  // -50 to +49
    let noteName = NOTE_NAMES[((midiRounded % 12) + 12) % 12]
    let octave = midiRounded / 12 - 1
    return (noteName, octave, cents)
}
```

### Semitone ↔ Frequency
```
// Semitone offset from A4 (range: -39 to +39)
func semitoneToFreq(_ semitone: Int) -> Double {
    return 440.0 * pow(2.0, Double(semitone) / 12.0)
}

// Note name from semitone offset
func noteNameFromSemitone(_ semitone: Int) -> String {
    let midi = A4_MIDI + semitone
    let name = NOTE_NAMES[((midi % 12) + 12) % 12]
    let octave = midi / 12 - 1
    return "\(name)\(octave)"
}
```

## 6. Tuner Display Smoothing

Applied in TunerViewModel, updated each frame (~30fps).

### EMA Cents Smoothing
```
alpha = 0.15  // smoothing factor (~200ms settling time at 30fps)

if pitchDetected:
    smoothedCents = alpha * rawCents + (1 - alpha) * smoothedCents
else:
    // Decay toward center when no pitch
    smoothedCents = (1 - alpha) * smoothedCents
```

### Note Stability
```
stabilityCount = 0
stableNote = nil
STABILITY_THRESHOLD = 5      // frames (~150ms at 30fps)
TIMEOUT_THRESHOLD = 10        // frames (~300ms at 30fps)
timeoutCount = 0

if pitchDetected:
    timeoutCount = 0
    if rawNote == lastRawNote:
        stabilityCount += 1
    else:
        stabilityCount = 1
        lastRawNote = rawNote

    if stabilityCount >= STABILITY_THRESHOLD:
        stableNote = rawNote  // update displayed note
else:
    timeoutCount += 1
    if timeoutCount >= TIMEOUT_THRESHOLD:
        stableNote = nil      // clear display
        stabilityCount = 0
```

### Tuner Gauge Colors
```
absCents = abs(smoothedCents)
if absCents <= 8:   green   // in tune
elif absCents <= 20: yellow  // close
else:                red     // out of tune
```

## 7. Piano-Roll Pitch Chart

### Auto-Range Mode
```
// Collect all non-nil pitches from history
// Convert each to semitone: semi = 12 * log2(freq / 440)
// Find median semitone
// Display range: median ± 6 semitones (1 octave above and below)
```

### Fixed-Range Mode
```
// Use settings.pitchNoteMin and settings.pitchNoteMax directly
// These are semitone offsets from A4
```

### Y-Axis Grid
```
// Major lines: every octave (every 12 semitones)
// Minor lines: every semitone
// Labels: natural note names only (C, D, E, F, G, A, B) — no sharps/flats
```

### Pitch Trace Rendering
```
// For each time step with a detected pitch:
//   Convert freq to semitone Y position
//   If previous step also had pitch: draw line connecting them
//   If previous step was nil: draw dot (isolated detection)
```
