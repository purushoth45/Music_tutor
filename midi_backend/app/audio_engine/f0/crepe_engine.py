"""
TorchCREPE F0 Extraction Engine.

Implements the CREPE full-capacity pitch estimation model,
strictly compatible with models/pitch_model/full.pth.
"""

import os
import io
import time
import functools
from typing import Dict, Any, Optional, Union, Tuple
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from app.audio_engine.f0.base import F0Engine, F0Result, resolve_model_path


# ==============================================================================
# CREPE Architecture Definition (Matches full.pth checkpoint)
# ==============================================================================

class CrepeCore(nn.Module):
    """
    Crepe full capacity model definition matching full.pth.
    """

    def __init__(self):
        super().__init__()
        in_channels = [1, 1024, 128, 128, 128, 256]
        out_channels = [1024, 128, 128, 128, 256, 512]
        self.in_features = 2048

        kernel_sizes = [(512, 1)] + 5 * [(64, 1)]
        strides = [(4, 1)] + 5 * [(1, 1)]

        batch_norm_fn = functools.partial(
            nn.BatchNorm2d,
            eps=0.0010000000474974513,
            momentum=0.0
        )

        self.conv1 = nn.Conv2d(in_channels[0], out_channels[0], kernel_sizes[0], strides[0])
        self.conv1_BN = batch_norm_fn(num_features=out_channels[0])

        self.conv2 = nn.Conv2d(in_channels[1], out_channels[1], kernel_sizes[1], strides[1])
        self.conv2_BN = batch_norm_fn(num_features=out_channels[1])

        self.conv3 = nn.Conv2d(in_channels[2], out_channels[2], kernel_sizes[2], strides[2])
        self.conv3_BN = batch_norm_fn(num_features=out_channels[2])

        self.conv4 = nn.Conv2d(in_channels[3], out_channels[3], kernel_sizes[3], strides[3])
        self.conv4_BN = batch_norm_fn(num_features=out_channels[3])

        self.conv5 = nn.Conv2d(in_channels[4], out_channels[4], kernel_sizes[4], strides[4])
        self.conv5_BN = batch_norm_fn(num_features=out_channels[4])

        self.conv6 = nn.Conv2d(in_channels[5], out_channels[5], kernel_sizes[5], strides[5])
        self.conv6_BN = batch_norm_fn(num_features=out_channels[5])

        self.classifier = nn.Linear(self.in_features, 360)

    def _layer(self, x: torch.Tensor, conv: nn.Module, bn: nn.Module, padding: Tuple[int, int, int, int] = (0, 0, 31, 32)) -> torch.Tensor:
        x = F.pad(x, padding)
        x = conv(x)
        x = F.relu(x)
        x = bn(x)
        return F.max_pool2d(x, (2, 1), (2, 1))

    def forward(self, frames: torch.Tensor) -> torch.Tensor:
        """
        Forward pass over framed audio.
        frames shape: (B, 1024)
        Returns: salience probabilities (B, 360)
        """
        x = frames[:, None, :, None]  # (B, 1, 1024, 1)

        x = self._layer(x, self.conv1, self.conv1_BN, (0, 0, 254, 254))
        x = self._layer(x, self.conv2, self.conv2_BN)
        x = self._layer(x, self.conv3, self.conv3_BN)
        x = self._layer(x, self.conv4, self.conv4_BN)
        x = self._layer(x, self.conv5, self.conv5_BN)
        x = self._layer(x, self.conv6, self.conv6_BN)

        x = x.permute(0, 2, 1, 3).reshape(-1, self.in_features)
        logits = self.classifier(x)
        return torch.sigmoid(logits)


# ==============================================================================
# CREPE F0 Engine Implementation
# ==============================================================================

class CREPEF0Engine(F0Engine):
    """
    TorchCREPE F0 extraction engine backed by models/pitch_model/full.pth.
    """

    SAMPLE_RATE = 16000
    WINDOW_SIZE = 1024
    HOP_LENGTH = 160         # 10ms at 16kHz
    PITCH_BINS = 360
    CENTS_MAPPING = 1997.3794084376191 + 20.0 * np.arange(360)

    def __init__(self, model_path: str = "models/pitch_model/full.pth", device: Optional[str] = None):
        if device is None:
            device = "cpu"
        super().__init__(model_path=model_path, device=device)
        self.model: Optional[CrepeCore] = None
        self.load()

    @property
    def name(self) -> str:
        return "CREPE"

    @property
    def default_sample_rate(self) -> int:
        return self.SAMPLE_RATE

    @property
    def default_hop_length(self) -> int:
        return self.HOP_LENGTH

    def load(self) -> bool:
        """Load pretrained full.pth checkpoint strictly."""
        resolved = resolve_model_path(self.model_path)
        if not os.path.exists(resolved):
            self._is_loaded = False
            return False

        try:
            self.model = CrepeCore()
            ckpt = torch.load(resolved, map_location="cpu")
            self.model.load_state_dict(ckpt, strict=True)
            self.model.to(self.device)
            self.model.eval()
            self._is_loaded = True
            return True
        except Exception:
            self._is_loaded = False
            self.model = None
            return False

    def _decode_audio(self, audio: Union[np.ndarray, bytes], sample_rate: Optional[int]) -> Tuple[np.ndarray, int]:
        """Decode input audio to mono float32 numpy array and sample rate."""
        if isinstance(audio, bytes):
            import soundfile as sf
            wav, sr = sf.read(io.BytesIO(audio), dtype="float32")
            if wav.ndim > 1:
                wav = np.mean(wav, axis=1)
            return wav, sr

        wav = np.asarray(audio, dtype=np.float32)
        if wav.ndim > 1:
            wav = np.mean(wav, axis=0)
        sr = sample_rate or self.SAMPLE_RATE
        return wav, sr

    def _resample_if_needed(self, wav: np.ndarray, sr: int) -> np.ndarray:
        """Resample waveform to 16 kHz if necessary."""
        if sr == self.SAMPLE_RATE:
            return wav
        import scipy.signal
        num_samples = int(round(len(wav) * self.SAMPLE_RATE / sr))
        return scipy.signal.resample(wav, num_samples).astype(np.float32)

    def _frame_audio(self, audio: np.ndarray) -> np.ndarray:
        """
        Create 1024-sample frames with center padding, normalized to zero mean & unit variance.
        """
        pad_amount = self.WINDOW_SIZE // 2
        padded = np.pad(audio, (pad_amount, pad_amount), mode="constant")
        num_frames = 1 + (len(padded) - self.WINDOW_SIZE) // self.HOP_LENGTH

        shape = (num_frames, self.WINDOW_SIZE)
        strides = (padded.strides[0] * self.HOP_LENGTH, padded.strides[0])
        frames = np.lib.stride_tricks.as_strided(padded, shape=shape, strides=strides).copy()

        # Zero mean and unit variance per frame (CREPE preprocessing requirement)
        means = np.mean(frames, axis=1, keepdims=True)
        stds = np.std(frames, axis=1, keepdims=True)
        stds[stds < 1e-8] = 1.0
        frames = (frames - means) / stds

        return frames

    def _salience_to_f0(self, salience: np.ndarray, threshold: float = 0.25) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Convert 360-bin salience matrix to F0 (Hz), confidence, and voiced mask.
        Uses local weighted average around peak bin.
        """
        num_frames = salience.shape[0]
        f0_hz = np.zeros(num_frames, dtype=np.float32)
        confidence = np.zeros(num_frames, dtype=np.float32)
        voiced = np.zeros(num_frames, dtype=bool)

        if num_frames == 0:
            return f0_hz, confidence, voiced

        max_indices = np.argmax(salience, axis=1)
        max_vals = np.max(salience, axis=1)
        confidence = max_vals.astype(np.float32)

        for i in range(num_frames):
            c_val = max_vals[i]
            if c_val >= threshold:
                center = max_indices[i]
                start = max(0, center - 4)
                end = min(360, center + 5)
                sub_s = salience[i, start:end]
                sub_cents = self.CENTS_MAPPING[start:end]
                w_sum = np.sum(sub_s)
                if w_sum > 0:
                    avg_cent = np.sum(sub_s * sub_cents) / w_sum
                    f0 = 10.0 * (2.0 ** (avg_cent / 1200.0))
                    f0_hz[i] = float(f0)
                    voiced[i] = True

        return f0_hz, confidence, voiced

    def extract_f0(
        self,
        audio: Union[np.ndarray, bytes],
        sample_rate: Optional[int] = None,
        confidence_threshold: float = 0.25,
        batch_size: int = 64,
        **kwargs
    ) -> F0Result:
        """
        Extract frame-level F0 pitch contour using TorchCREPE full model.
        """
        if not self._is_loaded or self.model is None:
            raise RuntimeError(f"TorchCREPE model checkpoint could not be loaded from {self.model_path}")

        wav, sr = self._decode_audio(audio, sample_rate)
        if len(wav) == 0:
            return F0Result(
                timestamps=np.array([], dtype=np.float32),
                f0_hz=np.array([], dtype=np.float32),
                confidence=np.array([], dtype=np.float32),
                voiced=np.array([], dtype=bool),
                engine_name=self.name,
                sample_rate=self.SAMPLE_RATE,
                hop_length=self.HOP_LENGTH,
            )

        wav = self._resample_if_needed(wav, sr)
        frames = self._frame_audio(wav)

        t0 = time.time()
        num_frames = frames.shape[0]
        salience_chunks = []

        with torch.no_grad():
            for i in range(0, num_frames, batch_size):
                batch_np = frames[i:i + batch_size]
                batch_tensor = torch.from_numpy(batch_np).float().to(self.device)
                sal = self.model(batch_tensor)
                salience_chunks.append(sal.cpu().numpy())

        salience = np.concatenate(salience_chunks, axis=0) if salience_chunks else np.empty((0, 360))
        infer_time = time.time() - t0

        f0_hz, confidence, voiced = self._salience_to_f0(salience, threshold=confidence_threshold)
        timestamps = (np.arange(len(f0_hz)) * (self.HOP_LENGTH / self.SAMPLE_RATE)).astype(np.float32)

        return F0Result(
            timestamps=timestamps,
            f0_hz=f0_hz,
            confidence=confidence,
            voiced=voiced,
            engine_name=self.name,
            sample_rate=self.SAMPLE_RATE,
            hop_length=self.HOP_LENGTH,
            metadata={"inference_time": infer_time}
        )

    def extract_chunk(
        self,
        chunk: np.ndarray,
        sample_rate: Optional[int] = None,
        confidence_threshold: float = 0.25,
        **kwargs
    ) -> F0Result:
        """
        Run inference on an audio chunk (for real-time streaming).
        """
        return self.extract_f0(
            audio=chunk,
            sample_rate=sample_rate,
            confidence_threshold=confidence_threshold,
            **kwargs
        )
