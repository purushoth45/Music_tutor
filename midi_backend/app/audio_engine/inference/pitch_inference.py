"""
Pitch Inference Module.

Integrates pretrained neural pitch models (RMVPE, TorchCREPE) into the backend
audio processing pipeline, converting incoming audio bytes into frame-level F0
and voicing confidence tracks.
"""

import os
from typing import Dict, Any, List, Optional
import numpy as np

from app.audio_engine.f0.base import F0Engine, F0Result
from app.audio_engine.f0.factory import get_f0_engine


class PitchInferenceEngine:
    """
    Inference interface for production and evaluation neural pitch models.
    """

    def __init__(
        self,
        model_dir: str = "models/pitch_model",
        engine_name: Optional[str] = None
    ):
        self.model_dir = model_dir
        self.engine_name = engine_name or os.environ.get("F0_ENGINE", "rmvpe")
        self.rmvpe_path = os.path.join(model_dir, "rmvpe.pt")
        self.crepe_path = os.path.join(model_dir, "full.pth")
        self.custom_path = os.path.join(model_dir, "model.pt")

        self.f0_engine: Optional[F0Engine] = None
        self._init_engine()

    def _init_engine(self):
        """Initialize and verify active F0 neural engine."""
        try:
            if self.engine_name.lower() in ("rmvpe", "crepe", "torchcrepe"):
                self.f0_engine = get_f0_engine(
                    engine_name=self.engine_name,
                    rmvpe_path=self.rmvpe_path,
                    crepe_path=self.crepe_path
                )
            else:
                self.f0_engine = None
        except Exception:
            self.f0_engine = None

    @property
    def is_loaded(self) -> bool:
        """
        Indicates whether a neural pitch model checkpoint is currently loaded.
        """
        return self.f0_engine is not None and self.f0_engine.is_loaded

    def run_inference(self, audio_bytes: bytes, confidence_threshold: float = 0.3) -> Dict[str, Any]:
        """
        Execute frame-level pitch model inference on audio waveform bytes.
        
        Args:
            audio_bytes: Raw PCM or encoded audio file bytes (WAV, FLAC, MP3).
            confidence_threshold: Voicing confidence threshold.
            
        Returns:
            Dict containing:
            - 'f0_sequence': List of F0 Hz values per frame
            - 'voicing_confidence': List of voicing probabilities per frame
            - 'timestamps': List of frame timestamps in seconds
            - 'model_source': 'pretrained' (explicitly denotes pretrained weights)
            - 'model_name': Name of neural engine (e.g. 'RMVPE', 'CREPE')
            - 'is_pretrained_model': True
            - 'is_trained_model': True (backward-compatible alias for checkpoint availability)
        """
        if not self.is_loaded or self.f0_engine is None:
            return {
                "f0_sequence": [],
                "voicing_confidence": [],
                "timestamps": [],
                "model_source": "none",
                "model_name": None,
                "is_pretrained_model": False,
                "is_trained_model": False,  # Preserved for backward compatibility
                "status": "Model weights pending. Awaiting neural pitch model checkpoint.",
            }

        try:
            result: F0Result = self.f0_engine.extract_f0(
                audio=audio_bytes,
                confidence_threshold=confidence_threshold
            )

            return {
                "f0_sequence": result.f0_hz.tolist(),
                "voicing_confidence": result.confidence.tolist(),
                "timestamps": result.timestamps.tolist(),
                "model_source": "pretrained",
                "model_name": self.f0_engine.name,
                "is_pretrained_model": True,
                "is_trained_model": True,  # Backward compatibility: indicates neural checkpoint availability
                "f0_result": result,
                "status": "Inference complete.",
            }
        except Exception as e:
            return {
                "f0_sequence": [],
                "voicing_confidence": [],
                "timestamps": [],
                "model_source": "pretrained",
                "model_name": self.f0_engine.name if self.f0_engine else None,
                "is_pretrained_model": True,
                "is_trained_model": True,
                "status": f"Inference failed: {str(e)}",
            }
