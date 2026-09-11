"""
F0 Engine Abstraction Layer.

Provides unified dataclasses and abstract interfaces for fundamental frequency (F0)
extraction engines (RMVPE, TorchCREPE, and future models).
"""

import os
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Dict, Any, Optional, Union
import numpy as np


def resolve_model_path(relative_path: str) -> str:
    """
    Resolve model checkpoint path cleanly whether running from project root
    or from inside subdirectories like midi_backend.
    """
    if os.path.exists(relative_path):
        return relative_path

    # Check relative to project root (4 levels up from this file)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(current_dir, "../../../.."))
    candidate = os.path.join(project_root, relative_path)
    if os.path.exists(candidate):
        return candidate

    return relative_path


@dataclass
class F0Result:
    """
    Standardized result structure returned by all F0 extraction engines.
    """
    timestamps: np.ndarray          # Timestamp for each frame in seconds (1D float32)
    f0_hz: np.ndarray               # Fundamental frequency in Hz (1D float32; 0.0 = unvoiced)
    confidence: np.ndarray          # Voicing confidence / salience in [0.0, 1.0] (1D float32)
    voiced: np.ndarray              # Boolean array indicating voiced frames (confidence >= th & f0 > 0)
    engine_name: str                # Name of the engine used (e.g. "RMVPE", "CREPE")
    sample_rate: int = 16000        # Sampling rate of processed audio
    hop_length: int = 160           # Hop length in samples (e.g. 160 @ 16kHz = 10ms)
    metadata: Dict[str, Any] = field(default_factory=dict)

    @property
    def num_frames(self) -> int:
        return len(self.f0_hz)

    @property
    def voiced_frames_count(self) -> int:
        return int(np.sum(self.voiced))

    @property
    def voiced_percentage(self) -> float:
        if self.num_frames == 0:
            return 0.0
        return float((self.voiced_frames_count / self.num_frames) * 100.0)

    @property
    def voiced_f0(self) -> np.ndarray:
        return self.f0_hz[self.voiced]

    @property
    def min_f0(self) -> float:
        v = self.voiced_f0
        return float(np.min(v)) if len(v) > 0 else 0.0

    @property
    def max_f0(self) -> float:
        v = self.voiced_f0
        return float(np.max(v)) if len(v) > 0 else 0.0

    @property
    def mean_voiced_f0(self) -> float:
        v = self.voiced_f0
        return float(np.mean(v)) if len(v) > 0 else 0.0

    def to_dict(self) -> Dict[str, Any]:
        return {
            "engine_name": self.engine_name,
            "sample_rate": self.sample_rate,
            "hop_length": self.hop_length,
            "num_frames": self.num_frames,
            "voiced_frames": self.voiced_frames_count,
            "voiced_percentage": self.voiced_percentage,
            "min_f0": self.min_f0,
            "max_f0": self.max_f0,
            "mean_voiced_f0": self.mean_voiced_f0,
            "timestamps": self.timestamps.tolist(),
            "f0_hz": self.f0_hz.tolist(),
            "confidence": self.confidence.tolist(),
            "voiced": self.voiced.tolist(),
            "metadata": self.metadata,
        }


class F0Engine(ABC):
    """
    Abstract Base Class for neural F0 pitch extraction engines.
    """

    def __init__(self, model_path: str, device: str = "cpu"):
        self.model_path = model_path
        self.device = device
        self._is_loaded = False

    @property
    @abstractmethod
    def name(self) -> str:
        """Return human-readable engine name (e.g. 'RMVPE', 'CREPE')."""
        pass

    @property
    @abstractmethod
    def default_sample_rate(self) -> int:
        """Native audio sample rate expected by the model (e.g. 16000)."""
        pass

    @property
    @abstractmethod
    def default_hop_length(self) -> int:
        """Default hop length in samples."""
        pass

    @property
    def is_loaded(self) -> bool:
        return self._is_loaded

    @property
    def is_available(self) -> bool:
        """Alias for is_loaded indicating engine availability."""
        return self._is_loaded

    @abstractmethod
    def load(self) -> bool:
        """Load pretrained model weights into memory."""
        pass

    @abstractmethod
    def extract_f0(
        self,
        audio: Union[np.ndarray, bytes],
        sample_rate: Optional[int] = None,
        confidence_threshold: float = 0.3,
        **kwargs
    ) -> F0Result:
        """
        Extract frame-level F0 pitch contour, voicing, and confidence from audio.
        
        Args:
            audio: 1D numpy array of float32 audio or raw audio bytes (WAV/FLAC/MP3).
            sample_rate: Sampling rate of input audio (resampled if different from native).
            confidence_threshold: Voicing confidence threshold in [0.0, 1.0].
            
        Returns:
            F0Result object containing timestamps, f0_hz, confidence, voiced.
        """
        pass

    @abstractmethod
    def extract_chunk(
        self,
        chunk: np.ndarray,
        sample_rate: Optional[int] = None,
        confidence_threshold: float = 0.3,
        **kwargs
    ) -> F0Result:
        """
        Extract F0 from a short streaming audio chunk (for real-time microphone processing).
        
        Args:
            chunk: 1D numpy array of float32 audio samples.
            sample_rate: Sampling rate of input audio.
            confidence_threshold: Voicing threshold.
            
        Returns:
            F0Result for the frames in the chunk.
        """
        pass
