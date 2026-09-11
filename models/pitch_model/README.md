# Pitch Detection Production Model Directory

This directory is designated for finalized, trained, and evaluated neural pitch detection models deployed for the Music Tutor application.

## Expected Directory Layout

When a model is trained, validated, and approved for production, the following files should be placed here:

```
models/pitch_model/
├── README.md
├── model.pt          # PyTorch TorchScript model weights
├── model.onnx        # ONNX runtime optimized model weights (optional)
└── metadata.json     # Model versioning, input shape, & evaluation metadata
```

## Expected Metadata Schema (`metadata.json`)

```json
{
  "model_name": "MusicTutorPitchNet",
  "version": "1.0.0",
  "training_date": "2026-09-09",
  "training_datasets": ["MIR-1K", "MIR-ST500"],
  "framework": "PyTorch 2.x",
  "input_spec": {
    "sample_rate": 16000,
    "channels": 1,
    "format": "Float32 PCM waveform or Log-Mel Spectrogram",
    "tensor_shape": [1, 16000]
  },
  "output_spec": {
    "f0_frequency_hz": "Float32 frame predictions",
    "voicing_confidence": "Float32 probability per frame [0.0, 1.0]",
    "frame_resolution_ms": 10
  },
  "validation_metrics": {
    "raw_pitch_accuracy": 94.5,
    "voiced_recall": 96.2,
    "mean_cents_error": 12.4
  }
}
```

> **Note**: Do not place untrained, dummy, or synthetic model weights in this directory. Model deployment must follow complete dataset training and validation procedures documented in `docs/model_training.md`.
