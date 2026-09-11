# Music Tutor System Architecture

This document provides a high-level overview of the Music Tutor application architecture, detailing how the Flutter frontend, FastAPI backend, ML Audio AI engine, and MySQL storage interact seamlessly while keeping MIDI and Audio AI workloads strictly decoupled.

```
+-------------------------------------------------------------------------+
|                           FLUTTER FRONTEND                              |
|  +--------------------------------+  +-------------------------------+  |
|  |     MIDI Practice Feature      |  |     Audio Practice Feature    |  |
|  | (Hardware / USB MIDI Inputs)   |  | (Microphone Recording / Audio)|  |
|  +--------------------------------+  +-------------------------------+  |
+-----------------------------------|-------------------------------------+
                                    | HTTP / REST API
                                    v
+-------------------------------------------------------------------------+
|                            FASTAPI BACKEND                              |
|  +--------------------------------+  +-------------------------------+  |
|  |    Routers: /auth, /trainer,   |  |     Router: /audio-ai         |  |
|  |     /exercises, /practice      |  |                               |  |
|  +--------------------------------+  +---------------+---------------+  |
|                                                      |                  |
|                                                      v                  |
|                                      +-------------------------------+  |
|                                      |       Audio AI Service        |  |
|                                      +---------------+---------------+  |
+------------------------------------------------------|------------------+
                                                       |
                                                       v
+-------------------------------------------------------------------------+
|                             AUDIO ENGINE                                |
|  1. Preprocessing (16kHz mono normalization, framing, STFT/Mel)         |
|  2. Neural Pitch Model (Frame-level F0 prediction + Voicing)            |
|  3. Analysis Engine (Cents deviation, note segmentation, timing)        |
|  4. Performance Scorer (Pitch accuracy, timing, stability scoring)      |
|  5. Feedback Generator (Actionable vocal/instrument tips)               |
+------------------------------------------------------|------------------+
                                                       |
                                                       v
+-------------------------------------------------------------------------+
|                             MYSQL DATABASE                              |
|  Tables: users, exercises, trainer_assignments, user_progress,          |
|          practice_sessions, user_settings                               |
+-------------------------------------------------------------------------+
```

## Core Architectural Principles

1. **Decoupled Engine & Scoring**:
   - The ML Neural Model strictly handles pattern recognition (predicting continuous fundamental frequency $F0$ in Hz and binary/continuous voicing probability per time frame).
   - Domain-specific musical logic (note segmentation, pitch accuracy calculation, cents error calculation, stability metrics) is computed deterministically in the **Analysis & Scoring Engine**.
   - Overall score is derived from transparent, weighted domain metrics ($Score_{pitch}$, $Score_{timing}$, $Score_{stability}$), avoiding "black-box" end-to-end score guessing.

2. **MIDI System Independence**:
   - MIDI practice handles discrete note-on/note-off velocity events sent via hardware/USB MIDI controllers.
   - Audio practice processes continuous analog audio sampled from the user's microphone.
   - Shared data models (`PracticeSession`, `UserProgress`) index both session types cleanly via standard enums (`session_type: MIDI | AUDIO`).

3. **Stateless RESTful Processing**:
   - Micro-recordings captured by Flutter are transmitted as standard WAV/FLAC audio files via multipart POST endpoints (`/api/v1/audio-ai/analyze`).
   - The FastAPI backend validates audio constraints, runs preprocessing and model inference, evaluates musical precision, persists session metrics into MySQL, and returns comprehensive JSON analysis back to the client.
