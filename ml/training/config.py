"""
Training Pipeline Configuration Module.

Defines dataclasses for training hyperparameters, data paths,
loss weights, and model output directories.
"""

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class AudioConfig:
    sample_rate: int = 16000
    n_fft: int = 1024
    hop_length: int = 160  # 10ms frame step at 16kHz
    n_mels: int = 128
    frame_length_ms: float = 40.0


@dataclass
class TrainingConfig:
    batch_size: int = 32
    num_epochs: int = 100
    learning_rate: float = 1e-3
    weight_decay: float = 1e-4
    seed: int = 42
    device: str = "cuda"  # "cuda", "mps", or "cpu"
    early_stopping_patience: int = 15
    f0_loss_weight: float = 1.0
    voiced_loss_weight: float = 1.0
    
    dataset_metadata_dir: str = "ml/datasets/metadata"
    checkpoint_dir: str = "ml/experiments/checkpoints"
    export_model_dir: str = "models/pitch_model"
