# Model Training Workflow

This document outlines the standard training workflow, loss function design, hyperparameter setup, checkpointing strategy, and model export procedure for the Music Tutor Neural Pitch Model.

## Training Configuration (`ml/training/config.py`)

Key training parameters are controlled via structured dataclasses:

- **Sample Rate**: 16,000 Hz
- **Hop Length**: 160 samples (10 ms time step resolution)
- **Window Length / FFT Size**: 1024 samples (~64 ms context frame)
- **Batch Size**: 32 or 64 clips
- **Optimizer**: AdamW (Learning Rate: $1 \times 10^{-3}$, Weight Decay: $1 \times 10^{-4}$)
- **LR Scheduler**: CosineAnnealingLR or ReduceLROnPlateau
- **Random Seed**: 42 (ensures deterministic reproducible splits and weight initializations)

## Multi-Task Loss Function Design

The pitch estimation model uses a joint loss combining frequency regression and voicing classification:

$$\mathcal{L}_{total} = \lambda_{f0} \cdot \mathcal{L}_{f0} + \lambda_{voiced} \cdot \mathcal{L}_{voiced}$$

1. **F0 Pitch Loss ($\mathcal{L}_{f0}$)**:
   - Evaluated ONLY over voiced frames ($V_{gt} = 1$).
   - Log-frequency $L1$ Loss or Cent Loss:
     $$\mathcal{L}_{f0} = \frac{1}{N_{v}} \sum_{i \in voiced} \left| \log_2(F0_{pred, i}) - \log_2(F0_{gt, i}) \right|$$

2. **Voicing Loss ($\mathcal{L}_{voiced}$)**:
   - Binary Cross Entropy (BCE) Loss over all frame predictions:
     $$\mathcal{L}_{voiced} = -\frac{1}{N} \sum_{i=1}^{N} \left[ V_{gt, i} \log(\hat{V}_i) + (1 - V_{gt, i}) \log(1 - \hat{V}_i) \right]$$

## Checkpointing & Early Stopping

- Checkpoints are saved to `ml/experiments/checkpoints/` after every epoch.
- Best model state is selected based on **Raw Pitch Accuracy (RPA)** on the validation set.
- Early stopping halts training if validation loss fails to improve over 15 consecutive epochs.

## Exporting for Production

Once validated on the test set:
1. Export model weights to PyTorch TorchScript format (`models/pitch_model/model.pt`).
2. Export model to ONNX format (`models/pitch_model/model.onnx`) for optimized inference execution.
3. Write `models/pitch_model/metadata.json` documenting versioning, dataset provenance, and input/output tensor shapes.
