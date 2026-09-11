# Audio AI Pipeline

This document details the step-by-step processing pipeline for Audio AI pitch estimation, note segmentation, intonation analysis, scoring, and actionable feedback generation.

## End-to-End Processing Pipeline

```
  Flutter Microphone Recording
             │
             ▼
  Audio File Upload (.wav / .flac)
             │
             ▼
  FastAPI Preprocessing
   • Sample-rate resampling to 16 kHz
   • Mono channel conversion
   • Peak amplitude normalization (-1 dB FS)
   • Silence trimming & framing (hop size: 10 ms, frame len: 40 ms)
             │
             ▼
  Neural Pitch Model (Inference)
   • Input: Normalized Audio Frames / Spectrogram
   • Output: Frame-level F0 (Hz) & Voicing Confidence [0.0 - 1.0]
             │
             ▼
  Note Conversion & Segmentation
   • Frequency to MIDI note mapping: N_midi = 69 + 12 * log2(F0 / 440)
   • Temporal smoothing & continuous voiced frame grouping
             │
             ▼
  Performance Analysis
   • Pitch deviation error (cents = 1200 * log2(F0_detected / F0_expected))
   • Timing onset & duration alignment against target exercise sequence
   • Stability evaluation (pitch drift variance per sustained note)
             │
             ▼
  Scoring Engine
   • Pitch Score: 100 - (mean_cents_error * scale_factor)
   • Stability Rating: 10 - (frequency_variance * scale_factor)
   • Overall Score: Weighted combination of Pitch, Timing & Stability
             │
             ▼
  Feedback Generator
   • Contextual tips for flat/sharp tendencies or unstable sustain
             │
             ▼
  MySQL Database & Flutter UI Rendering
```

## Stage Detail & Responsibilities

### 1. Preprocessing
- **Resampling**: Standardizes input to 16,000 Hz.
- **Channel Conversion**: Multi-channel inputs are averaged down to single mono channel.
- **Normalization**: Peak volume normalized to ensure invariant level scaling across different mic gains.
- **Framing**: Audio is sliced into overlapping frames (e.g., 640 samples per frame, 160 sample hop size = 10 ms resolution).

### 2. Neural Pitch Model
- **Input**: Raw waveform audio tensors $[B, 1, T]$ or spectrograms $[B, 1, F, T]$.
- **Backbone**: Convolutional feature extractor paired with recurrent/transformer temporal layers.
- **Output**:
  - `f0`: Fundamental frequency prediction per frame in Hz.
  - `voiced`: Binary indicator / probability score representing voiced speech/singing vs unvoiced/silence.

### 3. Note Conversion & Segmentation
- Converts continuous Hz predictions into discrete musical note pitch labels ($A4=440\text{Hz}$, $C4 \approx 261.63\text{Hz}$).
- Filters transient noise and groups contiguous voiced frames into detected note events.

### 4. Performance Analysis
- **Pitch Deviation**: Computes deviation in musical cents ($1\text{ semitone} = 100\text{ cents}$).
- **Timing Alignment**: Measures target note start/stop times against detected note boundaries using Dynamic Time Warping (DTW) or sequence alignment.
- **Stability Metric**: Evaluates frequency jitter and standard deviation during sustained note holds.

### 5. Scoring & Actionable Feedback
- Transparent mathematical scoring without arbitrary heuristics.
- Structured feedback highlights specific pitch tendencies (e.g., "Slightly flat on note F4 by -25 cents").
