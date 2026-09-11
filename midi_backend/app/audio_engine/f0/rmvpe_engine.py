"""
RMVPE F0 Extraction Engine.

Implements the official DeepUnet + BiGRU RMVPE neural network architecture
for vocal fundamental frequency extraction, fully compatible with models/pitch_model/rmvpe.pt.
"""

import os
import io
import time
from typing import Dict, Any, Optional, Union, Tuple
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

from app.audio_engine.f0.base import F0Engine, F0Result, resolve_model_path


# ==============================================================================
# RMVPE Neural Architecture (Strictly matched to rmvpe.pt checkpoint)
# ==============================================================================

class ConvBlockRes(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, momentum: float = 0.01):
        super().__init__()
        self.conv = nn.Sequential(
            nn.Conv2d(in_channels, out_channels, (3, 3), (1, 1), (1, 1), bias=False),
            nn.BatchNorm2d(out_channels, momentum=momentum),
            nn.ReLU(),
            nn.Conv2d(out_channels, out_channels, (3, 3), (1, 1), (1, 1), bias=False),
            nn.BatchNorm2d(out_channels, momentum=momentum),
            nn.ReLU(),
        )
        if in_channels != out_channels:
            self.shortcut = nn.Conv2d(in_channels, out_channels, (1, 1))
            self.is_shortcut = True
        else:
            self.is_shortcut = False

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.conv(x) + (self.shortcut(x) if self.is_shortcut else x)


class ResEncoderBlock(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, kernel_size: Optional[Tuple[int, int]], n_blocks: int = 1, momentum: float = 0.01):
        super().__init__()
        self.n_blocks = n_blocks
        self.conv = nn.ModuleList([
            ConvBlockRes(in_channels if i == 0 else out_channels, out_channels, momentum)
            for i in range(n_blocks)
        ])
        self.kernel_size = kernel_size
        if kernel_size is not None:
            self.pool = nn.AvgPool2d(kernel_size=kernel_size)

    def forward(self, x: torch.Tensor) -> Union[torch.Tensor, Tuple[torch.Tensor, torch.Tensor]]:
        for c in self.conv:
            x = c(x)
        if self.kernel_size is not None:
            return x, self.pool(x)
        return x


class ResDecoderBlock(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, stride: Tuple[int, int], n_blocks: int = 1, momentum: float = 0.01):
        super().__init__()
        out_padding = (0, 1) if stride == (1, 2) else (1, 1)
        self.conv1 = nn.Sequential(
            nn.ConvTranspose2d(in_channels, out_channels, (3, 3), stride=stride, padding=(1, 1), output_padding=out_padding, bias=False),
            nn.BatchNorm2d(out_channels, momentum=momentum),
            nn.ReLU(),
        )
        self.conv2 = nn.ModuleList([
            ConvBlockRes(out_channels * 2 if i == 0 else out_channels, out_channels, momentum)
            for i in range(n_blocks)
        ])

    def forward(self, x: torch.Tensor, concat_tensor: torch.Tensor) -> torch.Tensor:
        x = self.conv1(x)
        diff_h = concat_tensor.shape[2] - x.shape[2]
        diff_w = concat_tensor.shape[3] - x.shape[3]
        if diff_h != 0 or diff_w != 0:
            if diff_h > 0 or diff_w > 0:
                x = F.pad(x, [0, max(0, diff_w), 0, max(0, diff_h)])
            if diff_h < 0 or diff_w < 0:
                x = x[:, :, :concat_tensor.shape[2], :concat_tensor.shape[3]]
        x = torch.cat((x, concat_tensor), dim=1)
        for c in self.conv2:
            x = c(x)
        return x


class Encoder(nn.Module):
    def __init__(self, in_channels: int, in_size: int, n_encoders: int, kernel_size: Tuple[int, int], n_blocks: int, out_channels: int = 16, momentum: float = 0.01):
        super().__init__()
        self.n_encoders = n_encoders
        self.bn = nn.BatchNorm2d(in_channels, momentum=momentum)
        self.layers = nn.ModuleList()
        self.latent_channels = []
        for _ in range(n_encoders):
            self.layers.append(ResEncoderBlock(in_channels, out_channels, kernel_size, n_blocks, momentum=momentum))
            self.latent_channels.append([out_channels, in_size])
            in_channels = out_channels
            out_channels *= 2
            in_size //= 2
        self.out_size = in_size
        self.out_channel = out_channels

    def forward(self, x: torch.Tensor) -> Tuple[torch.Tensor, list]:
        concat_tensors = []
        x = self.bn(x)
        for layer in self.layers:
            cat, x = layer(x)
            concat_tensors.append(cat)
        return x, concat_tensors


class Intermediate(nn.Module):
    def __init__(self, in_channels: int, out_channels: int, n_inters: int, n_blocks: int, momentum: float = 0.01):
        super().__init__()
        self.layers = nn.ModuleList([
            ResEncoderBlock(in_channels if i == 0 else out_channels, out_channels, None, n_blocks, momentum)
            for i in range(n_inters)
        ])

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        for layer in self.layers:
            x = layer(x)
        return x


class Decoder(nn.Module):
    def __init__(self, in_channels: int, n_decoders: int, stride: Tuple[int, int], n_blocks: int, momentum: float = 0.01):
        super().__init__()
        self.layers = nn.ModuleList()
        for _ in range(n_decoders):
            out_channels = in_channels // 2
            self.layers.append(ResDecoderBlock(in_channels, out_channels, stride, n_blocks, momentum))
            in_channels = out_channels

    def forward(self, x: torch.Tensor, concat_tensors: list) -> torch.Tensor:
        for i, layer in enumerate(self.layers):
            x = layer(x, concat_tensors[-1 - i])
        return x


class DeepUnet0(nn.Module):
    def __init__(self, kernel_size: Tuple[int, int] = (2, 2), n_blocks: int = 4, en_de_layers: int = 5, inter_layers: int = 4, in_channels: int = 1, en_out_channels: int = 16):
        super().__init__()
        self.encoder = Encoder(in_channels, 256, en_de_layers, kernel_size, n_blocks, en_out_channels)
        self.intermediate = Intermediate(self.encoder.out_channel // 2, self.encoder.out_channel, inter_layers, n_blocks)
        self.decoder = Decoder(self.encoder.out_channel, en_de_layers, kernel_size, n_blocks)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x, concat = self.encoder(x)
        x = self.intermediate(x)
        return self.decoder(x, concat)


class BiGRU(nn.Module):
    def __init__(self, in_features: int, hidden_features: int, num_layers: int = 1):
        super().__init__()
        self.gru = nn.GRU(in_features, hidden_features, num_layers=num_layers, batch_first=True, bidirectional=True)

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.gru(x)[0]


class RMVPECore(nn.Module):
    """Full neural backbone loading rmvpe.pt."""
    def __init__(self, n_blocks: int = 4, n_gru: int = 1, kernel_size: Tuple[int, int] = (2, 2)):
        super().__init__()
        self.unet = DeepUnet0(kernel_size=kernel_size, n_blocks=n_blocks)
        self.cnn = nn.Conv2d(16, 3, (3, 3), padding=(1, 1))
        self.fc = nn.Sequential(
            BiGRU(3 * 128, 256, n_gru),
            nn.Linear(512, 360),
            nn.Dropout(0.25),
            nn.Sigmoid()
        )

    def forward(self, mel: torch.Tensor) -> torch.Tensor:
        # mel shape: (B, 1, T, 256)
        orig_t = mel.shape[2]
        # Pad time dimension to at least 32 frames and a multiple of 16 for UNet 4-stage downsampling
        target_t = max(32, int(np.ceil(orig_t / 16.0)) * 16)
        if orig_t < target_t:
            mel = F.pad(mel, (0, 0, 0, target_t - orig_t), mode="replicate")

        x = self.unet(mel)
        x = self.cnn(x)                       # (B, 3, T, 128)
        x = x.transpose(1, 2).flatten(-2)      # (B, T, 3 * 128 = 384)
        x = self.fc(x)                         # (B, T, 360)

        if x.shape[1] != orig_t:
            x = x[:, :orig_t, :]
        return x


# ==============================================================================
# RMVPE F0 Engine Implementation
# ==============================================================================

class RMVPEF0Engine(F0Engine):
    """
    RMVPE F0 extraction engine backed by models/pitch_model/rmvpe.pt.
    """

    SAMPLE_RATE = 16000
    N_MELS = 128
    N_CLASS = 360
    HOP_LENGTH = 160        # 10ms at 16kHz
    FILTER_LENGTH = 1024
    WIN_LENGTH = 1024
    MEL_FMIN = 30.0
    MEL_FMAX = 8000.0
    CENTS_MAPPING = np.linspace(0, 7180, 360) + 1997.3794084376191

    def __init__(self, model_path: str = "models/pitch_model/rmvpe.pt", device: Optional[str] = None):
        if device is None:
            device = "mps" if torch.backends.mps.is_available() else "cpu"
            # PyTorch MPS GRU has edge cases in some versions; CPU is fast and rock solid for RMVPE
            device = "cpu"
        super().__init__(model_path=model_path, device=device)
        self.model: Optional[RMVPECore] = None
        self._mel_basis: Optional[torch.Tensor] = None
        self._stft_window: Optional[torch.Tensor] = None
        self.load()

    @property
    def name(self) -> str:
        return "RMVPE"

    @property
    def default_sample_rate(self) -> int:
        return self.SAMPLE_RATE

    @property
    def default_hop_length(self) -> int:
        return self.HOP_LENGTH

    def load(self) -> bool:
        """Load pretrained rmvpe.pt checkpoint strictly."""
        resolved = resolve_model_path(self.model_path)
        if not os.path.exists(resolved):
            self._is_loaded = False
            return False

        try:
            self.model = RMVPECore(n_blocks=4, n_gru=1, kernel_size=(2, 2))
            ckpt = torch.load(resolved, map_location="cpu")
            self.model.load_state_dict(ckpt, strict=True)
            self.model.to(self.device)
            self.model.eval()

            # Pre-compute STFT window and mel filterbank
            from librosa.filters import mel as librosa_mel
            mel_basis_np = librosa_mel(
                sr=self.SAMPLE_RATE,
                n_fft=self.FILTER_LENGTH,
                n_mels=self.N_MELS,
                fmin=self.MEL_FMIN,
                fmax=self.MEL_FMAX,
                htk=True
            )
            self._mel_basis = torch.from_numpy(mel_basis_np).float().to(self.device)
            self._stft_window = torch.hann_window(self.WIN_LENGTH).to(self.device)

            self._is_loaded = True
            return True
        except Exception as e:
            self._is_loaded = False
            self.model = None
            return False

    def compute_mel(self, audio: torch.Tensor) -> torch.Tensor:
        """
        Extract mel-spectrogram matching Dream-High RMVPE specifications.
        Audio shape: (B, T_samples). Returns: (B, 1, T_frames, 256)
        """
        # Ensure STFT pad
        stft = torch.stft(
            audio,
            n_fft=self.FILTER_LENGTH,
            hop_length=self.HOP_LENGTH,
            win_length=self.WIN_LENGTH,
            window=self._stft_window,
            center=True,
            pad_mode="reflect",
            return_complex=True
        )
        magnitudes = torch.abs(stft)  # (B, 1025, T_frames)
        mel_output = torch.matmul(self._mel_basis, magnitudes)  # (B, 256, T_frames)
        mel_output = torch.log(torch.clamp(mel_output, min=1e-5))
        mel_output = mel_output.transpose(-1, -2).unsqueeze(1)  # (B, 1, T_frames, 256)
        return mel_output

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

    def _salience_to_f0(self, salience: np.ndarray, threshold: float = 0.3) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
        """
        Convert 360-bin salience matrix to F0 (Hz), confidence, and voiced mask.
        salience shape: (T_frames, 360)
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
                sub_salience = salience[i, start:end]
                sub_cents = self.CENTS_MAPPING[start:end]
                w_sum = np.sum(sub_salience)
                if w_sum > 0:
                    avg_cent = np.sum(sub_salience * sub_cents) / w_sum
                    f0 = 10.0 * (2.0 ** (avg_cent / 1200.0))
                    f0_hz[i] = float(f0)
                    voiced[i] = True

        return f0_hz, confidence, voiced

    def extract_f0(
        self,
        audio: Union[np.ndarray, bytes],
        sample_rate: Optional[int] = None,
        confidence_threshold: float = 0.3,
        **kwargs
    ) -> F0Result:
        """
        Extract frame-level F0 pitch contour using RMVPE.
        """
        if not self._is_loaded or self.model is None:
            raise RuntimeError(f"RMVPE model checkpoint could not be loaded from {self.model_path}")

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

        # Peak normalization
        peak = np.max(np.abs(wav))
        if peak > 0:
            wav = wav / peak

        # Convert to tensor
        tensor_audio = torch.from_numpy(wav).unsqueeze(0).float().to(self.device)

        t0 = time.time()
        with torch.no_grad():
            mel = self.compute_mel(tensor_audio)
            salience_tensor = self.model(mel)  # (1, T, 360)
            salience = salience_tensor.squeeze(0).cpu().numpy()

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
        confidence_threshold: float = 0.3,
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
