# ML Dataset Guidelines & Specification

This document details dataset requirements, expected directory layout, supported public datasets, and annotation schema standards for training and evaluating the Music Tutor Neural Pitch Model.

## Directory Structure

Datasets must be organized under `ml/datasets/` following this structure:

```
ml/datasets/
├── raw/
│   ├── mir_1k/
│   │   ├── audio/
│   │   │   ├── abv2_1_01.wav
│   │   │   └── ...
│   │   └── annotations/
│   │       ├── abv2_1_01.pv
│   │       └── ...
│   ├── mir_st500/
│   └── medleydb/
│
├── processed/
│   ├── train/
│   │   ├── sample_00001.pt
│   │   └── ...
│   ├── validation/
│   └── test/
│
└── metadata/
    ├── train.csv
    ├── validation.csv
    └── test.csv
```

## Supported Datasets

1. **MIR-1K**: 1,000 song clips of vocal audio with frame-level ground truth pitch annotations sampled at 10ms intervals.
2. **MIR-ST500**: 500 studio pitch-annotated vocal tracks designed for polyphonic/monophonic pitch evaluation.
3. **MedleyDB**: Multi-track dataset with fundamental frequency ($F0$) annotations for vocal and instrumental solos.

## Metadata CSV Format

Metadata CSV files (`metadata/train.csv`, `metadata/validation.csv`, `metadata/test.csv`) index dataset files using the following schema:

| Column | Type | Description |
| :--- | :--- | :--- |
| `audio_path` | String | Relative path to `.wav` audio file |
| `annotation_path` | String | Relative path to frame-level ground-truth pitch file |
| `duration_sec` | Float | Duration of audio clip in seconds |
| `sample_rate` | Integer | Original sampling rate in Hz |
| `dataset_source` | String | Source dataset name (e.g. `MIR-1K`) |
| `is_voiced_ratio` | Float | Proportion of voiced frames (0.0 to 1.0) |

## Expected Annotation Format

Frame-level pitch annotations should provide high-resolution pitch tracks:

- **Timestamp (sec)**: Time offset of frame center.
- **F0 Frequency (Hz)**: Continuous fundamental frequency ($F0 = 0.0$ for unvoiced / silence).
- **Voiced Indicator**: $1$ if voiced sound present, $0$ if unvoiced/silence.
- **Note Label (Optional)**: Standard pitch string (e.g., `"C4"`, `"A4"`) if note boundaries are annotated.
